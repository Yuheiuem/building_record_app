import 'dart:typed_data';

import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/models/record_draft_photo.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/record_image_picker_service.dart';
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
}

RecordDraftController _createController({
  List<RecordDraftPhoto> photos = const <RecordDraftPhoto>[],
  BootstrapData? bootstrapData,
}) {
  return RecordDraftController(
    imagePickerService: _FakeRecordImagePickerService(photos),
    bootstrapApiService: _FakeBootstrapApiService(
      bootstrapData ?? _emptyBootstrapData(),
    ),
    authService: _FakeAuthService(),
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
    counts: const BootstrapCounts(buildings: 2, visits: 0, photos: 0, tags: 4),
  );
}

Building _building({
  required String id,
  required String name,
  String? address,
  List<String> designTags = const <String>[],
  List<String> salesTags = const <String>[],
  List<String> constructionTags = const <String>[],
}) {
  return Building(
    buildingId: id,
    buildingName: name,
    searchName: name,
    latitude: null,
    longitude: null,
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
