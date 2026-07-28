import 'package:building_record_app/data/models/bootstrap_data.dart';
import 'package:building_record_app/data/services/auth_service.dart';
import 'package:building_record_app/data/services/bootstrap_api_service.dart';
import 'package:building_record_app/features/browse/presentation/browse_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('タグマスターを4種類に分けて表示し再取得できる', (WidgetTester tester) async {
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
    expect(find.text('タグ 5件'), findsOneWidget);
    expect(find.text('タグマスター'), findsOneWidget);
    expect(find.text('きっかけ'), findsOneWidget);
    expect(find.text('設計'), findsOneWidget);
    expect(find.text('営業'), findsOneWidget);
    expect(find.text('施工'), findsOneWidget);
    expect(find.text('営業の仕事'), findsOneWidget);
    expect(find.text('設計研修'), findsOneWidget);
    expect(find.text('個人旅行'), findsOneWidget);
    expect(find.text('当社施工'), findsOneWidget);
    expect(find.text('鹿島施工'), findsOneWidget);
    expect(find.text('未登録'), findsNWidgets(2));

    await tester.ensureVisible(find.text('最新データを取得'));
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
        'stage': '2-2',
        'buildings': <Object?>[],
        'tags': <Map<String, dynamic>>[
          _tagJson('tag-trigger-sales-work', 'trigger', '営業の仕事', 10),
          _tagJson('tag-trigger-design-training', 'trigger', '設計研修', 20),
          _tagJson('tag-trigger-personal-travel', 'trigger', '個人旅行', 30),
          _tagJson('tag-construction-in-house', 'construction', '当社施工', 10),
          _tagJson('tag-construction-kajima', 'construction', '鹿島施工', 20),
        ],
        'counts': <String, dynamic>{
          'buildings': 0,
          'visits': 0,
          'photos': 0,
          'tags': 5,
        },
      },
      'errorCode': null,
      'message': null,
    });
  }

  @override
  void close() {}
}

Map<String, dynamic> _tagJson(
  String tagId,
  String tagType,
  String tagName,
  int displayOrder,
) {
  return <String, dynamic>{
    'tagId': tagId,
    'tagType': tagType,
    'tagName': tagName,
    'normalizedName': tagName,
    'displayOrder': displayOrder,
    'isActive': true,
    'createdAt': '2026-07-28T10:00:00+09:00',
    'updatedAt': '2026-07-28T10:00:00+09:00',
  };
}
