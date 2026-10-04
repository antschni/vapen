# Build & Deploy (Android)

How to produce release APKs for **self-hosted** Vapen (`dev.vapen.app`). Distribution is **sideload** (not Google Play). Each user runs their own server; invite links use that server’s hostname.

Development setup and `flutter run`: [`../README.md`](../README.md).

## Prerequisites

| Tool | Notes |
|------|--------|
| [Flutter](https://docs.flutter.dev/get-started/install) stable (3.47+) | `flutter doctor` with no critical Android issues |
| Android SDK | `minSdk` 26, JDK 17 (matches Gradle/Kotlin in this project) |
| Running [Vapen API](../../api/) | Release builds expect an **HTTPS** server URL for the default endpoint (see below) |

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

Optional **default** for first launch (origin only, no `/api/v1` suffix). Users can change the server under **Einstellungen → Server**; invite links also set the server from the link host.

In **release**, only `https` URLs are allowed for public hosts; private/LAN `http` is allowed (`lib/core/config.dart`).

```bash
flutter build apk --release \
  --dart-define=VAPEN_BASE_URL=https://your-domain.example
```

Without `--dart-define`, the debug default is the emulator (`http://10.0.2.2:8080`).

### Group invites (deep links)

Invite links look like `https://<your-host>/join/<code>` (same origin as your deployed web/API).

The Android manifest declares **generic** `https` and `http` handlers for `pathPrefix="/join"` — **no fixed hostname** and **no** `android:autoVerify`. That matches self-hosting: one APK works with every instance.

When the user opens a link:

1. Android may show **“Open with”** (browser or Vapen) — normal for non–Play-Store, non-verified links.
2. The app reads the **host** from the URL, checks `/healthz`, saves it as the server URL, and opens the join screen with the code.

Optional on the server: `ANDROID_*` env vars still serve `/.well-known/assetlinks.json` for operators who want verified links for **one** domain; that requires a **custom manifest host** per build and is not needed for sideload + generic `/join` handling.

## Version

In `pubspec.yaml`:

```yaml
version: 1.2.3+45
```

`1.2.3` → `versionName`, `45` → `versionCode` (Android). Bump the build number after `+` before redistributing APKs.

## Release signing (Android)

`android/app/build.gradle.kts` uses **debug signing** for `release` — convenient for sideload and CI.

For a dedicated release key (recommended if you redistribute the APK widely):

1. Create a keystore once, e.g. `keytool -genkey -v -keystore upload-keystore.jks ...`
2. Add `android/key.properties` (do not commit):

   ```properties
   storePassword=...
   keyPassword=...
   keyAlias=upload
   storeFile=../upload-keystore.jks
   ```

3. Wire `signingConfigs` in `android/app/build.gradle.kts` (Flutter: [Android deployment](https://docs.flutter.dev/deployment/android#signing-the-app)).

Never commit keystore files or passwords.

## Build artifacts

```bash
cd mobile
flutter build apk --release --dart-define=VAPEN_BASE_URL=https://your-domain.example
```

| Output | Path |
|--------|------|
| APK | `build/app/outputs/flutter-apk/app-release.apk` |

Optional: `flutter build apk --split-per-abi` for smaller per-ABI APKs.

## Deploy

### Sideload

Install the APK on devices that allow apps from unknown sources. Point the app at your instance (settings or an invite link).

### Backend dependency

The mobile app needs a reachable Vapen instance (API + web on the same origin for invite URLs). Typical setup: root [`docker-compose.yml`](../../docker-compose.yml) with profile `full` and `.env` — see [repository README](../../README.md).

## Pre-release checklist

- [ ] Optional `VAPEN_BASE_URL` matches your instance (or rely on settings / invite links)
- [ ] `version` in `pubspec.yaml` bumped
- [ ] Manual: [`testing.md`](testing.md)

## iOS (optional)

A Flutter iOS target lives under `ios/` with no dedicated release pipeline. BLE background behavior is Android-first.
