import 'package:flutter/foundation.dart';

enum GoogleAuthStatus { initializing, signedOut, signedIn, error }

@immutable
class AuthenticatedGoogleUser {
  const AuthenticatedGoogleUser({
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String email;
  final String? displayName;
  final String? photoUrl;
}

abstract class AuthService extends ChangeNotifier {
  GoogleAuthStatus get status;

  AuthenticatedGoogleUser? get currentUser;

  String? get idToken;
  String? get errorMessage;

  bool get hasIdToken => idToken?.isNotEmpty ?? false;

  Future<void> initialize();

  /// 既存のGoogleログイン状態を利用して、IDトークンの再取得を試みる。
  ///
  /// テスト用の簡易AuthServiceは実装を追加しなくてもよいよう、既定ではfalseを返す。
  Future<bool> refreshIdToken() async => false;

  Future<void> signOut();
}
