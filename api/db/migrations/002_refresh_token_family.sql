-- +goose Up
-- Refresh tokens are now one row per issued token: rotation marks the old row and inserts a new one.
-- Rows written by the old in-place rotation always hold the session's current token, so they must
-- not count as rotated, otherwise their next refresh would be treated as token reuse.
UPDATE refresh_tokens
SET rotated_at = NULL, grace_token_hash = NULL, grace_expires_at = NULL
WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS refresh_tokens_session_id_idx ON refresh_tokens (session_id);

-- +goose Down
DROP INDEX IF EXISTS refresh_tokens_session_id_idx;
