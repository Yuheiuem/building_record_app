import 'dart:typed_data';

import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_location.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/models/tag_creation_result.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
import 'package:building_record_app/data/services/record_location_service.dart';
import 'package:building_record_app/data/services/tag_api_service.dart';
import 'package:building_record_app/features/record/controllers/record_draft_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('複数写真を下書きへ追加し合計容量を計算する', () async {
    final RecordDraftController controller = _createController(
      photos: <RecordDraftPhoto>[
        _photo(id: 'photo-1', fileName: 'one.jpg', byteSize: 1200),
        _photo(id: 'photo-2', fileName: 'two.png', byteSize: 2400),
      ],
    );

    await controller.addPhotos();

    expect(controller.photoCount, 2);
    expect(controller.totalBytes, 3600);
    expect(controller.noticeMessage, '2枚を下書きへ追加しました。');
    expect(controller.errorMessage, isNull);
  });

  test('個別写真を削除できる', () async {
    final RecordDraftController controller = _createController(
      photos: <RecordDraftPhoto>[
        _photo(id: 'photo-1', fileName: 'one.jpg', byteSize: 1200),
        _photo(id: 'photo-2', fileName: 'two.png', byteSize: 2400),
      ],
    );

    await controller.addPhotos();
    controller.removePhoto('photo-1');

    expect(controller.photoCount, 1);
    expect(controller.photos.single.photoId, 'photo-2');
    expect(controller.totalBytes, 2400);
  });

  test('未対応形式と5MB超過写真は追加しない', () async {
    final RecordDraftController controller = _createController(
      photos: <RecordDraftPhoto>[
        RecordDraftPhoto(
          photoId: 'unsupported',
          fileName: 'photo.heic',
          mimeType: 'image/heic',
          bytes: Uint8List(100),
        ),
        _photo(
          id: 'oversized',
          fileName: 'large.jpg',
          byteSize: 5 * 1024 * 1024 + 1,
        ),
        _photo(id: 'accepted', fileName: 'ok.jpg', byteSize: 1000),
      ],
    );

    await controller.addPhotos();

    expect(controller.photoCount, 1);
    expect(controller.photos.single.photoId, 'accepted');
    expect(controller.errorMessage, '未対応形式 1枚、5MB超過 1枚は追加しませんでした。');
  });

  test('建物とタグを読み込み、新規建物の入力を保持する', () async {
    final RecordDraftController controller = _createController(
      photos: <RecordDraftPhoto>[
        _photo(id: 'photo-1', fileName: 'one.jpg', byteSize: 1200),
      ],
      bootstrapData: _bootstrapData(),
    );

    await controller.loadBootstrapData();
    await controller.addPhotos();
    controller.setNewBuildingName('テスト建物');
    controller.toggleBuildingTag(BuildingTagType.construction, 'tag-con-1');
    controller.setBuildingMode(RecordBuildingMode.existingBuilding);
    controller.setBuildingMode(RecordBuildingMode.newBuilding);

    expect(controller.hasLoadedBootstrap, isTrue);
    expect(controller.buildings.length, 2);
    expect(controller.tagsFor(BuildingTagType.construction).length, 2);
    expect(controller.newBuildingName, 'テスト建物');
    expect(
      controller.isTagSelected(BuildingTagType.construction, 'tag-con-1'),
      isTrue,
    );
    expect(controller.photoCount, 1);
  });

  test('既存建物を検索して選択できる', () async {
    final RecordDraftController controller = _createController(
      bootstrapData: _bootstrapData(),
    );

    await controller.loadBootstrapData();
    controller.setBuildingMode(RecordBuildingMode.existingBuilding);
    controller.setBuildingSearchQuery('第二');

    expect(controller.filteredBuildings, hasLength(1));
    expect(controller.filteredBuildings.single.buildingId, 'building-2');

    controller.selectExistingBuilding('building-2');
    expect(controller.selectedExistingBuilding?.buildingName, '第二工場');
    expect(controller.selectedExistingBuilding?.constructionTags, <String>[
      '鹿島施工',
    ]);
  });

  test('きっかけタグと感想を建物モード切替後も保持する', () async {
    final RecordDraftController controller = _createController(
      bootstrapData: _bootstrapData(),
    );

    await controller.loadBootstrapData();
    controller.toggleTriggerTag('tag-trigger-1');
    controller.setImpression('外観の素材の切り替えが印象的だった。');
    controller.setBuildingMode(RecordBuildingMode.existingBuilding);
    controller.setBuildingMode(RecordBuildingMode.newBuilding);

    expect(
      controller.isTagSelected(BuildingTagType.trigger, 'tag-trigger-1'),
      isTrue,
    );
    expect(controller.impression, '外観の素材の切り替えが印象的だった。');
  });

  test('現在地を取得して下書きに保持し、クリアできる', () async {
    final RecordDraftLocation location = _gpsLocation();
    final RecordDraftController controller = _createController(
      locationService: _FakeRecordLocationService(location),
    );

    await controller.acquireCurrentLocation();

    expect(controller.visitLocation, same(location));
    expect(controller.locationNoticeMessage, '現在地を取得しました。');
    expect(controller.locationErrorMessage, isNull);

    controller.clearVisitLocation();
    expect(controller.visitLocation, isNull);
    expect(controller.locationNoticeMessage, '位置情報をクリアしました。');
  });

  test('既存建物の代表位置を訪問位置として利用できる', () async {
    final RecordDraftController controller = _createController(
      bootstrapData: _bootstrapData(),
    );

    await controller.loadBootstrapData();
    controller.setBuildingMode(RecordBuildingMode.existingBuilding);
    controller.selectExistingBuilding('building-1');

    expect(controller.canUseSelectedBuildingLocation, isTrue);

    controller.useSelectedBuildingLocation();

    expect(
      controller.visitLocation?.source,
      RecordLocationSource.buildingFallback,
    );
    expect(controller.visitLocation?.latitude, 35.681236);
    expect(controller.visitLocation?.longitude, 139.767125);
    expect(controller.visitLocation?.accuracyM, isNull);
  });
  test('新しいタグを追加すると候補へ反映して自動選択する', () async {
    final BuildingTag createdTag = _tag(
      id: 'tag-design-new',
      type: BuildingTagType.design,
      name: '新しい設計室',
      order: 20,
    );
    final _FakeTagApiService tagService = _FakeTagApiService(
      TagCreationResult(tag: createdTag, created: true, reactivated: false),
    );
    final RecordDraftController controller = _createController(
      bootstrapData: _bootstrapData(),
      tagApiService: tagService,
    );

    await controller.loadBootstrapData();
    final String? error = await controller.createAndSelectTag(
      BuildingTagType.design,
      '新しい設計室',
    );

    expect(error, isNull);
    expect(tagService.lastType, BuildingTagType.design);
    expect(tagService.lastName, '新しい設計室');
    expect(
      controller
          .tagsFor(BuildingTagType.design)
          .map((BuildingTag tag) => tag.tagId),
      contains('tag-design-new'),
    );
    expect(
      controller.isTagSelected(BuildingTagType.design, 'tag-design-new'),
      isTrue,
    );
    expect(controller.noticeMessage, '「新しい設計室」を追加して選択しました。');
  });

  test('同名の既存タグが返った場合は重複させず選択する', () async {
    final BuildingTag existingTag = _tag(
      id: 'tag-trigger-1',
      type: BuildingTagType.trigger,
      name: '営業の仕事',
      order: 1,
    );
    final RecordDraftController controller = _createController(
      bootstrapData: _bootstrapData(),
      tagApiService: _FakeTagApiService(
        TagCreationResult(tag: existingTag, created: false, reactivated: false),
      ),
    );

    await controller.loadBootstrapData();
    final String? error = await controller.createAndSelectTag(
      BuildingTagType.trigger,
      '営業の仕事',
    );

    expect(error, isNull);
    expect(
      controller
          .tagsFor(BuildingTagType.trigger)
          .where((BuildingTag tag) => tag.tagId == 'tag-trigger-1'),
      hasLength(1),
    );
    expect(
      controller.isTagSelected(BuildingTagType.trigger, 'tag-trigger-1'),
      isTrue,
    );
    expect(controller.noticeMessage, '登録済みの「営業の仕事」を選択しました。');
  });

  test('既存建物で追加したタグは建物への追加予定として保持する', () async {
    final BuildingTag createdTag = _tag(
      id: 'tag-design-existing-new',
      type: BuildingTagType.design,
      name: '追加設計室',
      order: 30,
    );
    final RecordDraftController controller = _createController(
      bootstrapData: _bootstrapData(),
      tagApiService: _FakeTagApiService(
        TagCreationResult(tag: createdTag, created: true, reactivated: false),
      ),
    );

    await controller.loadBootstrapData();
    controller.setBuildingMode(RecordBuildingMode.existingBuilding);
    controller.selectExistingBuilding('building-1');

    final String? error = await controller.createAndSelectTag(
      BuildingTagType.design,
      '追加設計室',
    );

    expect(error, isNull);
    expect(
      controller.isExistingBuildingTagSelected(
        BuildingTagType.design,
        'tag-design-existing-new',
      ),
      isTrue,
    );
    expect(
      controller.isTagSelected(
        BuildingTagType.design,
        'tag-design-existing-new',
      ),
      isFalse,
    );
  });
}

