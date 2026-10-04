# Elfbar Master (ELFA MASTER) / InnoGate BLE protocol

Status: **vendor `fff0` profile validated against anonymized lab captures** in `android/app/src/test/resources/ble-captures/` (notify **`fff2`**, `0xAA` framing). Still confirm handshake bytes on your unit via BLE Explorer if live data is missing.

## Device & app context (public sources)

| Item | Value |
|------|--------|
| Product | ELFA MASTER (`elfbar_master` in Vapen API) |
| Vendor app | **InnoGate** (TINKLE JINGLE LIMITED) |
| Android package | `com.innogate.igate` ([Google Play](https://play.google.com/store/apps/details?id=com.innogate.igate)) |
| iOS bundle | InnoGate (`id6740220042`) |
| Features via BLE | Puff count/duration, battery, liquid/resistance/power UI, child lock, OTA, SmartSensation power curve |
| Connection | Single central typical; ~10 m range; pairing advertised as 2–5 s |

There is **no public** open-source decode of InnoGate traffic (unlike Pax / IQOS community work). Vapen uses a **profile table + Explorer** to lock UUIDs after the first successful capture.

## Reverse-engineering playbook

1. **BLE Explorer** (Vapen, release via developer mode): scan → connect → subscribe all notify characteristics → marker notes during known actions (puff 3 s, open battery screen).
2. **HCI snoop**: Developer options → Bluetooth HCI snoop log → reproduce scripted session → `adb bugreport` → Wireshark `btatt`.
3. **Static analysis** (interoperability, EU): pull `com.innogate.igate` from your own phone (`adb shell pm path com.innogate.igate`), decompile with jadx, search:
   - `BluetoothGattCallback`, `writeCharacteristic`, `setCharacteristicNotification`
   - UUID strings (`fff`, `6e40`, `0000`)
   - `MessageDigest`, `AES`, `Cipher` (encryption likely on command channel)
4. **Correlate**: align notification timestamps with puff stopwatch; diff frames before/after puff.
5. **Do not** commit InnoGate binaries or keys; document algorithms in prose only.

See `reverse-engineering.md` for step-by-step capture.

## GATT profile candidates (auto-detect order)

Vapen tries these profiles in `BleProfileDetector` until one matches discovered services:

### A — Nordic UART (common on BLE MCUs)

| Role | UUID |
|------|------|
| Service | `6e400001-b5a3-f393-e0a9-e50e24dcca9e` |
| TX (phone → device) | `6e400002-b5a3-f393-e0a9-e50e24dcca9e` |
| RX (device → phone, notify) | `6e400003-b5a3-f393-e0a9-e50e24dcca9e` |

### B — 16-bit vendor UART (legacy Chinese gadgets)

| Role | UUID |
|------|------|
| Service | `0000fff0-0000-1000-8000-00805f9b34fb` |
| Write | `0000fff1-0000-1000-8000-00805f9b34fb` |
| Notify | `0000fff2-0000-1000-8000-00805f9b34fb` |

### C — User-learned (from Explorer export)

Stored in encrypted prefs `learned_profile_json` after you pick TX/RX in Explorer.

## Framing hypothesis (v1 — **verify on device**)

Many closed vape apps use **length-prefixed binary** on one notify/write pair:

```text
[0xAA magic][uint8 len][uint8 opcode][payload…][uint8 checksum8]
checksum8 = (sum of bytes from len through last payload) & 0xFF
```

| Opcode | Direction | Meaning (hypothesis) |
|--------|-----------|----------------------|
| `0x01` | device→phone | Status snapshot |
| `0x02` | device→phone | Puff started |
| `0x03` | device→phone | Puff completed |
| `0x10` | phone→device | Handshake / auth step 1 |
| `0x11` | phone→device | Handshake / auth step 2 |
| `0x20` | phone→device | Request status |
| `0x21` | phone→device | Request history sync |

### Status payload (opcode `0x01`, hypothesis)

| Offset | Type | Field |
|--------|------|--------|
| 0 | uint8 | Battery % |
| 1 | uint8 | Liquid % (or pod level) |
| 2 | uint8 | Flags (bit0 charging, bit1 child lock) |
| 3 | uint32 LE | Total puff counter |
| 7 | uint8 | Power mode enum |

### Puff completed (opcode `0x03`, hypothesis)

| Offset | Type | Field |
|--------|------|--------|
| 0 | uint32 LE | Device puff index |
| 4 | uint16 LE | Duration ms |
| 6 | uint32 LE | Device timestamp (seconds since boot) |

If InnoGate uses **encryption** after pairing, cleartext opcodes will not match until handshake bytes from jadx are implemented in `ElfbarMasterProtocol.initialize()`.

## Advertising (expected)

- Local name contains `ELFA`, `MASTER`, `Elfbar`, or similar (region-dependent).
- Manufacturer data may carry model id (log full AD in Explorer).

## Connection sequence (target)

1. Scan filter by name / learned MAC (CDM association).
2. `connectGatt(..., autoConnect=true, TRANSPORT_LE)`.
3. Discover services → `BleProfileDetector`.
4. MTU 247.
5. Enable notify on RX characteristic.
6. Run `initialize()` handshake (writes on TX).
7. `requestStatus()`; `requestHistory(lastIndex from Room)`.
8. Live: decode notifications → `DeviceMessage` → Room → ingest.

## InnoGate conflict

If connection drops immediately or GATT 133 loops: prompt user to force-stop InnoGate (single-central behavior).

## Deterministic `client_event_id` (Vapen ingest)

Namespace UUID: `6ba7b810-9dad-11d1-80b4-00c04fd430c8` (UUIDv5).

- **Puff**: `hardware_id:puff:{deviceIndex}` else `hardware_id:puff:{started_at_ms/100*100}`
- **Status**: `hardware_id:status:{recorded_at minute}`
- **Puff started**: `hardware_id:puff_started:{epoch second}`

Implemented in `EventIdFactory.kt`.

## Open questions

- [ ] Confirm service/characteristic UUIDs on ELFA MASTER hardware
- [ ] Confirm framing (magic `0xAA` vs other)
- [ ] Auth: none vs bonded vs app-level challenge
- [ ] History sync command format and index field
- [ ] Serial number GATT read for `hardware_id` vs MAC fallback
