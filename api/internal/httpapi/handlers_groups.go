package httpapi

import (
	"context"
	"errors"
	"fmt"
	"io"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	openapi_types "github.com/oapi-codegen/runtime/types"

	grouppkg "github.com/antschni/vapen/api/internal/groups"
	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/privacy"
	"github.com/antschni/vapen/api/internal/store"
)

func (s *Server) ListGroups(ctx context.Context, _ openapi.ListGroupsRequestObject) (openapi.ListGroupsResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	rows, err := s.q.ListUserGroups(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	out := make([]openapi.GroupSummary, 0, len(rows))
	for _, g := range rows {
		out = append(out, openapi.GroupSummary{
			Id:          openapi_types.UUID(uuidFromPG(g.ID)),
			Name:        g.Name,
			Role:        openapi.GroupRole(g.Role),
			MemberCount: int(g.MemberCount),
			CreatedAt:   g.CreatedAt.Time.UTC(),
		})
	}
	return openapi.ListGroups200JSONResponse(out), nil
}

func (s *Server) CreateGroup(ctx context.Context, request openapi.CreateGroupRequestObject) (openapi.CreateGroupResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("name required")
	}
	code, err := grouppkg.NewInviteCode()
	if err != nil {
		return nil, err
	}
	gid := uuid.Must(uuid.NewV7())
	g, err := s.q.CreateGroup(ctx, store.CreateGroupParams{
		ID:         pgUUID(gid),
		Name:       body.Name,
		OwnerID:    pgUUID(userID),
		InviteCode: code,
	})
	if err != nil {
		return nil, err
	}
	_ = s.q.AddGroupMember(ctx, store.AddGroupMemberParams{
		GroupID: pgUUID(gid), UserID: pgUUID(userID), Role: "owner",
	})
	return openapi.CreateGroup201JSONResponse(s.groupToAPI(ctx, g, userID, true)), nil
}

func (s *Server) JoinGroup(ctx context.Context, request openapi.JoinGroupRequestObject) (openapi.JoinGroupResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("invite_code required")
	}
	code := grouppkg.NormalizeInviteCode(body.InviteCode)
	g, err := s.q.GetGroupByInviteCode(ctx, code)
	if err != nil {
		return nil, errNotFound()
	}
	cnt, _ := s.q.CountGroupMembers(ctx, g.ID)
	if cnt >= 100 {
		return nil, errConflict("group is full")
	}
	_ = s.q.AddGroupMember(ctx, store.AddGroupMemberParams{
		GroupID: g.ID, UserID: pgUUID(userID), Role: "member",
	})
	return openapi.JoinGroup200JSONResponse(s.groupToAPI(ctx, g, userID, false)), nil
}

func (s *Server) GetGroup(ctx context.Context, request openapi.GetGroupRequestObject) (openapi.GetGroupResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	if _, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)}); err != nil {
		return nil, errNotFound()
	}
	g, err := s.q.GetGroupByID(ctx, pgUUID(gid))
	if err != nil {
		return nil, errNotFound()
	}
	return openapi.GetGroup200JSONResponse(s.groupToAPI(ctx, g, userID, true)), nil
}

func (s *Server) PatchGroup(ctx context.Context, request openapi.PatchGroupRequestObject) (openapi.PatchGroupResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	m, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)})
	if err != nil || (m.Role != "admin" && m.Role != "owner") {
		return nil, errForbidden()
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("name required")
	}
	g, err := s.q.UpdateGroupName(ctx, store.UpdateGroupNameParams{ID: pgUUID(gid), Name: body.Name})
	if err != nil {
		return nil, err
	}
	return openapi.PatchGroup200JSONResponse(s.groupToAPI(ctx, g, userID, true)), nil
}

func (s *Server) DeleteGroup(ctx context.Context, request openapi.DeleteGroupRequestObject) (openapi.DeleteGroupResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	g, err := s.q.GetGroupByID(ctx, pgUUID(gid))
	if err != nil || uuidFromPG(g.OwnerID) != userID {
		return nil, errForbidden()
	}
	return openapi.DeleteGroup204Response{}, s.q.DeleteGroup(ctx, pgUUID(gid))
}

