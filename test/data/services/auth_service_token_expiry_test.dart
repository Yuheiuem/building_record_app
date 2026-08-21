import 'dart:convert';

import 'package:building_record_app/data/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthService ID token expiry', () {
    test('JWT expから有効期限と残存時間を判定できる', () {
      final DateTime expiresAt = DateTime.now().toUtc().add(
        const Duration(minutes: 10),
      );
      final _FakeAuthService service = _FakeAuthService(
        _jwtWithExpiry(expiresAt),
      );

      expect(service.idTokenExpiresAt, isNotNull);
      expect(
        service.idTokenExpiresAt!.difference(expiresAt).inSeconds.abs(),
        lessThanOrEqualTo(1),
      );
      expect(service.hasIdTokenValidity(const Duration(minutes: 3)), isTrue);
    });

    test('残り3分未満のJWTは保存用の有効時間不足と判定する', () {
      final _FakeAuthService service = _FakeAuthService(
        _jwtWithExpiry(DateTime.now().toUtc().add(const Duration(minutes: 1))),
      );

      expect(service.hasIdTokenValidity(const Duration(minutes: 3)), isFalse);
    });

    test('テスト用の非JWTトークンは従来互換で利用可能として扱う', () {
      final _FakeAuthService service = _FakeAuthService('test-id-token');

      expect(service.idTokenExpiresAt, isNull);
      expect(service.hasIdTokenValidity(const Duration(minutes: 3)), isTrue);
    });
  });
}

String _jwtWithExpiry(DateTime expiresAt) {
  String encodePart(Object value) {
    return base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  }

  return '${encodePart(<String, Object>{'alg': 'none'})}.'
      '${encodePart(<String, Object>{'exp': expiresAt.millisecondsSinceEpoch ~/ 1000})}.'
      'signature';
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this._idToken);

  final String? _idToken;

  @override
  GoogleAuthStatus get status => GoogleAuthStatus.signedIn;

  @override
  AuthenticatedGoogleUser? get currentUser =>
      const AuthenticatedGoogleUser(email: 'test@example.com');

  @override
  String? get idToken => _idToken;

  @override
  String? get errorMessage => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> signOut() async {}
}
