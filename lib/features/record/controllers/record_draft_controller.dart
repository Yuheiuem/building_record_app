import 'dart:async';
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
import '../domain/record_submission_draft_builder.dart';
import 'record_photo_upload_executor.dart';

part 'record_submission_session.dart';

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
       _recordSubmissionApiService = recordSubmissionApiService,
       _photoUploadExecutor = RecordPhotoUploadExecutor(
         recordSubmissionApiService: recordSubmissionApiService,
       ) {
    _authService.addListener(_handleAuthServiceChanged);
  }

  final RecordImagePickerService _imagePickerService;
  final BootstrapApiService _bootstrapApiService;
  final AuthService _authService;
  final RecordLocationService _locationService;
  final TagApiService _tagApiService;
  final RecordSubmissionApiService _recordSubmissionApiService;
  final RecordPhotoUploadExecutor _photoUploadExecutor;

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
  String? _photoPreparationStatusMessage;

  bool _isLoadingBootstrap = false;
  bool _hasLoadedBootstrap = false;
  String? _bootstrapErrorMessage;
  bool _requiresReauthentication = false;
  bool _isRefreshingAuthentication = false;
  String? _authenticationFailureToken;

  RecordBuildingMode _buildingMode = RecordBuildingMode.newBuilding;
  String _newBuildingName = '';
  String _buildingSearchQuery = '';
  Building? _selectedExistingBuilding;

  String _impression = '';
  RecordDraftLocation? _visitLocation;
  bool _isGettingLocation = false;
  String? _locationErrorMessage;
  String? _locationNoticeMessage;

  final RecordSubmissionSession _submissionSession =
      RecordSubmissionSession();
  int _draftRevision = 0;

  RecordSubmissionPhase get _submissionPhase => _submissionSession.phase;
  set _submissionPhase(RecordSubmissionPhase value) =>
      _submissionSession.phase = value;
  String? get _submissionErrorMessage => _submissionSession.errorMessage;
  set _submissionErrorMessage(String? value) =>
      _submissionSession.errorMessage = value;
  String? get _submissionErrorDetail => _submissionSession.errorDetail;
  set _submissionErrorDetail(String? value) =>
      _submissionSession.errorDetail = value;
  String? get _submissionNoticeMessage => _submissionSession.noticeMessage;
  set _submissionNoticeMessage(String? value) =>
      _submissionSession.noticeMessage = value;
  String? get _submissionOperationMessage =>
      _submissionSession.operationMessage;
  set _submissionOperationMessage(String? value) =>
      _submissionSession.operationMessage = value;
  DateTime? get _submissionStartedAt => _submissionSession.startedAt;
  set _submissionStartedAt(DateTime? value) =>
      _submissionSession.startedAt = value;
  BeginRecordResult? get _beginRecordResult =>
      _submissionSession.beginRecordResult;
  set _beginRecordResult(BeginRecordResult? value) =>
      _submissionSession.beginRecordResult = value;
  FinalizeRecordResult? get _finalizeRecordResult =>
      _submissionSession.finalizeRecordResult;
  set _finalizeRecordResult(FinalizeRecordResult? value) =>
      _submissionSession.finalizeRecordResult = value;
  String? get _beginRequestId => _submissionSession.beginRequestId;
  set _beginRequestId(String? value) =>
      _submissionSession.beginRequestId = value;
  String? get _finalizeRequestId => _submissionSession.finalizeRequestId;
  set _finalizeRequestId(String? value) =>
      _submissionSession.finalizeRequestId = value;
  String? get _submissionBuildingId => _submissionSession.buildingId;
  set _submissionBuildingId(String? value) =>
      _submissionSession.buildingId = value;
  String? get _submissionVisitId => _submissionSession.visitId;
  set _submissionVisitId(String? value) => _submissionSession.visitId = value;
  DateTime? get _submissionVisitedAt => _submissionSession.visitedAt;
  set _submissionVisitedAt(DateTime? value) =>
      _submissionSession.visitedAt = value;
  String? get _currentUploadingPhotoId =>
      _submissionSession.currentUploadingPhotoId;
  set _currentUploadingPhotoId(String? value) =>
      _submissionSession.currentUploadingPhotoId = value;
  Map<String, String> get _photoRequestIds =>
      _submissionSession.photoRequestIds;
  Map<String, RecordPhotoUploadStatus> get _photoUploadStatuses =>
      _submissionSession.photoUploadStatuses;
  Duration? get _lastSubmissionDuration =>
      _submissionSession.lastSubmissionDuration;
  set _lastSubmissionDuration(Duration? value) =>
      _submissionSession.lastSubmissionDuration = value;
  Duration? get _lastPreparationDuration =>
      _submissionSession.lastPreparationDuration;
  set _lastPreparationDuration(Duration? value) =>
      _submissionSession.lastPreparationDuration = value;
  Duration? get _lastPhotoUploadDuration =>
      _submissionSession.lastPhotoUploadDuration;
  set _lastPhotoUploadDuration(Duration? value) =>
      _submissionSession.lastPhotoUploadDuration = value;
  Duration? get _lastFinalizeDuration => _submissionSession.lastFinalizeDuration;
  set _lastFinalizeDuration(Duration? value) =>
      _submissionSession.lastFinalizeDuration = value;
  Duration? get _lastCombinedSaveDuration =>
      _submissionSession.lastCombinedSaveDuration;
  set _lastCombinedSaveDuration(Duration? value) =>
      _submissionSession.lastCombinedSaveDuration = value;

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
  String? get photoPreparationStatusMessage => _photoPreparationStatusMessage;

  bool get isLoadingBootstrap => _isLoadingBootstrap;
  bool get hasLoadedBootstrap => _hasLoadedBootstrap;
  String? get bootstrapErrorMessage => _bootstrapErrorMessage;
  bool get requiresReauthentication => _requiresReauthentication;
  bool get isRefreshingAuthentication => _isRefreshingAuthentication;
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
  String? get submissionOperationMessage => _submissionOperationMessage;
  DateTime? get submissionStartedAt => _submissionStartedAt;
  String? get currentUploadingPhotoId => _currentUploadingPhotoId;
  String? get savedBuildingId => _finalizeRecordResult?.buildingId;
  String? get savedVisitId => _finalizeRecordResult?.visitId;
  int get draftRevision => _draftRevision;
  Duration? get lastSubmissionDuration => _lastSubmissionDuration;
  Duration? get lastPreparationDuration => _lastPreparationDuration;
  Duration? get lastPhotoUploadDuration => _lastPhotoUploadDuration;
  Duration? get lastFinalizeDuration => _lastFinalizeDuration;
  Duration? get lastCombinedSaveDuration => _lastCombinedSaveDuration;
  RecordPhasePerformance? get beginRecordPerformance =>
      _beginRecordResult?.performance;
  RecordPhasePerformance? get finalizeRecordPerformance =>
      _finalizeRecordResult?.performance;
  bool get submissionSucceeded => _submissionSession.succeeded;
  bool get isSubmitting => _submissionSession.isSubmitting;
  bool get isDraftLocked => _submissionSession.isDraftLocked;
  bool get canSubmitRecord =>
      !isSubmitting && !submissionSucceeded && !_requiresReauthentication;
  int get uploadedPhotoCount => _submissionSession.countPhotosWithStatus(
    RecordPhotoUploadStatus.uploaded,
  );
  int get failedPhotoCount => _submissionSession.countPhotosWithStatus(
    RecordPhotoUploadStatus.failed,
  );
  int get uploadingPhotoCount => _submissionSession.countPhotosWithStatus(
    RecordPhotoUploadStatus.uploading,
  );
  int get pendingPhotoCount => _submissionSession.countPhotosWithStatus(
    RecordPhotoUploadStatus.pending,
  );
  double get submissionProgress =>
      _submissionSession.progressForPhotoCount(_photos.length);

  RecordPhotoUploadStatus photoUploadStatus(String photoId) {
    return _submissionSession.photoStatus(photoId);
  }

  UploadRecordPhotoResult? photoUploadResult(String photoId) {
    return _submissionSession.photoResult(photoId);
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

    bool shouldRefreshAuthentication = false;
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
      _requiresReauthentication = false;
      _authenticationFailureToken = null;
    } on BootstrapApiException catch (error) {
      if (_isAuthenticationRequired(error.errorCode)) {
        _markAuthenticationRequired(idToken);
        _bootstrapErrorMessage = 'IDトークンが無効または期限切れです。入力内容を残したまま認証を更新します。';
        shouldRefreshAuthentication = true;
      } else {
        _bootstrapErrorMessage = error.message;
      }
    } catch (_) {
      _bootstrapErrorMessage = '建物とタグのデータを取得できませんでした。';
    } finally {
      _isLoadingBootstrap = false;
      notifyListeners();
    }

    if (shouldRefreshAuthentication) {
      await refreshAuthentication();
    }
  }

  Future<void> refreshAuthentication() async {
    if (_isRefreshingAuthentication) {
      return;
    }

    _isRefreshingAuthentication = true;
    notifyListeners();

    final bool refreshed = await _authService.refreshIdToken();
    _isRefreshingAuthentication = false;

    if (!_requiresReauthentication) {
      notifyListeners();
      return;
    }

    final String? currentToken = _authService.idToken;
    final bool hasFreshToken =
        refreshed &&
        currentToken != null &&
        currentToken.isNotEmpty &&
        currentToken != _authenticationFailureToken;

    if (!hasFreshToken) {
      _bootstrapErrorMessage =
          '認証を自動更新できませんでした。下のGoogleログインボタンから再ログインしてください。入力内容は保持されています。';
      notifyListeners();
      return;
    }

    _completeReauthentication();
    notifyListeners();
    await loadBootstrapData();
  }

  Future<void> addPhotos() async {
    if (_isPicking || isDraftLocked) {
      return;
    }

    _isPicking = true;
    _errorMessage = null;
    _noticeMessage = null;
    _photoPreparationStatusMessage = '写真を選択・変換しています。';
    notifyListeners();

    try {
      final RecordImagePickerService imagePickerService = _imagePickerService;
      final List<RecordDraftPhoto> selectedPhotos;
      if (imagePickerService is RecordImagePickerProgressService) {
        final RecordImagePickerProgressService progressService =
            imagePickerService as RecordImagePickerProgressService;
        selectedPhotos = await progressService.pickImagesWithProgress(
          onProgress: (RecordImagePickProgress progress) {
            _photoPreparationStatusMessage = progress.message;
            notifyListeners();
          },
        );
      } else {
        selectedPhotos = await imagePickerService.pickImages();
      }
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
      _photoPreparationStatusMessage = null;
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
      if (_isAuthenticationRequired(error.errorCode)) {
        _markAuthenticationRequired(idToken);
        const String message =
            'Googleログインの有効期限が切れました。認証を更新してから、もう一度タグを追加してください。';
        _errorMessage = message;
        return message;
      }
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
    if (isSubmitting || submissionSucceeded || _requiresReauthentication) {
      return;
    }

    final String? validationMessage = RecordSubmissionDraftBuilder.validate(
      hasPhotos: _photos.isNotEmpty,
      isNewBuilding: _buildingMode == RecordBuildingMode.newBuilding,
      newBuildingName: _newBuildingName,
      hasSelectedExistingBuilding: _selectedExistingBuilding != null,
      hasVisitLocation: _visitLocation != null,
      idToken: _authService.idToken,
    );
    if (validationMessage != null) {
      _submissionPhase = RecordSubmissionPhase.idle;
      _submissionErrorMessage = validationMessage;
      _submissionErrorDetail = null;
      _submissionNoticeMessage = null;
      _submissionOperationMessage = null;
      notifyListeners();
      return;
    }

    _submissionErrorMessage = null;
    _submissionErrorDetail = null;
    _submissionNoticeMessage = null;
    _submissionOperationMessage = 'Googleログイン情報の有効期限を確認しています。';
    _submissionStartedAt = DateTime.now();
    _lastSubmissionDuration = null;
    _lastPreparationDuration = null;
    _lastPhotoUploadDuration = null;
    _lastFinalizeDuration = null;
    _lastCombinedSaveDuration = null;
    _submissionPhase = RecordSubmissionPhase.starting;
    notifyListeners();

    final Stopwatch submissionStopwatch = Stopwatch()..start();
    final String? guardedIdToken = await _resolveSubmissionIdToken();
    if (guardedIdToken == null) {
      submissionStopwatch.stop();
      _lastSubmissionDuration = submissionStopwatch.elapsed;
      _submissionPhase = RecordSubmissionPhase.failed;
      _submissionOperationMessage = 'Googleログイン情報を更新してください。';
      _submissionErrorMessage = 'Googleログイン情報を更新できませんでした。';
      _submissionErrorDetail =
          '入力内容は保持されています。上のGoogleログインから認証を更新し、もう一度保存してください。';
      notifyListeners();
      return;
    }

    final String idToken = guardedIdToken;
    final RecordDraftLocation location = _visitLocation!;
    const Uuid uuid = Uuid();

    _beginRequestId ??= uuid.v4();
    _finalizeRequestId ??= uuid.v4();
    _submissionVisitId ??= uuid.v4();
    _submissionBuildingId ??= _buildingMode == RecordBuildingMode.newBuilding
        ? uuid.v4()
        : _selectedExistingBuilding!.buildingId;
    _submissionVisitedAt ??= DateTime.now();

    final RecordSubmissionDraft submissionDraft =
        RecordSubmissionDraftBuilder.build(
          isNewBuilding: _buildingMode == RecordBuildingMode.newBuilding,
          newBuildingName: _newBuildingName,
          newDesignTagIds: _selectedDesignTagIds,
          newSalesTagIds: _selectedSalesTagIds,
          newConstructionTagIds: _selectedConstructionTagIds,
          pendingExistingDesignTagIds: _pendingExistingDesignTagIds,
          pendingExistingSalesTagIds: _pendingExistingSalesTagIds,
          pendingExistingConstructionTagIds:
              _pendingExistingConstructionTagIds,
          buildingId: _submissionBuildingId!,
          visitId: _submissionVisitId!,
          visitedAt: _submissionVisitedAt!,
          triggerTagIds: _selectedTriggerTagIds,
          impression: _impression,
          location: location,
          expectedPhotoCount: _photos.length,
        );

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

    _submissionOperationMessage = '保存処理を開始しています。';
    notifyListeners();

    bool refreshBootstrapAfterSuccess = false;

    try {
      final List<String> failedDetails = _photos.length == 1
          ? await _submitSinglePhotoRecord(idToken, submissionDraft)
          : await _submitMultiplePhotoRecord(idToken, submissionDraft);

      _currentUploadingPhotoId = null;
      if (failedDetails.isNotEmpty) {
        _submissionPhase = RecordSubmissionPhase.failed;
        _submissionOperationMessage = '送信に失敗しました。送信済みの写真は保持しています。';
        if (_requiresReauthentication) {
          _submissionErrorMessage = 'ログインの有効期限が切れました。';
          _submissionErrorDetail = '入力内容と送信済み写真は保持されています。認証更新後にもう一度保存してください。';
        } else {
          _submissionErrorMessage = '送信できませんでした。もう一度送信してください。';
          _submissionErrorDetail = failedDetails.join('\n');
        }
        notifyListeners();
        return;
      }

      if (_finalizeRecordResult == null) {
        _submissionPhase = RecordSubmissionPhase.failed;
        _submissionOperationMessage = '記録を確定できませんでした。';
        _submissionErrorMessage = '送信できませんでした。もう一度送信してください。';
        _submissionErrorDetail = '記録を確定できませんでした。';
        notifyListeners();
        return;
      }

      _submissionPhase = RecordSubmissionPhase.succeeded;
      _submissionOperationMessage = '保存が完了しました。';
      _submissionNoticeMessage = '建物・訪問・写真${_photos.length}枚を保存しました。';
      _submissionErrorMessage = null;
      _submissionErrorDetail = null;
      refreshBootstrapAfterSuccess = true;
      notifyListeners();
    } on RecordSubmissionApiException catch (error) {
      _submissionPhase = RecordSubmissionPhase.failed;
      _submissionOperationMessage = '送信に失敗しました。送信済みの内容は保持しています。';
      _currentUploadingPhotoId = null;
      if (_isAuthenticationRequired(error.errorCode)) {
        _markAuthenticationRequired(idToken);
        _submissionErrorMessage = 'ログインの有効期限が切れました。';
        _submissionErrorDetail = '入力内容と送信済み写真は保持されています。認証更新後にもう一度保存してください。';
      } else {
        _submissionErrorMessage = '送信できませんでした。もう一度送信してください。';
        _submissionErrorDetail = error.message;
      }
      notifyListeners();
    } catch (_) {
      _submissionPhase = RecordSubmissionPhase.failed;
      _submissionOperationMessage = '保存中に予期しないエラーが発生しました。';
      _currentUploadingPhotoId = null;
      _submissionErrorMessage = '送信できませんでした。もう一度送信してください。';
      _submissionErrorDetail = '記録の保存中に予期しないエラーが発生しました。';
      notifyListeners();
    } finally {
      submissionStopwatch.stop();
      _lastSubmissionDuration = submissionStopwatch.elapsed;
      notifyListeners();
    }

    if (refreshBootstrapAfterSuccess) {
      await loadBootstrapData();
    }
  }

  Future<String?> _resolveSubmissionIdToken() async {
    final String? currentToken = _authService.idToken;
    if (currentToken == null || currentToken.isEmpty) {
      return null;
    }

    if (_authService.hasIdTokenValidity(
      AppConfig.recordSubmissionMinTokenValidity,
    )) {
      _submissionOperationMessage = 'Googleログイン情報を確認しました。保存を開始します。';
      notifyListeners();
      return currentToken;
    }

    _submissionOperationMessage = 'Googleログイン情報の期限が近いため、認証を更新しています。';
    notifyListeners();

    final bool refreshed = await _authService.refreshIdToken();
    final String? refreshedToken = _authService.idToken;
    final bool hasUsableToken =
        refreshed &&
        refreshedToken != null &&
        refreshedToken.isNotEmpty &&
        _authService.hasIdTokenValidity(
          AppConfig.recordSubmissionMinTokenValidity,
        );

    if (!hasUsableToken) {
      _markAuthenticationRequired(currentToken);
      return null;
    }

    _requiresReauthentication = false;
    _authenticationFailureToken = null;
    _submissionOperationMessage = '認証を更新しました。保存を開始します。';
    notifyListeners();
    return refreshedToken;
  }

  Future<List<String>> _submitSinglePhotoRecord(
    String idToken,
    RecordSubmissionDraft submissionDraft,
  ) async {
    final RecordDraftPhoto photo = _photos.single;
    if (photoUploadStatus(photo.photoId) == RecordPhotoUploadStatus.uploaded &&
        _finalizeRecordResult != null) {
      return const <String>[];
    }

    _submissionPhase = RecordSubmissionPhase.finalizing;
    _submissionOperationMessage = '建物・訪問・写真を送信用データへ変換して保存しています。';
    _currentUploadingPhotoId = photo.photoId;
    _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.uploading;
    notifyListeners();

    final Stopwatch combinedSaveStopwatch = Stopwatch()..start();
    try {
      final UploadRecordPhotoResult uploadResult =
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
            takenAt: submissionDraft.visitedAt,
            latitude: submissionDraft.location.latitude,
            longitude: submissionDraft.location.longitude,
            accuracyM: submissionDraft.location.accuracyM,
            locationSource: submissionDraft.location.source.apiValue,
            displayOrder: 1,
            recordPreparation: _beginRecordResult == null
                ? submissionDraft.toRecordPreparationPayload(
                    requestId: _beginRequestId!,
                  )
                : null,
            finalizeAfterUpload: true,
          );

      _submissionSession.applyPhotoUploadResult(
        photoId: photo.photoId,
        result: uploadResult,
      );
      _beginRecordResult ??= BeginRecordResult(
        buildingId: _submissionBuildingId!,
        visitId: _submissionVisitId!,
        expectedPhotoCount: 1,
        buildingCreated: uploadResult.buildingCreated,
        visitCreated: uploadResult.visitCreated,
        reused: uploadResult.reused,
      );
      if (uploadResult.recordCompleted) {
        _finalizeRecordResult = FinalizeRecordResult(
          buildingId: _submissionBuildingId!,
          visitId: _submissionVisitId!,
          photoCount: uploadResult.photoCount ?? 1,
          status: 'completed',
          reused: uploadResult.reused,
        );
      }
      notifyListeners();
      return const <String>[];
    } on RecordSubmissionApiException catch (error) {
      _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.failed;
      if (_isAuthenticationRequired(error.errorCode)) {
        _markAuthenticationRequired(idToken);
      }
      notifyListeners();
      return <String>['${photo.fileName}: ${error.message}'];
    } catch (_) {
      _photoUploadStatuses[photo.photoId] = RecordPhotoUploadStatus.failed;
      notifyListeners();
      return <String>['${photo.fileName}: 不明なエラー'];
    } finally {
      combinedSaveStopwatch.stop();
      _lastCombinedSaveDuration = combinedSaveStopwatch.elapsed;
    }
  }

  Future<List<String>> _submitMultiplePhotoRecord(
    String idToken,
    RecordSubmissionDraft submissionDraft,
  ) async {
    if (_beginRecordResult == null) {
      _submissionPhase = RecordSubmissionPhase.starting;
      _submissionOperationMessage = '建物・訪問データを送信しています。';
      notifyListeners();

      final Stopwatch preparationStopwatch = Stopwatch()..start();
      try {
        final BeginRecordResult beginResult = await _recordSubmissionApiService
            .beginRecord(
              requestId: _beginRequestId!,
              clientVersion: AppConfig.version,
              idToken: idToken,
              buildingMode: submissionDraft.buildingMode,
              buildingId: submissionDraft.buildingId,
              visitId: submissionDraft.visitId,
              buildingName: submissionDraft.buildingName,
              designTagIds: submissionDraft.designTagIds,
              salesTagIds: submissionDraft.salesTagIds,
              constructionTagIds: submissionDraft.constructionTagIds,
              visitedAt: submissionDraft.visitedAt,
              triggerTagIds: submissionDraft.triggerTagIds,
              impression: submissionDraft.impression,
              latitude: submissionDraft.location.latitude,
              longitude: submissionDraft.location.longitude,
              accuracyM: submissionDraft.location.accuracyM,
              locationSource: submissionDraft.location.source.apiValue,
              expectedPhotoCount: submissionDraft.expectedPhotoCount,
            );
        _beginRecordResult = beginResult;
        _submissionBuildingId = beginResult.buildingId;
        _submissionVisitId = beginResult.visitId;
      } finally {
        preparationStopwatch.stop();
        _lastPreparationDuration = preparationStopwatch.elapsed;
      }
    }

    final List<RecordDraftPhoto> pendingPhotos = _photos
        .where(
          (RecordDraftPhoto photo) =>
              photoUploadStatus(photo.photoId) !=
              RecordPhotoUploadStatus.uploaded,
        )
        .toList(growable: false);
    final List<String> failedDetails = <String>[];

    if (pendingPhotos.isNotEmpty) {
      final Stopwatch photoUploadStopwatch = Stopwatch()..start();
      try {
        for (int offset = 0; offset < pendingPhotos.length; offset += 4) {
          final int end = (offset + 4).clamp(0, pendingPhotos.length).toInt();
          final List<RecordDraftPhoto> wave = pendingPhotos.sublist(
            offset,
            end,
          );

          _submissionPhase = RecordSubmissionPhase.uploading;
          final int completedBeforeWave = uploadedPhotoCount;
          _submissionOperationMessage =
              '写真を送信用データへ変換して送信しています。'
              ' 完了 $completedBeforeWave/${_photos.length}枚、'
              '今回 ${wave.length}枚を処理中です。';
          _currentUploadingPhotoId = wave.first.photoId;
          for (final RecordDraftPhoto photo in wave) {
            _photoUploadStatuses[photo.photoId] =
                RecordPhotoUploadStatus.uploading;
          }
          notifyListeners();

          final List<RecordPhotoUploadAttempt> attempts = await Future.wait(
            wave.map((RecordDraftPhoto photo) {
              return _photoUploadExecutor.upload(
                requestId: _photoRequestIds[photo.photoId]!,
                idToken: idToken,
                buildingId: _submissionBuildingId!,
                visitId: _submissionVisitId!,
                submissionDraft: submissionDraft,
                photo: photo,
                displayOrder: _photos.indexOf(photo) + 1,
              );
            }),
          );

          for (final RecordPhotoUploadAttempt attempt in attempts) {
            final UploadRecordPhotoResult? result = attempt.result;
            if (result != null) {
              _submissionSession.applyPhotoUploadResult(
                photoId: attempt.photo.photoId,
                result: result,
              );
              continue;
            }

            _photoUploadStatuses[attempt.photo.photoId] =
                RecordPhotoUploadStatus.failed;
            if (attempt.authenticationRequired) {
              _markAuthenticationRequired(idToken);
            }
            failedDetails.add(
              '${attempt.photo.fileName}: '
              '${attempt.errorMessage ?? '不明なエラー'}',
            );
          }
          notifyListeners();

          if (failedDetails.isNotEmpty) {
            _submissionOperationMessage = '一部の写真送信に失敗しました。失敗分だけ再送できます。';
            return failedDetails;
          }
        }
      } finally {
        photoUploadStopwatch.stop();
        _lastPhotoUploadDuration = photoUploadStopwatch.elapsed;
      }
    }

    if (_finalizeRecordResult == null) {
      _submissionPhase = RecordSubmissionPhase.finalizing;
      _submissionOperationMessage = '保存した写真を確認して記録を確定しています。';
      _currentUploadingPhotoId = null;
      notifyListeners();

      final Stopwatch finalizeStopwatch = Stopwatch()..start();
      try {
        _finalizeRecordResult = await _recordSubmissionApiService
            .finalizeRecord(
              requestId: _finalizeRequestId!,
              clientVersion: AppConfig.version,
              idToken: idToken,
              buildingId: _submissionBuildingId!,
              visitId: _submissionVisitId!,
            );
      } finally {
        finalizeStopwatch.stop();
        _lastFinalizeDuration = finalizeStopwatch.elapsed;
      }
    }

    return failedDetails;
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
    _requiresReauthentication = false;
    _authenticationFailureToken = null;
    _errorMessage = null;
    _noticeMessage = null;
    _photoPreparationStatusMessage = null;
    _submissionSession.reset();
    _draftRevision += 1;
    notifyListeners();

    await loadBootstrapData();
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

  void useManualLocation({
    required double latitude,
    required double longitude,
  }) {
    if (isDraftLocked) {
      return;
    }

    _visitLocation = RecordDraftLocation(
      latitude: latitude,
      longitude: longitude,
      accuracyM: null,
      source: RecordLocationSource.manual,
      capturedAt: DateTime.now(),
    );
    _locationErrorMessage = null;
    _locationNoticeMessage = '地図で指定した位置を使用します。';
    notifyListeners();
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

  void _handleAuthServiceChanged() {
    if (!_requiresReauthentication) {
      return;
    }

    final String? currentToken = _authService.idToken;
    if (currentToken == null ||
        currentToken.isEmpty ||
        currentToken == _authenticationFailureToken) {
      return;
    }

    _completeReauthentication();
    notifyListeners();
    unawaited(loadBootstrapData());
  }

  void _markAuthenticationRequired(String failedToken) {
    _requiresReauthentication = true;
    _authenticationFailureToken = failedToken;
  }

  void _completeReauthentication() {
    _requiresReauthentication = false;
    _authenticationFailureToken = null;
    _bootstrapErrorMessage = null;
    if (_submissionPhase == RecordSubmissionPhase.failed &&
        _submissionErrorMessage == 'ログインの有効期限が切れました。') {
      _submissionErrorDetail = '認証を更新しました。もう一度「記録を保存」を押してください。';
    }
  }

  bool _isAuthenticationRequired(String? errorCode) {
    return errorCode == 'AUTH_REQUIRED';
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

  @override
  void dispose() {
    _authService.removeListener(_handleAuthServiceChanged);
    super.dispose();
  }
}

String _normalizeSearchText(String value) {
  return value.trim().toLowerCase();
}
