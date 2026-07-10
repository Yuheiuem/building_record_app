# 建築記録Webアプリ

建築物・建築現場の訪問記録を、Flutter Webで登録・閲覧する個人用アプリです。

現在の実装段階は **段階0-1**、アプリバージョンは **v0.1.0** です。

## 現在できること

- Flutter Webの最小画面を表示する
- 専用Googleアカウントが作成済みであることを表示する
- 次工程がGoogleログイン・Apps Script・Driveの技術スパイクであることを表示する
- アプリ内に `v0.1.0` を表示する

現時点ではGoogleログイン、Apps Script通信、Sheets保存、Drive保存は実装していません。

## 必要環境

- Flutter stable 3.44系
- Dart 3.12系
- Microsoft Edge
- VS Code

## 初回実行

PowerShellでプロジェクトフォルダへ移動し、次を実行します。

```powershell
flutter doctor -v
flutter pub get
dart format .
flutter analyze
flutter test
flutter run -d edge
```

Web向けのリリースビルド確認は次を実行します。

```powershell
flutter build web
```

## 秘密情報の扱い

次の情報はGitHubへコミットしません。

- Googleアカウントのパスワード
- IDトークン、アクセストークン、秘密鍵
- 許可メールアドレス
- Spreadsheet ID
- DriveフォルダID
- 実際の建築記録や写真

Google側の識別子・許可メールなどは、後続段階でApps ScriptのScript Propertiesへ保存します。
