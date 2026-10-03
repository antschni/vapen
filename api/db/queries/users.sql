-- name: CreateUser :one
INSERT INTO users (id, email, display_name, timezone, password_hash)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: GetUserByEmailLower :one
SELECT * FROM users WHERE email_lower = lower($1);

-- name: GetUserByID :one
SELECT * FROM users WHERE id = $1;

-- name: UpdateUser :one
UPDATE users
SET display_name = COALESCE(sqlc.narg('display_name'), display_name),
    timezone = COALESCE(sqlc.narg('timezone'), timezone)
WHERE id = $1
RETURNING *;

-- name: UpdateUserPassword :exec
UPDATE users SET password_hash = $2 WHERE id = $1;

-- name: DeleteUser :exec
DELETE FROM users WHERE id = $1;
