abstract final class AppConfig {
  static const String workingTitle = '建築記録Webアプリ';
  static const String version = 'v0.15.2';
  static const String stage = '段階 4-2.2';

  static const int driveSpikeMaxPhotoBytes = 2 * 1024 * 1024;

  // 正式な記録画面で選択する写真の初期設定。
  static const int recordImageMaxDimension = 1600;
  static const int recordImageQuality = 75;
  static const int recordMaxPhotoBytes = 5 * 1024 * 1024;

  // 記録画面の手動位置指定マップ初期値（東京駅付近）。
  static const double recordMapDefaultLatitude = 35.681236;
  static const double recordMapDefaultLongitude = 139.767125;
  static const double recordMapDefaultZoom = 17;

  // OAuth WebクライアントIDは公開識別子です。
  // クライアントシークレットやアクセストークンはここへ置きません。
  static const String googleOAuthClientId =
      '96133736616-ptvr37poigcd5c0ob14o6e343jv4gjrt.apps.googleusercontent.com';

  // Apps Script WebアプリのURLは公開エンドポイントです。
  // 実データへのアクセス可否はApps Script側の認証で判断します。
  static const String appsScriptWebAppUrl =
      'https://script.google.com/macros/s/AKfycbyg_gwbedhsonziKn84lg9EeJpvE4Gqc3A1Lp8rDETLA33LLRM0YpzHOJGQrU1Nhrs/exec';
}
