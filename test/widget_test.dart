import 'package:building_record_app/core/config/app_config.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/features/auth/presentation/auth_spike_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未ログイン状態とv0.2.0を表示する', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService(
      initialStatus: GoogleAuthStatus.signedOut,
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthSpikePage(authService: authService)),
    );

    expect(find.text(AppConfig.workingTitle), findsOneWidget);
    expect(find.text(AppConfig.stage), findsOneWidget);
    expect(find.text('Googleログイン確認'), findsOneWidget);
    expect(find.text('未ログイン'), findsOneWidget);
    expect(find.text('未取得'), findsOneWidget);
    expect(find.text(AppConfig.version), findsOneWidget);
    expect(find.text('GoogleログインボタンはWeb版で表示されます。'), findsOneWidget);
  });

  testWidgets('ログイン済みユーザーとIDトークン取得状態を表示する', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService(
      initialStatus: GoogleAuthStatus.signedIn,
      currentUser: const AuthenticatedGoogleUser(
        email: 'test@example.com',
        displayName: 'テスト利用者',
      ),
      idToken: 'test-id-token',
    );

    await tester.pumpWidget(
      MaterialApp(home: AuthSpikePage(authService: authService)),
    );

    expect(find.text('ログイン済み'), findsOneWidget);
    expect(find.text('取得済み'), findsOneWidget);
    expect(find.text('テスト利用者'), findsOneWidget);
    expect(find.text('test@example.com'), findsOneWidget);
    expect(find.text('IDトークンを取得できました。'), findsOneWidget);

    final Finder logoutButton = find.widgetWithText(OutlinedButton, 'ログアウト');

    expect(logoutButton, findsOneWidget);

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
