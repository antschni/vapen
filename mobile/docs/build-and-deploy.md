# Build & Deploy (Android)

How to produce release-ready artifacts and roll out the Vapen app (`dev.vapen.app`). The app is **Android-first**; an iOS project exists in the repo but is not intended for production (see [iOS](#ios-optional)).

Development setup and `flutter run`: [`../README.md`](../README.md).

## Prerequisites

| Tool | Notes |
|------|--------|
| [Flutter](https://docs.flutter.dev/get-started/install) stable (3.47+) | `flutter doctor` with no critical Android issues |
| Android SDK | `minSdk` 26, JDK 17 (matches Gradle/Kotlin in this project) |
| Running [Vapen API](../../api/) | Release builds expect an **HTTPS** server URL (see below) |

Optional for store upload: Google Play Console, upload key / app signing.

## Prepare the project

Before every build (local and CI):

```bash
cd mobile
flutter pub get
dart run pigeon --input pigeons/vapen_native.dart
```

If `api/openapi.yaml` changed, refresh the API client (`../tool/generate_api.sh` or `tool/generate_api.ps1`) and, if needed, in `packages/vapen_api`:

```bash
cd packages/vapen_api
dart run build_runner build --delete-conflicting-outputs
```

GitHub Actions [`.github/workflows/mobile.yml`](../../.github/workflows/mobile.yml) runs analyze, tests, and `flutter build apk --debug`.

## Build-time configuration

### API base URL (`VAPEN_BASE_URL`)

The app talks to the **origin** only (no `/api/v1` suffix). In **release**, only `https` URLs are allowed (`lib/core/config.dart`).

Set at build time:

```bash
flutter build appbundle --release \
  --dart-define=VAPEN_BASE_URL=https://your-domain.example
```

Without `--dart-define`, the debug default is the emulator (`http://10.0.2.2:8080`); release builds must set the production URL.

### Group invites (Android App Links)

Invite links look like `https://<host>/join/<code>`. Two things must match the **same public domain**:

1. **Manifest host** — set placeholder `vapenAppLinkHost` in `android/app/build.gradle.kts` (`defaultConfig.manifestPlaceholders`) to your hostname (e.g. `VAPEN_DOMAIN` / `PUBLIC_BASE_URL` from the root `.env.example`).
2. **Web `assetlinks.json`** — the web service serves `/.well-known/assetlinks.json` from `ANDROID_PACKAGE_NAME` (`dev.vapen.app`) and `ANDROID_CERT_SHA256_FINGERPRINTS` (comma-separated). Configure these in `.env` / `docker-compose` for the `web` service (see [web README](../../web/README.md)).

Obtain the signing certificate fingerprint:

```bash
# Debug keystore (currently used for release in build.gradle.kts = debug signing)
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

On Linux/macOS: `~/.android/debug.keystore`. Put the SHA-256 entry (colon format) in `ANDROID_CERT_SHA256_FINGERPRINTS`. For Play Store releases, use the **upload / app signing** fingerprint from Google Play or your release keystore.

After deployment, verify `https://<host>/.well-known/assetlinks.json` and Android app link verification (or open a join link in the browser — the app should handle `/join/…`).

## Version

In `pubspec.yaml`:

```yaml
version: 1.2.3+45
```

`1.2.3` → `versionName`, `45` → `versionCode` (Android). Bump the build number after `+` before each store upload.

## Release signing (Android)

`android/app/build.gradle.kts` currently uses **debug signing** for `release` — fine for internal tests and CI, **not** for Google Play.

For production:

1. Create an upload keystore once, e.g. `keytool -genkey -v -keystore upload-keystore.jks ...`
2. Add `android/key.properties` (do not commit; local / CI secret):

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

3. Define a `signingConfigs` block for release in `android/app/build.gradle.kts` and point `buildTypes.release.signingConfig` at it (Flutter docs: [Android deployment](https://docs.flutter.dev/deployment/android#signing-the-app)).

4. Register the new SHA-256 fingerprint in `ANDROID_CERT_SHA256_FINGERPRINTS` on the server.

Never commit keystore files or passwords to the repository.

## Build artifacts

```bash
cd mobile

# Release APK (sideload, QA)
flutter build apk --release --dart-define=VAPEN_BASE_URL=https://your-domain.example

# Google Play (recommended)
flutter build appbundle --release --dart-define=VAPEN_BASE_URL=https://your-domain.example
```

Output:

| Command | Path |
|---------|------|
| APK | `build/app/outputs/flutter-apk/app-release.apk` |
| AAB | `build/app/outputs/bundle/release/app-release.aab` |

Optional: `flutter build apk --split-per-abi` for smaller per-ABI APKs.

## Deploy

### Google Play

1. Upload the AAB in [Google Play Console](https://play.google.com/console) (internal testing → production).
2. Complete store listing, privacy policy, and declare BLE / background service permissions as used (foreground service “Connected device”, companion device, notifications).
3. After the first release, note app signing in the console and align `assetlinks.json` with Google’s certificate if needed.

### Direct distribution (sideload)

Install the APK on devices that allow unknown apps. Use the same `VAPEN_BASE_URL` and app-link host as production.

### Backend dependency

The mobile app needs a reachable Vapen instance (API plus web frontend on the same origin for app links). Typical server setup: root [`docker-compose.yml`](../../docker-compose.yml) with profile `full` and a configured `.env` — see [repository README](../../README.md).

## Pre-release checklist

- [ ] `VAPEN_BASE_URL` set to production HTTPS
- [ ] `vapenAppLinkHost` = public URL host
- [ ] `ANDROID_CERT_SHA256_FINGERPRINTS` includes certificate(s) for the built APK/AAB
- [ ] `version` in `pubspec.yaml` bumped
- [ ] Release keystore (Play) instead of debug signing
- [ ] Manual: [`testing.md`](testing.md)

## iOS (optional)

A Flutter iOS target lives under `ios/` with no dedicated release pipeline in the repo. If needed locally, configure Xcode (team, bundle ID, capabilities):

```bash
flutter build ipa --release --dart-define=VAPEN_BASE_URL=https://your-domain.example
```

BLE background behavior and companion features are implemented on Android; iOS is not feature-parity.
