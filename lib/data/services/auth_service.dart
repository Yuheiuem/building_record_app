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

  Future<void> signOut();
}
