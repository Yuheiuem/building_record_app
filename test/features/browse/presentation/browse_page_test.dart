import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/features/browse/presentation/browse_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sheetsから取得した件数を表示し再取得できる', (WidgetTester tester) async {
    final _FakeAuthService authService = _FakeAuthService();
    final _FakeBootstrapApiService apiService = _FakeBootstrapApiService();

    await tester.pumpWidget(
      MaterialApp(
        home: BrowsePage(
          authService: authService,
          bootstrapApiService: apiService,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(apiService.callCount, 1);
    expect(apiService.lastIdToken, 'test-id-token');
    expect(find.text('Sheets接続成功'), findsOneWidget);
    expect(find.text('建物 0件'), findsOneWidget);
    expect(find.text('訪問 0件'), findsOneWidget);
    expect(find.text('写真 0件'), findsOneWidget);
    expect(find.text('タグ 0件'), findsOneWidget);
    expect(find.text('建物データはまだありません'), findsOneWidget);

    await tester.tap(find.text('最新データを取得'));
    await tester.pumpAndSettle();

    expect(apiService.callCount, 2);
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

class _FakeBootstrapApiService implements BootstrapApiService {
  int callCount = 0;
  String? lastIdToken;

  @override
  Future<BootstrapData> getBootstrapData({
    required String requestId,
    required String clientVersion,
    required String idToken,
  }) async {
    callCount += 1;
    lastIdToken = idToken;

    return BootstrapData.fromJson(<String, dynamic>{
      'ok': true,
      'requestId': requestId,
      'serverTime': '2026-07-28T12:00:00+09:00',
      'data': <String, dynamic>{
        'schemaVersion': '1.0',
        'stage': '2-1',
        'buildings': <Object?>[],
        'tags': <Object?>[],
        'counts': <String, dynamic>{
          'buildings': 0,
          'visits': 0,
          'photos': 0,
          'tags': 0,
        },
      },
      'errorCode': null,
      'message': null,
    });
  }

  @override
  void close() {}
}
