import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/bootstrap_data.dart';
import '../../../data/models/building.dart';
import '../../../data/models/building_tag.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/models/record_submission_result.dart';
import '../../../data/models/tag_creation_result.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/bootstrap_api_service.dart';
import '../../../data/services/record_image_picker_service.dart';
import '../../../data/services/record_location_service.dart';
import '../../../data/services/record_submission_api_service.dart';
import '../../../data/services/tag_api_service.dart';

enum RecordBuildingMode { newBuilding, existingBuilding }

enum RecordSubmissionPhase {
  idle,
  starting,
  uploading,
  finalizing,
  failed,
  succeeded,
}

enum RecordPhotoUploadStatus { pending, uploading, uploaded, failed }

class RecordDraftController extends ChangeNotifier {
  RecordDraftController({
    required RecordImagePickerService imagePickerService,
    required BootstrapApiService bootstrapApiService,
    required AuthService authService,
    required RecordLocationService locationService,
    required TagApiService tagApiService,
    required RecordSubmissionApiService recordSubmissionApiService,
  }) : _imagePickerService = imagePickerService,
       _bootstrapApiService = bootstrapApiService,
       _authService = authService,
       _locationService = locationService,
       _tagApiService = tagApiService,
       _recordSubmissionApiService = recordSubmissionApiService;

  final RecordImagePickerService _imagePickerService;
  final BootstrapApiService _bootstrapApiService;
  final AuthService _authService;
  final RecordLocationService _locationService;
  final TagApiService _tagApiService;
  final RecordSubmissionApiService _recordSubmissionApiService;

  final List<RecordDraftPhoto> _photos = <RecordDraftPhoto>[];
  final List<Building> _buildings = <Building>[];
  final List<BuildingTag> _tags = <BuildingTag>[];
  final Set<String> _selectedDesignTagIds = <String>{};
  final Set<String> _selectedSalesTagIds = <String>{};
  final Set<String> _selectedConstructionTagIds = <String>{};
  final Set<String> _selectedTriggerTagIds = <String>{};
  final Set<String> _pendingExistingDesignTagIds = <String>{};
  final Set<String> _pendingExistingSalesTagIds = <String>{};
  final Set<String> _pendingExistingConstructionTagIds = <String>{};
  final Set<BuildingTagType> _creatingTagTypes = <BuildingTagType>{};

  bool _isPicking = false;
  String? _errorMessage;
  String? _noticeMessage;

  bool _isLoadingBootstrap = false;
  bool _hasLoadedBootstrap = false;
  String? _bootstrapErrorMessage;

  RecordBuildingMode _buildingMode = RecordBuildingMode.newBuilding;
  String _newBuildingName = '';
  String _buildingSearchQuery = '';
  Building? _selectedExistingBuilding;

  String _impression = '';
  RecordDraftLocation? _visitLocation;
  bool _isGettingLocation = false;
  String? _locationErrorMessage;
  String? _locationNoticeMessage;

  RecordSubmissionPhase _submissionPhase = RecordSubmissionPhase.idle;
  String? _submissionErrorMessage;
  String? _submissionErrorDetail;
  String? _submissionNoticeMessage;
  BeginRecordResult? _beginRecordResult;
  FinalizeRecordResult? _finalizeRecordResult;
  String? _beginRequestId;
  String? _finalizeRequestId;
  String? _submissionBuildingId;
  String? _submissionVisitId;
  DateTime? _submissionVisitedAt;
  String? _currentUploadingPhotoId;
  final Map<String, String> _photoRequestIds = <String, String>{};
  final Map<String, RecordPhotoUploadStatus> _photoUploadStatuses =
      <String, RecordPhotoUploadStatus>{};
  int _draftRevision = 0;

