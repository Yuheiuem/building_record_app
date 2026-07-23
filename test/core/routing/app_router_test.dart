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

  testWidgets('保護されたURLはログイン後に元の画面へ戻る', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService.signedOut();

    await tester.pumpWidget(
      BuildingRecordApp(
        authService: authService,
        initialLocation: AppRoutes.record,
      ),
    );
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

  factory _FakeAuthService.signedOut() {
    return _FakeAuthService._(status: GoogleAuthStatus.signedOut);
  }

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
