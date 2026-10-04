# Vapen Mobile (Flutter + Android)

Android-first app: Flutter UI, Kotlin foreground service for BLE, buffering, and ingest upload.

## Requirements

- Flutter stable (3.47+)
- Android SDK 26+
- Running [Vapen API](../api/) (e.g. `docker compose up -d postgres api` → `http://localhost:8080`, emulator `http://10.0.2.2:8080`)

## Run

```bash
cd mobile
flutter pub get
dart run pigeon --input pigeons/vapen_native.dart
flutter run
```

Server URL: **Einstellungen → Server** (persistiert lokal). Optionaler Build-Default: `--dart-define=VAPEN_BASE_URL=…`. Login/Registrierung übernehmen die gespeicherte URL.

## Build & deploy

Release builds, signing, Google Play, and Android App Links: [`docs/build-and-deploy.md`](docs/build-and-deploy.md). Manual QA: [`docs/testing.md`](docs/testing.md).

## BLE / InnoGate reverse engineering

There is **no public** GATT specification for ELFA MASTER. Vapen ships:

- **BLE Explorer** (developer mode) + HCI snoop procedure in `docs/reverse-engineering.md`
- **Hypothesized framing** (`0xAA` + opcode) in `docs/elfbar-protocol.md` and `InnogateFrameCodec.kt`
- **Profile auto-detect** (Nordic UART, `FFF0`, or first write+notify service)
- **Real Android stack**: GATT queue, foreground service, CDM pairing (`com.innogate.igate` is the vendor app package)

After capture on hardware, update opcodes/UUIDs in `ElfbarMasterProtocol` and add JSONL fixtures under `android/app/src/test/resources/ble-captures/`.

## Simulated device

Pairing → toggle **Simulated device** to exercise ingest without hardware. Disable simulation and pair via CDM for real BLE (once UUIDs/opcodes are confirmed).

## API client

Hand-maintained package in `packages/vapen_api/`. Regenerate from OpenAPI when the contract changes:

```bash
./tool/generate_api.sh   # or tool/generate_api.ps1
```

## Android App Links

See [`docs/build-and-deploy.md`](docs/build-and-deploy.md) (manifest host `vapenAppLinkHost`, web `assetlinks.json`, SHA-256 fingerprints).

## Pigeon

Bridge definitions: `pigeons/vapen_native.dart` → `lib/data/native/vapen_native.g.dart` and `android/.../VapenNativePigeon.kt`.
