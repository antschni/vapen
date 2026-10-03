-- +goose Up
CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE users (
    id UUID PRIMARY KEY,
    email TEXT NOT NULL,
    email_lower TEXT GENERATED ALWAYS AS (lower(email)) STORED,
    display_name TEXT NOT NULL CHECK (char_length(display_name) BETWEEN 2 AND 40),
    timezone TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_lower_idx ON users (email_lower);

CREATE TABLE sessions (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    revoked_at TIMESTAMPTZ
);
CREATE INDEX sessions_user_id_idx ON sessions (user_id);

CREATE TABLE refresh_tokens (
    id UUID PRIMARY KEY,
    session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    token_hash BYTEA NOT NULL,
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    rotated_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ,
    grace_token_hash BYTEA,
    grace_expires_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX refresh_tokens_token_hash_idx ON refresh_tokens (token_hash);

CREATE TABLE devices (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    model TEXT NOT NULL CHECK (model = 'elfbar_master'),
    name TEXT NOT NULL,
    hardware_id TEXT NOT NULL,
    firmware_version TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_seen_at TIMESTAMPTZ,
    last_puff_at TIMESTAMPTZ,
    vaping_since TIMESTAMPTZ,
    latest_status JSONB,
    UNIQUE (user_id, hardware_id)
);
CREATE INDEX devices_user_id_idx ON devices (user_id);

CREATE TABLE device_tokens (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    token_hash BYTEA NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at TIMESTAMPTZ,
    revoked_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX device_tokens_token_hash_idx ON device_tokens (token_hash);
CREATE INDEX device_tokens_device_id_idx ON device_tokens (device_id);

CREATE TABLE puffs (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    client_event_id UUID NOT NULL,
    started_at TIMESTAMPTZ NOT NULL,
    duration_ms INT NOT NULL CHECK (duration_ms BETWEEN 1 AND 60000),
    source TEXT NOT NULL CHECK (source IN ('live', 'history')),
    received_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    raw JSONB,
    UNIQUE (device_id, client_event_id)
);
CREATE INDEX puffs_user_started_idx ON puffs (user_id, started_at DESC);
CREATE INDEX puffs_device_started_idx ON puffs (device_id, started_at DESC);

CREATE TABLE device_status_snapshots (
    id UUID PRIMARY KEY,
    device_id UUID NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_event_id UUID NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    status JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (device_id, client_event_id)
);
CREATE INDEX device_status_snapshots_device_recorded_idx ON device_status_snapshots (device_id, recorded_at DESC);

CREATE TABLE groups (
    id UUID PRIMARY KEY,
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 60),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    invite_code TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX groups_invite_code_idx ON groups (invite_code);

CREATE TABLE group_members (
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL CHECK (role IN ('owner', 'admin', 'member')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (group_id, user_id)
);
CREATE INDEX group_members_user_id_idx ON group_members (user_id);

CREATE TABLE privacy_defaults (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    share_live_status BOOLEAN NOT NULL DEFAULT true,
    share_usage_summary BOOLEAN NOT NULL DEFAULT true,
    share_usage_detail BOOLEAN NOT NULL DEFAULT false,
    share_device_stats BOOLEAN NOT NULL DEFAULT false,
    show_in_leaderboard BOOLEAN NOT NULL DEFAULT true
);

CREATE TABLE group_privacy_overrides (
    group_id UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    share_live_status BOOLEAN,
    share_usage_summary BOOLEAN,
    share_usage_detail BOOLEAN,
    share_device_stats BOOLEAN,
    show_in_leaderboard BOOLEAN,
    PRIMARY KEY (group_id, user_id)
);

-- +goose Down
DROP TABLE IF EXISTS group_privacy_overrides;
DROP TABLE IF EXISTS privacy_defaults;
DROP TABLE IF EXISTS group_members;
DROP TABLE IF EXISTS groups;
DROP TABLE IF EXISTS device_status_snapshots;
DROP TABLE IF EXISTS puffs;
DROP TABLE IF EXISTS device_tokens;
DROP TABLE IF EXISTS devices;
DROP TABLE IF EXISTS refresh_tokens;
DROP TABLE IF EXISTS sessions;
DROP TABLE IF EXISTS users;