RecordDraftController _createController({
  List<RecordDraftPhoto> photos = const <RecordDraftPhoto>[],
  BootstrapData? bootstrapData,
  RecordLocationService? locationService,
  TagApiService? tagApiService,
}) {
  return RecordDraftController(
    imagePickerService: _FakeRecordImagePickerService(photos),
    bootstrapApiService: _FakeBootstrapApiService(
      bootstrapData ?? _emptyBootstrapData(),
    ),
    authService: _FakeAuthService(),
    locationService:
        locationService ?? _FakeRecordLocationService(_gpsLocation()),
    tagApiService:
        tagApiService ?? _FakeTagApiService(_defaultTagCreationResult()),
  );
}

RecordDraftPhoto _photo({
  required String id,
  required String fileName,
  required int byteSize,
}) {
  return RecordDraftPhoto(
    photoId: id,
    fileName: fileName,
    mimeType: fileName.endsWith('.png') ? 'image/png' : 'image/jpeg',
    bytes: Uint8List(byteSize),
  );
}

RecordDraftLocation _gpsLocation() {
  return RecordDraftLocation(
    latitude: 35.681236,
    longitude: 139.767125,
    accuracyM: 8.4,
    source: RecordLocationSource.gps,
    capturedAt: DateTime.parse('2026-07-29T10:00:00+09:00'),
  );
}

