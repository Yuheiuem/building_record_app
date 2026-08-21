import 'dart:convert';

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

  /// IDトークンのJWT payloadに含まれるexpをUTC日時として返す。
  ///
  /// テスト用トークンなどJWTでない値はnullを返す。
  DateTime? get idTokenExpiresAt {
    final String? token = idToken;
    if (token == null || token.isEmpty) {
      return null;
    }

    final List<String> parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }

    try {
      final String payloadText = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final Object? decoded = jsonDecode(payloadText);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      final Object? rawExpiry = decoded['exp'];
      final int? expirySeconds = rawExpiry is int
          ? rawExpiry
          : rawExpiry is num
          ? rawExpiry.toInt()
          : rawExpiry is String
          ? int.tryParse(rawExpiry)
          : null;
      if (expirySeconds == null) {
        return null;
      }

      return DateTime.fromMillisecondsSinceEpoch(
        expirySeconds * 1000,
        isUtc: true,
      );
    } on Object {
      return null;
    }
  }

  Duration? get idTokenRemainingLifetime {
    final DateTime? expiresAt = idTokenExpiresAt;
    if (expiresAt == null) {
      return null;
    }
    return expiresAt.difference(DateTime.now().toUtc());
  }

  /// JWTとして有効期限を読める場合だけ残存時間を判定する。
  ///
  /// テスト用の非JWTトークンなど有効期限を判定できない場合は、従来互換のため
  /// 利用可能として扱い、サーバー側のAUTH_REQUIRED判定へ委ねる。
  bool hasIdTokenValidity(Duration minimumValidity) {
    final String? token = idToken;
    if (token == null || token.isEmpty) {
      return false;
    }

    final Duration? remaining = idTokenRemainingLifetime;
    if (remaining == null) {
      return true;
    }
    return remaining >= minimumValidity;
  }

  Future<void> initialize();

  /// 既存のGoogleログイン状態を利用して、IDトークンの再取得を試みる。
  ///
  /// テスト用の簡易AuthServiceは実装を追加しなくてもよいよう、既定ではfalseを返す。
  Future<bool> refreshIdToken() async => false;

  Future<void> signOut();
}
