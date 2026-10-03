package httpapi

import (
	"encoding/json"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"

	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/antschni/vapen/api/internal/auth"
	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/store"
)

func userToAPI(u store.User) openapi.User {
	return openapi.User{
		Id:          openapi_types.UUID(uuidFromPG(u.ID)),
		Email:       openapi_types.Email(u.Email),
		DisplayName: u.DisplayName,
		Timezone:    u.Timezone,
		CreatedAt:   u.CreatedAt.Time.UTC(),
	}
}

func deviceToAPI(d store.Device) openapi.Device {
	dev := openapi.Device{
		Id:         openapi_types.UUID(uuidFromPG(d.ID)),
		UserId:     openapi_types.UUID(uuidFromPG(d.UserID)),
		Model:      openapi.DeviceModel(d.Model),
		Name:       d.Name,
		HardwareId: d.HardwareID,
		CreatedAt:  d.CreatedAt.Time.UTC(),
	}
	if d.FirmwareVersion.Valid {
		dev.FirmwareVersion = &d.FirmwareVersion.String
	}
	if d.LastSeenAt.Valid {
		t := d.LastSeenAt.Time.UTC()
		dev.LastSeenAt = &t
	}
	if len(d.LatestStatus) > 0 {
		var st openapi.DeviceStatus
		if err := json.Unmarshal(d.LatestStatus, &st); err == nil {
			dev.LatestStatus = &st
		}
	}
	return dev
}

func privacyToAPI(p store.PrivacyDefault) openapi.PrivacySettings {
	return openapi.PrivacySettings{
		ShareLiveStatus:   p.ShareLiveStatus,
		ShareUsageSummary: p.ShareUsageSummary,
		ShareUsageDetail:  p.ShareUsageDetail,
		ShareDeviceStats:  p.ShareDeviceStats,
		ShowInLeaderboard: p.ShowInLeaderboard,
	}
}

func tokenPairToAPI(pair auth.TokenPair, user openapi.User) openapi.TokenPair {
	return openapi.TokenPair{
		AccessToken:          pair.AccessToken,
		AccessTokenExpiresAt: pair.AccessTokenExpiresAt.UTC(),
		RefreshToken:         pair.RefreshToken,
		RefreshTokenExpiresAt: pair.RefreshTokenExpiresAt.UTC(),
		User:                 user,
	}
}

func uuidFromPG(u pgtype.UUID) uuid.UUID {
	id, _ := uuid.Parse(u.String())
	return id
}

func pgUUID(id uuid.UUID) pgtype.UUID {
	var u pgtype.UUID
	_ = u.Scan(id.String())
	return u
}

func pgTime(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t.UTC(), Valid: true}
}

func pgText(s string) pgtype.Text {
	return pgtype.Text{String: s, Valid: true}
}

func pgTextPtr(s *string) pgtype.Text {
	if s == nil {
		return pgtype.Text{}
	}
	return pgtype.Text{String: *s, Valid: true}
}

func pgBoolPtr(b *bool) pgtype.Bool {
	if b == nil {
		return pgtype.Bool{}
	}
	return pgtype.Bool{Bool: *b, Valid: true}
}
