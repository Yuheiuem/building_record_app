abstract final class AppConfig {
  static const String workingTitle = '建築記録Webアプリ';
  static const String version = 'v0.3.0';
  static const String stage = '段階 0-3C-2';

  // OAuth WebクライアントIDは公開識別子です。
  // クライアントシークレットやアクセストークンはここへ置きません。
  static const String googleOAuthClientId =
      '96133736616-ptvr37poigcd5c0ob14o6e343jv4gjrt.apps.googleusercontent.com';

  // Apps Script WebアプリのURLは公開エンドポイントです。
  // 現段階では固定のhealthCheckだけを呼び出します。
  static const String appsScriptWebAppUrl =
      'https://script.google.com/macros/s/AKfycbxl1gLPpeDB90dzu6wVWzaj_m9r5atil-sHABUpLmLdegeJzuCbXrMsvR9tZ4q3vnH9/exec';
}
