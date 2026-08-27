# 建築記録Webアプリ

建築物・建築現場の訪問記録を、写真・位置情報・タグ・メモとともに個人用Google環境へ保存し、Flutter Webから登録・閲覧するアプリです。

現在の実装段階は **段階 5-6.3D**、アプリバージョンは **v0.20.12** です。
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
- **5-6.1**: `building_detail/presentation` の責務分割（実施済み）
  - `building/`: 建物概要・建物情報編集・代表位置など
  - `photo/`: 写真ギャラリー・写真表示・非表示写真管理など
  - `visit/`: 訪問履歴・訪問編集・非表示Visit管理など
  - `shared/`: 共通表示・日時/容量表記・非同期リクエスト制御など
  - `building_detail_page.dart` はデータ取得と各機能を束ねるページとして `presentation/` 直下に維持
- **5-6.2**: `record_page.dart` のUI分割（実施済み）
  - `building/`: 新規・既存建物の指定と候補表示
  - `photo/`: 写真下書き、一覧、削除
  - `save/`: 保存操作、進捗、送信時間の内訳
  - `tag/`: タグ選択とタグ追加
  - `visit/`: 訪問内容と位置指定
  - `shared/`: 認証案内、共通メッセージ、表示用フォーマッタ
  - `record_page.dart` はService/Controller保持、画面全体の組み立て、Dialog・画面遷移を担当
- **5-6.3**: `record_draft_controller.dart` の内部責務整理
  - **5-6.3A**: 保存・再送・認証復旧の回帰テスト追加（実施済み）
  - **5-6.3B**: 入力検証・タグ整列・送信用draft生成を純粋クラスへ分離（実施済み）
  - **5-6.3C**: requestId・保存先ID・写真状態・結果・計測値を送信セッションへ分離（実施済み）
  - **5-6.3D**: 複数写真の1枚分送信と結果反映を専用クラス・送信セッションへ分離（実施済み）
  - **5-6.3E**: begin・4件wave・finalizeの送信調整処理を段階的に分離（次工程）
- **5-6.4**: `record_service.gs` の物理分割とApps Script共通処理整理
- **5-6.5**: Flutter側のApps Script HTTP共通処理整理
段階5-6では、認証、requestId/photoIdによる冪等性、手動再送、写真送信のバッチ方式、SheetsのLock位置、論理削除から完全削除へ進む安全な順序など、実機確認済みの挙動を維持します。
### Building Detail presentation構成（5-6.1）

`building_detail_page.dart` は建物詳細全体のデータ取得・Service保持・画面遷移と各操作の調整を担当し、表示Widgetは同一Dart libraryの `part` ファイルへ分離しています。privateなWidget名や既存Keyを変更せず、挙動を維持したまま物理分割しています。
```text
lib/features/building_detail/presentation/
├─ building_detail_page.dart
├─ building/
│  ├─ building_overview_section.dart
│  ├─ building_information_card.dart
│  ├─ building_information_edit_dialog.dart
│  └─ building_location_card.dart
├─ photo/
│  ├─ photo_gallery_section.dart
│  ├─ photo_tile.dart
│  ├─ full_photo_dialog.dart
│  ├─ hidden_photo_manager_dialog.dart
│  └─ hidden_photo_preview_dialog.dart
├─ visit/
│  ├─ visit_history_section.dart
│  ├─ visit_card.dart
│  ├─ visit_information_edit_dialog.dart
│  └─ hidden_visit_manager_dialog.dart
└─ shared/
   ├─ building_detail_common_widgets.dart
   ├─ building_detail_formatters.dart
   └─ async_request_limiter.dart
```

### Record Page presentation構成（5-6.2）

`record_page.dart` はService/Controllerの生成・破棄、初期データ読込、タグ追加Dialog、手動位置指定画面への遷移、画面全体の組み立てを担当します。表示Widgetは5-6.1と同じく同一Dart libraryの `part` ファイルへ分離し、privateなWidget名、既存Key、文言、Callback、スクロール構造を維持しています。
```text
lib/features/record/presentation/
├─ record_page.dart
├─ building/
│  ├─ record_building_section.dart
│  ├─ new_building_draft_form.dart
│  └─ existing_building_draft_form.dart
├─ photo/
│  └─ record_photo_section.dart
├─ save/
│  ├─ record_save_section.dart
│  └─ record_upload_performance.dart
├─ tag/
│  └─ record_tag_widgets.dart
├─ visit/
│  └─ record_visit_section.dart
└─ shared/
   ├─ record_common_widgets.dart
   └─ record_formatters.dart
```

### RecordDraftController回帰テスト（5-6.3A）

`record_draft_controller.dart` の内部責務分割に入る前に、既存挙動を固定する回帰テストを追加しています。Controller本体、写真送信Service、Apps Script、API仕様は変更していません。

追加した主な確認項目:

- 下書き不備時にAPIを呼ばないこと
- 写真1枚の一括保存経路を維持すること
- 準備・写真・確定の各失敗後も同じrequestIdで再送すること
- 成功済み写真を再送せず、失敗写真だけ再送すること
- 送信開始後は下書きを変更できないこと
- 写真5枚では4件のwaveと残り1件に分けること
- 保存前のIDトークン更新と、送信中のAUTH_REQUIREDから復旧できること
- 既存建物では今回追加するタグだけを送ること
- 保存完了後に新しい記録を始めると送信セッションを初期化すること

