-- name: CreateSession :one
INSERT INTO sessions (id, user_id) VALUES ($1, $2) RETURNING *;

-- name: GetSession :one
SELECT * FROM sessions WHERE id = $1;

-- name: RevokeSession :exec
UPDATE sessions SET revoked_at = now() WHERE id = $1 AND revoked_at IS NULL;

-- name: RevokeOtherSessions :exec
UPDATE sessions SET revoked_at = now()
WHERE user_id = $1 AND id != $2 AND revoked_at IS NULL;

-- name: RevokeAllUserSessions :exec
UPDATE sessions SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL;

-- name: CreateRefreshToken :one
INSERT INTO refresh_tokens (id, session_id, token_hash, expires_at)
VALUES ($1, $2, $3, $4) RETURNING *;

-- name: GetRefreshTokenByHash :one
SELECT * FROM refresh_tokens WHERE token_hash = $1 AND revoked_at IS NULL;

-- name: MarkRefreshTokenRotated :one
-- Claims the token for rotation; returns no row when a concurrent request rotated it first.
UPDATE refresh_tokens
SET rotated_at = now(), grace_expires_at = $2
WHERE id = $1 AND rotated_at IS NULL AND revoked_at IS NULL
RETURNING *;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1;

-- name: RevokeSessionRefreshTokens :exec
UPDATE refresh_tokens SET revoked_at = now() WHERE session_id = $1 AND revoked_at IS NULL;
