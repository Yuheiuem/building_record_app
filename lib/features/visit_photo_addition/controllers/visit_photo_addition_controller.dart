import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/building_detail_data.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/models/record_submission_result.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/building_detail_api_service.dart';
import '../../../data/services/record_image_picker_service.dart';
import '../../../data/services/record_submission_api_service.dart';

enum VisitPhotoAdditionUploadStatus {
  pending,
  uploading,
  uploaded,
  failed,
}

class VisitPhotoAdditionController extends ChangeNotifier {
  VisitPhotoAdditionController({
    required this.buildingId,
    required this.visitId,
    required AuthService authService,
    required BuildingDetailApiService buildingDetailApiService,
    required RecordImagePickerService imagePickerService,
    required RecordSubmissionApiService recordSubmissionApiService,
  }) : _authService = authService,
       _buildingDetailApiService = buildingDetailApiService,
       _imagePickerService = imagePickerService,
       _recordSubmissionApiService = recordSubmissionApiService;

  final String buildingId;
  final String visitId;
  final AuthService _authService;
  final BuildingDetailApiService _buildingDetailApiService;
  final RecordImagePickerService _imagePickerService;
  final RecordSubmissionApiService _recordSubmissionApiService;

  final List<RecordDraftPhoto> _photos = <RecordDraftPhoto>[];
  final Map<String, String> _requestIds = <String, String>{};
  final Map<String, int> _displayOrders = <String, int>{};
  final Map<String, VisitPhotoAdditionUploadStatus> _uploadStatuses =
      <String, VisitPhotoAdditionUploadStatus>{};
  final Map<String, UploadRecordPhotoResult> _uploadResults =
      <String, UploadRecordPhotoResult>{};

  BuildingDetailData? _detail;
  BuildingVisit? _visit;
  bool _isLoading = false;
  bool _isPicking = false;
  bool _isUploading = false;
  bool _isRefreshingAuthentication = false;
  bool _requiresReauthentication = false;
  bool _succeeded = false;
  String? _authenticationFailureToken;
  String? _errorMessage;
  String? _noticeMessage;
  String? _errorDetail;
  Duration? _lastUploadDuration;
  int _nextDisplayOrder = 1;
  double? _photoLatitude;
  double? _photoLongitude;
  double? _photoAccuracyM;
  String _photoLocationSource = '';

  UnmodifiableListView<RecordDraftPhoto> get photos =>
      UnmodifiableListView<RecordDraftPhoto>(_photos);
  BuildingDetailData? get detail => _detail;
  BuildingVisit? get visit => _visit;
  bool get isLoading => _isLoading;
  bool get isPicking => _isPicking;
  bool get isUploading => _isUploading;
  bool get isRefreshingAuthentication => _isRefreshingAuthentication;
  bool get requiresReauthentication => _requiresReauthentication;
  bool get succeeded => _succeeded;
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;
  String? get errorDetail => _errorDetail;
  Duration? get lastUploadDuration => _lastUploadDuration;
  int get photoCount => _photos.length;
  int get totalBytes => _photos.fold<int>(
    0,
    (int total, RecordDraftPhoto photo) => total + photo.byteSize,
  );
  int get uploadedPhotoCount => _uploadStatuses.values
      .where(
        (VisitPhotoAdditionUploadStatus status) =>
            status == VisitPhotoAdditionUploadStatus.uploaded,
      )
      .length;
  int get failedPhotoCount => _uploadStatuses.values
      .where(
        (VisitPhotoAdditionUploadStatus status) =>
            status == VisitPhotoAdditionUploadStatus.failed,
      )
      .length;
  double get uploadProgress {
    if (_photos.isEmpty) {
      return 0;
    }
    return uploadedPhotoCount / _photos.length;
  }

  bool get canAddPhotos =>
      !_isPicking && !_isUploading && !_succeeded && !_requiresReauthentication;
  bool get canUpload =>
      !_isUploading &&
      !_succeeded &&
      !_requiresReauthentication &&
      _photos.isNotEmpty &&
      _visit != null &&
      _photoLatitude != null &&
      _photoLongitude != null;

  VisitPhotoAdditionUploadStatus uploadStatus(String photoId) {
    return _uploadStatuses[photoId] ??
        VisitPhotoAdditionUploadStatus.pending;
  }

  UploadRecordPhotoResult? uploadResult(String photoId) {
    return _uploadResults[photoId];
  }

