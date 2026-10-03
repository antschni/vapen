-- name: CreateGroup :one
INSERT INTO groups (id, name, owner_id, invite_code) VALUES ($1, $2, $3, $4) RETURNING *;

-- name: GetGroupByID :one
SELECT * FROM groups WHERE id = $1;

-- name: GetGroupByInviteCode :one
SELECT * FROM groups WHERE invite_code = $1;

-- name: UpdateGroupName :one
UPDATE groups SET name = $2 WHERE id = $1 RETURNING *;

-- name: UpdateGroupInviteCode :one
UPDATE groups SET invite_code = $2 WHERE id = $1 RETURNING *;

-- name: DeleteGroup :exec
DELETE FROM groups WHERE id = $1;

-- name: AddGroupMember :exec
INSERT INTO group_members (group_id, user_id, role) VALUES ($1, $2, $3)
ON CONFLICT DO NOTHING;

-- name: GetGroupMember :one
SELECT gm.*, u.display_name
FROM group_members gm
JOIN users u ON u.id = gm.user_id
WHERE gm.group_id = $1 AND gm.user_id = $2;

-- name: ListGroupMembers :many
SELECT gm.*, u.display_name
FROM group_members gm
JOIN users u ON u.id = gm.user_id
WHERE gm.group_id = $1
ORDER BY gm.joined_at;

-- name: CountGroupMembers :one
SELECT count(*)::int FROM group_members WHERE group_id = $1;

-- name: ListUserGroups :many
SELECT g.id, g.name, g.created_at, gm.role,
       (SELECT count(*)::int FROM group_members WHERE group_id = g.id) AS member_count
FROM group_members gm
JOIN groups g ON g.id = gm.group_id
WHERE gm.user_id = $1
ORDER BY g.created_at DESC;

-- name: UpdateGroupMemberRole :exec
UPDATE group_members SET role = $3 WHERE group_id = $1 AND user_id = $2;

-- name: RemoveGroupMember :exec
DELETE FROM group_members WHERE group_id = $1 AND user_id = $2;

-- name: DemoteOwnerToAdmin :exec
UPDATE group_members SET role = 'admin' WHERE group_id = $1 AND user_id = $2 AND role = 'owner';

-- name: PromoteMemberToOwner :exec
UPDATE group_members SET role = 'owner' WHERE group_id = $1 AND user_id = $2;

-- name: SetGroupOwner :exec
UPDATE groups SET owner_id = $2 WHERE id = $1;
