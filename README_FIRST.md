# 建築記録Webアプリ stage 5-5.5 容量監視・警告

## バージョン
- App: v0.20.5
- Stage: 5-5.5
- Build: 0.20.5+48

## 今回の確定仕様
容量監視は **HOMEと技術診断ページにのみ表示**します。

- HOME: ページ表示時に自動取得 + 手動更新
- 技術診断: ページ表示時に自動取得 + 手動更新
- 記録画面、建物詳細などその他のページ: 表示なし
- 保存完了後のポップアップ / SnackBar: なし
- 写真保存処理への追加容量確認通信: なし

## 表示内容
- Googleアカウントの総使用量 / 上限 / 残容量
- Drive内使用量
- Driveゴミ箱使用量
- 本アプリが保持している元画像容量と枚数
- 表示中写真枚数 / 非表示写真枚数
- 使用率80%以上: 注意
- 使用率90%以上: 危険

## 今回の構成変更
容量表示UIを `StorageMonitorCard` として共通Widget化し、HOMEと技術診断の両方から使用します。

ルートの `README.md` も今回から `overlay/README.md` に含め、実装段階に合わせて更新します。

## 適用方法
ZIPを短い場所へ展開し、`overlay/` の**中身だけ**をプロジェクト直下へ上書きしてください。

```powershell
cd C:\flutter_projects\building_record_app
flutter pub get
dart format .
flutter analyze
flutter test test/features/home/presentation/home_storage_monitor_test.dart
flutter test test/features/diagnostics/presentation/diagnostics_storage_monitor_test.dart
flutter test
flutter build web
```

## Apps Script
Flutter側の確認後、Apps Scriptへ以下を反映してください。

- `apps_script/main.gs` -> 既存ファイルを全置換
- `apps_script/storage_monitor.gs` -> 新規作成して全貼り付け

その後、Webアプリを**新バージョンで再デプロイ**してください。

### Drive API
既存の Advanced Drive Service をそのまま使います。

- Drive API
- v3
- ID: `Drive`

新しいDrive APIサービスの追加やID変更は不要です。

### Spreadsheet
シート構造の変更はありません。
`setupDataSpreadsheet()` は実行しないでください。

## 実機確認
1. HOMEを開くと容量情報が自動取得される。
2. HOMEの更新ボタンで再取得できる。
3. 技術診断を開くと容量情報が自動取得される。
4. 技術診断の更新ボタンで再取得できる。
5. その他のページに容量表示が出ない。
6. 記録保存完了時に容量ポップアップが出ない。
7. 80% / 90%の警告表示が想定どおりである。

## 変更ファイル
- `README.md`
- `apps_script/main.gs`
- `apps_script/storage_monitor.gs` (new)
- `lib/core/config/app_config.dart`
- `lib/data/services/storage_monitor_api_service.dart` (new)
- `lib/shared/widgets/storage_monitor_card.dart` (new)
- `lib/features/home/presentation/home_page.dart`
- `lib/features/diagnostics/presentation/diagnostics_page.dart`
- `pubspec.yaml`
- `test/features/home/presentation/home_storage_monitor_test.dart` (new)
- `test/features/diagnostics/presentation/diagnostics_storage_monitor_test.dart` (new)
