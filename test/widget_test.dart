import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/health_check_response.dart';
import 'package:building_record_app/data/services/apps_script_api_service.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/features/auth/presentation/auth_spike_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未ログイン状態と未実行のhealthCheckを表示する', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService(
      initialStatus: GoogleAuthStatus.signedOut,
    );
    final _FakeAppsScriptApiService apiService =
        _FakeAppsScriptApiService.success();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthSpikePage(
          authService: authService,
          appsScriptApiService: apiService,
        ),
      ),
    );

    expect(find.text(AppConfig.workingTitle), findsOneWidget);
    expect(find.text(AppConfig.stage), findsOneWidget);
    expect(find.text('Apps Script通信確認'), findsOneWidget);
    expect(find.text('未ログイン'), findsOneWidget);
    expect(find.text('未取得'), findsOneWidget);
    expect(find.text('未実行'), findsOneWidget);
    expect(find.text(AppConfig.version), findsOneWidget);
    expect(find.text('GoogleログインボタンはWeb版で表示されます。'), findsOneWidget);
  });

  testWidgets('healthCheck成功結果を表示する', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService(
      initialStatus: GoogleAuthStatus.signedIn,
      currentUser: const AuthenticatedGoogleUser(
        email: 'test@example.com',
        displayName: 'テスト利用者',
      ),
      idToken: 'test-id-token',
    );
    final _FakeAppsScriptApiService apiService =
        _FakeAppsScriptApiService.success();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthSpikePage(
          authService: authService,
          appsScriptApiService: apiService,
        ),
      ),
    );

    final Finder healthCheckButton = find.widgetWithText(
      FilledButton,
      'healthCheckを実行',
    );

    expect(healthCheckButton, findsOneWidget);

    await tester.ensureVisible(healthCheckButton);
    await tester.pumpAndSettle();
    await tester.tap(healthCheckButton);
    await tester.pumpAndSettle();

    expect(apiService.callCount, 1);
    expect(find.text('通信成功'), findsNWidgets(2));
    expect(find.text('2026-07-13T13:24:34+09:00'), findsOneWidget);
    expect(find.text('POST / 0-3C-1'), findsOneWidget);
    expect(find.text('healthCheckを再実行'), findsOneWidget);
  });

  testWidgets('ログアウト後に未ログイン状態へ戻る', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService(
      initialStatus: GoogleAuthStatus.signedIn,
      currentUser: const AuthenticatedGoogleUser(
        email: 'test@example.com',
        displayName: 'テスト利用者',
      ),
      idToken: 'test-id-token',
    );
    final _FakeAppsScriptApiService apiService =
        _FakeAppsScriptApiService.success();

    await tester.pumpWidget(
      MaterialApp(
        home: AuthSpikePage(
          authService: authService,
          appsScriptApiService: apiService,
        ),
      ),
    );

    final Finder logoutButton = find.widgetWithText(OutlinedButton, 'ログアウト');

    await tester.ensureVisible(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(authService.status, GoogleAuthStatus.signedOut);
    expect(find.text('未ログイン'), findsOneWidget);
    expect(find.text('未取得'), findsOneWidget);
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService({
    required GoogleAuthStatus initialStatus,
    AuthenticatedGoogleUser? currentUser,
    String? idToken,
  }) : _status = initialStatus,
       _currentUser = currentUser,
       _idToken = idToken;

  GoogleAuthStatus _status;
  AuthenticatedGoogleUser? _currentUser;
  String? _idToken;

  @override
  GoogleAuthStatus get status => _status;

  @override
  AuthenticatedGoogleUser? get currentUser => _currentUser;

  @override
  String? get idToken => _idToken;

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {
    _status = GoogleAuthStatus.signedOut;
    _currentUser = null;
    _idToken = null;
    notifyListeners();
  }
}

class _FakeAppsScriptApiService implements AppsScriptApiService {
  _FakeAppsScriptApiService.success()
    : _response = const HealthCheckResponse(
        ok: true,
        requestId: 'test-request-id',
        serverTime: '2026-07-13T13:24:34+09:00',
        status: 'ok',
        stage: '0-3C-1',
        method: 'POST',
        errorCode: null,
        message: null,
      );

  final HealthCheckResponse _response;
  int callCount = 0;

  @override
  Future<HealthCheckResponse> healthCheck({
    required String requestId,
    required String clientVersion,
  }) async {
    callCount += 1;
    return _response;
  }

  @override
  void close() {}
}
