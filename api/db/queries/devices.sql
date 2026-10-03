-- name: ListDevicesByUser :many
SELECT * FROM devices WHERE user_id = $1 ORDER BY created_at;

-- name: GetDeviceByID :one
SELECT * FROM devices WHERE id = $1;

-- name: GetDeviceByUserHardware :one
SELECT * FROM devices WHERE user_id = $1 AND hardware_id = $2;

-- name: CreateDevice :one
INSERT INTO devices (id, user_id, model, name, hardware_id, firmware_version)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING *;

-- name: UpdateDeviceName :one
UPDATE devices SET name = $2 WHERE id = $1 AND user_id = $3 RETURNING *;

-- name: DeleteDevice :exec
DELETE FROM devices WHERE id = $1 AND user_id = $2;

-- name: UpdateDeviceLiveState :exec
UPDATE devices SET
    last_seen_at = COALESCE(sqlc.narg('last_seen_at'), last_seen_at),
    last_puff_at = COALESCE(sqlc.narg('last_puff_at'), last_puff_at),
    vaping_since = sqlc.narg('vaping_since'),
    latest_status = COALESCE(sqlc.narg('latest_status'), latest_status),
    firmware_version = COALESCE(sqlc.narg('firmware_version'), firmware_version)
WHERE id = $1;

-- name: CreateDeviceToken :one
INSERT INTO device_tokens (id, device_id, name, token_hash)
VALUES ($1, $2, $3, $4) RETURNING *;

-- name: ListDeviceTokens :many
SELECT * FROM device_tokens WHERE device_id = $1 ORDER BY created_at;

-- name: RevokeDeviceToken :exec
UPDATE device_tokens SET revoked_at = now()
WHERE id = $1 AND device_id = $2 AND revoked_at IS NULL;

-- name: GetDeviceTokenByHash :one
SELECT
    dt.id, dt.device_id, dt.name, dt.token_hash, dt.created_at, dt.last_used_at, dt.revoked_at,
    d.user_id AS owner_user_id
FROM device_tokens dt
JOIN devices d ON d.id = dt.device_id
WHERE dt.token_hash = $1 AND dt.revoked_at IS NULL;

-- name: TouchDeviceTokenLastUsed :exec
UPDATE device_tokens SET last_used_at = now()
WHERE id = $1 AND (last_used_at IS NULL OR last_used_at < now() - interval '1 minute');

-- name: RevokeAllDeviceTokens :exec
UPDATE device_tokens SET revoked_at = now() WHERE device_id = $1 AND revoked_at IS NULL;