  UnmodifiableListView<RecordDraftPhoto> get photos =>
      UnmodifiableListView<RecordDraftPhoto>(_photos);
  bool get isPicking => _isPicking;
  bool get hasPhotos => _photos.isNotEmpty;
  int get photoCount => _photos.length;
  int get totalBytes => _photos.fold<int>(
    0,
    (int total, RecordDraftPhoto photo) => total + photo.byteSize,
  );
  String? get errorMessage => _errorMessage;
  String? get noticeMessage => _noticeMessage;

  bool get isLoadingBootstrap => _isLoadingBootstrap;
  bool get hasLoadedBootstrap => _hasLoadedBootstrap;
  String? get bootstrapErrorMessage => _bootstrapErrorMessage;
  UnmodifiableListView<Building> get buildings =>
      UnmodifiableListView<Building>(_buildings);
  UnmodifiableListView<BuildingTag> get tags =>
      UnmodifiableListView<BuildingTag>(_tags);

  RecordBuildingMode get buildingMode => _buildingMode;
  String get newBuildingName => _newBuildingName;
  String get buildingSearchQuery => _buildingSearchQuery;
  Building? get selectedExistingBuilding => _selectedExistingBuilding;

  String get impression => _impression;
  RecordDraftLocation? get visitLocation => _visitLocation;
  bool get isGettingLocation => _isGettingLocation;
  String? get locationErrorMessage => _locationErrorMessage;
  String? get locationNoticeMessage => _locationNoticeMessage;
  bool get hasVisitLocation => _visitLocation != null;
  bool isCreatingTag(BuildingTagType type) => _creatingTagTypes.contains(type);

  RecordSubmissionPhase get submissionPhase => _submissionPhase;
  String? get submissionErrorMessage => _submissionErrorMessage;
  String? get submissionErrorDetail => _submissionErrorDetail;
  String? get submissionNoticeMessage => _submissionNoticeMessage;
  String? get currentUploadingPhotoId => _currentUploadingPhotoId;
  String? get savedBuildingId => _finalizeRecordResult?.buildingId;
  String? get savedVisitId => _finalizeRecordResult?.visitId;
  int get draftRevision => _draftRevision;
  bool get submissionSucceeded =>
      _submissionPhase == RecordSubmissionPhase.succeeded;
  bool get isSubmitting =>
      _submissionPhase == RecordSubmissionPhase.starting ||
      _submissionPhase == RecordSubmissionPhase.uploading ||
      _submissionPhase == RecordSubmissionPhase.finalizing;
  bool get isDraftLocked => _beginRequestId != null;
  bool get canSubmitRecord => !isSubmitting && !submissionSucceeded;
  int get uploadedPhotoCount =>
      _photoUploadStatuses.values.where((RecordPhotoUploadStatus status) {
        return status == RecordPhotoUploadStatus.uploaded;
      }).length;
  int get failedPhotoCount =>
      _photoUploadStatuses.values.where((RecordPhotoUploadStatus status) {
        return status == RecordPhotoUploadStatus.failed;
      }).length;
  double get submissionProgress {
    if (_photos.isEmpty) {
      return 0;
    }
    return uploadedPhotoCount / _photos.length;
  }

  RecordPhotoUploadStatus photoUploadStatus(String photoId) {
    return _photoUploadStatuses[photoId] ?? RecordPhotoUploadStatus.pending;
  }

  bool get canUseSelectedBuildingLocation {
    final Building? building = _selectedExistingBuilding;
    return _buildingMode == RecordBuildingMode.existingBuilding &&
        building?.latitude != null &&
        building?.longitude != null;
  }

  List<Building> get filteredBuildings {
    final String query = _normalizeSearchText(_buildingSearchQuery);
    if (query.isEmpty) {
      return List<Building>.unmodifiable(_buildings);
    }

    return List<Building>.unmodifiable(
      _buildings.where((Building building) {
        final String haystack = <String>[
          building.buildingName,
          building.searchName,
          building.address ?? '',
        ].map(_normalizeSearchText).join(' ');
        return haystack.contains(query);
      }),
    );
  }

