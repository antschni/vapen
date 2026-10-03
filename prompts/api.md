# Vapen: REST API (Go + PostgreSQL)

## Role & Goal

You are a senior Go backend engineer. Build the **Vapen REST API** in the folder `api/` of this monorepo, plus the shared deployment files (`docker-compose.yml`, `deploy/Caddyfile`, `.env.example`).

The API receives live vaping data (puffs and device status) from the Vapen mobile app, stores it in PostgreSQL, provides filtered read and statistics endpoints for the mobile app and the web dashboard, handles secure login, groups and per-user privacy settings, and pushes live presence ("who is vaping right now") via Server-Sent Events.

You are the **first** component to be built. You write `api/openapi.yaml`, which becomes the contract for the web and mobile agents. Part A below is the contract all three components agree on; implement it exactly. Part B is your detailed specification.

<!-- BEGIN SHARED CONTEXT: keep this block byte-identical in prompts/api.md, prompts/mobile.md and prompts/web.md -->

## Part A: Shared System Context & Contract

> This part is identical in `prompts/api.md`, `prompts/mobile.md` and `prompts/web.md`. It gives every agent enough context about the other components to integrate cleanly. If you change anything in this contract, change it in all three prompt files **and** in `api/openapi.yaml` in the same commit.

### A.1 Product

**Vapen** tracks the usage of an **Elfbar Master** e-cigarette. The device talks Bluetooth Low Energy (BLE) and is normally used with the official vendor app **InnoGate**. Vapen replaces the read-out part of InnoGate with its own app, stores the data on a self-hosted server and visualizes it. Users can form **groups** (for example colleagues) to see who is vaping right now and how much, limited by per-user privacy settings.

| Component | Folder | Technology | Responsibility |
|---|---|---|---|
| Mobile app | `mobile/` | Flutter (UI) + native Kotlin Android foreground service (BLE, buffering, upload). iOS optional. | Connects to the Elfbar Master, decodes puffs and device status, streams them live to the API, also while the app UI is closed. Account, device, group and privacy UI. |
| REST API | `api/` | Go + PostgreSQL | Authentication, data ingest, storage, statistics, groups, privacy enforcement, live events (SSE). Owns the contract `api/openapi.yaml`. |
| Dashboard | `web/` | SvelteKit 2 + Svelte 5 (runes), TypeScript | Browser dashboard with charts for personal usage, device stats, groups and settings. Talks to the API server-side only (BFF pattern). |

Android is the primary platform and always has priority. iOS support is optional and must never degrade the Android implementation.

User-facing language in mobile and web: **German** (de-DE), with all strings centralized so they can be translated later. Code, comments, identifiers, commit messages and API field names: English.

### A.2 Architecture

```mermaid
flowchart LR
    Elfbar["Elfbar Master"] -->|"BLE GATT"| NativeSvc["Android foreground service (Kotlin)"]
    NativeSvc -->|"Pigeon"| FlutterUI["Flutter UI"]
    NativeSvc -->|"POST /api/v1/ingest (device token)"| Caddy
    FlutterUI -->|"REST + SSE (user JWT)"| Caddy
    Browser -->|"HTTPS (cookies)"| Caddy
    Caddy -->|"all other paths"| Web["SvelteKit BFF (adapter-node)"]
    Caddy -->|"/api/*"| Api["Go API"]
    Web -->|"internal REST + SSE (user JWT)"| Api
    Api --> Pg[("PostgreSQL")]
    Api -->|"LISTEN/NOTIFY"| Pg
```

Repository layout:

```text
vapen/
├── api/                  Go REST API; api/openapi.yaml is the contract source of truth
├── mobile/               Flutter app; mobile/android/ contains the native Kotlin service
├── web/                  SvelteKit dashboard
├── prompts/              Agent prompts (api.md, mobile.md, web.md)
├── deploy/Caddyfile      Reverse proxy config (automatic TLS)
├── docker-compose.yml    Services: postgres, api, web, caddy
├── .env.example          All environment variables with safe example values
└── README.md
```

Ownership: the API agent owns `api/`, `deploy/`, `docker-compose.yml` and `.env.example`. The web agent owns `web/` (including `web/Dockerfile`, which the compose service `web` builds). The mobile agent owns `mobile/`. Do not edit another component's folder; contract changes go through `api/openapi.yaml` (see A.3).

Networking:

