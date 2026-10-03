package privacy

import (
	"context"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/antschni/vapen/api/internal/store"
)

type Capability string

const (
	ShareLiveStatus   Capability = "share_live_status"
	ShareUsageSummary Capability = "share_usage_summary"
	ShareUsageDetail  Capability = "share_usage_detail"
	ShareDeviceStats  Capability = "share_device_stats"
	ShowInLeaderboard Capability = "show_in_leaderboard"
)

type Resolver struct {
	q *store.Queries
}

func New(q *store.Queries) *Resolver {
	return &Resolver{q: q}
}

func (r *Resolver) CanView(ctx context.Context, viewerID, targetID uuid.UUID, groupID *uuid.UUID, cap Capability) (bool, error) {
	if viewerID == targetID {
		return true, nil
	}
	var gid pgtype.UUID
	if groupID != nil {
		gid = pgUUID(*groupID)
	}
	ok, err := r.q.CanViewCapability(ctx, store.CanViewCapabilityParams{
		TargetUserID: pgUUID(targetID),
		ViewerUserID: pgUUID(viewerID),
		GroupID:      gid,
		Capability:   string(cap),
	})
	return ok, err
}

func pgUUID(id uuid.UUID) pgtype.UUID {
	var u pgtype.UUID
	_ = u.Scan(id.String())
	return u
}
