# Apps Script

このディレクトリは、建築記録WebアプリのGoogle Apps Script Web App実装です。

## 役割

- Google IDトークンの検証
- Buildings / Visits / Photos / Tags のGoogle Sheets読み書き
- 写真とサムネイルのGoogle Drive保存・取得
- 写真 / Visit / Building の非表示・復元・完全削除
- 建物・訪問情報の編集
- 記録送信の begin / photo upload / finalize
- 容量監視

## 秘密情報

秘密情報はソースコードへ直接書かず、Apps ScriptのScript Propertiesで管理します。

主な設定:

- `GOOGLE_OAUTH_CLIENT_ID`
- `ALLOWED_EMAIL`
- `ALLOWED_SUB`
- Spreadsheet ID
- DriveルートフォルダID

## Drive API

完全削除では既存のAdvanced Drive Serviceを使用します。

- Service: Drive API
- Version: v3
- ID: `Drive`

同じDrive APIを別IDで重複登録しません。

## 反映手順

Apps Script側の `.gs` を変更した場合は、Apps Scriptエディタの同名ファイルへ反映し、Webアプリを**新バージョンとして再デプロイ**します。

Flutter/GitHub Pagesを更新しただけではApps Scriptの変更は反映されません。

通常のコード更新・動作確認で `setupDataSpreadsheet()` は実行しません。シート初期構築・スキーマ移行が明示的に必要な段階だけで使用します。

## 段階5-6の整理

段階5-6.0ではApps Scriptの動作ロジックは変更しません。

`record_service.gs` の分割、API共通エラー関数などの重複整理、古い実装stage文字列の整理は、Apps Scriptをまとめて扱う **段階5-6.4** で実施します。認証・Lock・冪等性・再送挙動を変えず、まず物理分割から行います。