- Production: one public origin, for example `https://vapen.example.com`. Caddy routes `/api/*` to `api:8080` (path unchanged) and everything else to `web:3000`.
- The web server calls the API via `API_INTERNAL_URL` (compose: `http://api:8080`). The browser never calls the API directly.
- The mobile app uses a configurable server base URL (for example `https://vapen.example.com`); all API paths below are relative to it.
- Android App Links: the web app serves `/.well-known/assetlinks.json` built from the environment variables `ANDROID_PACKAGE_NAME` (`dev.vapen.app`) and `ANDROID_CERT_SHA256_FINGERPRINTS` (comma-separated), so invite links (A.8) open the mobile app.
- Local development: `docker compose up -d postgres api` serves the API at `http://localhost:8080`. The web dev server runs at `http://localhost:5173` with `API_INTERNAL_URL=http://localhost:8080`. The Android emulator reaches the host at `http://10.0.2.2:8080`.
- Demo data: `go run ./cmd/seed` (in `api/`) creates the users `alice@example.com` and `bob@example.com` (password `vapen-demo-password`), one device each, 30 days of realistic puffs and status snapshots, and a shared group "Büro". `go run ./cmd/simulate --email alice@example.com` continuously sends live puffs through `POST /api/v1/ingest`. Web and mobile UI work can start against this data before the BLE protocol is decoded.

### A.3 Contract rules

- `api/openapi.yaml` (OpenAPI 3.1) is the single source of truth once it exists. Until then, this Part A is authoritative.
- Never silently invent endpoints or fields. If a consumer needs something that is missing, extend `api/openapi.yaml` and this Part A in all three prompt files in the same change, and keep it backwards compatible within `/api/v1`.
- Web generates TypeScript types from `api/openapi.yaml`; mobile generates Dart models from it. Regenerate after every contract change.

### A.4 Conventions

- Base path: `/api/v1`. Health checks `GET /healthz` (liveness) and `GET /readyz` (database reachable) are unauthenticated, live outside `/api/v1` and are only used inside the compose network.
- JSON everywhere, field names in `snake_case`. Unknown request fields are rejected with `400`.
- IDs: UUID strings (server generates UUIDv7). Clients generate `client_event_id` (see A.7).
- Timestamps: RFC 3339. Responses are always UTC with `Z`; requests may use any offset.
- Durations: integers in milliseconds with the suffix `_ms`.
- Time zones: IANA names (for example `Europe/Berlin`). Every user has a `timezone`; statistics endpoints accept a `tz` override. Bucket boundaries (day, week, month) are computed in that time zone and serialized as UTC. Weeks start on Monday (ISO 8601).
- Time ranges: `from` is inclusive, `to` is exclusive.
- Pagination: cursor based. Request `?limit=100&cursor=<opaque>`, response `{"items": [...], "next_cursor": "<opaque>" | null}`. `limit` max 500.
- Errors: RFC 9457 `application/problem+json`, always with a stable machine-readable `code`:

  ```json
  {"type": "https://vapen.dev/problems/validation-failed", "title": "Validation failed", "status": 400, "code": "validation_failed", "detail": "Request body is invalid", "errors": [{"field": "email", "message": "must be a valid email address"}]}
  ```

  Codes: `validation_failed`, `invalid_credentials`, `unauthorized`, `token_expired`, `forbidden`, `not_found`, `conflict`, `rate_limited`, `payload_too_large`, `internal`.
- Status codes: `200`/`201`/`204` success, `400` validation, `401` missing, invalid or expired token, `403` authenticated but not allowed, `404` unknown or not visible, `409` conflict, `413` payload too large, `429` rate limited (with `Retry-After` header).

### A.5 Authentication & sessions

- Users register and log in with email + password. Email is unique case-insensitively. Passwords: 12 to 128 characters, stored as argon2id hashes.
- Login errors are always generic (`invalid_credentials`); never reveal whether an email exists.
- All tokens are sent as `Authorization: Bearer <token>`.

| Token | Format | Lifetime | Used by | Allowed endpoints |
|---|---|---|---|---|
| Access token | JWT signed with EdDSA (Ed25519). Claims: `sub` (user id), `sid` (session id), `iat`, `exp`, `iss=vapen`, `aud=vapen-api` | 15 minutes | Web BFF server, Flutter UI | all `user` endpoints |
| Refresh token | Opaque: `vpr_` + 32 random bytes base64url. Server stores only the SHA-256 hash | 30 days, rotated on every use | Web BFF server, Flutter UI | `POST /auth/refresh` |
| Device ingest token | Opaque: `vpd_` + 32 random bytes base64url. Server stores only the SHA-256 hash. Plain value is shown once at creation | until revoked | Native Android service (and the optional iOS equivalent) | `POST /api/v1/ingest` only, only for its own device |

Refresh rotation: every `POST /auth/refresh` returns a new token pair and invalidates the presented refresh token. To tolerate parallel refreshes (for example two browser requests at the same moment), a just-rotated refresh token is accepted once more within a **grace period of 30 seconds** and then yields another new pair in the same session. Presenting a rotated token after the grace period is treated as token theft: the whole session is revoked and `401` is returned.

Sessions: every login or registration creates a session (`sid`). `POST /auth/logout` revokes the current session. Changing the password revokes all other sessions. Access tokens of a revoked session stay valid until they expire (at most 15 minutes); this is accepted.