func (s *Server) RotateGroupInvite(ctx context.Context, request openapi.RotateGroupInviteRequestObject) (openapi.RotateGroupInviteResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	m, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)})
	if err != nil || (m.Role != "admin" && m.Role != "owner") {
		return nil, errForbidden()
	}
	code, err := grouppkg.NewInviteCode()
	if err != nil {
		return nil, err
	}
	g, err := s.q.UpdateGroupInviteCode(ctx, store.UpdateGroupInviteCodeParams{ID: pgUUID(gid), InviteCode: code})
	if err != nil {
		return nil, err
	}
	return openapi.RotateGroupInvite200JSONResponse(openapi.InviteCodeResponse{InviteCode: g.InviteCode}), nil
}

func (s *Server) LeaveGroup(ctx context.Context, request openapi.LeaveGroupRequestObject) (openapi.LeaveGroupResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	m, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)})
	if err != nil {
		return nil, errNotFound()
	}
	if m.Role == "owner" {
		return nil, errConflict("transfer ownership before leaving")
	}
	return openapi.LeaveGroup204Response{}, s.q.RemoveGroupMember(ctx, store.RemoveGroupMemberParams{
		GroupID: pgUUID(gid), UserID: pgUUID(userID),
	})
}

func (s *Server) PatchGroupMember(ctx context.Context, request openapi.PatchGroupMemberRequestObject) (openapi.PatchGroupMemberResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	target := uuid.UUID(request.UserId)
	body := request.Body
	if body == nil {
		return nil, errValidation("role required")
	}
	owner, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)})
	if err != nil || owner.Role != "owner" {
		return nil, errForbidden()
	}
	role := string(body.Role)
	if role == "owner" {
		_ = s.q.DemoteOwnerToAdmin(ctx, store.DemoteOwnerToAdminParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)})
		_ = s.q.PromoteMemberToOwner(ctx, store.PromoteMemberToOwnerParams{GroupID: pgUUID(gid), UserID: pgUUID(target)})
		_ = s.q.SetGroupOwner(ctx, store.SetGroupOwnerParams{ID: pgUUID(gid), OwnerID: pgUUID(target)})
	} else if role == "admin" || role == "member" {
		_ = s.q.UpdateGroupMemberRole(ctx, store.UpdateGroupMemberRoleParams{
			GroupID: pgUUID(gid), UserID: pgUUID(target), Role: role,
		})
	}
	m, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(target)})
	if err != nil {
		return nil, errNotFound()
	}
	return openapi.PatchGroupMember200JSONResponse(openapi.GroupMember{
		GroupId:     openapi_types.UUID(gid),
		UserId:      openapi_types.UUID(target),
		DisplayName: m.DisplayName,
		Role:        openapi.GroupRole(m.Role),
		JoinedAt:    m.JoinedAt.Time.UTC(),
	}), nil
}

func (s *Server) RemoveGroupMember(ctx context.Context, request openapi.RemoveGroupMemberRequestObject) (openapi.RemoveGroupMemberResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	target := uuid.UUID(request.UserId)
	actor, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)})
	if err != nil || (actor.Role != "admin" && actor.Role != "owner") {
		return nil, errForbidden()
	}
	targetM, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(target)})
	if err != nil {
		return nil, errNotFound()
	}
	if targetM.Role == "owner" || (targetM.Role == "admin" && actor.Role != "owner") {
		return nil, errForbidden()
	}
	return openapi.RemoveGroupMember204Response{}, s.q.RemoveGroupMember(ctx, store.RemoveGroupMemberParams{
		GroupID: pgUUID(gid), UserID: pgUUID(target),
	})
}