  List<BuildingTag> tagsFor(BuildingTagType type) {
    return List<BuildingTag>.unmodifiable(
      _tags.where((BuildingTag tag) => tag.tagType == type),
    );
  }

  bool isTagSelected(BuildingTagType type, String tagId) {
    return _tagIdsFor(type).contains(tagId);
  }

  List<BuildingTag> selectedTagsFor(BuildingTagType type) {
    final Set<String> selectedIds = _tagIdsFor(type);
    return List<BuildingTag>.unmodifiable(
      _tags.where((BuildingTag tag) {
        return tag.tagType == type && selectedIds.contains(tag.tagId);
      }),
    );
  }

  bool isExistingBuildingTagSelected(BuildingTagType type, String tagId) {
    return _pendingExistingTagIdsFor(type).contains(tagId);
  }

  List<BuildingTag> selectedExistingBuildingTagsFor(BuildingTagType type) {
    final Set<String> selectedIds = _pendingExistingTagIdsFor(type);
    return List<BuildingTag>.unmodifiable(
      _tags.where((BuildingTag tag) {
        return tag.tagType == type && selectedIds.contains(tag.tagId);
      }),
    );
  }

  List<String> tagNamesForIds(Iterable<String> tagIds) {
    return List<String>.unmodifiable(
      tagIds.map((String tagId) {
        for (final BuildingTag tag in _tags) {
          if (tag.tagId == tagId) {
            return tag.tagName;
          }
        }
        return '不明なタグ';
      }),
    );
  }

  Future<void> loadBootstrapData() async {
    if (_isLoadingBootstrap) {
      return;
    }

    final String? idToken = _authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      _bootstrapErrorMessage = 'Googleログイン情報を取得できませんでした。';
      notifyListeners();
      return;
    }

    _isLoadingBootstrap = true;
    _bootstrapErrorMessage = null;
    notifyListeners();

