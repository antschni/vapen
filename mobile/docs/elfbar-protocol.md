# ELFA MASTER / InnoGate BLE protocol

Status: **derived from static analysis of the InnoGate Android app** (`com.innogate.igate`, internal project name `rd05`), October 2026, for interoperability. Implemented in `ElfbarMasterProtocol.kt`; covered by `ElfbarMasterProtocolTest`. Not yet verified against a live HCI capture — if something misbehaves, capture with the BLE Explorer and compare with this document.

## Device & app context

| Item | Value |
|------|--------|
| Product | ELFA MASTER (`elfbar_master` in Vapen API) |
| Vendor app | InnoGate (TINKLE JINGLE LIMITED) |
| Android package | `com.innogate.igate` — native Kotlin, BLE code in `com.rd05.lib_bluetooth` |
| Bonding | none (plain GATT, no `createBond`) |
| Connection | single central — InnoGate must be closed while Vapen is connected |

## GATT layout

| Role | UUID |
|------|------|
| Command service | `00010203-0405-0607-0809-0a0b0c0dff00` |
| Write (phone → device, write **with** response) | `00010203-0405-0607-0809-0a0b0c0dff01` |
| Notify (device → phone) | `00010203-0405-0607-0809-0a0b0c0dff02` |
| OTA service (firmware/themes — **never write**) | `00010203-0405-0607-0809-0a0b0c0da100` |
| OTA notify (InnoGate subscribes to it too) | `00010203-0405-0607-0809-0a0b0c0da102` |
| Device information | standard `180a` / software revision `2a28` |

The UUIDs follow the Telink SDK pattern. Older Vapen builds guessed `fff0` / Nordic UART — those services do not exist on this device.

## Framing

```text
[header][command][length u16 big-endian][payload…]
header = version << 6 | encrypted << 4 | seq & 0x0F
```

- `version` is 0 in practice (InnoGate never populates it).
- `seq` increments per request, wraps at 16. The response echoes it.
- Response command = request command `| 0x80` (e.g. `0x12` → `0x92`).
- `encrypted` is only set for `ACTIVATE` (`0x01`): payload AES-128-CBC/PKCS7, key and IV derived from constants in the app. Vapen does not implement activation (it is gated behind InnoGate's age verification).
- No checksum; one frame per notification. MTU 517 is requested.

Most payload results use `payload[0] == 0` for success.

## Connection sequence (as InnoGate does it)

1. `connectGatt(autoConnect = false, TRANSPORT_LE)`, discover services.
2. Request MTU 517.
3. Enable notifications on `…ff02` (CCCD `01 00`), then on the OTA notify characteristic.
4. `FIRST_LINK_INFO` (`0x2A`): `[0x02 = Android][len][phone name UTF-8][len][phone id UTF-8]`. Result `0` = accepted. InnoGate waits up to 60 s on first pairing (device-side confirmation possible) and 5 s on reconnect. Phone name = `Settings.Global.device_name`, falling back to `Build.BRAND`; id = `ANDROID_ID`.
5. `READ_ACTIVE_STATE` (`0x0A`) → `payload[0] == 1` activated.
6. `READ_FIRMWARE_VERSION` (`0x06`) → ASCII.
7. `READ_IDENTIFIER` (`0x05`) → raw bytes (device serial).
8. `SET_TIME` (`0x07`): ASCII `yyyyMMddHHmmss` in phone-local time.

## Commands used by Vapen

| Cmd | Name | Request payload | Response payload |
|-----|------|-----------------|------------------|
| `0x05` | READ_IDENTIFIER | — | identifier bytes |
| `0x06` | READ_FIRMWARE_VERSION | — | ASCII |
| `0x07` | SET_TIME | ASCII `yyyyMMddHHmmss` | `[result]` |
| `0x0A` | READ_ACTIVE_STATE | — | `[1 = activated]` |
| `0x0B` | READ_LOCK_STATE | — | `[1 = child lock on]` |
| `0x12` | READ_SOC (battery) | `[0 = percent]` | `[percent]` |
| `0x13` | READ_FUEL (liquid) | `[0 = percent]` | `[percent]`, `255` = unknown |
| `0x16` | READ_SUCTION_TIME (last puff) | `[unit]` | `[duration × 0.1 s]` |
| `0x2A` | FIRST_LINK_INFO | see above | `[result]` |
| `0x33` | READ_PUFF_RECORDS | `[offset u16 BE][count u16 BE]` | see below |
| `0x41` | READ_DAY_PUFF | `[days]` | `[days][count u16 BE per day…]`, today first |

### Puff records (`0x33`)

Response payload: `[count u16 BE]`, then `count` records of 8 bytes:

| Offset | Type | Field |
|--------|------|-------|
| 0 | u8 | power × 0.1 W |
| 1 | u16 **LE** | duration × 10 ms |
| 3 | u8 | coil resistance × 0.1 Ω |
| 4 | u32 **LE** | start time, device seconds |

Device seconds are **local wall-clock time encoded as if it were UTC**; subtract the phone's UTC offset to get an instant. InnoGate reads pages of 10 starting at offset 0 and continues while `count == requested`.

Vapen keeps a per-device cursor (`HistoryCursorStore`: next offset, timestamp of the record at `offset − 1`, newest timestamp). Before resuming it re-reads record `offset − 1`; if that no longer matches, the device list changed and Vapen rescans from 0, emitting only records newer than the newest one already synced. Page size is reduced when the negotiated MTU is small.

### Unsolicited pushes

The device sends response-coded frames without a request when values change. InnoGate handles them in its notify callback:

| Cmd | Meaning |
|-----|---------|
| `0x92` | battery percent `[pct]` |
| `0x93` | liquid percent `[pct]` (`255` = unknown) |
| `0x8B` | child lock changed |
| `0x96` | **puff finished** — `[duration × 0.1 s]`; InnoGate refreshes today's data for `rd05` |
| `0xC1` | per-day puff counts `[days][u16 BE…]` |
| `0x9E` | device alert `[type]`: 1 low battery, 2 low liquid, 3 overheat, 4 short circuit, 5 open circuit, 6 daily limit |

## Vapen data flow

1. On connect: handshake → `LIVE` → status (`0x12`, `0x13`, `0x0B`, `0x41`) → history sync (`0x33`).
2. On push `0x96`: wait 1.5 s, sync history (retry once after 4 s), refresh status.
3. Every 60 s status; every 5 min a safety-net history sync.
4. Records younger than 10 min are uploaded as `source: live`, older ones as `history`.

## Deterministic `client_event_id` (Vapen ingest)

Namespace UUID: `6ba7b810-9dad-11d1-80b4-00c04fd430c8` (UUIDv5).

- **Puff**: `hardware_id:puff:{device seconds of the record}` — stable across re-syncs.
- **Status**: `hardware_id:status:{recorded_at minute}`
- **Puff started**: `hardware_id:puff_started:{epoch second}`

Implemented in `EventIdFactory.kt`.

## Open questions

- [ ] Confirm on hardware that offset 0 is the oldest record (the rescan logic tolerates either order).
- [ ] Whether `FIRST_LINK_INFO` shows a confirmation prompt on the device for a new phone id.
- [ ] Charging state (no dedicated command found).