func (s *Server) GetGroupPrivacy(ctx context.Context, request openapi.GetGroupPrivacyRequestObject) (openapi.GetGroupPrivacyResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	if _, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)}); err != nil {
		return nil, errNotFound()
	}
	return openapi.GetGroupPrivacy200JSONResponse(s.groupPrivacy(ctx, gid, userID)), nil
}

func (s *Server) PutGroupPrivacy(ctx context.Context, request openapi.PutGroupPrivacyRequestObject) (openapi.PutGroupPrivacyResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	if _, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)}); err != nil {
		return nil, errNotFound()
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("overrides required")
	}
	o := body.Overrides
	_, _ = s.q.UpsertGroupPrivacyOverride(ctx, store.UpsertGroupPrivacyOverrideParams{
		GroupID:           pgUUID(gid),
		UserID:            pgUUID(userID),
		ShareLiveStatus:   pgBoolPtr(o.ShareLiveStatus),
		ShareUsageSummary: pgBoolPtr(o.ShareUsageSummary),
		ShareUsageDetail:  pgBoolPtr(o.ShareUsageDetail),
		ShareDeviceStats:  pgBoolPtr(o.ShareDeviceStats),
		ShowInLeaderboard: pgBoolPtr(o.ShowInLeaderboard),
	})
	return openapi.PutGroupPrivacy200JSONResponse(s.groupPrivacy(ctx, gid, userID)), nil
}

func (s *Server) GetGroupOverview(ctx context.Context, request openapi.GetGroupOverviewRequestObject) (openapi.GetGroupOverviewResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	if _, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)}); err != nil {
		return nil, errNotFound()
	}
	g, err := s.q.GetGroupByID(ctx, pgUUID(gid))
	if err != nil {
		return nil, errNotFound()
	}
	u, _ := s.q.GetUserByID(ctx, pgUUID(userID))
	tz := u.Timezone
	if request.Params.Tz != nil {
		tz = *request.Params.Tz
	}
	now := time.Now().UTC()
	from := startOfDay(now, tz)
	to := now
	if request.Params.From != nil {
		from = request.Params.From.UTC()
	}
	if request.Params.To != nil {
		to = request.Params.To.UTC()
	}
	members, _ := s.q.ListGroupMembers(ctx, g.ID)
	outMembers := []openapi.GroupOverviewMember{}
	leaderboard := []openapi.LeaderboardEntry{}
	rank := 1
	for _, m := range members {
		mid := uuidFromPG(m.UserID)
		eff := s.groupPrivacy(ctx, gid, mid).Effective
		vis := openapi.MemberVisibility{
			LiveStatus:    eff.ShareLiveStatus,
			UsageSummary:  eff.ShareUsageSummary,
			UsageDetail:   eff.ShareUsageDetail,
			DeviceStats:   eff.ShareDeviceStats,
			Leaderboard:   eff.ShowInLeaderboard,
		}
		om := openapi.GroupOverviewMember{
			UserId:      openapi_types.UUID(mid),
			DisplayName: m.DisplayName,
			Role:        openapi.GroupRole(m.Role),
			Visibility:  vis,
		}
		if mid == userID || vis.LiveStatus {
			devs, _ := s.q.ListDevicesByUser(ctx, m.UserID)
			if len(devs) > 0 {
				d := devs[0]
				ml := openapi.MemberLive{}
				if d.VapingSince.Valid {
					ml.VapingSince = &d.VapingSince.Time
				}
				if d.LastPuffAt.Valid {
					ml.LastPuffAt = &d.LastPuffAt.Time
				}
				var live openapi.GroupOverviewMember_Live
				_ = live.FromMemberLive(ml)
				om.Live = &live
			}
		}
		outMembers = append(outMembers, om)
		if eff.ShowInLeaderboard && eff.ShareUsageSummary {
			leaderboard = append(leaderboard, openapi.LeaderboardEntry{
				Rank: rank, UserId: openapi_types.UUID(mid), DisplayName: m.DisplayName,
			})
			rank++
		}
	}
	cnt, _ := s.q.CountGroupMembers(ctx, g.ID)
	overview := openapi.GroupOverview{
		From: from, To: to, Tz: tz,
		Members:     outMembers,
		Leaderboard: leaderboard,
	}
	overview.Group.Id = openapi_types.UUID(gid)
	overview.Group.Name = g.Name
	overview.Group.MemberCount = int(cnt)
	return openapi.GetGroupOverview200JSONResponse(overview), nil
}

