abstract final class AppConfig {
  static const String workingTitle = '建築記録Webアプリ';
  static const String version = 'v0.5.0';
  static const String stage = '段階 0-4';

  static const int driveSpikeMaxPhotoBytes = 2 * 1024 * 1024;

  // OAuth WebクライアントIDは公開識別子です。
  // クライアントシークレットやアクセストークンはここへ置きません。
  static const String googleOAuthClientId =
      '96133736616-ptvr37poigcd5c0ob14o6e343jv4gjrt.apps.googleusercontent.com';

  // Apps Script WebアプリのURLは公開エンドポイントです。
  // 実データへのアクセス可否はApps Script側の認証で判断します。
  static const String appsScriptWebAppUrl =
      'https://script.google.com/macros/s/AKfycbyg_gwbedhsonziKn84lg9EeJpvE4Gqc3A1Lp8rDETLA33LLRM0YpzHOJGQrU1Nhrs/exec';
}
