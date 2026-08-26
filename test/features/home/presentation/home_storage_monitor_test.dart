import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/storage_monitor_api_service.dart';
import 'package:building_record_app/features/home/presentation/home_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ホームでGoogle容量とアプリ元画像容量を表示して再取得できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1100);
    addTearDown(tester.view.reset);

    final _FakeStorageMonitorApiService apiService =
        _FakeStorageMonitorApiService(
          summary: const StorageUsageSummary(
            quotaLimitBytes: 15 * _gib,
            quotaUsageBytes: 13 * _gib,
            driveUsageBytes: 10 * _gib,
            driveTrashBytes: 512 * _mib,
            appOriginalBytes: 1536 * _mib,
            appStoredPhotoCount: 120,
            appActivePhotoCount: 116,
            appHiddenPhotoCount: 4,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: _FakeAuthService(),
          storageMonitorApiService: apiService,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(apiService.callCount, 1);
    expect(find.byKey(const Key('storage-monitor-card')), findsOneWidget);
    expect(find.text('容量監視'), findsOneWidget);
    expect(find.text('13.0 GB / 15.0 GB'), findsOneWidget);
    expect(find.text('使用率 86.7%'), findsOneWidget);
    expect(find.text('残り 2.0 GB'), findsOneWidget);
    expect(find.text('注意'), findsOneWidget);
    expect(find.text('使用率が80%を超えています。不要な写真を整理して空きを確保してください。'), findsOneWidget);
    expect(find.text('このアプリの元画像 1.5 GB （120枚）'), findsOneWidget);
    expect(find.text('表示中 116枚／非表示 4枚'), findsOneWidget);

    final Finder refreshButton = find.byKey(
      const Key('refresh-storage-monitor'),
    );
    await tester.ensureVisible(refreshButton);
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();

    expect(apiService.callCount, 2);
  });

  testWidgets('容量使用率90%以上を危険として表示する', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1100);
    addTearDown(tester.view.reset);

    final _FakeStorageMonitorApiService apiService =
        _FakeStorageMonitorApiService(
          summary: const StorageUsageSummary(
            quotaLimitBytes: 15 * _gib,
            quotaUsageBytes: 14 * _gib,
            driveUsageBytes: 12 * _gib,
            driveTrashBytes: 0,
            appOriginalBytes: 2 * _gib,
            appStoredPhotoCount: 200,
            appActivePhotoCount: 200,
            appHiddenPhotoCount: 0,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          authService: _FakeAuthService(),
          storageMonitorApiService: apiService,
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(find.text('危険'), findsOneWidget);
    expect(
      find.text('使用率が90%を超えています。完全削除や容量引っ越しの準備を検討してください。'),
      findsOneWidget,
    );
  });
}

const int _mib = 1024 * 1024;
const int _gib = 1024 * _mib;

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

class _FakeStorageMonitorApiService implements StorageMonitorApiService {
  _FakeStorageMonitorApiService({required this.summary});

  final StorageUsageSummary summary;
  int callCount = 0;

  @override
  Future<StorageUsageSummary> getStorageUsage({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    callCount += 1;
    return summary;
  }

  @override
  void close() {}
}
