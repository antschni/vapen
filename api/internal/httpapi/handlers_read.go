package httpapi

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/privacy"
	"github.com/antschni/vapen/api/internal/stats"
	"github.com/antschni/vapen/api/internal/store"
)

func (s *Server) ListPuffs(ctx context.Context, request openapi.ListPuffsRequestObject) (openapi.ListPuffsResponseObject, error) {
	viewer, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	target := viewer
	if request.Params.UserId != nil {
		target = uuid.UUID(*request.Params.UserId)
	}
	if target != viewer {
		allowed, err := s.privacy.CanView(ctx, viewer, target, nil, privacy.ShareUsageDetail)
		if err != nil || !allowed {
			return nil, errNotFound()
		}
	}
	now := time.Now().UTC()
	from := now.Add(-24 * time.Hour)
	to := now
	if request.Params.From != nil {
		from = request.Params.From.UTC()
	}
	if request.Params.To != nil {
		to = request.Params.To.UTC()
	}
	limit := 100
	if request.Params.Limit != nil {
		limit = *request.Params.Limit
	}
	deviceID := pgtypeOptionalUUID(request.Params.DeviceId)
	rows, err := s.q.ListPuffs(ctx, store.ListPuffsParams{
		UserID:    pgUUID(target),
		StartedAt: pgTime(from),
		StartedAt_2: pgTime(to),
		DeviceID:  deviceID,
		Limit:     int32(limit),
	})
	if err != nil {
		return nil, err
	}
	items := make([]openapi.Puff, 0, len(rows))
	for _, p := range rows {
		items = append(items, puffToAPI(p))
	}
	var next *string
	if len(rows) == limit {
		last := rows[len(rows)-1]
		next = ptr(last.StartedAt.Time.UTC().Format(time.RFC3339Nano))
	}
	return openapi.ListPuffs200JSONResponse(openapi.PuffPage{Items: items, NextCursor: next}), nil
}

func pgtypeOptionalUUID(id *openapi_types.UUID) pgtype.UUID {
	if id == nil {
		return pgtype.UUID{Valid: false}
	}
	return pgUUID(uuid.UUID(*id))
}

func puffToAPI(p store.Puff) openapi.Puff {
	return openapi.Puff{
		Id:            openapi_types.UUID(uuidFromPG(p.ID)),
		UserId:        openapi_types.UUID(uuidFromPG(p.UserID)),
		DeviceId:      openapi_types.UUID(uuidFromPG(p.DeviceID)),
		ClientEventId: openapi_types.UUID(uuidFromPG(p.ClientEventID)),
		StartedAt:     p.StartedAt.Time.UTC(),
		DurationMs:    int(p.DurationMs),
		Source:        openapi.PuffSource(p.Source),
		ReceivedAt:    p.ReceivedAt.Time.UTC(),
	}
}

func (s *Server) GetUsageStats(ctx context.Context, request openapi.GetUsageStatsRequestObject) (openapi.GetUsageStatsResponseObject, error) {
	viewer, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	u, err := s.q.GetUserByID(ctx, pgUUID(viewer))
	if err != nil {
		return nil, err
	}
	target := viewer
	if request.Params.UserId != nil {
		target = uuid.UUID(*request.Params.UserId)
	}
	if target != viewer {
		allowed, err := s.privacy.CanView(ctx, viewer, target, nil, privacy.ShareUsageDetail)
		if err != nil || !allowed {
			return nil, errNotFound()
		}
	}
	tz := u.Timezone
	if request.Params.Tz != nil {
		tz = *request.Params.Tz
	}
	now := time.Now().UTC()
	from := startOfDay(now.AddDate(0, 0, -6), tz)
	to := now
	if request.Params.From != nil {
		from = request.Params.From.UTC()
	}
	if request.Params.To != nil {
		to = request.Params.To.UTC()
	}
	bucket := "day"
	if request.Params.Bucket != nil {
		bucket = string(*request.Params.Bucket)
	}
	var dev *uuid.UUID
	if request.Params.DeviceId != nil {
		dev = (*uuid.UUID)(request.Params.DeviceId)
	}
	st, err := stats.Usage(ctx, s.pool, target, dev, from, to, bucket, tz)
	if err != nil {
		return nil, err
	}
	return openapi.GetUsageStats200JSONResponse(st), nil
}

func (s *Server) GetDeviceStats(ctx context.Context, request openapi.GetDeviceStatsRequestObject) (openapi.GetDeviceStatsResponseObject, error) {
	viewer, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	devID := uuid.UUID(request.Id)
	d, err := s.q.GetDeviceByID(ctx, pgUUID(devID))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errNotFound()
		}
		return nil, err
	}
	owner := uuidFromPG(d.UserID)
	if owner != viewer {
		okView, err := s.privacy.CanView(ctx, viewer, owner, nil, privacy.ShareDeviceStats)
		if err != nil || !okView {
			return nil, errNotFound()
		}
	}
	tz := "UTC"
	if request.Params.Tz != nil {
		tz = *request.Params.Tz
	}
	now := time.Now().UTC()
	from := now.Add(-7 * 24 * time.Hour)
	to := now
	if request.Params.From != nil {
		from = request.Params.From.UTC()
	}
	if request.Params.To != nil {
		to = request.Params.To.UTC()
	}
	bucket := openapi.Hour
	if request.Params.Bucket != nil {
		bucket = *request.Params.Bucket
	}
	latest := openapi.DeviceStatus{}
	if len(d.LatestStatus) > 0 {
		_ = jsonUnmarshalStatus(d.LatestStatus, &latest)
	}
	resp := openapi.DeviceStats{}
	resp.Device.Id = openapi_types.UUID(devID)
	resp.Device.Model = openapi.DeviceModel(d.Model)
	resp.Device.Name = d.Name
	resp.From = from
	resp.To = to
	resp.Bucket = openapi.DeviceStatsBucket(bucket)
	resp.Tz = tz
	resp.LatestStatus = latest
	resp.BatterySeries = []openapi.BatterySeriesPoint{}
	resp.LiquidSeries = []openapi.LiquidSeriesPoint{}
	resp.PuffDuration = openapi.PuffDurationStats{Histogram: []openapi.HistogramBin{}}
	resp.PuffsSinceLastCharge = 0
	if d.LastSeenAt.Valid {
		resp.Device.LastSeenAt = &d.LastSeenAt.Time
	}
	return openapi.GetDeviceStats200JSONResponse(resp), nil
}

func startOfDay(t time.Time, tz string) time.Time {
	loc, err := time.LoadLocation(tz)
	if err != nil {
		loc = time.UTC
	}
	lt := t.In(loc)
	y, m, d := lt.Date()
	return time.Date(y, m, d, 0, 0, 0, 0, loc).UTC()
}

func jsonUnmarshalStatus(b []byte, st *openapi.DeviceStatus) error {
	return json.Unmarshal(b, st)
}
