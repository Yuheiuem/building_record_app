# GitHub Actions

Flutter Webの検証とGitHub Pagesデプロイは `deploy-pages.yml` で行います。

`main` へのpush、または手動実行で次を実施します。

1. Flutter 3.44.4 stable をセットアップ
2. 依存関係を取得
3. `lib/` と `test/` のDart format差分を確認
4. `flutter analyze`
5. `flutter test`
6. Flutter Webをrelease build
7. GitHub Pagesへデプロイ

Flutterの自動更新によるCI差分を避けるため、Flutter SDKはローカル開発環境と同じ **3.44.4** に固定します。
