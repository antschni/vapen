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

There is **no public** GATT specification for ELFA MASTER. The protocol in [`docs/elfbar-protocol.md`](docs/elfbar-protocol.md) was derived from the InnoGate app (`com.innogate.igate`) and is implemented in `ElfbarMasterProtocol` / `InnogateFrameCodec`:

- InnoGate command service `…0a0b0c0dff00` (write `ff01`, notify `ff02`), 4-byte header framing
- Handshake (`FIRST_LINK_INFO`, set time), status reads, paged puff-record sync, live push on every puff
- **BLE Explorer** (developer mode) + HCI snoop procedure in `docs/reverse-engineering.md` for verifying on hardware
- **Real Android stack**: GATT queue, foreground service, CDM pairing

InnoGate and Vapen cannot be connected at the same time — close InnoGate before pairing.

## Simulated device

Pairing → toggle **Simulated device** to exercise ingest without hardware.

## API client

Hand-maintained package in `packages/vapen_api/`. Regenerate from OpenAPI when the contract changes:

```bash
./tool/generate_api.sh   # or tool/generate_api.ps1
```

## Android App Links

See [`docs/build-and-deploy.md`](docs/build-and-deploy.md): generic `/join` deep links for any self-hosted origin (sideload, no fixed manifest host).

## Pigeon

Bridge definitions: `pigeons/vapen_native.dart` → `lib/data/native/vapen_native.g.dart` and `android/.../VapenNativePigeon.kt`.
