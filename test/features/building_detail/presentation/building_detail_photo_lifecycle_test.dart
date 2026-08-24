// stage 5-5.2 test fix v2: hidden photo manager is identified by Key, not duplicated title text.
import 'dart:convert';
import 'dart:typed_data';

import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_detail_data.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/building_detail_api_service.dart';
import 'package:building_record_app/data/services/photo_lifecycle_api_service.dart';
import 'package:building_record_app/features/building_detail/presentation/building_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('通常写真を非表示にして非表示写真一覧へ移せる', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService();
    final _FakePhotoLifecycleApiService lifecycleApiService =
        _FakePhotoLifecycleApiService(detailApiService);

    await _pumpPage(
      tester,
      detailApiService: detailApiService,
      lifecycleApiService: lifecycleApiService,
    );

    final Finder actions = find.byKey(
      const ValueKey<String>('photo-actions-photo-active-1'),
    );
    await tester.ensureVisible(actions);
    await tester.pumpAndSettle();
    await tester.tap(actions);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('hide-photo-photo-active-1')),
    );
    await tester.pumpAndSettle();

    expect(find.text('写真を非表示にしますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-hide-photo')));
    await tester.pumpAndSettle();

    expect(lifecycleApiService.hideCallCount, 1);
    expect(lifecycleApiService.lastPhotoId, 'photo-active-1');
    expect(detailApiService.activePhotos.length, 1);
    expect(lifecycleApiService.hiddenPhotos.length, 1);
    expect(find.text('写真を非表示にしました。'), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('building-photo-photo-active-1')),
      findsNothing,
    );
  });

  testWidgets('非表示写真を管理画面から復元できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService(
          activePhotos: <BuildingPhoto>[_photo('photo-active-2', 2)],
        );
    final _FakePhotoLifecycleApiService lifecycleApiService =
        _FakePhotoLifecycleApiService(
          detailApiService,
          hiddenPhotos: <BuildingPhoto>[_photo('photo-hidden-1', 1)],
        );

    await _pumpPage(
      tester,
      detailApiService: detailApiService,
      lifecycleApiService: lifecycleApiService,
    );

    final Finder manageButton = find.byKey(
      const Key('manage-hidden-building-photos'),
    );
    await tester.ensureVisible(manageButton);
    await tester.pumpAndSettle();
    await tester.tap(manageButton);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('close-hidden-photo-manager')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('hidden-photo-photo-hidden-1')),
      findsOneWidget,
    );

    final Finder restoreButton = find.byKey(
      const ValueKey<String>('restore-hidden-photo-photo-hidden-1'),
    );
    await tester.ensureVisible(restoreButton);
    await tester.pumpAndSettle();
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();

    expect(lifecycleApiService.restoreCallCount, 1);
    expect(lifecycleApiService.hiddenPhotos, isEmpty);
    expect(detailApiService.activePhotos.length, 2);
    expect(find.text('写真を復元しました。'), findsWidgets);

    await tester.tap(find.byKey(const Key('close-hidden-photo-manager')));
    await tester.pumpAndSettle();

    expect(detailApiService.detailCallCount, 2);
    expect(
      find.byKey(const ValueKey<String>('building-photo-photo-hidden-1')),
      findsOneWidget,
    );
  });

  testWidgets('通常写真を確認後に完全削除できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService();
    final _FakePhotoLifecycleApiService lifecycleApiService =
        _FakePhotoLifecycleApiService(detailApiService);

    await _pumpPage(
      tester,
      detailApiService: detailApiService,
      lifecycleApiService: lifecycleApiService,
    );

    final Finder actions = find.byKey(
      const ValueKey<String>('photo-actions-photo-active-2'),
    );
    await tester.ensureVisible(actions);
    await tester.pumpAndSettle();
    await tester.tap(actions);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(
        const ValueKey<String>(
          'delete-photo-permanently-photo-active-2',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('写真を完全に削除しますか？'), findsOneWidget);
    expect(find.textContaining('この操作はアプリから元に戻せません。'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-permanent-photo-deletion')));
    await tester.pumpAndSettle();

    expect(lifecycleApiService.deleteCallCount, 1);
    expect(lifecycleApiService.lastPhotoId, 'photo-active-2');
    expect(detailApiService.activePhotos.length, 1);
    expect(lifecycleApiService.hiddenPhotos, isEmpty);
    expect(
      find.text('写真をGoogle Driveから完全に削除しました。'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('building-photo-photo-active-2')),
      findsNothing,
    );
  });
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required _FakeBuildingDetailApiService detailApiService,
  required _FakePhotoLifecycleApiService lifecycleApiService,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BuildingDetailPage(
        authService: _FakeAuthService(),
        buildingId: 'building-test-1',
        buildingDetailApiService: detailApiService,
        photoLifecycleApiService: lifecycleApiService,
        enableNetworkTiles: false,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
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
  _FakeBuildingDetailApiService({List<BuildingPhoto>? activePhotos})
    : activePhotos = activePhotos ??
          <BuildingPhoto>[
            _photo('photo-active-1', 1),
            _photo('photo-active-2', 2),
          ];

  final List<BuildingPhoto> activePhotos;
  int detailCallCount = 0;

  @override
  Future<BuildingDetailData> getBuildingDetail({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    detailCallCount += 1;
    return BuildingDetailData(
      requestId: requestId,
      serverTime: DateTime.parse('2026-08-24T11:00:00+09:00'),
      schemaVersion: '1.0',
      stage: AppConfig.stage,
      building: Building(
        buildingId: buildingId,
        buildingName: '写真ライフサイクルテスト建物',
        searchName: 'しゃしんらいふさいくるてすとたてもの',
        latitude: 35.6812,
        longitude: 139.7671,
        address: '東京都千代田区',
        designTags: const <String>[],
        salesTags: const <String>[],
        constructionTags: const <String>[],
        driveFolderId: 'drive-folder-test',
        coverPhotoId: activePhotos.isEmpty ? null : activePhotos.first.photoId,
        createdAt: null,
        updatedAt: null,
        isDeleted: false,
      ),
      visits: <BuildingVisit>[
        BuildingVisit(
          visitId: 'visit-test-1',
          buildingId: buildingId,
          visitedAt: DateTime.parse('2026-08-24T10:00:00+09:00'),
          triggerTags: const <String>[],
          impression: '',
          latitude: 35.6812,
          longitude: 139.7671,
          accuracyM: 5,
          locationSource: 'gps',
          status: 'completed',
          expectedPhotoCount: activePhotos.length,
          createdAt: null,
          updatedAt: null,
        ),
      ],
      photos: List<BuildingPhoto>.unmodifiable(activePhotos),
      tags: const <BuildingTag>[],
      counts: BuildingDetailCounts(visits: 1, photos: activePhotos.length),
    );
  }

  @override
  Future<BuildingPhotoData> getPhotoThumbnailData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) async {
    return _photoData(requestId, photoId);
  }

  @override
  Future<BuildingPhotoData> getPhotoData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) async {
    return _photoData(requestId, photoId);
  }

  @override
  void close() {}
}

class _FakePhotoLifecycleApiService implements PhotoLifecycleApiService {
  _FakePhotoLifecycleApiService(
    this.detailApiService, {
    List<BuildingPhoto>? hiddenPhotos,
  }) : hiddenPhotos = hiddenPhotos ?? <BuildingPhoto>[];

  final _FakeBuildingDetailApiService detailApiService;
  final List<BuildingPhoto> hiddenPhotos;
  int hideCallCount = 0;
  int restoreCallCount = 0;
  int deleteCallCount = 0;
  String? lastPhotoId;

  @override
  Future<List<BuildingPhoto>> getHiddenBuildingPhotos({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    return List<BuildingPhoto>.unmodifiable(hiddenPhotos);
  }

  @override
  Future<BuildingPhotoData> getHiddenPhotoThumbnailData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) async {
    return _photoData(requestId, photoId);
  }

  @override
  Future<void> hidePhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) async {
    hideCallCount += 1;
    lastPhotoId = photoId;
    final int index = detailApiService.activePhotos.indexWhere(
      (BuildingPhoto photo) => photo.photoId == photoId,
    );
    if (index >= 0) {
      hiddenPhotos.add(detailApiService.activePhotos.removeAt(index));
    }
  }

  @override
  Future<void> restorePhoto({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) async {
    restoreCallCount += 1;
    lastPhotoId = photoId;
    final int index = hiddenPhotos.indexWhere(
      (BuildingPhoto photo) => photo.photoId == photoId,
    );
    if (index >= 0) {
      detailApiService.activePhotos.add(hiddenPhotos.removeAt(index));
    }
  }

  @override
  Future<void> deletePhotoPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String photoId,
  }) async {
    deleteCallCount += 1;
    lastPhotoId = photoId;
    detailApiService.activePhotos.removeWhere(
      (BuildingPhoto photo) => photo.photoId == photoId,
    );
    hiddenPhotos.removeWhere((BuildingPhoto photo) => photo.photoId == photoId);
  }

  @override
  void close() {}
}

BuildingPhoto _photo(String photoId, int displayOrder) {
  return BuildingPhoto(
    photoId: photoId,
    buildingId: 'building-test-1',
    visitId: 'visit-test-1',
    fileName: '$photoId.png',
    mimeType: 'image/png',
    byteSize: _pngBytes.length,
    width: 1,
    height: 1,
    takenAt: DateTime.parse('2026-08-24T10:00:00+09:00'),
    latitude: 35.6812,
    longitude: 139.7671,
    accuracyM: 5,
    locationSource: 'gps',
    displayOrder: displayOrder,
    createdAt: null,
  );
}

BuildingPhotoData _photoData(String requestId, String photoId) {
  return BuildingPhotoData(
    requestId: requestId,
    serverTime: DateTime.parse('2026-08-24T11:00:00+09:00'),
    photoId: photoId,
    fileName: '$photoId.png',
    mimeType: 'image/png',
    byteSize: _pngBytes.length,
    bytes: _pngBytes,
    stage: AppConfig.stage,
  );
}

final Uint8List _pngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
