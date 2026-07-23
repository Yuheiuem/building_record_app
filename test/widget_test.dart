import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/models/health_check_response.dart';
import 'package:building_record_app/data/services/apps_script_api_service.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/features/auth/presentation/auth_spike_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未ログイン状態では本人確認を実行できない', (WidgetTester tester) async {
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
    expect(find.text('Apps Script本人確認'), findsWidgets);
    expect(find.text('未ログイン'), findsOneWidget);
    expect(find.text('未取得'), findsOneWidget);
    expect(find.text('未実行'), findsOneWidget);
    expect(find.text(AppConfig.version), findsOneWidget);
    expect(find.text('GoogleログインボタンはWeb版で表示されます。'), findsOneWidget);

    final Finder button = find.widgetWithText(FilledButton, 'Googleログイン後に実行');

    expect(button, findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
  });

  testWidgets('IDトークン付き本人確認の成功結果を表示する', (WidgetTester tester) async {
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
      '本人確認を実行',
    );

    expect(healthCheckButton, findsOneWidget);

    await tester.ensureVisible(healthCheckButton);
    await tester.pumpAndSettle();
    await tester.tap(healthCheckButton);
    await tester.pumpAndSettle();

    expect(apiService.callCount, 1);
    expect(apiService.lastIdToken, 'test-id-token');
    expect(find.text('認証成功'), findsOneWidget);
    expect(find.text('本人確認成功'), findsOneWidget);
    expect(find.text('2026-07-13T13:24:34+09:00'), findsOneWidget);
    expect(find.text('POST / 0-3D'), findsOneWidget);
    expect(find.text('tokeninfo_spike'), findsOneWidget);
    expect(find.text('本人確認を再実行'), findsOneWidget);
  });

  testWidgets('ログアウト後に本人確認結果を破棄する', (WidgetTester tester) async {
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
      '本人確認を実行',
    );

    await tester.ensureVisible(healthCheckButton);
    await tester.pumpAndSettle();
    await tester.tap(healthCheckButton);
    await tester.pumpAndSettle();

    final Finder logoutButton = find.widgetWithText(OutlinedButton, 'ログアウト');

    await tester.ensureVisible(logoutButton);
    await tester.pumpAndSettle();
    await tester.tap(logoutButton);
    await tester.pumpAndSettle();

    expect(authService.status, GoogleAuthStatus.signedOut);
    expect(find.text('未ログイン'), findsOneWidget);
    expect(find.text('未取得'), findsOneWidget);
    expect(find.text('未実行'), findsOneWidget);
    expect(find.text('本人確認成功'), findsNothing);
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
        stage: '0-3D',
        method: 'POST',
        authenticated: true,
        validationMode: 'tokeninfo_spike',
        errorCode: null,
        message: null,
      );

  final HealthCheckResponse _response;
  int callCount = 0;
  String? lastIdToken;

  @override
  Future<HealthCheckResponse> healthCheck({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    callCount += 1;
    lastIdToken = idToken;
    return _response;
  }

  @override
  void close() {}
}
