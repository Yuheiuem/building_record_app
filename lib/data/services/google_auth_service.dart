import 'dart:async';

import 'package:google_sign_in/google_sign_in.dart';

import '../../core/config/app_config.dart';
import 'auth_service.dart';

class GoogleAuthService extends AuthService {
  GoogleAuthService._();

  static final GoogleAuthService instance = GoogleAuthService._();

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  StreamSubscription<GoogleSignInAuthenticationEvent>?
  _authenticationSubscription;
  Future<void>? _initializationFuture;

  GoogleAuthStatus _status = GoogleAuthStatus.initializing;
  AuthenticatedGoogleUser? _currentUser;
  String? _idToken;
  String? _errorMessage;

  @override
  GoogleAuthStatus get status => _status;

  @override
  AuthenticatedGoogleUser? get currentUser => _currentUser;

  @override
  String? get idToken => _idToken;

  @override
  String? get errorMessage => _errorMessage;

  @override
  Future<void> initialize() {
    return _initializationFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _googleSignIn.initialize(clientId: AppConfig.googleOAuthClientId);

      _authenticationSubscription = _googleSignIn.authenticationEvents.listen(
        _handleAuthenticationEvent,
      )..onError(_handleAuthenticationError);

      _status = GoogleAuthStatus.signedOut;
      _errorMessage = null;
      notifyListeners();
      _googleSignIn.attemptLightweightAuthentication();
    } on Object catch (error) {
      _setAuthenticationError(error);
    }
  }

  void _handleAuthenticationEvent(GoogleSignInAuthenticationEvent event) {
    final GoogleSignInAccount? account = switch (event) {
      GoogleSignInAuthenticationEventSignIn() => event.user,
      GoogleSignInAuthenticationEventSignOut() => null,
    };

    if (account == null) {
      _setSignedOut();
      return;
    }
    _setSignedIn(account);
  }

  void _handleAuthenticationError(Object error) {
    _setAuthenticationError(error);
  }

  @override
  Future<bool> refreshIdToken() async {
    await initialize();

    final String? previousToken = _idToken;
    try {
      final Future<GoogleSignInAccount?>? attempt = _googleSignIn
          .attemptLightweightAuthentication(reportAllExceptions: true);
      if (attempt == null) {
        return false;
      }

      final GoogleSignInAccount? account = await attempt;
      final String? refreshedToken = account?.authentication.idToken;
      if (account == null ||
          refreshedToken == null ||
          refreshedToken.isEmpty ||
          refreshedToken == previousToken) {
        return false;
      }

      _setSignedIn(account);
      return true;
    } on Object catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'Googleログイン情報を更新できませんでした。',
      );
      notifyListeners();
      return false;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      _setSignedOut();
    } on Object catch (error) {
      _errorMessage = _messageFromError(
        error,
        fallback: 'Googleアカウントからログアウトできませんでした。',
      );
      notifyListeners();
    }
  }

  void _setSignedIn(GoogleSignInAccount account) {
    _currentUser = AuthenticatedGoogleUser(
      email: account.email,
      displayName: account.displayName,
      photoUrl: account.photoUrl,
    );
    _idToken = account.authentication.idToken;
    _errorMessage = null;
    _status = GoogleAuthStatus.signedIn;
    notifyListeners();
  }

  void _setSignedOut() {
    _currentUser = null;
    _idToken = null;
    _errorMessage = null;
    _status = GoogleAuthStatus.signedOut;
    notifyListeners();
  }

  void _setAuthenticationError(Object error) {
    _currentUser = null;
    _idToken = null;
    _errorMessage = _messageFromError(
      error,
      fallback: 'Googleログインに失敗しました。もう一度お試しください。',
    );
    _status = GoogleAuthStatus.error;
    notifyListeners();
  }

  String _messageFromError(Object error, {required String fallback}) {
    if (error is! GoogleSignInException) {
      return fallback;
    }
    return switch (error.code) {
      GoogleSignInExceptionCode.canceled => 'Googleログインがキャンセルされました。',
      GoogleSignInExceptionCode.interrupted =>
        'Googleログインが中断されました。もう一度お試しください。',
      GoogleSignInExceptionCode.clientConfigurationError =>
        'Googleログインのクライアント設定を確認してください。',
      GoogleSignInExceptionCode.providerConfigurationError =>
        'Googleログインの提供元設定を確認してください。',
      GoogleSignInExceptionCode.uiUnavailable => 'Googleログイン画面を表示できませんでした。',
      _ => fallback,
    };
  }

  @override
  void dispose() {
    final StreamSubscription<GoogleSignInAuthenticationEvent>? subscription =
        _authenticationSubscription;
    if (subscription != null) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }
}
