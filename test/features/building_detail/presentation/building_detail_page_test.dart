import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_detail_data.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/data/services/building_detail_api_service.dart';
import 'package:building_record_app/data/services/building_information_api_service.dart';
import 'package:building_record_app/data/services/building_location_api_service.dart';
import 'package:building_record_app/data/services/visit_information_api_service.dart';
import 'package:building_record_app/features/building_detail/presentation/building_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('建物情報・写真・訪問履歴を表示し再取得できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService apiService =
        _FakeBuildingDetailApiService();
    final _FakeBuildingLocationApiService locationApiService =
        _FakeBuildingLocationApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingDetailPage(
          authService: _FakeAuthService(),
          buildingId: 'building-12345678',
          buildingDetailApiService: apiService,
          buildingLocationApiService: locationApiService,
          enableNetworkTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(apiService.detailCallCount, 1);
    expect(apiService.lastBuildingId, 'building-12345678');
    expect(find.text('テスト建物'), findsOneWidget);
    expect(find.text(AppConfig.version), findsOneWidget);
    expect(find.text('東京都千代田区'), findsOneWidget);
    expect(find.text('設計第一部'), findsOneWidget);
    expect(find.text('設計研修'), findsOneWidget);
    expect(find.text('外観を見学した。'), findsOneWidget);
    expect(find.text('写真ギャラリー'), findsOneWidget);
    expect(find.text('訪問履歴'), findsOneWidget);
    expect(find.byKey(const Key('edit-building-information')), findsOneWidget);
    expect(find.byKey(const Key('record-building-revisit')), findsOneWidget);
    expect(
      find.byKey(const Key('building-representative-location-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('edit-visit-visit-12345678')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('add-photos-to-visit-visit-12345678')),
      findsOneWidget,
    );
    expect(apiService.thumbnailCallCount, 4);
    expect(apiService.photoCallCount, 0);
    expect(find.byKey(const Key('show-all-building-photos')), findsOneWidget);
    expect(find.byKey(const Key('open-building-drive-folder')), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('building-photo-photo-00000001')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(apiService.photoCallCount, 1);
    expect(find.byType(InteractiveViewer), findsOneWidget);

    await tester.tap(find.byTooltip('閉じる'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.byKey(const Key('show-all-building-photos')),
    );
    await tester.tap(find.byKey(const Key('show-all-building-photos')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(apiService.thumbnailCallCount, 6);
    expect(
      find.byKey(const ValueKey<String>('building-photo-photo-00000006')),
      findsOneWidget,
    );

    final Finder representativeLocationChip = find.byKey(
      const Key('building-representative-location-chip'),
    );
    await tester.ensureVisible(representativeLocationChip);
    await tester.pumpAndSettle();
    await tester.tap(representativeLocationChip);
    await tester.pumpAndSettle();

    expect(find.text('地図で位置を指定'), findsOneWidget);
    expect(find.text('緯度 35.681200'), findsOneWidget);
    expect(find.text('経度 139.767100'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-map-location')));
    await tester.pumpAndSettle();

    expect(locationApiService.updateCallCount, 1);
    expect(locationApiService.lastBuildingId, 'building-12345678');
    expect(locationApiService.lastLatitude, 35.6812);
    expect(locationApiService.lastLongitude, 139.7671);
    expect(apiService.detailCallCount, 2);
    expect(find.text('建物の代表位置を更新しました。'), findsOneWidget);

    final Finder refreshButton = find.byKey(
      const Key('refresh-building-detail'),
    );
    await tester.ensureVisible(refreshButton);
    await tester.pumpAndSettle();
    await tester.tap(refreshButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(apiService.detailCallCount, 3);
  });

  testWidgets('建物名・住所・建物タグを編集できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService();
    final _FakeBootstrapApiService bootstrapApiService =
        _FakeBootstrapApiService();
    final _FakeBuildingInformationApiService informationApiService =
        _FakeBuildingInformationApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingDetailPage(
          authService: _FakeAuthService(),
          buildingId: 'building-12345678',
          buildingDetailApiService: detailApiService,
          buildingLocationApiService: _FakeBuildingLocationApiService(),
          bootstrapApiService: bootstrapApiService,
          buildingInformationApiService: informationApiService,
          enableNetworkTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Finder editButton = find.byKey(
      const Key('edit-building-information'),
    );
    await tester.ensureVisible(editButton);
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(bootstrapApiService.callCount, 1);
    expect(find.byKey(const Key('edit-building-name-field')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('edit-building-name-field')),
      '更新後のテスト建物',
    );
    await tester.enterText(
      find.byKey(const Key('edit-building-address-field')),
      '東京都千代田区丸の内1-1',
    );

    final Finder salesTag = find.byKey(
      const ValueKey<String>('edit-building-tag-tag-sales-1234'),
    );
    await tester.ensureVisible(salesTag);
    await tester.pumpAndSettle();
    await tester.tap(salesTag);
    await tester.pumpAndSettle();

    final Finder saveButton = find.byKey(
      const Key('save-building-information-edit'),
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(informationApiService.updateCallCount, 1);
    expect(informationApiService.lastBuildingId, 'building-12345678');
    expect(informationApiService.lastBuildingName, '更新後のテスト建物');
    expect(informationApiService.lastAddress, '東京都千代田区丸の内1-1');
    expect(informationApiService.lastDesignTagIds, <String>['tag-design-1234']);
    expect(informationApiService.lastSalesTagIds, <String>['tag-sales-1234']);
    expect(informationApiService.lastConstructionTagIds, <String>[
      'tag-construction-1234',
    ]);
    expect(detailApiService.detailCallCount, 2);
    expect(find.text('建物情報を更新しました。'), findsOneWidget);
  });

  testWidgets('訪問記録のきっかけ・感想・位置を編集できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService();
    final _FakeBootstrapApiService bootstrapApiService =
        _FakeBootstrapApiService();
    final _FakeVisitInformationApiService visitInformationApiService =
        _FakeVisitInformationApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingDetailPage(
          authService: _FakeAuthService(),
          buildingId: 'building-12345678',
          buildingDetailApiService: detailApiService,
          buildingLocationApiService: _FakeBuildingLocationApiService(),
          bootstrapApiService: bootstrapApiService,
          buildingInformationApiService: _FakeBuildingInformationApiService(),
          visitInformationApiService: visitInformationApiService,
          enableNetworkTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Finder editButton = find.byKey(
      const ValueKey<String>('edit-visit-visit-12345678'),
    );
    await tester.ensureVisible(editButton);
    await tester.pumpAndSettle();
    await tester.tap(editButton);
    await tester.pumpAndSettle();

    expect(bootstrapApiService.callCount, 1);
    expect(
      find.descendant(of: find.byType(Dialog), matching: find.text('訪問記録を編集')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('edit-visit-impression-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('edit-visit-impression-field')),
      '更新後の訪問感想',
    );

    final Finder activeTriggerTag = find.byKey(
      const ValueKey<String>('edit-visit-trigger-tag-tag-trigger-active-1234'),
    );
    await tester.ensureVisible(activeTriggerTag);
    await tester.pumpAndSettle();
    await tester.tap(activeTriggerTag);
    await tester.pumpAndSettle();

    final Finder locationButton = find.byKey(const Key('edit-visit-location'));
    await tester.ensureVisible(locationButton);
    await tester.pumpAndSettle();
    await tester.tap(locationButton);
    await tester.pumpAndSettle();

    expect(find.text('地図で位置を指定'), findsOneWidget);
    expect(find.text('緯度 35.681300'), findsOneWidget);
    expect(find.text('経度 139.767200'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirm-map-location')));
    await tester.pumpAndSettle();

    final Finder saveButton = find.byKey(
      const Key('save-visit-information-edit'),
    );
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    expect(visitInformationApiService.updateCallCount, 1);
    expect(visitInformationApiService.lastBuildingId, 'building-12345678');
    expect(visitInformationApiService.lastVisitId, 'visit-12345678');
    expect(
      visitInformationApiService.lastVisitedAt,
      DateTime.parse('2026-07-30T14:00:00+09:00').toLocal(),
    );
    expect(visitInformationApiService.lastTriggerTagIds, <String>[
      'tag-trigger-1234',
      'tag-trigger-active-1234',
    ]);
    expect(visitInformationApiService.lastImpression, '更新後の訪問感想');
    expect(visitInformationApiService.lastLatitude, 35.6813);
    expect(visitInformationApiService.lastLongitude, 139.7672);
    expect(visitInformationApiService.lastAccuracyM, isNull);
    expect(visitInformationApiService.lastLocationSource, 'manual');
    expect(detailApiService.detailCallCount, 2);
    expect(find.text('訪問記録を更新しました。'), findsOneWidget);
  });
}

class _FakeAuthService extends AuthService {
  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser get currentUser =>
      const AuthenticatedGoogleUser(email: 'test@example.com');

  @override
  String get idToken => 'test-id-token';

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}

class _FakeBuildingDetailApiService implements BuildingDetailApiService {
  int detailCallCount = 0;
  int thumbnailCallCount = 0;
  int photoCallCount = 0;
  String? lastBuildingId;

  @override
  Future<BuildingDetailData> getBuildingDetail({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    detailCallCount += 1;
    lastBuildingId = buildingId;

    return BuildingDetailData(
      requestId: requestId,
      serverTime: DateTime.parse('2026-07-30T15:30:00+09:00'),
      schemaVersion: '1.0',
      stage: '4-2',
      building: Building(
        buildingId: buildingId,
        buildingName: 'テスト建物',
        searchName: 'てすとたてもの',
        latitude: 35.6812,
        longitude: 139.7671,
        address: '東京都千代田区',
        designTags: const <String>['tag-design-1234'],
        salesTags: const <String>[],
        constructionTags: const <String>['tag-construction-1234'],
        driveFolderId: 'drive-folder-12345678',
        coverPhotoId: 'photo-12345678',
        createdAt: null,
        updatedAt: null,
        isDeleted: false,
      ),
      visits: <BuildingVisit>[
        BuildingVisit(
          visitId: 'visit-12345678',
          buildingId: buildingId,
          visitedAt: DateTime.parse('2026-07-30T14:00:00+09:00'),
          triggerTags: const <String>['tag-trigger-1234'],
          impression: '外観を見学した。',
          latitude: 35.6813,
          longitude: 139.7672,
          accuracyM: 8.5,
          locationSource: 'gps',
          status: 'completed',
          expectedPhotoCount: 6,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      photos: List<BuildingPhoto>.generate(6, (int index) {
        final int number = index + 1;
        return BuildingPhoto(
          photoId: 'photo-${number.toString().padLeft(8, '0')}',
          buildingId: buildingId,
          visitId: 'visit-12345678',
          fileName: 'photo-$number.png',
          mimeType: 'image/png',
          byteSize: _pngBytes.length,
          width: 1,
          height: 1,
          takenAt: DateTime.parse('2026-07-30T14:00:00+09:00'),
          latitude: 35.6813,
          longitude: 139.7672,
          accuracyM: 8.5,
          locationSource: 'gps',
          displayOrder: number,
          createdAt: null,
        );
      }),
      tags: const <BuildingTag>[
        BuildingTag(
          tagId: 'tag-trigger-active-1234',
          tagType: BuildingTagType.trigger,
          tagName: '個人旅行',
          normalizedName: '個人旅行',
          displayOrder: 20,
          isActive: true,
          createdAt: null,
          updatedAt: null,
        ),
        BuildingTag(
          tagId: 'tag-design-1234',
          tagType: BuildingTagType.design,
          tagName: '設計第一部',
          normalizedName: '設計第一部',
          displayOrder: 10,
          isActive: true,
          createdAt: null,
          updatedAt: null,
        ),
        BuildingTag(
          tagId: 'tag-construction-1234',
          tagType: BuildingTagType.construction,
          tagName: '当社施工',
          normalizedName: '当社施工',
          displayOrder: 10,
          isActive: true,
          createdAt: null,
          updatedAt: null,
        ),
        BuildingTag(
          tagId: 'tag-trigger-1234',
          tagType: BuildingTagType.trigger,
          tagName: '設計研修',
          normalizedName: '設計研修',
          displayOrder: 10,
          isActive: false,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      counts: const BuildingDetailCounts(visits: 1, photos: 6),
    );
  }

  @override
  Future<BuildingPhotoData> getPhotoThumbnailData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) async {
    thumbnailCallCount += 1;
    return BuildingPhotoData(
      requestId: requestId,
      serverTime: DateTime.parse('2026-07-30T15:30:00+09:00'),
      photoId: photoId,
      fileName: '$photoId-thumbnail.png',
      mimeType: 'image/png',
      byteSize: _pngBytes.length,
      bytes: _pngBytes,
      stage: '5-2B',
    );
  }

  @override
  Future<BuildingPhotoData> getPhotoData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) async {
    photoCallCount += 1;
    return BuildingPhotoData(
      requestId: requestId,
      serverTime: DateTime.parse('2026-07-30T15:30:00+09:00'),
      photoId: photoId,
      fileName: 'photo-12345678.png',
      mimeType: 'image/png',
      byteSize: _pngBytes.length,
      bytes: _pngBytes,
      stage: '4-2',
    );
  }

  @override
  void close() {}
}

class _FakeBuildingLocationApiService implements BuildingLocationApiService {
  int updateCallCount = 0;
  String? lastBuildingId;
  double? lastLatitude;
  double? lastLongitude;

  @override
  Future<void> updateBuildingLocation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required double latitude,
    required double longitude,
  }) async {
    updateCallCount += 1;
    lastBuildingId = buildingId;
    lastLatitude = latitude;
    lastLongitude = longitude;
  }

  @override
  void close() {}
}

class _FakeBootstrapApiService implements BootstrapApiService {
  int callCount = 0;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    callCount += 1;
    return BootstrapData(
      requestId: requestId,
      serverTime: DateTime.parse('2026-08-04T15:00:00+09:00'),
      schemaVersion: '1.0',
      stage: '5-3A',
      buildings: const <Building>[],
      tags: const <BuildingTag>[
        BuildingTag(
          tagId: 'tag-design-1234',
          tagType: BuildingTagType.design,
          tagName: '設計第一部',
          normalizedName: '設計第一部',
          displayOrder: 10,
          isActive: true,
          createdAt: null,
          updatedAt: null,
        ),
        BuildingTag(
          tagId: 'tag-sales-1234',
          tagType: BuildingTagType.sales,
          tagName: '営業第一部',
          normalizedName: '営業第一部',
          displayOrder: 10,
          isActive: true,
          createdAt: null,
          updatedAt: null,
        ),
        BuildingTag(
          tagId: 'tag-construction-1234',
          tagType: BuildingTagType.construction,
          tagName: '当社施工',
          normalizedName: '当社施工',
          displayOrder: 10,
          isActive: true,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      counts: const BootstrapCounts(
        buildings: 1,
        visits: 1,
        photos: 6,
        tags: 4,
      ),
    );
  }

  @override
  void close() {}
}

class _FakeBuildingInformationApiService
    implements BuildingInformationApiService {
  int updateCallCount = 0;
  String? lastBuildingId;
  String? lastBuildingName;
  String? lastAddress;
  List<String>? lastDesignTagIds;
  List<String>? lastSalesTagIds;
  List<String>? lastConstructionTagIds;

  @override
  Future<void> updateBuildingInformation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String buildingName,
    required String? address,
    required List<String> designTagIds,
    required List<String> salesTagIds,
    required List<String> constructionTagIds,
  }) async {
    updateCallCount += 1;
    lastBuildingId = buildingId;
    lastBuildingName = buildingName;
    lastAddress = address;
    lastDesignTagIds = List<String>.from(designTagIds);
    lastSalesTagIds = List<String>.from(salesTagIds);
    lastConstructionTagIds = List<String>.from(constructionTagIds);
  }

  @override
  void close() {}
}

class _FakeVisitInformationApiService implements VisitInformationApiService {
  int updateCallCount = 0;
  String? lastBuildingId;
  String? lastVisitId;
  DateTime? lastVisitedAt;
  List<String>? lastTriggerTagIds;
  String? lastImpression;
  double? lastLatitude;
  double? lastLongitude;
  double? lastAccuracyM;
  String? lastLocationSource;

  @override
  Future<void> updateVisitInformation({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
    required DateTime visitedAt,
    required List<String> triggerTagIds,
    required String impression,
    required double? latitude,
    required double? longitude,
    required double? accuracyM,
    required String locationSource,
  }) async {
    updateCallCount += 1;
    lastBuildingId = buildingId;
    lastVisitId = visitId;
    lastVisitedAt = visitedAt;
    lastTriggerTagIds = List<String>.from(triggerTagIds);
    lastImpression = impression;
    lastLatitude = latitude;
    lastLongitude = longitude;
    lastAccuracyM = accuracyM;
    lastLocationSource = locationSource;
  }

  @override
  void close() {}
}

final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