Token storage per client:

- Web: the SvelteKit server keeps access and refresh token in `httpOnly`, `Secure`, `SameSite=Lax` cookies and refreshes server-side. Browser JavaScript never sees a token.
- Mobile UI: tokens in `flutter_secure_storage` (Android Keystore backed).
- Mobile background service: uses only the device ingest token, stored in Android Keystore-backed encrypted storage. It never touches user tokens. This avoids refresh races between UI and service and limits the damage if the token leaks.

### A.6 Domain model

Conceptual model; the API decides the exact SQL. Device fields marked `?` are nullable because the BLE protocol is not fully known yet.

- **User**: `id`, `email`, `display_name` (2 to 40 characters, visible to group members), `timezone`, `created_at`.
- **Device**: `id`, `user_id`, `model` (enum, currently only `elfbar_master`), `name` (user-editable), `hardware_id` (lowercase SHA-256 hex of the device serial number or, if none is available, of the BLE MAC address; unique per user), `firmware_version?`, `created_at`, `last_seen_at?`, `latest_status?` (DeviceStatus).
- **Puff** (one inhalation): `id`, `user_id`, `device_id`, `client_event_id`, `started_at`, `duration_ms` (1 to 60000), `source` (`live` = observed in real time, `history` = read from device memory later), `received_at`.
- **DeviceStatus** (snapshot): `recorded_at`, `battery_percent?` (0 to 100), `is_charging?`, `liquid_percent?` (0 to 100), `puff_counter_total?` (device-internal counter), `power_mode?` (string), `child_lock?`, `firmware_version?`.
- **Group**: `id`, `name` (1 to 60 characters), `owner_id`, `invite_code` (10 characters Crockford Base32, rotatable, only visible to owner and admins), `member_count`, `created_at`.
- **GroupMember**: `group_id`, `user_id`, `display_name`, `role` (`owner` | `admin` | `member`), `joined_at`. A user can be in many groups. Max 100 members per group.
- **PrivacySettings**: five boolean flags, see A.8.

Ingest events may carry the raw BLE payload as `raw` (`{"hex": "..."}`). The API stores it for debugging and never exposes it to other users.

### A.7 Ingest contract (`POST /api/v1/ingest`, device token)

Request:

```json
{
  "device_id": "01926b1e-7c1a-7a51-9d0e-6f1c2a3b4c5d",
  "sent_at": "2026-10-03T11:02:03.120Z",
  "events": [
    {"type": "puff_started", "client_event_id": "5b0e6c1a-...", "occurred_at": "2026-10-03T11:02:01.000Z"},
    {"type": "puff", "client_event_id": "8a1d0f2e-...", "started_at": "2026-10-03T11:02:01.000Z", "duration_ms": 2350, "source": "live", "raw": {"hex": "a5010c..."}},
    {"type": "status", "client_event_id": "c3e2a9b4-...", "recorded_at": "2026-10-03T11:02:03.000Z", "battery_percent": 76, "is_charging": false, "liquid_percent": 40, "puff_counter_total": 1234, "power_mode": "normal", "child_lock": false, "firmware_version": "1.2.3"}
  ]
}
```

Response `200`:

```json
{"accepted": 2, "duplicates": 1, "rejected": [{"client_event_id": "...", "code": "validation_failed", "message": "duration_ms out of range"}]}
```

Rules:

- `device_id` must match the device of the token, otherwise `403`.
- Max 500 events and 1 MiB per request. Events are processed independently; one invalid event never fails the batch. Only malformed JSON, auth errors or size limits fail the whole request.
- Idempotent: `(device_id, client_event_id)` is unique. Re-sent events are counted as `duplicates` and not stored twice. Clients delete buffered events once they are `accepted` or `duplicates`; `rejected` events must not be retried automatically.
- `client_event_id` is a UUID. For `puff` and `status` events it must be **deterministic** (UUIDv5 over stable inputs such as `hardware_id` plus device puff index or device timestamp), so the same puff read live and later again from device history deduplicates.
- `puff_started` is transient: it only updates live presence (A.9), is not stored as a puff and is ignored if `occurred_at` is older than 30 seconds. Not every protocol may provide it; everything must work without it.
- Timestamps more than 5 minutes in the future are rejected. Clients use the phone clock.
- `status` events update `latest_status` and `last_seen_at` of the device. The API may thin out stored snapshots to at most one per device per minute.
- Rate limit: 120 requests per minute per device token.

### A.8 Groups & privacy

Every user has **privacy defaults** and can **override** each flag per group (`null` = inherit the default). Effective value = override if set, otherwise default.

