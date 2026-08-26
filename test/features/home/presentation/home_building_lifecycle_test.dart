import 'package:building_record_app/data/models/building.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/building_lifecycle_api_service.dart';
import 'package:building_record_app/features/home/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('非表示建物を管理画面から復元できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingLifecycleApiService apiService =
        _FakeBuildingLifecycleApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: _FakeAuthService(),
          buildingLifecycleApiService: apiService,
        ),
      ),
    );

    final Finder manageButton = find.byKey(
      const Key('manage-hidden-buildings'),
    );
    await tester.ensureVisible(manageButton);
    await tester.tap(manageButton);
    await tester.pumpAndSettle();

    expect(apiService.hiddenCallCount, 1);
    expect(
      find.byKey(const Key('close-hidden-building-manager')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey<String>('hidden-building-building-hidden-0001'),
      ),
      findsOneWidget,
    );

    final Finder restoreButton = find.byKey(
      const ValueKey<String>('restore-building-building-hidden-0001'),
    );
    await tester.ensureVisible(restoreButton);
    await tester.pumpAndSettle();
    await tester.tap(restoreButton);
    await tester.pumpAndSettle();

    expect(apiService.restoreCallCount, 1);
    expect(apiService.lastBuildingId, 'building-hidden-0001');
    expect(find.text('建物を復元しました。'), findsWidgets);
    expect(
      find.byKey(
        const ValueKey<String>('hidden-building-building-hidden-0001'),
      ),
      findsNothing,
    );
  });

  testWidgets('非表示建物の影響件数を確認して完全削除できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1000);
    addTearDown(tester.view.reset);

    final _FakeBuildingLifecycleApiService apiService =
        _FakeBuildingLifecycleApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: _FakeAuthService(),
          buildingLifecycleApiService: apiService,
        ),
      ),
    );

    final Finder manageButton = find.byKey(
      const Key('manage-hidden-buildings'),
    );
    await tester.ensureVisible(manageButton);
    await tester.tap(manageButton);
    await tester.pumpAndSettle();

    final Finder deleteButton = find.byKey(
      const ValueKey<String>('delete-building-building-hidden-0001'),
    );
    await tester.ensureVisible(deleteButton);
    await tester.pumpAndSettle();
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(apiService.previewCallCount, 1);
    expect(find.text('建物を完全に削除しますか？'), findsOneWidget);
    final Finder deletionDialog = find.byType(AlertDialog);
    expect(
      find.descendant(
        of: deletionDialog,
        matching: find.textContaining('訪問 2件'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: deletionDialog,
        matching: find.textContaining('写真 3枚'),
      ),
      findsOneWidget,
    );

    final Finder confirmButton = find.byKey(
      const Key('confirm-delete-building-permanently'),
    );
    await tester.tap(confirmButton);
    await tester.pumpAndSettle();

    expect(apiService.deleteCallCount, 1);
    expect(apiService.lastBuildingId, 'building-hidden-0001');
    expect(find.text('建物と写真をGoogle Driveから完全に削除しました。'), findsWidgets);
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

class _FakeBuildingLifecycleApiService implements BuildingLifecycleApiService {
  int hiddenCallCount = 0;
  int previewCallCount = 0;
  int restoreCallCount = 0;
  int hideCallCount = 0;
  int deleteCallCount = 0;
  String? lastBuildingId;

  BuildingLifecycleSummary get summary => const BuildingLifecycleSummary(
    building: const Building(
      buildingId: 'building-hidden-0001',
      buildingName: '非表示テスト建物',
      searchName: 'ひひょうじてすとたてもの',
      latitude: 35.0,
      longitude: 139.0,
      address: '東京都千代田区',
      designTags: <String>[],
      salesTags: <String>[],
      constructionTags: <String>[],
      driveFolderId: 'drive-folder-hidden-0001',
      coverPhotoId: 'photo-hidden-0001',
      createdAt: null,
      updatedAt: null,
      isDeleted: true,
    ),
    visitCount: 2,
    photoCount: 3,
    photoBytes: 1536 * 1024,
  );

  @override
  Future<List<BuildingLifecycleSummary>> getHiddenBuildings({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    hiddenCallCount += 1;
    return <BuildingLifecycleSummary>[summary];
  }

  @override
  Future<BuildingLifecycleSummary> getBuildingDeletionPreview({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    previewCallCount += 1;
    lastBuildingId = buildingId;
    return summary;
  }

  @override
  Future<void> hideBuilding({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    hideCallCount += 1;
    lastBuildingId = buildingId;
  }

  @override
  Future<void> restoreBuilding({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    restoreCallCount += 1;
    lastBuildingId = buildingId;
  }

  @override
  Future<void> deleteBuildingPermanently({
    required String requestId,
    required String clientVersion,
    required String idToken,
    required String buildingId,
  }) async {
    deleteCallCount += 1;
    lastBuildingId = buildingId;
  }

  @override
  void close() {}
}
