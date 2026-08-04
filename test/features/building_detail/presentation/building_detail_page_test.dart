import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_detail_data.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/building_detail_api_service.dart';
import 'package:building_record_app/data/services/building_location_api_service.dart';
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
    expect(find.byKey(const Key('record-building-revisit')), findsOneWidget);
    expect(
      find.byKey(const Key('building-representative-location-chip')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('add-photos-to-visit-visit-12345678')),
      findsOneWidget,
    );
    expect(apiService.photoCallCount, 1);

    await tester.tap(
      find.byKey(const Key('building-representative-location-chip')),
    );
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

    await tester.tap(find.byKey(const Key('refresh-building-detail')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(apiService.detailCallCount, 3);
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
        driveFolderId: null,
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
          expectedPhotoCount: 1,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      photos: <BuildingPhoto>[
        BuildingPhoto(
          photoId: 'photo-12345678',
          buildingId: buildingId,
          visitId: 'visit-12345678',
          fileName: 'photo-12345678.png',
          mimeType: 'image/png',
          byteSize: _pngBytes.length,
          width: 1,
          height: 1,
          takenAt: DateTime.parse('2026-07-30T14:00:00+09:00'),
          latitude: 35.6813,
          longitude: 139.7672,
          accuracyM: 8.5,
          locationSource: 'gps',
          displayOrder: 1,
          createdAt: null,
        ),
      ],
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
      counts: const BuildingDetailCounts(visits: 1, photos: 1),
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

final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
