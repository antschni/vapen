-- name: GetPrivacyDefaults :one
SELECT * FROM privacy_defaults WHERE user_id = $1;

-- name: UpsertPrivacyDefaults :one
INSERT INTO privacy_defaults (user_id, share_live_status, share_usage_summary, share_usage_detail, share_device_stats, show_in_leaderboard)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (user_id) DO UPDATE SET
    share_live_status = EXCLUDED.share_live_status,
    share_usage_summary = EXCLUDED.share_usage_summary,
    share_usage_detail = EXCLUDED.share_usage_detail,
    share_device_stats = EXCLUDED.share_device_stats,
    show_in_leaderboard = EXCLUDED.show_in_leaderboard
RETURNING *;

-- name: GetGroupPrivacyOverride :one
SELECT * FROM group_privacy_overrides WHERE group_id = $1 AND user_id = $2;

-- name: UpsertGroupPrivacyOverride :one
INSERT INTO group_privacy_overrides (group_id, user_id, share_live_status, share_usage_summary, share_usage_detail, share_device_stats, show_in_leaderboard)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (group_id, user_id) DO UPDATE SET
    share_live_status = EXCLUDED.share_live_status,
    share_usage_summary = EXCLUDED.share_usage_summary,
    share_usage_detail = EXCLUDED.share_usage_detail,
    share_device_stats = EXCLUDED.share_device_stats,
    show_in_leaderboard = EXCLUDED.show_in_leaderboard
RETURNING *;

-- name: CanViewCapability :one
SELECT EXISTS (
    SELECT 1
    FROM group_members viewer
    JOIN group_members target ON target.group_id = viewer.group_id AND target.user_id = @target_user_id
    JOIN privacy_defaults pd ON pd.user_id = target.user_id
    LEFT JOIN group_privacy_overrides gpo ON gpo.group_id = viewer.group_id AND gpo.user_id = target.user_id
    WHERE viewer.user_id = @viewer_user_id
      AND (@group_id::uuid IS NULL OR viewer.group_id = @group_id)
      AND CASE @capability::text
        WHEN 'share_live_status' THEN COALESCE(gpo.share_live_status, pd.share_live_status)
        WHEN 'share_usage_summary' THEN COALESCE(gpo.share_usage_summary, pd.share_usage_summary)
        WHEN 'share_usage_detail' THEN COALESCE(gpo.share_usage_detail, pd.share_usage_detail)
        WHEN 'share_device_stats' THEN COALESCE(gpo.share_device_stats, pd.share_device_stats)
        WHEN 'show_in_leaderboard' THEN COALESCE(gpo.show_in_leaderboard, pd.show_in_leaderboard)
      END = true
) AS allowed;
