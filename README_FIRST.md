# stage 5-6.0 cleanup patch

Base: GitHub commit `c8130baa54a8124a3c9af1bd5f08c584390ea3b2` (v0.20.5 / stage 5-5.5)
Target: v0.20.6 / stage 5-6.0 / build 49

## Purpose

This is a refactoring-preparation patch. It does not intentionally change application behavior.

Changes:

- Pin GitHub Actions to Flutter 3.44.4 stable.
- Add CI format check for `lib/` and `test/`.
- Move the Flutter health-check test from `apps_script/test.dart` into the normal `test/` tree.
- Refresh root README, Apps Script README, and workflow README.
- Record the stage 5-6 refactoring plan.
- Update displayed app version/stage to v0.20.6 / 5-6.0.

Apps Script runtime `.gs` files are not changed in this patch, so Apps Script redeploy is NOT required.
The `createApiError_()` duplicate and old internal stage strings are intentionally deferred to stage 5-6.4, when Apps Script files will be reorganized together. This avoids touching authentication/runtime code only for cleanup.

## Apply

1. Copy only the contents of `overlay/` onto the project root.
2. Remove the old misplaced test with:

```powershell
git rm .\apps_script\test.dart
```

3. Run:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build web
```

4. Check `git status --short` before commit.

Expected notable changes include:

- `.github/workflows/deploy-pages.yml`
- `.github/workflows/README.md`
- `apps_script/README.md`
- deletion of `apps_script/test.dart`
- `test/data/services/apps_script_api_service_test.dart`
- `lib/core/config/app_config.dart`
- `pubspec.yaml`
- `README.md`

## CI note

After push, GitHub Actions now checks formatting before analyze/test/build. A format difference will intentionally fail CI.
