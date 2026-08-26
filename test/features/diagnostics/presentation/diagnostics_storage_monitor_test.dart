import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/storage_monitor_api_service.dart';
import 'package:building_record_app/features/diagnostics/presentation/diagnostics_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('技術診断で容量を自動取得し手動更新できる', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1200);
    addTearDown(tester.view.reset);

    final _FakeStorageMonitorApiService apiService =
        _FakeStorageMonitorApiService(
          summary: const StorageUsageSummary(
            quotaLimitBytes: 15 * _gib,
            quotaUsageBytes: 12 * _gib,
            driveUsageBytes: 9 * _gib,
            driveTrashBytes: 256 * _mib,
            appOriginalBytes: 1024 * _mib,
            appStoredPhotoCount: 80,
            appActivePhotoCount: 78,
            appHiddenPhotoCount: 2,
          ),
        );

    await tester.pumpWidget(
      MaterialApp(
        home: DiagnosticsPage(
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
    expect(find.text('12.0 GB / 15.0 GB'), findsOneWidget);
    expect(find.text('使用率 80.0%'), findsOneWidget);
    expect(find.text('残り 3.0 GB'), findsOneWidget);

    final Finder refreshButton = find.byKey(
      const Key('refresh-storage-monitor'),
    );
    await tester.ensureVisible(refreshButton);
    await tester.tap(refreshButton);
    await tester.pumpAndSettle();

    expect(apiService.callCount, 2);
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