| Flag | Default | What other group members can see when `true` |
|---|---|---|
| `share_live_status` | `true` | Live status (vaping, active, idle) and `last_puff_at` |
| `share_usage_summary` | `true` | Aggregated totals and daily series (puff count, total duration) |
| `share_usage_detail` | `false` | Individual puffs with timestamps and durations, full usage statistics; allows other members to call `/puffs` and `/stats/usage` with `user_id` |
| `share_device_stats` | `false` | Device model, battery, liquid level, charging state; allows `/stats/devices/{id}` |
| `show_in_leaderboard` | `true` | Appears in group rankings (only effective together with `share_usage_summary`) |

Enforcement by the API, server-side, without exceptions:

- A user always sees all of their own data.
- Viewer V may see capability C of target user T only if V and T share at least one group in which T's effective flag C is `true`. For group-scoped endpoints (`/groups/{id}/...`) only the settings of that group count.
- Hidden data is omitted. In group overviews the section is `null` and a `visibility` object tells the client which sections are shared. Detail endpoints (`/puffs`, `/stats/usage`, `/stats/devices/{id}` for another user's data) answer `404` if not visible, so existence is not leaked.
- Group membership itself (display name, role) is visible to all members of that group.

Group lifecycle: any user can create groups and becomes `owner`. Others join via invite code or invite link `https://<origin>/join/<invite_code>` (handled by the web route `/join/[code]` and by Android App Links in the mobile app; QR codes encode this link). Owner and admins can rotate the invite code and remove members; only the owner can promote or demote admins, transfer ownership and delete the group. The owner cannot leave without transferring ownership first. Admins cannot remove the owner or other admins.

### A.9 Live presence (SSE)

`GET /api/v1/groups/{id}/live` returns `text/event-stream` (user access token; the web BFF proxies it). Only members whose effective `share_live_status` is `true` in this group are included.

```text
event: snapshot
data: {"members":[{"user_id":"...","display_name":"Alice","vaping_since":null,"last_puff_at":"2026-10-03T11:02:03Z","last_puff_duration_ms":2350}]}

event: member_update
data: {"user_id":"...","display_name":"Alice","vaping_since":"2026-10-03T11:05:00Z","last_puff_at":"2026-10-03T11:02:03Z","last_puff_duration_ms":2350}

event: member_removed
data: {"user_id":"..."}

: ping
```

- The first event is always `snapshot`. Then `member_update` on every `puff_started`, `puff`, or when a member starts sharing; `member_removed` when a member leaves or stops sharing live status. A `: ping` comment is sent every 15 seconds. Clients reconnect with exponential backoff and receive a fresh snapshot.
- The server sets `vaping_since` on `puff_started` and clears it when the following `puff` arrives.
- Status is derived by clients with these rules and re-evaluated every few seconds:
  - `vaping`: `vaping_since` is set and less than 15 seconds old.
  - `active`: `last_puff_at` is less than 5 minutes old.
  - `idle`: otherwise.
- Fan-out: ingest calls `pg_notify('vapen_live', ...)`, every API instance listens and forwards to its SSE subscribers.

### A.10 Endpoint catalog (`/api/v1`)

Auth column: `public` = no token, `user` = access token, `device` = device ingest token, `member` / `admin` / `owner` = access token plus group role.

Auth & account:

| Method & path | Auth | Purpose |
|---|---|---|
| `POST /auth/register` | public | `{email, password, display_name, timezone}` → `201 TokenPair` |
| `POST /auth/login` | public | `{email, password}` → `200 TokenPair` |
| `POST /auth/refresh` | public | `{refresh_token}` → `200 TokenPair` |
| `POST /auth/logout` | user | Revoke current session → `204` |
| `GET /me` | user | Current `User` |
| `PATCH /me` | user | `{display_name?, timezone?}` → `User` |
| `POST /me/password` | user | `{current_password, new_password}` → `204`; revokes all other sessions |
| `DELETE /me` | user | `{password}` → `204`; hard-deletes the user and all their data, removes them from groups (groups they own are deleted) |
| `GET /me/export` | user | JSON export of all own data (GDPR) |
| `GET /me/privacy-defaults` | user | `PrivacySettings` |
| `PUT /me/privacy-defaults` | user | `PrivacySettings` → `PrivacySettings` |

`TokenPair`: `{"access_token", "access_token_expires_at", "refresh_token", "refresh_token_expires_at", "user": User}`.

`PrivacySettings`: `{"share_live_status": true, "share_usage_summary": true, "share_usage_detail": false, "share_device_stats": false, "show_in_leaderboard": true}`.

Devices:

| Method & path | Auth | Purpose |
|---|---|---|
| `GET /devices` | user | Own devices including `latest_status` |
| `POST /devices` | user | `{model, name, hardware_id, firmware_version?}` → `201 Device`. If the `hardware_id` is already registered for this user: `200` with the existing device (idempotent) |
| `GET /devices/{id}` | user | Own device |
| `PATCH /devices/{id}` | user | `{name}` → `Device` |
| `DELETE /devices/{id}` | user | Delete device and all its data, revoke its tokens → `204` |
| `GET /devices/{id}/ingest-tokens` | user | `[{id, name, created_at, last_used_at, revoked_at}]` |
| `POST /devices/{id}/ingest-tokens` | user | `{name}` → `201 {id, name, token, created_at}`; `token` is returned only here |
| `DELETE /devices/{id}/ingest-tokens/{token_id}` | user | Revoke → `204` |

Ingest:

| Method & path | Auth | Purpose |
|---|---|---|
| `POST /ingest` | device | Batch of `puff_started`, `puff`, `status` events, see A.7 |

Read & statistics:

| Method & path | Auth | Purpose |
|---|---|---|
| `GET /puffs` | user | Individual puffs. Query: `from` (default now minus 24 h), `to` (default now), `user_id` (default self; others need `share_usage_detail`), `device_id`, `source`, `min_duration_ms`, `max_duration_ms`, `order` (`desc` default, `asc`), `limit` (default 100), `cursor` → `{items: [Puff], next_cursor}` |
| `GET /stats/usage` | user | Vaping behavior over time. Query: `from` (default start of the day 6 days ago in `tz`), `to` (default now), `bucket` (`hour`, `day`, `week`, `month`; default `day`), `tz` (default user time zone), `user_id` (default self; others need `share_usage_detail`), `device_id` → `UsageStats` |
| `GET /stats/devices/{id}` | user | Device statistics. Query: `from` (default now minus 7 days), `to` (default now), `bucket` (`hour`, `day`; default `hour`), `tz`. Own devices, or other members' devices with `share_device_stats` → `DeviceStats` |

`UsageStats` (series are gap-filled with zero buckets; `previous_period` covers the same length directly before `from`; `heatmap` covers the whole range, `iso_weekday` 1 = Monday, `hour` 0 to 23 in `tz`):

```json
{
  "user_id": "...", "device_id": null,
  "from": "2026-09-26T22:00:00Z", "to": "2026-10-03T11:00:00Z", "bucket": "day", "tz": "Europe/Berlin",
  "totals": {"puff_count": 312, "total_duration_ms": 701000, "avg_duration_ms": 2247, "max_duration_ms": 6100, "active_days": 7},
  "previous_period": {"puff_count": 290, "total_duration_ms": 650000},
  "series": [{"bucket_start": "2026-09-26T22:00:00Z", "puff_count": 40, "total_duration_ms": 90000, "avg_duration_ms": 2250, "max_duration_ms": 5000}],
  "heatmap": [{"iso_weekday": 1, "hour": 9, "puff_count": 12, "total_duration_ms": 26000}]
}
```

`DeviceStats` (series contain the last value per bucket; histogram bins are 500 ms wide up to 10 s, plus one overflow bin with `upper_ms: null`):

```json
{
  "device": {"id": "...", "model": "elfbar_master", "name": "Meine Elfbar", "last_seen_at": "..."},
  "from": "...", "to": "...", "bucket": "hour", "tz": "Europe/Berlin",
  "latest_status": {"recorded_at": "...", "battery_percent": 76, "is_charging": false, "liquid_percent": 40, "puff_counter_total": 1234, "power_mode": "normal", "child_lock": false, "firmware_version": "1.2.3"},
  "battery_series": [{"bucket_start": "...", "battery_percent": 76, "is_charging": false}],
  "liquid_series": [{"bucket_start": "...", "liquid_percent": 40}],
  "puff_duration": {"count": 312, "avg_ms": 2247, "median_ms": 2100, "p90_ms": 3900, "max_ms": 6100, "histogram": [{"lower_ms": 0, "upper_ms": 500, "count": 3}]},
  "puffs_since_last_charge": 87
}
```

Groups:

| Method & path | Auth | Purpose |
|---|---|---|
| `GET /groups` | user | My groups `[{id, name, role, member_count, created_at}]` |
| `POST /groups` | user | `{name}` → `201 Group` (caller is owner) |
| `GET /groups/{id}` | member | `Group` with `members: [GroupMember]`; `invite_code` only for owner and admins |
| `PATCH /groups/{id}` | admin | `{name}` → `Group` |
| `DELETE /groups/{id}` | owner | `204` |
| `POST /groups/join` | user | `{invite_code}` → `200 Group` (idempotent if already a member) |
| `POST /groups/{id}/invite/rotate` | admin | → `{invite_code}` |
| `POST /groups/{id}/leave` | member | `204`; owner gets `409` unless ownership was transferred |
| `PATCH /groups/{id}/members/{user_id}` | owner | `{role}` with `admin` or `member`; `owner` transfers ownership (previous owner becomes `admin`) |
| `DELETE /groups/{id}/members/{user_id}` | admin | Remove member → `204` |
| `GET /groups/{id}/privacy` | member | Caller's settings in this group: `{defaults: PrivacySettings, overrides: {flag: bool or null}, effective: PrivacySettings}` |
| `PUT /groups/{id}/privacy` | member | Body: `overrides` (every flag `true`, `false` or `null`) → same shape as GET |
| `GET /groups/{id}/overview` | member | Visible data of all members. Query: `from` (default start of today in `tz`), `to` (default now), `tz` → `GroupOverview` |
| `GET /groups/{id}/live` | member | SSE stream, see A.9 |

`GroupOverview` (`live`, `usage` and `device` are `null` when not shared; `usage.daily` uses local dates in `tz`; `leaderboard` is sorted by `total_duration_ms` descending and only contains members with effective `show_in_leaderboard` and `share_usage_summary`):

```json
{
  "group": {"id": "...", "name": "Büro", "member_count": 6},
  "from": "...", "to": "...", "tz": "Europe/Berlin",
  "members": [{
    "user_id": "...", "display_name": "Alice", "role": "member",
    "visibility": {"live_status": true, "usage_summary": true, "usage_detail": false, "device_stats": false, "leaderboard": true},
    "live": {"vaping_since": null, "last_puff_at": "2026-10-03T11:02:03Z", "last_puff_duration_ms": 2350},
    "usage": {"puff_count": 23, "total_duration_ms": 51000, "avg_duration_ms": 2217, "daily": [{"date": "2026-10-03", "puff_count": 23, "total_duration_ms": 51000}]},
    "device": null
  }],
  "leaderboard": [{"rank": 1, "user_id": "...", "display_name": "Alice", "puff_count": 23, "total_duration_ms": 51000}]
}
```

When shared, `device` is `{"model": "elfbar_master", "battery_percent": 76, "is_charging": false, "liquid_percent": 40, "last_seen_at": "..."}`.

<!-- END SHARED CONTEXT -->

## Part B: API Specification

### B.1 Tech stack

Check the latest stable versions when you start and use them. Do not use deprecated or unmaintained libraries.

- Go (latest stable, at least 1.25), standard library `net/http` with method-based `ServeMux` routing.
- Spec-first: hand-write `api/openapi.yaml` (OpenAPI 3.1), generate server interfaces and models with `oapi-codegen` (strict server, `std-http` target). Handlers implement the generated strict interface, so the code cannot drift from the spec.
- PostgreSQL (latest stable major, at least 17) via `pgx/v5` (`pgxpool`).
- `sqlc` for type-safe queries (`db/queries/*.sql`), `goose` for migrations (`db/migrations/*.sql`, embedded via `embed`, applied on startup and via `cmd/migrate`).
- `log/slog` with JSON output, request IDs, no secrets in logs.
- `golang.org/x/crypto/argon2` for passwords, `crypto/ed25519` + `github.com/golang-jwt/jwt/v5` for access tokens, `crypto/rand` for opaque tokens, `github.com/google/uuid` (UUIDv7, UUIDv5).
- `golang.org/x/time/rate` for in-memory rate limiting (single instance is fine; keep the limiter behind an interface).
- Tests: standard `testing`, `testcontainers-go` (PostgreSQL module) for integration tests.
- Linting: `go vet`, `golangci-lint`, `govulncheck`.

### B.2 Project structure

```text
api/
├── cmd/
│   ├── vapen-api/main.go      Server entrypoint (config, migrations, HTTP server, graceful shutdown)
│   ├── migrate/main.go        Run migrations up/down/status
│   ├── seed/main.go           Demo data (see A.2)
│   └── simulate/main.go       Live puff simulator via POST /api/v1/ingest
├── internal/
│   ├── config/                Env parsing and validation
│   ├── httpapi/               Strict handlers, middleware (auth, request id, logging, recovery, body limit, security headers), problem+json
│   ├── auth/                  Passwords, JWT, refresh sessions, device tokens
│   ├── devices/
│   ├── ingest/
│   ├── stats/                 Usage and device aggregations
│   ├── groups/
│   ├── privacy/               Central visibility resolver
│   ├── live/                  LISTEN/NOTIFY hub, SSE fan-out
│   ├── ratelimit/
│   └── store/                 sqlc generated code + transaction helpers
├── db/
│   ├── migrations/
│   └── queries/
├── openapi.yaml
├── oapi-codegen.yaml
├── sqlc.yaml
├── generate.go                //go:generate for oapi-codegen and sqlc
├── Dockerfile                 Multi-stage, final image distroless/static, non-root
├── Makefile                   generate, build, test, lint, run, seed
└── README.md                  Setup, env vars, curl examples for every endpoint
```

### B.3 Configuration (environment variables)

| Variable | Example | Notes |
|---|---|---|
| `DATABASE_URL` | `postgres://vapen:vapen@postgres:5432/vapen?sslmode=disable` | required |
| `LISTEN_ADDR` | `:8080` | |
| `PUBLIC_BASE_URL` | `https://vapen.example.com` | used for invite links |
| `JWT_ED25519_PRIVATE_KEY` | base64 of the 64-byte private key | required; `cmd/vapen-api keygen` prints a new one |
| `ACCESS_TOKEN_TTL` | `15m` | |
| `REFRESH_TOKEN_TTL` | `720h` | |
| `CORS_ALLOWED_ORIGINS` | empty | CORS is off by default (web uses the BFF, mobile does not need CORS) |
| `TRUSTED_PROXIES` | `172.16.0.0/12` | only trust `X-Forwarded-For` from these |
| `LOG_LEVEL` | `info` | |

Fail fast on startup if required variables are missing or invalid.

### B.4 Database schema guidance

Design the schema yourself following A.6, with these requirements:

- `users`: unique index on `lower(email)`. `timezone` validated against the IANA database on write.
- `sessions` and `refresh_tokens`: refresh tokens reference a session, store `token_hash`, `expires_at`, `rotated_at`, `revoked_at`. Reuse detection and the 30 s grace period from A.5.
- `devices`: unique `(user_id, hardware_id)`; columns for the denormalized latest status, `last_seen_at`, `last_puff_at`, `vaping_since`.
- `device_tokens`: `token_hash` unique, `revoked_at`, `last_used_at` (update at most once per minute).
- `puffs`: unique `(device_id, client_event_id)`, indexes on `(user_id, started_at)` and `(device_id, started_at)`, check constraint on `duration_ms`. `raw jsonb` nullable. Design so that time-based partitioning could be added later, but do not partition now.
- `device_status_snapshots`: unique `(device_id, client_event_id)`, index `(device_id, recorded_at)`.
- `groups`, `group_members` (primary key `(group_id, user_id)`), `privacy_defaults` (one row per user), `group_privacy_overrides` (nullable booleans per flag).
- All foreign keys with `ON DELETE CASCADE` where account deletion must remove data.
- Timestamps as `timestamptz`.

### B.5 Implementation requirements

Auth:

- argon2id with OWASP-recommended parameters (for example m=64 MiB, t=3, p=2), parameters encoded in the hash string so they can be raised later. Constant-time comparisons. Run a dummy hash on unknown emails to avoid timing differences.
- Rate limits: `POST /auth/login` and `POST /auth/register` 5 per minute per IP and per email, `POST /auth/refresh` 30 per minute per IP. Respond `429` with `Retry-After`.
- Access token validation checks signature, `exp`, `iss`, `aud` and algorithm (reject anything but EdDSA).
- Device token middleware only on `POST /api/v1/ingest`; user token middleware on all other non-public endpoints. A device token on a user endpoint is `401`.

Ingest:

- Validate each event separately, insert with `INSERT ... ON CONFLICT DO NOTHING` and count `accepted` vs `duplicates` (use `RETURNING`). One transaction per request.
- After commit, update the device (`last_seen_at`, `latest_status`, `last_puff_at`, `vaping_since`) and send `pg_notify('vapen_live', <small JSON: user_id, device_id, kind, timestamps>)`.
- Body limit 1 MiB, decode with `DisallowUnknownFields`.

Statistics:

- Aggregate in SQL. Buckets via `date_trunc(<bucket>, started_at AT TIME ZONE $tz)`, gap-filled with `generate_series`, converted back to UTC.
- Heatmap via `extract(isodow ...)` and `extract(hour ...)` in `tz`.
- Percentiles with `percentile_cont`. Histogram with `width_bucket`.
- `puffs_since_last_charge`: puffs after the last status snapshot with `is_charging = true`.
- Validate ranges: `to > from`, max range 400 days, `hour` buckets max 31 days. Otherwise `400`.
- Test daylight saving transitions in `Europe/Berlin` (23 h and 25 h days).

Privacy:

- One central package `internal/privacy` with a function like `Resolve(ctx, viewerID, targetID, groupID *uuid.UUID) (Effective, error)` built on one SQL query. Every handler that returns another user's data must go through it. No ad-hoc checks in handlers.
- `/groups/{id}/overview` builds each member section only if the corresponding flag is effective in this group.

Live (SSE):

- One dedicated pgx connection runs `LISTEN vapen_live` and reconnects on failure. An in-process hub fans out to subscribers per group, filtered by the privacy resolver (cache membership and flags per group for a few seconds, invalidate on privacy or membership changes, which also notify via `pg_notify`).
- SSE handler: correct headers (`Content-Type: text/event-stream`, `Cache-Control: no-cache`, `X-Accel-Buffering: no`), flush after every event, ping every 15 s, use `http.ResponseController` to disable the write deadline for this response only, stop on client disconnect. Max 5 concurrent streams per user.

HTTP server hardening:

- `ReadHeaderTimeout`, `ReadTimeout`, `IdleTimeout` set; graceful shutdown on SIGTERM.
- Security headers on all responses: `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `Cache-Control: no-store` for authenticated responses.
- Panic recovery returning `500 problem+json` with code `internal`, no stack traces to clients.
- Only parameterized queries (sqlc). No string-built SQL.

### B.6 Deployment files (you own these)

- `docker-compose.yml` with services:
  - `postgres` (official image, named volume, healthcheck with `pg_isready`).
  - `api` (build `./api`, depends on healthy `postgres`, port `8080` exposed to the host for local development).
  - `web` (build `./web`) and `caddy` (official image, ports 80/443, volumes for data and config) in the compose profile `full`, so `docker compose up -d postgres api` works before `web/` exists. Environment of `web`: `API_INTERNAL_URL=http://api:8080`, `ORIGIN=https://${VAPEN_DOMAIN}`, `PROTOCOL_HEADER=x-forwarded-proto`, `HOST_HEADER=x-forwarded-host`, `ADDRESS_HEADER=x-forwarded-for`, `XFF_DEPTH=1`, `COOKIE_SECURE=true`, `ANDROID_PACKAGE_NAME`, `ANDROID_CERT_SHA256_FINGERPRINTS`.
  - The web server forwards the real client IP to the API as `X-Forwarded-For` (login rate limits are per IP), so `TRUSTED_PROXIES` must cover both Caddy and the web container (the compose network).
- `deploy/Caddyfile`: site `{$VAPEN_DOMAIN}`, `handle /api/*` → `reverse_proxy api:8080` with `flush_interval -1` (required for SSE), `handle` → `reverse_proxy web:3000`, HSTS header, gzip/zstd except for `text/event-stream`.
- `.env.example` with every variable used by compose, api and web, with safe example values and comments. Never commit a real `.env`.
- `.github/workflows/api.yml`: on changes in `api/**` run generate (check for diff), vet, lint, test (with testcontainers), govulncheck, docker build.

### B.7 Tests & quality gates

- Unit tests: password hashing, JWT issue/verify, refresh rotation including grace period and reuse detection, bucket math, deterministic validation helpers.
- Integration tests (testcontainers PostgreSQL, real HTTP server via `httptest`): every endpoint's happy path and main error cases.
- **Privacy matrix test**: table-driven, every flag × every endpoint that exposes other users' data (`/puffs`, `/stats/usage`, `/stats/devices/{id}`, `/groups/{id}/overview`, `/groups/{id}/live`), with default, override `true`, override `false`, and "users share two groups with different settings".
- Ingest: idempotency, partial rejection, future timestamps, wrong device id, revoked token, rate limit.
- SSE: snapshot first, update after ingest, removal after privacy change.
- `go test -race ./...` passes, `golangci-lint` clean, `govulncheck` clean, `openapi.yaml` validates (for example with `vacuum` or `redocly lint`).

### B.8 Milestones

Work through these in order. After each milestone, commit and make sure everything builds and all tests pass.

1. **Skeleton**: `openapi.yaml` with the **complete** contract from Part A (all endpoints and schemas, even if not implemented yet; unimplemented handlers return `501`), codegen, config, migrations framework, `/healthz` and `/readyz`, Dockerfile, `docker-compose.yml`, Caddyfile, `.env.example`, CI workflow. Done when `docker compose up -d postgres api` serves `/healthz` and the spec lints cleanly. Publish the spec early so the web and mobile agents can start.
2. **Auth & account**: register, login, refresh (rotation, grace, reuse detection), logout, `/me` endpoints, password change, rate limits.
3. **Devices & ingest**: device CRUD, ingest tokens, `POST /ingest` with all rules from A.7, `cmd/simulate`.
4. **Read endpoints**: `/puffs`, `/stats/usage`, `/stats/devices/{id}`, `cmd/seed`.
5. **Groups & privacy**: group lifecycle, privacy defaults and overrides, privacy resolver, `/groups/{id}/overview`, privacy matrix test.
6. **Live**: LISTEN/NOTIFY hub, `/groups/{id}/live`.
7. **Hardening & docs**: `/me/export`, `DELETE /me`, security review of all endpoints, `api/README.md` with curl examples, final lint and vulnerability checks.

### B.9 Assumptions, out of scope, open questions

- Single API instance is the default deployment; the design (LISTEN/NOTIFY, stateless JWT) must still allow several instances later. Only the in-memory rate limiter would need a shared store.
- Out of scope: email verification, password reset via email, OAuth/social login, 2FA, push notifications, admin UI. Design the user table so email verification and TOTP can be added later.
- The exact device data fields depend on the reverse-engineered BLE protocol (done by the mobile agent). If the mobile side discovers additional useful fields, they are added as nullable fields to `DeviceStatus` via a contract change (A.3).
- If something in Part A is contradictory or impossible, stop and ask the user instead of guessing.