BootstrapData _emptyBootstrapData() {
  return BootstrapData(
    requestId: 'request-empty',
    serverTime: DateTime.parse('2026-07-29T12:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '2-2',
    buildings: const <Building>[],
    tags: const <BuildingTag>[],
    counts: const BootstrapCounts(buildings: 0, visits: 0, photos: 0, tags: 0),
  );
}

BootstrapData _bootstrapData() {
  return BootstrapData(
    requestId: 'request-1',
    serverTime: DateTime.parse('2026-07-29T12:00:00+09:00'),
    schemaVersion: '1.0',
    stage: '2-2',
    buildings: <Building>[
      _building(
        id: 'building-1',
        name: '第一ビル',
        address: '東京都千代田区',
        latitude: 35.681236,
        longitude: 139.767125,
        designTags: const <String>['設計第一室'],
        salesTags: const <String>['営業第一部'],
        constructionTags: const <String>['当社施工'],
      ),
      _building(
        id: 'building-2',
        name: '第二工場',
        address: '神奈川県横浜市',
        constructionTags: const <String>['鹿島施工'],
      ),
    ],
    tags: <BuildingTag>[
      _tag(
        id: 'tag-trigger-1',
        type: BuildingTagType.trigger,
        name: '営業の仕事',
        order: 1,
      ),
      _tag(
        id: 'tag-trigger-2',
        type: BuildingTagType.trigger,
        name: '個人旅行',
        order: 2,
      ),
      _tag(
        id: 'tag-design-1',
        type: BuildingTagType.design,
        name: '設計第一室',
        order: 1,
      ),
      _tag(
        id: 'tag-sales-1',
        type: BuildingTagType.sales,
        name: '営業第一部',
        order: 1,
      ),
      _tag(
        id: 'tag-con-1',
        type: BuildingTagType.construction,
        name: '当社施工',
        order: 1,
      ),
      _tag(
        id: 'tag-con-2',
        type: BuildingTagType.construction,
        name: '鹿島施工',
        order: 2,
      ),
    ],
    counts: const BootstrapCounts(buildings: 2, visits: 0, photos: 0, tags: 6),
  );
}

Building _building({
  required String id,
  required String name,
  String? address,
  double? latitude,
  double? longitude,
  List<String> designTags = const <String>[],
  List<String> salesTags = const <String>[],
  List<String> constructionTags = const <String>[],
}) {
  return Building(
    buildingId: id,
    buildingName: name,
    searchName: name,
    latitude: latitude,
    longitude: longitude,
    address: address,
    designTags: designTags,
    salesTags: salesTags,
    constructionTags: constructionTags,
    driveFolderId: null,
    coverPhotoId: null,
    createdAt: null,
    updatedAt: null,
    isDeleted: false,
  );
}

BuildingTag _tag({
  required String id,
  required BuildingTagType type,
  required String name,
  required int order,
}) {
  return BuildingTag(
    tagId: id,
    tagType: type,
    tagName: name,
    normalizedName: name,
    displayOrder: order,
    isActive: true,
    createdAt: null,
    updatedAt: null,
  );
}

TagCreationResult _defaultTagCreationResult() {
  return TagCreationResult(
    tag: _tag(
      id: 'tag-trigger-default',
      type: BuildingTagType.trigger,
      name: '既定タグ',
      order: 999,
    ),
    created: true,
    reactivated: false,
  );
}

class _FakeTagApiService implements TagApiService {
  _FakeTagApiService(this.result);

  final TagCreationResult result;
  BuildingTagType? lastType;
  String? lastName;

  @override
  Future<TagCreationResult> createTag({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required BuildingTagType tagType,
    required String tagName,
  }) async {
    lastType = tagType;
    lastName = tagName;
    return result;
  }

  @override
  void close() {}
}

class _FakeRecordImagePickerService implements RecordImagePickerService {
  const _FakeRecordImagePickerService(this.photos);

  final List<RecordDraftPhoto> photos;

  @override
  Future<List<RecordDraftPhoto>> pickImages() async => photos;
}

class _FakeBootstrapApiService implements BootstrapApiService {
  const _FakeBootstrapApiService(this.data);

  final BootstrapData data;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    return data;
  }

  @override
  void close() {}
}

class _FakeRecordLocationService implements RecordLocationService {
  const _FakeRecordLocationService(this.location);

  final RecordDraftLocation location;

  @override
  Future<RecordDraftLocation> getCurrentLocation() async => location;
}

class _FakeAuthService extends AuthService {
  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser get currentUser => const AuthenticatedGoogleUser(
    email: 'test@example.com',
    displayName: 'テスト利用者',
  );

  @override
  String get idToken => 'test-id-token';

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}
