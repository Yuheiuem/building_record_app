import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/models/building_detail_data.dart';
import 'package:building_record_app/data/models/building_tag.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/building_detail_api_service.dart';
import 'package:building_record_app/data/services/visit_lifecycle_api_service.dart';
import 'package:building_record_app/features/building_detail/presentation/building_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('訪問記録を非表示にできる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService(visitVisible: true);
    final _FakeVisitLifecycleApiService visitLifecycleApiService =
        _FakeVisitLifecycleApiService(detailApiService: detailApiService);

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingDetailPage(
          authService: _FakeAuthService(),
          buildingId: 'building-12345678',
          buildingDetailApiService: detailApiService,
          visitLifecycleApiService: visitLifecycleApiService,
          enableNetworkTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Finder hideButton = find.byKey(
      const ValueKey<String>('hide-visit-visit-12345678'),
    );
    await tester.ensureVisible(hideButton);
    await tester.pumpAndSettle();
    await tester.tap(hideButton);
    await tester.pumpAndSettle();

    expect(find.text('訪問記録を非表示にしますか？'), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm-hide-visit')));
    await tester.pumpAndSettle();

    expect(visitLifecycleApiService.hideCallCount, 1);
    expect(visitLifecycleApiService.lastVisitId, 'visit-12345678');
    expect(detailApiService.detailCallCount, 2);
    expect(
      find.byKey(const ValueKey<String>('building-visit-visit-12345678')),
      findsNothing,
    );
    expect(find.text('訪問記録を非表示にしました。'), findsWidgets);
  });

  testWidgets('非表示の訪問記録を管理画面から復元できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService(visitVisible: false);
    final _FakeVisitLifecycleApiService visitLifecycleApiService =
        _FakeVisitLifecycleApiService(
          detailApiService: detailApiService,
          hiddenVisits: <VisitLifecycleSummary>[_hiddenVisitSummary()],
        );

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingDetailPage(
          authService: _FakeAuthService(),
          buildingId: 'building-12345678',
          buildingDetailApiService: detailApiService,
          visitLifecycleApiService: visitLifecycleApiService,
          enableNetworkTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Finder manageButton = find.byKey(const Key('manage-hidden-visits'));
    await tester.ensureVisible(manageButton);
    await tester.pumpAndSettle();
    await tester.tap(manageButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(visitLifecycleApiService.hiddenListCallCount, 1);
    expect(find.byKey(const Key('close-hidden-visit-manager')), findsOneWidget);
    expect(
      find.byKey(const ValueKey<String>('hidden-visit-visit-12345678')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('restore-hidden-visit-visit-12345678')),
    );
    await tester.pumpAndSettle();

    expect(visitLifecycleApiService.restoreCallCount, 1);
    expect(
      find.byKey(const ValueKey<String>('hidden-visit-visit-12345678')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('close-hidden-visit-manager')));
    await tester.pumpAndSettle();

    expect(detailApiService.detailCallCount, 2);
    expect(
      find.byKey(const ValueKey<String>('building-visit-visit-12345678')),
      findsOneWidget,
    );
  });

  testWidgets('非表示の訪問記録の影響枚数を確認して完全削除できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingDetailApiService detailApiService =
        _FakeBuildingDetailApiService(visitVisible: false);
    final _FakeVisitLifecycleApiService visitLifecycleApiService =
        _FakeVisitLifecycleApiService(
          detailApiService: detailApiService,
          hiddenVisits: <VisitLifecycleSummary>[_hiddenVisitSummary()],
        );

    await tester.pumpWidget(
      MaterialApp(
        home: BuildingDetailPage(
          authService: _FakeAuthService(),
          buildingId: 'building-12345678',
          buildingDetailApiService: detailApiService,
          visitLifecycleApiService: visitLifecycleApiService,
          enableNetworkTiles: false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final Finder manageButton = find.byKey(const Key('manage-hidden-visits'));
    await tester.ensureVisible(manageButton);
    await tester.pumpAndSettle();
    await tester.tap(manageButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(
      find.byKey(const ValueKey<String>('delete-hidden-visit-visit-12345678')),
    );
    await tester.pumpAndSettle();

    final Finder confirmation = find.byType(AlertDialog);
    expect(
      find.descendant(of: confirmation, matching: find.textContaining('写真 3枚')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: confirmation,
        matching: find.textContaining('1.5 MB'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('confirm-delete-visit-permanently')));
    await tester.pumpAndSettle();

    expect(visitLifecycleApiService.deleteCallCount, 1);
    expect(visitLifecycleApiService.lastVisitId, 'visit-12345678');
    expect(
      find.byKey(const ValueKey<String>('hidden-visit-visit-12345678')),
      findsNothing,
    );
  });
}

VisitLifecycleSummary _hiddenVisitSummary() {
  return VisitLifecycleSummary(
    visit: _visit(),
    photoCount: 3,
    photoBytes: 1536 * 1024,
  );
}

BuildingVisit _visit() {
  return BuildingVisit(
    visitId: 'visit-12345678',
    buildingId: 'building-12345678',
    visitedAt: DateTime.parse('2026-08-20T14:00:00+09:00'),
    triggerTags: const <String>[],
    impression: 'Visitライフサイクル確認用',
    latitude: 35.6813,
    longitude: 139.7672,
    accuracyM: 8.5,
    locationSource: 'gps',
    status: 'completed',
    expectedPhotoCount: 3,
    createdAt: null,
    updatedAt: null,
  );
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
  _FakeBuildingDetailApiService({required this.visitVisible});

  bool visitVisible;
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
      serverTime: DateTime.parse('2026-08-25T10:00:00+09:00'),
      schemaVersion: '1.0',
      stage: '5-5.4',
      building: Building(
        buildingId: buildingId,
        buildingName: 'Visitテスト建物',
        searchName: 'visitてすとたてもの',
        latitude: 35.6812,
        longitude: 139.7671,
        address: '東京都千代田区',
        designTags: const <String>[],
        salesTags: const <String>[],
        constructionTags: const <String>[],
        driveFolderId: 'drive-folder-12345678',
        coverPhotoId: null,
        createdAt: null,
        updatedAt: null,
        isDeleted: false,
      ),
      visits: visitVisible
          ? <BuildingVisit>[_visit()]
          : const <BuildingVisit>[],
      photos: const <BuildingPhoto>[],
      tags: const <BuildingTag>[],
      counts: BuildingDetailCounts(visits: visitVisible ? 1 : 0, photos: 0),
    );
  }

  @override
  Future<BuildingPhotoData> getPhotoData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) {
    return Future<BuildingPhotoData>.error(StateError('このテストでは元画像を取得しません。'));
  }

  @override
  Future<BuildingPhotoData> getPhotoThumbnailData({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String photoId,
  }) {
    return Future<BuildingPhotoData>.error(StateError('このテストではサムネイルを取得しません。'));
  }

  @override
  void close() {}
}

class _FakeVisitLifecycleApiService implements VisitLifecycleApiService {
  _FakeVisitLifecycleApiService({
    required this.detailApiService,
    List<VisitLifecycleSummary>? hiddenVisits,
  }) : hiddenVisits = hiddenVisits ?? <VisitLifecycleSummary>[];

  final _FakeBuildingDetailApiService detailApiService;
  final List<VisitLifecycleSummary> hiddenVisits;
  int hiddenListCallCount = 0;
  int hideCallCount = 0;
  int restoreCallCount = 0;
  int deleteCallCount = 0;
  String? lastVisitId;

  @override
  Future<List<VisitLifecycleSummary>> getHiddenBuildingVisits({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    hiddenListCallCount += 1;
    return List<VisitLifecycleSummary>.unmodifiable(hiddenVisits);
  }

  @override
  Future<void> hideVisit({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) async {
    hideCallCount += 1;
    lastVisitId = visitId;
    detailApiService.visitVisible = false;
    if (hiddenVisits.every(
      (VisitLifecycleSummary item) => item.visit.visitId != visitId,
    )) {
      hiddenVisits.add(_hiddenVisitSummary());
    }
  }

  @override
  Future<void> restoreVisit({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) async {
    restoreCallCount += 1;
    lastVisitId = visitId;
    hiddenVisits.removeWhere(
      (VisitLifecycleSummary item) => item.visit.visitId == visitId,
    );
    detailApiService.visitVisible = true;
  }

  @override
  Future<void> deleteVisitPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
    required String visitId,
  }) async {
    deleteCallCount += 1;
    lastVisitId = visitId;
    hiddenVisits.removeWhere(
      (VisitLifecycleSummary item) => item.visit.visitId == visitId,
    );
    detailApiService.visitVisible = false;
  }

  @override
  void close() {}
}
