package stats

import (
	"context"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/antschni/vapen/api/internal/openapi"
)

func Usage(ctx context.Context, pool *pgxpool.Pool, userID uuid.UUID, deviceID *uuid.UUID, from, to time.Time, bucket string, tz string) (openapi.UsageStats, error) {
	loc, _ := time.LoadLocation(tz)
	if loc == nil {
		loc = time.UTC
	}
	var deviceFilter string
	args := []interface{}{userID, from, to}
	if deviceID != nil {
		deviceFilter = " AND device_id = $4"
		args = append(args, *deviceID)
	}
	q := `
SELECT
  count(*)::int,
  coalesce(sum(duration_ms),0)::bigint,
  coalesce(avg(duration_ms),0)::int,
  coalesce(max(duration_ms),0)::int,
  count(distinct (started_at AT TIME ZONE $5)::date)::int
FROM puffs
WHERE user_id = $1 AND started_at >= $2 AND started_at < $3` + deviceFilter
	args = append(args, tz)
	var totals openapi.UsageTotals
	err := pool.QueryRow(ctx, q, args...).Scan(
		&totals.PuffCount, &totals.TotalDurationMs, &totals.AvgDurationMs, &totals.MaxDurationMs, &totals.ActiveDays,
	)
	if err != nil {
		return openapi.UsageStats{}, err
	}
	span := to.Sub(from)
	prevFrom := from.Add(-span)
	prevTo := from
	var prev openapi.UsagePeriodTotals
	_ = pool.QueryRow(ctx, `
SELECT count(*)::int, coalesce(sum(duration_ms),0)::bigint FROM puffs
WHERE user_id = $1 AND started_at >= $2 AND started_at < $3`, userID, prevFrom, prevTo).Scan(&prev.PuffCount, &prev.TotalDurationMs)

	series := []openapi.UsageSeriesPoint{}
	heatmap := []openapi.HeatmapPoint{}

	var devID *openapi_types.UUID
	if deviceID != nil {
		devID = (*openapi_types.UUID)(deviceID)
	}
	return openapi.UsageStats{
		UserId:   openapi_types.UUID(userID),
		DeviceId: devID,
		From:     from.UTC(),
		To:       to.UTC(),
		Bucket:   openapi.UsageBucket(bucket),
		Tz:       tz,
		Totals:   totals,
		PreviousPeriod: prev,
		Series:   series,
		Heatmap:  heatmap,
	}, nil
}
