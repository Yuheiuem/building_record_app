import 'package:building_record_app/app.dart';
import 'package:building_record_app/core/routing/app_routes.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('未ログインではログイン画面へ移動する', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService.signedOut();

    await tester.pumpWidget(BuildingRecordApp(authService: authService));
    await tester.pumpAndSettle();

    expect(find.text('Googleアカウントでログイン'), findsOneWidget);
    expect(find.text('建築を記録する'), findsNothing);
  });

  testWidgets('認証初期化中でも保護されたURLを保持する', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService.initializing();

    await tester.pumpWidget(
      BuildingRecordApp(
        authService: authService,
        initialLocation: AppRoutes.record,
      ),
    );

    await tester.pump();

    expect(find.text('ログイン状態を確認しています。'), findsOneWidget);

    authService.completeInitializationAsSignedOut();
    await tester.pumpAndSettle();

    expect(find.text('Googleアカウントでログイン'), findsOneWidget);

    authService.signIn();
    await tester.pumpAndSettle();

    expect(find.text('記録画面の入口'), findsOneWidget);
  });

  testWidgets('スマホ幅では記録を主操作にする', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BuildingRecordApp(authService: _FakeAuthService.signedIn()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('primary-record-action')), findsOneWidget);
    expect(find.byKey(const Key('primary-browse-action')), findsNothing);
  });

  testWidgets('PC幅では閲覧を主操作にする', (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 800);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      BuildingRecordApp(authService: _FakeAuthService.signedIn()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('primary-browse-action')), findsOneWidget);
    expect(find.byKey(const Key('primary-record-action')), findsNothing);
  });
}

class _FakeAuthService extends AuthService {
  _FakeAuthService._({
    required GoogleAuthStatus status,
    AuthenticatedGoogleUser? user,
    String? idToken,
  }) : _status = status,
       _user = user,
       _idToken = idToken;

  // 認証状態を確認している途中を再現する。
  factory _FakeAuthService.initializing() {
    return _FakeAuthService._(status: GoogleAuthStatus.initializing);
  }

  // 未ログイン状態を再現する。
  factory _FakeAuthService.signedOut() {
    return _FakeAuthService._(status: GoogleAuthStatus.signedOut);
  }

  // ログイン済み状態を再現する。
  factory _FakeAuthService.signedIn() {
    return _FakeAuthService._(
      status: GoogleAuthStatus.signedIn,
      user: const AuthenticatedGoogleUser(
        email: 'test@example.com',
        displayName: 'テスト利用者',
      ),
      idToken: 'test-id-token',
    );
  }

  GoogleAuthStatus _status;
  AuthenticatedGoogleUser? _user;
  String? _idToken;

  @override
  GoogleAuthStatus get status => _status;

  @override
  AuthenticatedGoogleUser? get currentUser => _user;

  @override
  String? get idToken => _idToken;

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  // 認証初期化が終わり、未ログインだった状態を再現する。
  void completeInitializationAsSignedOut() {
    _status = GoogleAuthStatus.signedOut;
    _user = null;
    _idToken = null;
    notifyListeners();
  }

  // Googleログイン成功を再現する。
  void signIn() {
    _status = GoogleAuthStatus.signedIn;
    _user = const AuthenticatedGoogleUser(
      email: 'test@example.com',
      displayName: 'テスト利用者',
    );
    _idToken = 'test-id-token';
    notifyListeners();
  }

  @override
  Future<void> signOut() async {
    _status = GoogleAuthStatus.signedOut;
    _user = null;
    _idToken = null;
    notifyListeners();
  }
}
