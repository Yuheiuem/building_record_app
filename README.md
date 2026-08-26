# 建築記録Webアプリ

建築物・建築現場の訪問記録を、写真・位置情報・タグ・メモとともに個人用Google環境へ保存し、Flutter Webから登録・閲覧するアプリです。

現在の実装段階は **段階 5-6.0**、アプリバージョンは **v0.20.6** です。

## 現在できること

- Googleアカウントでログイン
- 新規建物・既存建物への訪問記録
- 複数写真の登録、ブラウザ側での画像縮小・圧縮
- GPS現在地取得、地図上での手動位置指定
- 建物・訪問へのタグ、感想、訪問日時の保存
- PC向けの地図＋建物一覧表示
- 建物詳細、訪問履歴、写真ギャラリー表示
- 建物情報・代表位置・代表写真の編集
- 訪問情報の編集、既存Visitへの写真追加
- 写真の非表示・復元・完全削除
- Visitの非表示・復元・完全削除
- Buildingの非表示・復元・完全削除
- Google Drive容量の監視
  - HOMEと技術診断ページで自動取得
  - HOMEと技術診断ページで手動再取得
  - 使用率80%以上で注意、90%以上で危険表示
  - Googleアカウント全体、Drive、ゴミ箱、本アプリ元画像の容量を表示

## 構成

- Flutter Web
- GitHub / GitHub Actions / GitHub Pages
- Google Sign-In
- Google Apps Script Web App
- Google Sheets
  - Buildings
  - Visits
  - Photos
  - Tags
- Google Drive
  - 元画像
  - サムネイル

利用者は個人利用を前提としており、データと写真は利用者自身のGoogle環境に保存します。

## 開発環境

段階5-6.0から、ローカル開発環境とGitHub ActionsでFlutterバージョンを固定します。

- Flutter **3.44.4** stable
- Dart **3.12.2**
- Windows + VS Code
- Microsoft Edge

基本確認コマンド:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build web
```

## CI / GitHub Pages

`main` へのpush後、GitHub Actionsで以下を順に実行します。

1. Flutter 3.44.4をセットアップ
2. `flutter pub get`
3. `dart format --output=none --set-exit-if-changed lib test`
4. `flutter analyze`
5. `flutter test`
6. `flutter build web --release --base-href "/building_record_app/"`
7. GitHub Pagesへデプロイ

Flutter stableの更新によって、アプリ側を変更していないのにCI結果だけ変化することを避けるため、CIではFlutter 3.44.4を明示しています。

## デプロイ

Flutter Webは `main` へのpush後、GitHub Actionsでテスト・Webビルド・GitHub Pagesデプロイを行います。

Apps Scriptを変更した場合は、Apps Scriptエディタへ変更ファイルを反映した後、Webアプリを**新バージョンとして再デプロイ**します。Flutter側だけをGitHub Pagesへデプロイしても、Apps Scriptの変更は反映されません。

Apps Script Web App URLは `/macros/s/.../exec` 形式を使用し、アカウント依存の `/u/0/` 等は付けません。

## Google Drive API

Apps Scriptでは既存の Advanced Drive Service を使用します。

- Service: Drive API
- Version: v3
- ID: `Drive`

写真・Visit・Buildingの「完全削除」は、ゴミ箱へ移すだけではなくDrive上の対象ファイルを永久削除します。

## データ削除の考え方

### 非表示

- Sheets上で削除状態を記録
- Driveファイルは保持
- 復元可能

### 完全削除

- Drive上の元画像・サムネイルを永久削除
- Sheetsの行は履歴として残す
- 写真の保存先IDは空欄化
- 復元不可

## 容量監視

容量監視は **HOMEと技術診断ページだけ**に表示します。

- ページ表示時に自動取得
- 更新ボタンで手動再取得
- その他の個別ページには表示しない
- 記録保存完了後の容量ポップアップは表示しない
- 写真送信処理には容量確認通信を追加しない

本アプリの容量内訳は、Photosシートに保存された元画像の `byteSize` 合計です。サムネイルやSpreadsheet等はGoogleアカウント全体の使用量には含まれますが、アプリ元画像の内訳には含めません。

## 秘密情報の扱い

次の情報はGitHubへコミットしません。

- Googleアカウントのパスワード
- IDトークン、アクセストークン、秘密鍵
- 許可メールアドレス
- Spreadsheet ID
- DriveルートフォルダID
- 実際の建築記録や写真

Google OAuth Web Client IDやApps Script Web App URLは公開識別子・公開エンドポイントですが、実データへのアクセス可否は認証とApps Script側の設定で制御します。

## リファクタリング方針（段階5-6）

容量監視までの機能追加を一区切りとし、段階5-6では**既存機能の挙動を変えずに責務分割と保守性改善**を行います。

予定:

- **5-6.0**: CI・文書・テスト配置の整理とリファクタリング前の安全網強化
- **5-6.1**: `building_detail/presentation` の責務分割
  - `building/`
  - `photo/`
  - `visit/`
  - `shared/`
  - `building_detail_page.dart` は全体を束ねるページとして `presentation/` 直下に残す
- **5-6.2**: `record_page.dart` のUI分割
- **5-6.3**: `record_draft_controller.dart` の内部責務整理
- **5-6.4**: `record_service.gs` の物理分割とApps Script共通処理整理
- **5-6.5**: Flutter側のApps Script HTTP共通処理整理

段階5-6では、認証、requestId/photoIdによる冪等性、手動再送、写真送信のバッチ方式、SheetsのLock位置、論理削除から完全削除へ進む安全な順序など、実機確認済みの挙動を維持します。

整理完了後に、容量逼迫時のデータ引っ越し機能、他利用者向け配布版を検討します。
