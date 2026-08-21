# 建築記録Webアプリ 段階5-4A.10 パッチ

- 対象: 段階 5-4A.9 / v0.19.9 / 0.19.9+39
- 更新後: **段階 5-4A.10 / v0.19.10 / 0.19.10+40**
- パッチ名: `building_record_app_stage_5_4A_10_parallel_batches_patch.zip`
- 目的: **2枚バッチを最大2本まで並行送信し、4枚以上の写真送信区間を短縮する**

## 1. 今回の変更

v0.19.9では、2枚を1つの `uploadPhotosBatch` 通信へまとめるところまで実装済みです。
ただしControllerが2枚ごとに完了待ちしていたため、4枚では2つのバッチが直列になっていました。

v0.19.10ではControllerから最大4枚を同時に送信サービスへ渡します。
送信サービス側は既存のキュー処理で次のように分けます。

```text
Batch A: 写真1 + 写真2 ─┐
                         ├ 最大2本並行
Batch B: 写真3 + 写真4 ─┘
```

- 1バッチ最大2枚は維持
- 同時バッチ最大2本
- 1枚登録の既存高速経路は維持
- `requestId` / `photoId` の冪等性を維持
- 成功済み写真は再送しない
- 失敗写真だけ再送
- サムネイルは従来どおり後送信
- `beginRecord` / `finalizeRecord` は今回は変更しない

## 2. 変更ファイル

今回は**すべて完全ファイル上書き方式**です。

```text
overlay/
├─ lib/
│  ├─ core/config/app_config.dart
│  ├─ data/services/record_submission_api_service.dart
│  └─ features/record/controllers/record_draft_controller.dart
├─ test/data/services/record_submission_api_batch_service_test.dart
└─ pubspec.yaml
```

以前の修正版にあった `git apply` / PowerShell補助スクリプトは使いません。

## 3. 適用方法

ZIPを展開し、**`overlay/` の中身だけ**を次へ上書きしてください。

```text
C:\flutter_projects\building_record_app
```

`README_FIRST.md` と `MANIFEST_SHA256.txt` はプロジェクトへコピーしません。

## 4. 適用後確認

```powershell
cd C:\flutter_projects\building_record_app
git status --short
```

主な変更対象:

```text
lib/core/config/app_config.dart
lib/data/services/record_submission_api_service.dart
lib/features/record/controllers/record_draft_controller.dart
pubspec.yaml
test/data/services/record_submission_api_batch_service_test.dart
```

## 5. 検証

まず専用テスト:

```powershell
flutter test test/data/services/record_submission_api_batch_service_test.dart
```

通ったら全体確認:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build web
```

成功条件:

```text
No issues found!
All tests passed!
Built build\web
```

失敗した状態ではpushしません。

## 6. Apps Script

**今回の5-4A.10追加変更ではApps Script変更なし / 再デプロイ不要です。**

v0.19.9で反映済みの `uploadPhotosBatch` をそのまま使います。

実行しないもの:

```text
setupDataSpreadsheet()
```

`SPREADSHEET_ID`にも触りません。

## 7. GitHub反映

全テスト成功後:

```powershell
git status --short
git add pubspec.yaml lib/core/config/app_config.dart lib/data/services/record_submission_api_service.dart lib/features/record/controllers/record_draft_controller.dart test/data/services/record_submission_api_batch_service_test.dart
git commit -m "Parallelize photo batch uploads v0.19.10"
git push origin main
```

GitHub Actions成功後、公開版を確認します。

## 8. 公開版の確認

まず400KB前後の写真4枚程度で確認してください。

確認項目:

1. 画面版が `v0.19.10`
2. 4/4枚すべて保存成功
3. Driveに各写真が1個ずつ保存
4. Photosシートに重複行なし
5. 建物詳細から4枚とも表示できる
6. 写真1+2と写真3+4がそれぞれ同じ「通信全体」時間になる
7. 2つのバッチが並行し、写真送信区間が前回の直列合計より短くなるか確認

Google側負荷で時間は変動するため、特定秒数は成功条件にしません。

## 9. 今回触らないもの

- `beginRecord`
- `finalizeRecord`統合
- Apps Script保存ロジック
- 写真圧縮設定
- サムネイル後送信
- 再送冪等性

4枚テストで安定性と効果を確認してから、次段階で `finalizeRecord` 独立通信削減を判断します。
