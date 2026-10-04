# Reverse engineering InnoGate / ELFA MASTER

## Target

| Item | Detail |
|------|--------|
| Device | ELFA MASTER (Vapen model `elfbar_master`) |
| App | InnoGate — Android `com.innogate.igate`, iOS App Store id `6740220042` |
| Developer | TINKLE JINGLE LIMITED (`tech.developer@heavengifts.com`) |

No public GitHub project documents InnoGate GATT traffic (unlike Pax, IQOS, EcoFlow communities). Expect **vendor-specific 128-bit UUIDs** and possible **post-pairing encryption**.

## Phase 1 — Passive GATT map (30 min)

1. Install InnoGate from Play Store on a test phone; pair ELFA MASTER.
2. Install **nRF Connect**; connect to the vape while InnoGate is **force-stopped**.
3. Export service/characteristic list (screenshot or share).
4. Compare with Vapen BLE Explorer scan — same UUIDs should appear.

## Phase 2 — HCI snoop (1–2 h)

1. Developer options → **Bluetooth HCI snoop log** (Full).
2. Toggle BT off/on.
3. Script (stopwatch):
   - T+0 connect InnoGate
   - T+30 s puff **1 s**
   - T+45 s puff **3 s** (mark in Explorer if parallel test)
   - T+60 s open battery screen
   - T+90 s disconnect / reconnect (history sync?)
4. `adb bugreport bugreport.zip` → extract `btsnoop_hci.log`.
5. Wireshark: filter `btatt`, follow ATT writes/notifications, note handles vs UUIDs.

## Phase 3 — Static analysis (2–4 h, your device only)

```bash
adb shell pm path com.innogate.igate
adb pull /data/app/.../base.apk innogate.apk
jadx -d innogate-src innogate.apk
```

Search tree:

```bash
rg -n "BluetoothGatt|writeCharacteristic|setCharacteristicNotification" innogate-src
rg -n "fff[0-9a-f]|6e40|uuid" innogate-src -i
rg -n "AES|Cipher|MessageDigest|SHA|encrypt" innogate-src
```

Document findings in `elfbar-protocol.md` in your own words. **Do not commit** APK or decompiler output.

## Phase 4 — Correlate & implement

1. Map notification payloads to the command table in `elfbar-protocol.md`.
2. Update `InnogateFrameCodec` / `ElfbarMasterProtocol` constants.
3. Add JSONL fixtures under `android/app/src/test/resources/ble-captures/`.
4. Run `./gradlew :app:testDebugUnitTest`.

## Phase 5 — Vapen validation

- Enable developer mode → disable simulation → pair via CDM.
- Confirm puffs appear in API within ~2 s (`POST /api/v1/ingest`).
- Run manual checklist in `testing.md`.

## Known constraints

- **Single central**: InnoGate and Vapen cannot reliably share the device — force-stop InnoGate.
- **Bonding**: some builds require BT bond; test bonded vs unbonded.
- **Encryption**: if payloads are high-entropy, implement handshake from jadx before puff opcodes decode.

## References (methodology, not Elfbar-specific)

- [BLE RE from Android APK](https://magikh0e.pl/pubHardwareHacking/reversing-bluetooth-le-android.html)
- [op-co.de BLE RE talk](https://op-co.de/talks/ble-reverse-engineering/)
- [Bluetooth vape RE (Pax pattern)](https://blraaz.me/reverse-engineering/2021/08/29/bluetooth-reverse-engineering.html)
