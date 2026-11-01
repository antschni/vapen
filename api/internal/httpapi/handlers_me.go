package httpapi

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/antschni/vapen/api/internal/auth"
	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/store"
)

func (s *Server) GetMe(ctx context.Context, _ openapi.GetMeRequestObject) (openapi.GetMeResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	u, err := s.q.GetUserByID(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	return openapi.GetMe200JSONResponse(userToAPI(u)), nil
}

func (s *Server) PatchMe(ctx context.Context, request openapi.PatchMeRequestObject) (openapi.PatchMeResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("Request body is required")
	}
	if body.DisplayName != nil && !validDisplayName(*body.DisplayName) {
		return nil, errValidation("display_name must be 2 to 40 characters")
	}
	if body.Timezone != nil && !validTimezone(*body.Timezone) {
		return nil, errValidation("invalid timezone")
	}
	u, err := s.q.UpdateUser(ctx, store.UpdateUserParams{
		ID:          pgUUID(userID),
		DisplayName: pgTextPtr(body.DisplayName),
		Timezone:    pgTextPtr(body.Timezone),
	})
	if err != nil {
		return nil, err
	}
	return openapi.PatchMe200JSONResponse(userToAPI(u)), nil
}

func (s *Server) ChangePassword(ctx context.Context, request openapi.ChangePasswordRequestObject) (openapi.ChangePasswordResponseObject, error) {
	userID, sid, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil || !validPassword(body.NewPassword) {
		return nil, errValidation("new_password must be 12 to 128 characters")
	}
	if !s.passwordUser.Allow(userID.String()) {
		return nil, errRateLimited()
	}
	u, err := s.q.GetUserByID(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	if len(body.CurrentPassword) > maxPasswordLen || !auth.VerifyPassword(u.PasswordHash, body.CurrentPassword) {
		return nil, errUnauthorized("Invalid current password")
	}
	hash := auth.HashPassword(body.NewPassword)
	if err := s.q.UpdateUserPassword(ctx, store.UpdateUserPasswordParams{
		ID:           pgUUID(userID),
		PasswordHash: hash,
	}); err != nil {
		return nil, err
	}
	if err := s.auth.RevokeOtherSessions(ctx, userID, sid); err != nil {
		return nil, err
	}
	return openapi.ChangePassword204Response{}, nil
}

func (s *Server) DeleteMe(ctx context.Context, request openapi.DeleteMeRequestObject) (openapi.DeleteMeResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("password required")
	}
	if !s.passwordUser.Allow(userID.String()) {
		return nil, errRateLimited()
	}
	u, err := s.q.GetUserByID(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	if len(body.Password) > maxPasswordLen || !auth.VerifyPassword(u.PasswordHash, body.Password) {
		return nil, errUnauthorized("Invalid password")
	}
	return openapi.DeleteMe204Response{}, s.q.DeleteUser(ctx, pgUUID(userID))
}

func (s *Server) ExportMe(ctx context.Context, _ openapi.ExportMeRequestObject) (openapi.ExportMeResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	u, err := s.q.GetUserByID(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	devs, err := s.q.ListDevicesByUser(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	devices := make([]openapi.Device, 0, len(devs))
	for _, d := range devs {
		devices = append(devices, deviceToAPI(d))
	}
	groups, err := s.q.ListUserGroups(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	privacyDefaults, err := s.q.GetPrivacyDefaults(ctx, pgUUID(userID))
	if err != nil && !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}
	puffs, err := s.exportPuffs(ctx, userID)
	if err != nil {
		return nil, err
	}
	export := map[string]interface{}{
		"user":             userToAPI(u),
		"devices":          devices,
		"groups":           groups,
		"privacy_defaults": privacyToAPI(privacyDefaults),
		"puffs":            puffs,
	}
	return openapi.ExportMe200JSONResponse(export), nil
}

func (s *Server) GetPrivacyDefaults(ctx context.Context, _ openapi.GetPrivacyDefaultsRequestObject) (openapi.GetPrivacyDefaultsResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	p, err := s.q.GetPrivacyDefaults(ctx, pgUUID(userID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			p, err = s.q.UpsertPrivacyDefaults(ctx, store.UpsertPrivacyDefaultsParams{
				UserID: pgUUID(userID), ShareLiveStatus: true, ShareUsageSummary: true,
				ShareUsageDetail: false, ShareDeviceStats: false, ShowInLeaderboard: true,
			})
		}
		if err != nil {
			return nil, err
		}
	}
	return openapi.GetPrivacyDefaults200JSONResponse(privacyToAPI(p)), nil
}

func (s *Server) PutPrivacyDefaults(ctx context.Context, request openapi.PutPrivacyDefaultsRequestObject) (openapi.PutPrivacyDefaultsResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("body required")
	}
	p, err := s.q.UpsertPrivacyDefaults(ctx, store.UpsertPrivacyDefaultsParams{
		UserID:            pgUUID(userID),
		ShareLiveStatus:   body.ShareLiveStatus,
		ShareUsageSummary: body.ShareUsageSummary,
		ShareUsageDetail:  body.ShareUsageDetail,
		ShareDeviceStats:  body.ShareDeviceStats,
		ShowInLeaderboard: body.ShowInLeaderboard,
	})
	if err != nil {
		return nil, err
	}
	return openapi.PutPrivacyDefaults200JSONResponse(privacyToAPI(p)), nil
}

// exportPuffs returns every puff of the user, oldest first, for the data export.
func (s *Server) exportPuffs(ctx context.Context, userID uuid.UUID) ([]openapi.Puff, error) {
	rows, err := s.pool.Query(ctx, `
SELECT id, user_id, device_id, client_event_id, started_at, duration_ms, source, received_at, raw
FROM puffs WHERE user_id = $1 ORDER BY started_at, id`, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	out := []openapi.Puff{}
	for rows.Next() {
		var p store.Puff
		if err := rows.Scan(&p.ID, &p.UserID, &p.DeviceID, &p.ClientEventID, &p.StartedAt, &p.DurationMs, &p.Source, &p.ReceivedAt, &p.Raw); err != nil {
			return nil, err
		}
		out = append(out, puffToAPI(p))
	}
	return out, rows.Err()
}
