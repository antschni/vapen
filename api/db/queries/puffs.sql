-- name: InsertPuff :one
INSERT INTO puffs (id, user_id, device_id, client_event_id, started_at, duration_ms, source, raw)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
ON CONFLICT (device_id, client_event_id) DO NOTHING
RETURNING *;

-- name: InsertStatusSnapshot :one
INSERT INTO device_status_snapshots (id, device_id, user_id, client_event_id, recorded_at, status)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (device_id, client_event_id) DO NOTHING
RETURNING *;

-- name: ListPuffs :many
SELECT * FROM puffs
WHERE user_id = $1
  AND started_at >= $2
  AND started_at < $3
  AND (sqlc.narg('device_id')::uuid IS NULL OR device_id = sqlc.narg('device_id'))
  AND (sqlc.narg('source')::text IS NULL OR source = sqlc.narg('source'))
  AND (sqlc.narg('min_duration_ms')::int IS NULL OR duration_ms >= sqlc.narg('min_duration_ms'))
  AND (sqlc.narg('max_duration_ms')::int IS NULL OR duration_ms <= sqlc.narg('max_duration_ms'))
  AND (
    sqlc.narg('cursor_started_at')::timestamptz IS NULL
    OR (started_at, id) < (sqlc.narg('cursor_started_at'), sqlc.narg('cursor_id')::uuid)
  )
ORDER BY started_at DESC, id DESC
LIMIT $4;

-- name: ListPuffsAsc :many
SELECT * FROM puffs
WHERE user_id = $1
  AND started_at >= $2
  AND started_at < $3
  AND (sqlc.narg('device_id')::uuid IS NULL OR device_id = sqlc.narg('device_id'))
  AND (sqlc.narg('source')::text IS NULL OR source = sqlc.narg('source'))
  AND (
    sqlc.narg('cursor_started_at')::timestamptz IS NULL
    OR (started_at, id) > (sqlc.narg('cursor_started_at'), sqlc.narg('cursor_id')::uuid)
  )
ORDER BY started_at ASC, id ASC
LIMIT $4;
