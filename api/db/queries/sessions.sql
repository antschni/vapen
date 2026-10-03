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

-- name: GetRefreshTokenByGraceHash :one
SELECT * FROM refresh_tokens
WHERE grace_token_hash = $1 AND grace_expires_at > now() AND revoked_at IS NULL;

-- name: RotateRefreshToken :one
UPDATE refresh_tokens
SET token_hash = $2, expires_at = $3, rotated_at = now(),
    grace_token_hash = $4, grace_expires_at = $5
WHERE id = $1
RETURNING *;

-- name: RevokeRefreshToken :exec
UPDATE refresh_tokens SET revoked_at = now() WHERE id = $1;

-- name: RevokeSessionRefreshTokens :exec
UPDATE refresh_tokens SET revoked_at = now() WHERE session_id = $1 AND revoked_at IS NULL;