  Future<void> loadDetail() async {
    if (_isLoading || _isUploading) {
      return;
    }

    final String? idToken = _authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      _errorMessage = 'Googleログイン情報を取得できませんでした。もう一度ログインしてください。';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    _errorDetail = null;
    notifyListeners();

    try {
      final BuildingDetailData result =
          await _buildingDetailApiService.getBuildingDetail(
            requestId: const Uuid().v4(),
            clientVersion: AppConfig.version,
            idToken: idToken,
            buildingId: buildingId,
          );

      BuildingVisit? selectedVisit;
      for (final BuildingVisit candidate in result.visits) {
        if (candidate.visitId == visitId) {
          selectedVisit = candidate;
          break;
        }
      }

      if (selectedVisit == null) {
        _detail = null;
        _visit = null;
        _errorMessage = '指定した訪問記録が見つかりませんでした。';
        return;
      }

      final List<BuildingPhoto> existingPhotos = result.photosForVisit(visitId);
      int highestDisplayOrder = 0;
      for (final BuildingPhoto photo in existingPhotos) {
        if (photo.displayOrder > highestDisplayOrder) {
          highestDisplayOrder = photo.displayOrder;
        }
      }

      _detail = result;
      _visit = selectedVisit;
      _nextDisplayOrder = highestDisplayOrder + 1;
      _setPhotoLocation(result, selectedVisit);
      _requiresReauthentication = false;
      _authenticationFailureToken = null;
    } on BuildingDetailApiException catch (error) {
      if (_isAuthenticationRequired(error.errorCode)) {
        _markAuthenticationRequired(idToken);
        _errorMessage = 'Googleログインの有効期限が切れました。認証を更新してください。';
      } else {
        _errorMessage = error.message;
      }
    } catch (_) {
      _errorMessage = '建物と訪問の情報を取得できませんでした。もう一度お試しください。';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _setPhotoLocation(
    BuildingDetailData detail,
    BuildingVisit selectedVisit,
  ) {
    if (selectedVisit.latitude != null && selectedVisit.longitude != null) {
      _photoLatitude = selectedVisit.latitude;
      _photoLongitude = selectedVisit.longitude;
      _photoAccuracyM = selectedVisit.accuracyM;
      _photoLocationSource = selectedVisit.locationSource.isEmpty
          ? 'manual'
          : selectedVisit.locationSource;
      return;
    }

    if (detail.building.latitude != null && detail.building.longitude != null) {
      _photoLatitude = detail.building.latitude;
      _photoLongitude = detail.building.longitude;
      _photoAccuracyM = null;
      _photoLocationSource = 'building_fallback';
      return;
    }

    _photoLatitude = null;
    _photoLongitude = null;
    _photoAccuracyM = null;
    _photoLocationSource = '';
    _errorMessage = '訪問位置と建物代表位置がないため、この訪問へ写真を追加できません。';
  }

  Future<void> addPhotos() async {
    if (!canAddPhotos) {
      return;
    }

    _isPicking = true;
    _errorMessage = null;
    _errorDetail = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final List<RecordDraftPhoto> selectedPhotos =
          await _imagePickerService.pickImages();
      if (selectedPhotos.isEmpty) {
        return;
      }

      final List<RecordDraftPhoto> acceptedPhotos = <RecordDraftPhoto>[];
      int unsupportedCount = 0;
      int oversizedCount = 0;

      for (final RecordDraftPhoto photo in selectedPhotos) {
        if (!photo.isSupportedImage) {
          unsupportedCount += 1;
          continue;
        }
        if (photo.byteSize > AppConfig.recordMaxPhotoBytes) {
          oversizedCount += 1;
          continue;
        }
        acceptedPhotos.add(photo);
      }

      for (final RecordDraftPhoto photo in acceptedPhotos) {
        _photos.add(photo);
        _requestIds[photo.photoId] = const Uuid().v4();
        _displayOrders[photo.photoId] = _nextDisplayOrder;
        _nextDisplayOrder += 1;
        _uploadStatuses[photo.photoId] =
            VisitPhotoAdditionUploadStatus.pending;
      }

      final List<String> rejectedReasons = <String>[];
      if (unsupportedCount > 0) {
        rejectedReasons.add('未対応形式 $unsupportedCount枚');
      }
      if (oversizedCount > 0) {
        rejectedReasons.add('5MB超過 $oversizedCount枚');
      }
      if (rejectedReasons.isNotEmpty) {
        _errorMessage = '${rejectedReasons.join('、')}は追加しませんでした。';
      }
      if (acceptedPhotos.isNotEmpty) {
        _noticeMessage = '${acceptedPhotos.length}枚を追加候補へ入れました。';
      }
    } catch (_) {
      _errorMessage = '写真を選択できませんでした。もう一度お試しください。';
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  void removePhoto(String photoId) {
    if (_isUploading || _succeeded) {
      return;
    }
    final VisitPhotoAdditionUploadStatus status = uploadStatus(photoId);
    if (status == VisitPhotoAdditionUploadStatus.uploaded ||
        status == VisitPhotoAdditionUploadStatus.uploading) {
      return;
    }

    final int previousCount = _photos.length;
    _photos.removeWhere((RecordDraftPhoto photo) => photo.photoId == photoId);
    if (_photos.length == previousCount) {
      return;
    }

    _requestIds.remove(photoId);
    _displayOrders.remove(photoId);
    _uploadStatuses.remove(photoId);
    _uploadResults.remove(photoId);
    _noticeMessage = '写真を1枚削除しました。';
    _errorMessage = null;
    _errorDetail = null;
    notifyListeners();
  }

  void clearUnsentPhotos() {
    if (_isUploading || _succeeded) {
      return;
    }

    final List<String> removableIds = _photos
        .where((RecordDraftPhoto photo) {
          final VisitPhotoAdditionUploadStatus status = uploadStatus(
            photo.photoId,
          );
          return status != VisitPhotoAdditionUploadStatus.uploaded &&
              status != VisitPhotoAdditionUploadStatus.uploading;
        })
        .map((RecordDraftPhoto photo) => photo.photoId)
        .toList(growable: false);

    if (removableIds.isEmpty) {
      return;
    }

    final Set<String> removableSet = removableIds.toSet();
    _photos.removeWhere(
      (RecordDraftPhoto photo) => removableSet.contains(photo.photoId),
    );
    for (final String photoId in removableIds) {
      _requestIds.remove(photoId);
      _displayOrders.remove(photoId);
      _uploadStatuses.remove(photoId);
      _uploadResults.remove(photoId);
    }
    _noticeMessage = '未送信の写真をすべて削除しました。';
    _errorMessage = null;
    _errorDetail = null;
    notifyListeners();
  }

  Future<void> uploadPhotos() async {
    if (!canUpload) {
      if (_photos.isEmpty) {
        _errorMessage = '写真を1枚以上選択してください。';
      } else if (_photoLatitude == null || _photoLongitude == null) {
        _errorMessage = '写真へ設定する位置情報がありません。';
      }
      notifyListeners();
      return;
    }

    final String? idToken = _authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      _errorMessage = 'Googleログイン情報を取得できませんでした。';
      notifyListeners();
      return;
    }

    for (final RecordDraftPhoto photo in _photos) {
      if (uploadStatus(photo.photoId) ==
          VisitPhotoAdditionUploadStatus.failed) {
        _uploadStatuses[photo.photoId] =
            VisitPhotoAdditionUploadStatus.pending;
      }
    }

    final List<RecordDraftPhoto> pendingPhotos = _photos
        .where(
          (RecordDraftPhoto photo) =>
              uploadStatus(photo.photoId) !=
              VisitPhotoAdditionUploadStatus.uploaded,
        )
        .toList(growable: false);

    if (pendingPhotos.isEmpty) {
      _succeeded = true;
      _noticeMessage = '写真の追加が完了しています。';
      notifyListeners();
      return;
    }

    _isUploading = true;
    _errorMessage = null;
    _errorDetail = null;
    _noticeMessage = null;
    _lastUploadDuration = null;
    notifyListeners();

    final Stopwatch stopwatch = Stopwatch()..start();
    final List<String> failures = <String>[];

    try {
      for (int offset = 0; offset < pendingPhotos.length; offset += 2) {
        final int end = (offset + 2).clamp(0, pendingPhotos.length).toInt();
        final List<RecordDraftPhoto> batch = pendingPhotos.sublist(offset, end);

        for (final RecordDraftPhoto photo in batch) {
          _uploadStatuses[photo.photoId] =
              VisitPhotoAdditionUploadStatus.uploading;
        }
        notifyListeners();

        final List<_VisitPhotoUploadAttempt> attempts = await Future.wait(
          batch.map((RecordDraftPhoto photo) {
            return _uploadPhoto(idToken: idToken, photo: photo);
          }),
        );

        for (final _VisitPhotoUploadAttempt attempt in attempts) {
          if (attempt.result != null) {
            _uploadResults[attempt.photo.photoId] = attempt.result!;
            _uploadStatuses[attempt.photo.photoId] =
                VisitPhotoAdditionUploadStatus.uploaded;
            continue;
          }

          _uploadStatuses[attempt.photo.photoId] =
              VisitPhotoAdditionUploadStatus.failed;
          if (attempt.authenticationRequired) {
            _markAuthenticationRequired(idToken);
          }
          failures.add(
            '${attempt.photo.fileName}: ${attempt.errorMessage ?? '不明なエラー'}',
          );
        }
        notifyListeners();

        if (failures.isNotEmpty) {
          break;
        }
      }

      if (failures.isEmpty && uploadedPhotoCount == _photos.length) {
        _succeeded = true;
        _noticeMessage = 'この訪問へ写真${_photos.length}枚を追加しました。';
      } else {
        _errorMessage = _requiresReauthentication
            ? 'ログインの有効期限が切れました。'
            : '送信できませんでした。もう一度送信してください。';
        _errorDetail = failures.join('\n');
      }
    } finally {
      stopwatch.stop();
      _lastUploadDuration = stopwatch.elapsed;
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<_VisitPhotoUploadAttempt> _uploadPhoto({
    required String idToken,
    required RecordDraftPhoto photo,
  }) async {
    final BuildingVisit selectedVisit = _visit!;
    try {
      final UploadRecordPhotoResult result =
          await _recordSubmissionApiService.uploadPhoto(
            requestId: _requestIds[photo.photoId]!,
            clientVersion: AppConfig.version,
            idToken: idToken,
            buildingId: buildingId,
            visitId: visitId,
            photoId: photo.photoId,
            fileName: photo.fileName,
            mimeType: photo.mimeType,
            bytes: photo.bytes,
            takenAt: selectedVisit.visitedAt,
            latitude: _photoLatitude!,
            longitude: _photoLongitude!,
            accuracyM: _photoAccuracyM,
            locationSource: _photoLocationSource,
            displayOrder: _displayOrders[photo.photoId]!,
          );
      return _VisitPhotoUploadAttempt.success(photo, result);
    } on RecordSubmissionApiException catch (error) {
      return _VisitPhotoUploadAttempt.failure(
        photo,
        error.message,
        authenticationRequired: _isAuthenticationRequired(error.errorCode),
      );
    } catch (_) {
      return _VisitPhotoUploadAttempt.failure(photo, '不明なエラー');
    }
  }

  Future<void> refreshAuthentication() async {
    if (_isRefreshingAuthentication) {
      return;
    }

    _isRefreshingAuthentication = true;
    notifyListeners();

    final bool refreshed = await _authService.refreshIdToken();
    final String? currentToken = _authService.idToken;
    final bool hasFreshToken =
        refreshed &&
        currentToken != null &&
        currentToken.isNotEmpty &&
        currentToken != _authenticationFailureToken;

    _isRefreshingAuthentication = false;
    if (hasFreshToken) {
      _requiresReauthentication = false;
      _authenticationFailureToken = null;
      _errorMessage = null;
      _errorDetail = null;
      _noticeMessage = '認証を更新しました。失敗した写真をもう一度送信してください。';
    } else {
      _errorMessage = '認証を自動更新できませんでした。もう一度Googleログインしてください。';
    }
    notifyListeners();
  }

  void _markAuthenticationRequired(String failedToken) {
    _requiresReauthentication = true;
    _authenticationFailureToken = failedToken;
  }

  bool _isAuthenticationRequired(String? errorCode) {
    return errorCode == 'AUTH_REQUIRED';
  }
}

class _VisitPhotoUploadAttempt {
  const _VisitPhotoUploadAttempt._({
    required this.photo,
    required this.result,
    required this.errorMessage,
    required this.authenticationRequired,
  });

  factory _VisitPhotoUploadAttempt.success(
    RecordDraftPhoto photo,
    UploadRecordPhotoResult result,
  ) {
    return _VisitPhotoUploadAttempt._(
      photo: photo,
      result: result,
      errorMessage: null,
      authenticationRequired: false,
    );
  }

  factory _VisitPhotoUploadAttempt.failure(
    RecordDraftPhoto photo,
    String errorMessage, {
    bool authenticationRequired = false,
  }) {
    return _VisitPhotoUploadAttempt._(
      photo: photo,
      result: null,
      errorMessage: errorMessage,
      authenticationRequired: authenticationRequired,
    );
  }

  final RecordDraftPhoto photo;
  final UploadRecordPhotoResult? result;
  final String? errorMessage;
  final bool authenticationRequired;
}
