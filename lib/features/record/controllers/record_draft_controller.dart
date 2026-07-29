import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../data/models/bootstrap_data.dart';
import '../../../data/models/building.dart';
import '../../../data/models/building_tag.dart';
import '../../../data/models/record_draft_location.dart';
import '../../../data/models/record_draft_photo.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/bootstrap_api_service.dart';
import '../../../data/services/record_image_picker_service.dart';
import '../../../data/services/record_location_service.dart';

enum RecordBuildingMode { newBuilding, existingBuilding }

class RecordDraftController extends ChangeNotifier {
  RecordDraftController({
    required RecordImagePickerService imagePickerService,
    required BootstrapApiService bootstrapApiService,
    required AuthService authService,
    required RecordLocationService locationService,
  }) : _imagePickerService = imagePickerService,
       _bootstrapApiService = bootstrapApiService,
       _authService = authService,
       _locationService = locationService;

  final RecordImagePickerService _imagePickerService;
  final BootstrapApiService _bootstrapApiService;
  final AuthService _authService;
  final RecordLocationService _locationService;

  final List<RecordDraftPhoto> _photos = <RecordDraftPhoto>[];
  final List<Building> _buildings = <Building>[];
  final List<BuildingTag> _tags = <BuildingTag>[];
  final Set<String> _selectedDesignTagIds = <String>{};
  final Set<String> _selectedSalesTagIds = <String>{};
  final Set<String> _selectedConstructionTagIds = <String>{};
  final Set<String> _selectedTriggerTagIds = <String>{};

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
        ..addAll(data.tags.where((BuildingTag tag) => tag.isActive))
        ..sort((BuildingTag left, BuildingTag right) {
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

      final String? selectedId = _selectedExistingBuilding?.buildingId;
      if (selectedId != null) {
        _selectedExistingBuilding = _findBuildingById(selectedId);
      }

      _removeUnavailableTagIds(_selectedDesignTagIds);
      _removeUnavailableTagIds(_selectedSalesTagIds);
      _removeUnavailableTagIds(_selectedConstructionTagIds);
      _removeUnavailableTagIds(_selectedTriggerTagIds);
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
    if (_isPicking) {
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
    final int previousCount = _photos.length;
    _photos.removeWhere((RecordDraftPhoto photo) => photo.photoId == photoId);
    if (_photos.length == previousCount) {
      return;
    }

    _errorMessage = null;
    _noticeMessage = '写真を1枚削除しました。';
    notifyListeners();
  }

  void clearPhotos() {
    if (_photos.isEmpty) {
      return;
    }

    _photos.clear();
    _errorMessage = null;
    _noticeMessage = '写真の下書きを空にしました。';
    notifyListeners();
  }

  void setBuildingMode(RecordBuildingMode mode) {
    if (_buildingMode == mode) {
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
    _newBuildingName = value;
  }

  void toggleBuildingTag(BuildingTagType type, String tagId) {
    if (type == BuildingTagType.trigger) {
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

  void setBuildingSearchQuery(String value) {
    if (_buildingSearchQuery == value) {
      return;
    }

    _buildingSearchQuery = value;
    notifyListeners();
  }

  void selectExistingBuilding(String buildingId) {
    final Building? building = _findBuildingById(buildingId);
    if (building == null || building == _selectedExistingBuilding) {
      return;
    }

    _selectedExistingBuilding = building;
    if (_visitLocation?.source == RecordLocationSource.buildingFallback) {
      _setSelectedBuildingFallbackLocation(notify: false);
    }
    notifyListeners();
  }

  void clearExistingBuildingSelection() {
    if (_selectedExistingBuilding == null) {
      return;
    }

    _selectedExistingBuilding = null;
    if (_visitLocation?.source == RecordLocationSource.buildingFallback) {
      _visitLocation = null;
      _locationNoticeMessage = '建物の代表位置を解除しました。';
    }
    notifyListeners();
  }

  void toggleTriggerTag(String tagId) {
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
    _impression = value;
  }

  Future<void> acquireCurrentLocation() async {
    if (_isGettingLocation) {
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
    _setSelectedBuildingFallbackLocation(notify: true);
  }

  void clearVisitLocation() {
    if (_visitLocation == null) {
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