    try {
      final BootstrapData data = await _bootstrapApiService.getBootstrapData(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
      );

      _buildings
        ..clear()
        ..addAll(
          data.buildings.where((Building building) => !building.isDeleted),
        )
        ..sort((Building left, Building right) {
          return left.buildingName.compareTo(right.buildingName);
        });

      _tags
        ..clear()
        ..addAll(data.tags.where((BuildingTag tag) => tag.isActive));
      _sortTags();

      final String? selectedId = _selectedExistingBuilding?.buildingId;
      if (selectedId != null) {
        _selectedExistingBuilding = _findBuildingById(selectedId);
      }

      _removeUnavailableTagIds(_selectedDesignTagIds);
      _removeUnavailableTagIds(_selectedSalesTagIds);
      _removeUnavailableTagIds(_selectedConstructionTagIds);
      _removeUnavailableTagIds(_selectedTriggerTagIds);
      _removeUnavailableTagIds(_pendingExistingDesignTagIds);
      _removeUnavailableTagIds(_pendingExistingSalesTagIds);
      _removeUnavailableTagIds(_pendingExistingConstructionTagIds);
      _hasLoadedBootstrap = true;
    } on BootstrapApiException catch (error) {
      _bootstrapErrorMessage = error.message;
    } catch (_) {
      _bootstrapErrorMessage = '建物とタグのデータを取得できませんでした。';
    } finally {
      _isLoadingBootstrap = false;
      notifyListeners();
    }
  }

  Future<void> addPhotos() async {
    if (_isPicking || isDraftLocked) {
      return;
    }

    _isPicking = true;
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final List<RecordDraftPhoto> selectedPhotos = await _imagePickerService
          .pickImages();
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

      _photos.addAll(acceptedPhotos);
      for (final RecordDraftPhoto photo in acceptedPhotos) {
        _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.pending;
      }

      if (unsupportedCount > 0 || oversizedCount > 0) {
        final List<String> reasons = <String>[];
        if (unsupportedCount > 0) {
          reasons.add('未対応形式 $unsupportedCount枚');
        }
        if (oversizedCount > 0) {
          reasons.add('5MB超過 $oversizedCount枚');
        }
        _errorMessage = '${reasons.join('、')}は追加しませんでした。';
      }

      if (acceptedPhotos.isNotEmpty) {
        _noticeMessage = '${acceptedPhotos.length}枚を下書きへ追加しました。';
      }
    } catch (_) {
      _errorMessage = '写真を選択できませんでした。もう一度お試しください。';
    } finally {
      _isPicking = false;
      notifyListeners();
    }
  }

  void removePhoto(String photoId) {
    if (isDraftLocked) {
      return;
    }

    final int previousCount = _photos.length;
    _photos.removeWhere((RecordDraftPhoto photo) => photo.photoId == photoId);
    if (_photos.length == previousCount) {
      return;
    }

    _photoUploadStatuses.remove(photoId);
    _photoRequestIds.remove(photoId);
    _errorMessage = null;
    _noticeMessage = '写真を1枚削除しました。';
    notifyListeners();
  }

  void clearPhotos() {
    if (_photos.isEmpty || isDraftLocked) {
      return;
    }

    _photos.clear();
    _photoUploadStatuses.clear();
    _photoRequestIds.clear();
    _errorMessage = null;
    _noticeMessage = '写真の下書きを空にしました。';
    notifyListeners();
  }

  void setBuildingMode(RecordBuildingMode mode) {
    if (isDraftLocked || _buildingMode == mode) {
      return;
    }

    _buildingMode = mode;
    if (mode == RecordBuildingMode.newBuilding &&
        _visitLocation?.source == RecordLocationSource.buildingFallback) {
      _visitLocation = null;
      _locationErrorMessage = null;
      _locationNoticeMessage = '建物の代表位置を解除しました。';
    }
    notifyListeners();
  }

  void setNewBuildingName(String value) {
    if (isDraftLocked) {
      return;
    }
    _newBuildingName = value;
  }

  void toggleBuildingTag(BuildingTagType type, String tagId) {
    if (isDraftLocked || type == BuildingTagType.trigger) {
      return;
    }

    final Set<String> selectedIds = _tagIdsFor(type);
    if (selectedIds.contains(tagId)) {
      selectedIds.remove(tagId);
    } else {
      selectedIds.add(tagId);
    }
    notifyListeners();
  }

  void toggleExistingBuildingTag(BuildingTagType type, String tagId) {
    if (isDraftLocked ||
        type == BuildingTagType.trigger ||
        _selectedExistingBuilding == null) {
      return;
    }

    final Set<String> selectedIds = _pendingExistingTagIdsFor(type);
    if (selectedIds.contains(tagId)) {
      selectedIds.remove(tagId);
    } else {
      selectedIds.add(tagId);
    }
    notifyListeners();
  }

  void setBuildingSearchQuery(String value) {
    if (isDraftLocked || _buildingSearchQuery == value) {
      return;
    }

    _buildingSearchQuery = value;
    notifyListeners();
  }

  void selectExistingBuilding(String buildingId) {
    if (isDraftLocked) {
      return;
    }
    final Building? building = _findBuildingById(buildingId);
    if (building == null || building == _selectedExistingBuilding) {
      return;
    }

    _selectedExistingBuilding = building;
    _clearPendingExistingBuildingTags();
    if (_visitLocation?.source == RecordLocationSource.buildingFallback) {
      _setSelectedBuildingFallbackLocation(notify: false);
    }
    notifyListeners();
  }

  void clearExistingBuildingSelection() {
    if (isDraftLocked || _selectedExistingBuilding == null) {
      return;
    }

    _selectedExistingBuilding = null;
    _clearPendingExistingBuildingTags();
    if (_visitLocation?.source == RecordLocationSource.buildingFallback) {
      _visitLocation = null;
      _locationNoticeMessage = '建物の代表位置を解除しました。';
    }
    notifyListeners();
  }

  void toggleTriggerTag(String tagId) {
    if (isDraftLocked) {
      return;
    }
    final bool isAvailable = _tags.any((BuildingTag tag) {
      return tag.tagId == tagId && tag.tagType == BuildingTagType.trigger;
    });
    if (!isAvailable) {
      return;
    }

    if (_selectedTriggerTagIds.contains(tagId)) {
      _selectedTriggerTagIds.remove(tagId);
    } else {
      _selectedTriggerTagIds.add(tagId);
    }
    notifyListeners();
  }

  void setImpression(String value) {
    if (isDraftLocked) {
      return;
    }
    _impression = value;
  }

  Future<String?> createAndSelectTag(
    BuildingTagType type,
    String rawTagName,
  ) async {
    if (isDraftLocked) {
      return '送信開始後はタグを変更できません。';
    }

    final String tagName = rawTagName.trim();
    if (tagName.isEmpty) {
      return 'タグ名を入力してください。';
    }
    if (tagName.runes.length > 80) {
      return 'タグ名は80文字以内で入力してください。';
    }
    if (_creatingTagTypes.contains(type)) {
      return 'タグを追加しています。しばらくお待ちください。';
    }

    final String? idToken = _authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      return 'Googleログイン情報を取得できませんでした。';
    }

    _creatingTagTypes.add(type);
    _errorMessage = null;
    _noticeMessage = null;
    notifyListeners();

    try {
      final TagCreationResult result = await _tagApiService.createTag(
        requestId: const Uuid().v4(),
        clientVersion: AppConfig.version,
        idToken: idToken,
        tagType: type,
        tagName: tagName,
      );

      if (result.tag.tagType != type) {
        return '追加したタグの種類が一致しません。';
      }

      _upsertTag(result.tag);
      _tagIdsForCurrentContext(type).add(result.tag.tagId);

      if (result.created) {
        _noticeMessage = '「${result.tag.tagName}」を追加して選択しました。';
      } else if (result.reactivated) {
        _noticeMessage = '「${result.tag.tagName}」を再有効化して選択しました。';
      } else {
        _noticeMessage = '登録済みの「${result.tag.tagName}」を選択しました。';
      }
      return null;
    } on TagApiException catch (error) {
      _errorMessage = error.message;
      return error.message;
    } catch (_) {
      const String message = 'タグを追加できませんでした。もう一度お試しください。';
      _errorMessage = message;
      return message;
    } finally {
      _creatingTagTypes.remove(type);
      notifyListeners();
    }
  }

  Future<void> submitRecord() async {
    if (isSubmitting || submissionSucceeded) {
      return;
    }

    final String? validationMessage = _validateRecordDraft();
    if (validationMessage != null) {
      _submissionPhase = RecordSubmissionPhase.idle;
      _submissionErrorMessage = validationMessage;
      _submissionErrorDetail = null;
      _submissionNoticeMessage = null;
      notifyListeners();
      return;
    }

    final String idToken = _authService.idToken!;
    final RecordDraftLocation location = _visitLocation!;
    const Uuid uuid = Uuid();

    _beginRequestId ??= uuid.v4();
    _finalizeRequestId ??= uuid.v4();
    _submissionVisitId ??= uuid.v4();
    _submissionBuildingId ??= _buildingMode == RecordBuildingMode.newBuilding
        ? uuid.v4()
        : _selectedExistingBuilding!.buildingId;
    _submissionVisitedAt ??= DateTime.now();

    for (final RecordDraftPhoto photo in _photos) {
      _photoRequestIds.putIfAbsent(photo.photoId, uuid.v4);
      final RecordPhotoUploadStatus status = photoUploadStatus(photo.photoId);
      if (status == RecordPhotoUploadStatus.failed) {
        _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.pending;
      } else {
        _photoUploadStatuses.putIfAbsent(
          photo.photoId,
          () => RecordPhotoUploadStatus.pending,
        );
      }
    }

    _submissionErrorMessage = null;
    _submissionErrorDetail = null;
    _submissionNoticeMessage = null;
    _submissionPhase = RecordSubmissionPhase.starting;
    notifyListeners();

    try {
      _beginRecordResult ??= await _recordSubmissionApiService.beginRecord(
        requestId: _beginRequestId!,
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingMode: _buildingMode == RecordBuildingMode.newBuilding
            ? 'new'
            : 'existing',
        buildingId: _submissionBuildingId!,
        visitId: _submissionVisitId!,
        buildingName: _buildingMode == RecordBuildingMode.newBuilding
            ? _newBuildingName.trim()
            : null,
        designTagIds: _buildingTagIdsForSubmission(BuildingTagType.design),
        salesTagIds: _buildingTagIdsForSubmission(BuildingTagType.sales),
        constructionTagIds: _buildingTagIdsForSubmission(
          BuildingTagType.construction,
        ),
        visitedAt: _submissionVisitedAt!,
        triggerTagIds: _sortedIds(_selectedTriggerTagIds),
        impression: _impression.trim(),
        latitude: location.latitude,
        longitude: location.longitude,
        accuracyM: location.accuracyM,
        locationSource: location.source.apiValue,
        expectedPhotoCount: _photos.length,
      );

      _submissionBuildingId = _beginRecordResult!.buildingId;
      _submissionVisitId = _beginRecordResult!.visitId;
      _submissionPhase = RecordSubmissionPhase.uploading;
      notifyListeners();

      final List<String> failedDetails = <String>[];
      for (int index = 0; index < _photos.length; index += 1) {
        final RecordDraftPhoto photo = _photos[index];
        if (photoUploadStatus(photo.photoId) ==
            RecordPhotoUploadStatus.uploaded) {
          continue;
        }

        _currentUploadingPhotoId = photo.photoId;
        _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.uploading;
        notifyListeners();

        try {
          await _recordSubmissionApiService.uploadPhoto(
            requestId: _photoRequestIds[photo.photoId]!,
            clientVersion: AppConfig.version,
            idToken: idToken,
            buildingId: _submissionBuildingId!,
            visitId: _submissionVisitId!,
            photoId: photo.photoId,
            fileName: photo.fileName,
            mimeType: photo.mimeType,
            bytes: photo.bytes,
            takenAt: _submissionVisitedAt!,
            latitude: location.latitude,
            longitude: location.longitude,
            accuracyM: location.accuracyM,
            locationSource: location.source.apiValue,
            displayOrder: index + 1,
          );
          _photoUploadStatuses[photo.photoId] =
              RecordPhotoUploadStatus.uploaded;
        } on RecordSubmissionApiException catch (error) {
          _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.failed;
          failedDetails.add('${photo.fileName}: ${error.message}');
        } catch (_) {
          _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.failed;
          failedDetails.add('${photo.fileName}: 不明なエラー');
        }
        notifyListeners();
      }

      _currentUploadingPhotoId = null;
      if (failedDetails.isNotEmpty) {
        _submissionPhase = RecordSubmissionPhase.failed;
        _submissionErrorMessage = '送信できませんでした。もう一度送信してください。';
        _submissionErrorDetail = failedDetails.join('\n');
        notifyListeners();
        return;
      }

      _submissionPhase = RecordSubmissionPhase.finalizing;
      notifyListeners();

      _finalizeRecordResult = await _recordSubmissionApiService.finalizeRecord(
        requestId: _finalizeRequestId!,
        clientVersion: AppConfig.version,
        idToken: idToken,
        buildingId: _submissionBuildingId!,
        visitId: _submissionVisitId!,
      );

      _submissionPhase = RecordSubmissionPhase.succeeded;
      _submissionNoticeMessage = '建物・訪問・写真${_photos.length}枚を保存しました。';
      _submissionErrorMessage = null;
      _submissionErrorDetail = null;
      notifyListeners();

      await loadBootstrapData();
    } on RecordSubmissionApiException catch (error) {
      _submissionPhase = RecordSubmissionPhase.failed;
      _currentUploadingPhotoId = null;
      _submissionErrorMessage = '送信できませんでした。もう一度送信してください。';
      _submissionErrorDetail = error.message;
      notifyListeners();
    } catch (_) {
      _submissionPhase = RecordSubmissionPhase.failed;
      _currentUploadingPhotoId = null;
      _submissionErrorMessage = '送信できませんでした。もう一度送信してください。';
      _submissionErrorDetail = '記録の保存中に予期しないエラーが発生しました。';
      notifyListeners();
    }
  }

  Future<void> startNewRecord() async {
    if (!submissionSucceeded) {
      return;
    }

    _photos.clear();
    _selectedDesignTagIds.clear();
    _selectedSalesTagIds.clear();
    _selectedConstructionTagIds.clear();
    _selectedTriggerTagIds.clear();
    _clearPendingExistingBuildingTags();
    _buildingMode = RecordBuildingMode.newBuilding;
    _newBuildingName = '';
    _buildingSearchQuery = '';
    _selectedExistingBuilding = null;
    _impression = '';
    _visitLocation = null;
    _locationErrorMessage = null;
    _locationNoticeMessage = null;
    _errorMessage = null;
    _noticeMessage = null;
    _submissionPhase = RecordSubmissionPhase.idle;
    _submissionErrorMessage = null;
    _submissionErrorDetail = null;
    _submissionNoticeMessage = null;
    _beginRecordResult = null;
    _finalizeRecordResult = null;
    _beginRequestId = null;
    _finalizeRequestId = null;
    _submissionBuildingId = null;
    _submissionVisitId = null;
    _submissionVisitedAt = null;
    _currentUploadingPhotoId = null;
    _photoRequestIds.clear();
    _photoUploadStatuses.clear();
    _draftRevision += 1;
    notifyListeners();

    await loadBootstrapData();
  }

  String? _validateRecordDraft() {
    if (_photos.isEmpty) {
      return '写真を1枚以上選択してください。';
    }

    if (_buildingMode == RecordBuildingMode.newBuilding) {
      final String buildingName = _newBuildingName.trim();
      if (buildingName.isEmpty) {
        return '建物名を入力してください。';
      }
      if (buildingName.runes.length > 100) {
        return '建物名は100文字以内で入力してください。';
      }
    } else if (_selectedExistingBuilding == null) {
      return '登録済みの建物を選択してください。';
    }

    if (_visitLocation == null) {
      return '位置情報を取得してください。';
    }

    final String? idToken = _authService.idToken;
    if (idToken == null || idToken.isEmpty) {
      return 'Googleログイン情報を取得できませんでした。';
    }

    return null;
  }

  List<String> _buildingTagIdsForSubmission(BuildingTagType type) {
    final Set<String> ids = _buildingMode == RecordBuildingMode.newBuilding
        ? _tagIdsFor(type)
        : _pendingExistingTagIdsFor(type);
    return _sortedIds(ids);
  }

  List<String> _sortedIds(Set<String> ids) {
    final List<String> result = ids.toList()..sort();
    return List<String>.unmodifiable(result);
  }

  Future<void> acquireCurrentLocation() async {
    if (_isGettingLocation || isDraftLocked) {
      return;
    }

    _isGettingLocation = true;
    _locationErrorMessage = null;
    _locationNoticeMessage = null;
    notifyListeners();

    try {
      _visitLocation = await _locationService.getCurrentLocation();
      _locationNoticeMessage = '現在地を取得しました。';
    } on RecordLocationException catch (error) {
      _locationErrorMessage = error.message;
    } catch (_) {
      _locationErrorMessage = '現在地を取得できませんでした。もう一度お試しください。';
    } finally {
      _isGettingLocation = false;
      notifyListeners();
    }
  }

  void useSelectedBuildingLocation() {
    if (isDraftLocked) {
      return;
    }
    _setSelectedBuildingFallbackLocation(notify: true);
  }

  void clearVisitLocation() {
    if (isDraftLocked || _visitLocation == null) {
      return;
    }

    _visitLocation = null;
    _locationErrorMessage = null;
    _locationNoticeMessage = '位置情報をクリアしました。';
    notifyListeners();
  }

  void _setSelectedBuildingFallbackLocation({required bool notify}) {
    final Building? building = _selectedExistingBuilding;
    final double? latitude = building?.latitude;
    final double? longitude = building?.longitude;

    if (latitude == null || longitude == null) {
      _visitLocation = null;
      _locationErrorMessage = '選択した建物には代表位置が登録されていません。';
      _locationNoticeMessage = null;
      if (notify) {
        notifyListeners();
      }
      return;
    }

    _visitLocation = RecordDraftLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyM: null,
      source: RecordLocationSource.buildingFallback,
      capturedAt: DateTime.now(),
    );
    _locationErrorMessage = null;
    _locationNoticeMessage = '建物の代表位置を使用します。';
    if (notify) {
      notifyListeners();
    }
  }

  void _upsertTag(BuildingTag tag) {
    _tags.removeWhere((BuildingTag existing) {
      return existing.tagId == tag.tagId ||
          (existing.tagType == tag.tagType &&
              existing.normalizedName == tag.normalizedName);
    });
    if (tag.isActive) {
      _tags.add(tag);
    }
    _sortTags();
  }

  void _sortTags() {
    _tags.sort((BuildingTag left, BuildingTag right) {
      final int typeComparison = left.tagType.index.compareTo(
        right.tagType.index,
      );
      if (typeComparison != 0) {
        return typeComparison;
      }

      final int orderComparison = left.displayOrder.compareTo(
        right.displayOrder,
      );
      if (orderComparison != 0) {
        return orderComparison;
      }

      return left.tagName.compareTo(right.tagName);
    });
  }

  Set<String> _tagIdsForCurrentContext(BuildingTagType type) {
    if (type == BuildingTagType.trigger) {
      return _selectedTriggerTagIds;
    }
    if (_buildingMode == RecordBuildingMode.existingBuilding) {
      return _pendingExistingTagIdsFor(type);
    }
    return _tagIdsFor(type);
  }

  Set<String> _pendingExistingTagIdsFor(BuildingTagType type) {
    return switch (type) {
      BuildingTagType.design => _pendingExistingDesignTagIds,
      BuildingTagType.sales => _pendingExistingSalesTagIds,
      BuildingTagType.construction => _pendingExistingConstructionTagIds,
      BuildingTagType.trigger => _selectedTriggerTagIds,
    };
  }

  void _clearPendingExistingBuildingTags() {
    _pendingExistingDesignTagIds.clear();
    _pendingExistingSalesTagIds.clear();
    _pendingExistingConstructionTagIds.clear();
  }

  Set<String> _tagIdsFor(BuildingTagType type) {
    return switch (type) {
      BuildingTagType.design => _selectedDesignTagIds,
      BuildingTagType.sales => _selectedSalesTagIds,
      BuildingTagType.construction => _selectedConstructionTagIds,
      BuildingTagType.trigger => _selectedTriggerTagIds,
    };
  }

  Building? _findBuildingById(String buildingId) {
    for (final Building building in _buildings) {
      if (building.buildingId == buildingId) {
        return building;
      }
    }
    return null;
  }

  void _removeUnavailableTagIds(Set<String> selectedIds) {
    final Set<String> availableIds = _tags
        .map((BuildingTag tag) => tag.tagId)
        .toSet();
    selectedIds.removeWhere((String tagId) => !availableIds.contains(tagId));
  }
}

String _normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}