func (s *Server) GetGroupLive(ctx context.Context, request openapi.GetGroupLiveRequestObject) (openapi.GetGroupLiveResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	gid := uuid.UUID(request.Id)
	if _, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: pgUUID(gid), UserID: pgUUID(userID)}); err != nil {
		return nil, errNotFound()
	}
	pr, pw := io.Pipe()
	go s.streamLive(ctx, gid, userID, pw)
	return openapi.GetGroupLive200TexteventStreamResponse{Body: pr}, nil
}

func (s *Server) streamLive(ctx context.Context, gid, viewer uuid.UUID, w *io.PipeWriter) {
	defer w.Close()
	fmt.Fprintf(w, "event: snapshot\ndata: {\"members\":[]}\n\n")
	ch, unsub := s.live.Subscribe(gid)
	defer unsub()
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			fmt.Fprintf(w, ": ping\n\n")
		case ev := <-ch:
			if ev.UserID == viewer {
				continue
			}
			ok, _ := s.privacy.CanView(ctx, viewer, ev.UserID, &gid, privacy.ShareLiveStatus)
			if !ok {
				continue
			}
			fmt.Fprintf(w, "event: member_update\ndata: {\"user_id\":\"%s\"}\n\n", ev.UserID)
		}
	}
}

func (s *Server) groupToAPI(ctx context.Context, g store.Group, viewer uuid.UUID, withMembers bool) openapi.Group {
	cnt, _ := s.q.CountGroupMembers(ctx, g.ID)
	og := openapi.Group{
		Id:          openapi_types.UUID(uuidFromPG(g.ID)),
		Name:        g.Name,
		OwnerId:     openapi_types.UUID(uuidFromPG(g.OwnerID)),
		MemberCount: int(cnt),
		CreatedAt:   g.CreatedAt.Time.UTC(),
		Members:     []openapi.GroupMember{},
	}
	m, err := s.q.GetGroupMember(ctx, store.GetGroupMemberParams{GroupID: g.ID, UserID: pgUUID(viewer)})
	if err == nil && (m.Role == "owner" || m.Role == "admin") {
		og.InviteCode = &g.InviteCode
	}
	if withMembers {
		members, _ := s.q.ListGroupMembers(ctx, g.ID)
		for _, mem := range members {
			og.Members = append(og.Members, openapi.GroupMember{
				GroupId:     openapi_types.UUID(uuidFromPG(g.ID)),
				UserId:      openapi_types.UUID(uuidFromPG(mem.UserID)),
				DisplayName: mem.DisplayName,
				Role:        openapi.GroupRole(mem.Role),
				JoinedAt:    mem.JoinedAt.Time.UTC(),
			})
		}
	}
	return og
}

func (s *Server) groupPrivacy(ctx context.Context, gid, userID uuid.UUID) openapi.GroupPrivacy {
	def, err := s.q.GetPrivacyDefaults(ctx, pgUUID(userID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			def = store.PrivacyDefault{ShareLiveStatus: true, ShareUsageSummary: true}
		}
	}
	over, _ := s.q.GetGroupPrivacyOverride(ctx, store.GetGroupPrivacyOverrideParams{
		GroupID: pgUUID(gid), UserID: pgUUID(userID),
	})
	eff := privacyToAPI(def)
	ov := openapi.PrivacyOverrides{}
	if over.ShareLiveStatus.Valid {
		ov.ShareLiveStatus = &over.ShareLiveStatus.Bool
		eff.ShareLiveStatus = over.ShareLiveStatus.Bool
	}
	return openapi.GroupPrivacy{Defaults: privacyToAPI(def), Overrides: ov, Effective: eff}
}