5-6.3Bでは、この回帰テストを維持したまま入力検証と送信用draft生成をController外へ分離しました。5-6.3Cでは、requestId、保存先ID、写真ごとの送信状態・結果、処理時間を `RecordSubmissionSession` へ集約しました。5-6.3Dでは、複数写真の1枚分のAPI呼び出しと例外変換を `RecordPhotoUploadExecutor` へ、成功結果の状態反映を `RecordSubmissionSession` へ移しました。次工程の5-6.3Eでは、begin・4件wave・finalizeの順序を維持したまま送信調整処理の境界を整理します。

整理完了後に、容量逼迫時のデータ引っ越し機能、他利用者向け配布版を検討します。

### Record送信用draft生成の分離（5-6.3B）

`RecordDraftController` が直接担当していた、入力検証、建物タグIDの選択・並べ替え、送信用文字列のtrim、1枚保存用 `RecordPreparationPayload` の組み立てを、状態を持たない純粋クラスへ分離しています。

```text
lib/features/record/
├─ controllers/
│  └─ record_draft_controller.dart
└─ domain/
   └─ record_submission_draft_builder.dart
```

`RecordSubmissionDraftBuilder` は同じ入力から常に同じ検証結果と `RecordSubmissionDraft` を作ります。`RecordSubmissionDraft` は送信開始時点の整形済み値を保持し、1枚保存と複数枚保存の両方から参照します。

維持している挙動:

- `RecordDraftController` の公開APIと保持状態
- requestId / photoIdと再送時の冪等性
- 成功写真を再送せず失敗写真だけ再送する処理
- 1枚保存と複数枚保存の通信経路
- 4写真単位のwave、Service側の2枚バッチ・並行数・遅延
- 認証期限切れ時の下書き保持と再認証
- Apps Script、API payloadのキーと値

純粋クラスには、検証文言、タグIDの昇順化、新規/既存建物で送信対象タグを切り替える処理、`RecordPreparationPayload`変換の単体テストを追加しています。

### Record送信セッション状態の分離（5-6.3C）

`RecordDraftController` に散在していた、1回の保存・再送にだけ必要な可変状態を `RecordSubmissionSession` へ集約しています。Controllerの公開getter・メソッドと送信手順は維持し、内部の参照先だけを専用クラスへ切り替えています。

```text
lib/features/record/controllers/
├─ record_draft_controller.dart
└─ record_submission_session.dart
```

送信セッションが保持する主な状態:

- begin / finalize / 写真ごとのrequestId
- 送信対象のbuildingId / visitId / visitedAt
- `BeginRecordResult` / `FinalizeRecordResult`
- 写真ごとのpending / uploading / uploaded / failed
- 写真ごとの保存結果
- 保存全体・準備・写真送信・確定・一括保存の計測値
- 画面へ表示する送信phase・メッセージ

`startNewRecord()`では、送信関連の初期化を `RecordSubmissionSession.reset()` にまとめました。新しい単体テストで、初期状態、写真状態の件数と進捗、下書きロック、reset後にrequestId・結果・状態・計測値が残らないことを確認します。

維持している挙動:

- `RecordDraftController` の公開APIと画面から見える状態
- begin / 写真 / finalizeの実行順
- 同じrequestIdでの手動再送と冪等性
- 成功写真を再送せず失敗写真だけ再送
- 写真1枚の一括保存経路と複数写真の4件wave
- 認証期限切れ時の下書き保持
- Service側の2枚バッチ・最大2バッチ並行・700ms遅延
- Apps Script、Sheets / Drive、API payload


### 複数写真の1枚分送信と結果反映の分離（5-6.3D）

複数写真の4件wave内で写真1枚ごとに行っていた、`uploadPhoto` の引数組み立て、API例外の失敗結果への変換を `RecordPhotoUploadExecutor` へ分離しました。waveの組み立て、`Future.wait`、失敗後の中断、認証更新要求、begin / finalizeの順序は引き続き `RecordDraftController` が担当します。

```text
lib/features/record/controllers/
├─ record_draft_controller.dart
├─ record_submission_session.dart
└─ record_photo_upload_executor.dart
```

保存成功時のbuildingId / visitId、写真結果、uploaded状態への反映は、可変状態を保持する `RecordSubmissionSession.applyPhotoUploadResult()` へまとめました。写真1枚の一括保存経路と複数写真経路は同じ反映処理を利用します。

追加テスト:

- 写真1枚分のrequestId、IDトークン、building / visit ID、画像、位置、表示順が従来どおりServiceへ渡ること
- `AUTH_REQUIRED` を認証更新が必要な失敗結果として返すこと
- 予期しない例外を従来どおり「不明なエラー」として返すこと
- 保存成功結果を送信セッションへ反映し、レスポンスにIDがない場合は既存IDを保持すること

維持している挙動:

- Controllerの公開API、表示メッセージ、進捗
- begin → 4件wave → finalizeの順序
- 同じ写真requestIdでの手動再送
- 成功済み写真を除外し、失敗写真だけを再送
- 写真1枚の一括保存経路
- Service側の2枚バッチ・最大2バッチ並行・700ms遅延
- Apps Script、Sheets / Drive、API payload

