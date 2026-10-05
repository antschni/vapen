package stats

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/antschni/vapen/api/internal/openapi"
)

func Usage(ctx context.Context, pool *pgxpool.Pool, userID uuid.UUID, deviceID *uuid.UUID, from, to time.Time, bucket string, tz string) (openapi.UsageStats, error) {
	bucket = normalizeBucket(bucket)
	device := nullableDevice(deviceID)

	totals, err := scanTotals(ctx, pool, `
SELECT
  count(*)::int,
  coalesce(sum(duration_ms),0)::bigint,
  coalesce(avg(duration_ms),0)::int,
  coalesce(max(duration_ms),0)::int,
  count(distinct (started_at AT TIME ZONE $4)::date)::int
FROM puffs
WHERE user_id = $1
  AND started_at >= $2
  AND started_at < $3
  AND ($5::uuid IS NULL OR device_id = $5)`, userID, from, to, tz, device)
	if err != nil {
		return openapi.UsageStats{}, err
	}

	span := to.Sub(from)
	prevFrom := from.Add(-span)
	prev, err := scanPeriod(ctx, pool, userID, device, prevFrom, from)
	if err != nil {
		return openapi.UsageStats{}, err
	}

	series, err := loadSeries(ctx, pool, userID, device, from, to, tz, bucket)
	if err != nil {
		return openapi.UsageStats{}, err
	}
	heatmap, err := loadHeatmap(ctx, pool, userID, device, from, to, tz)
	if err != nil {
		return openapi.UsageStats{}, err
	}

	var devID *openapi_types.UUID
	if deviceID != nil {
		devID = (*openapi_types.UUID)(deviceID)
	}
	return openapi.UsageStats{
		UserId:         openapi_types.UUID(userID),
		DeviceId:       devID,
		From:           from.UTC(),
		To:             to.UTC(),
		Bucket:         openapi.UsageBucket(bucket),
		Tz:             tz,
		Totals:         totals,
		PreviousPeriod: prev,
		Series:         series,
		Heatmap:        heatmap,
	}, nil
}

func TotalsByUser(ctx context.Context, pool *pgxpool.Pool, userIDs []uuid.UUID, from, to time.Time, tz string) (map[uuid.UUID]openapi.UsageTotals, error) {
	out := make(map[uuid.UUID]openapi.UsageTotals, len(userIDs))
	for _, id := range userIDs {
		totals, err := scanTotals(ctx, pool, `
SELECT
  count(*)::int,
  coalesce(sum(duration_ms),0)::bigint,
  coalesce(avg(duration_ms),0)::int,
  coalesce(max(duration_ms),0)::int,
  count(distinct (started_at AT TIME ZONE $4)::date)::int
FROM puffs
WHERE user_id = $1
  AND started_at >= $2
  AND started_at < $3`, id, from, to, tz)
		if err != nil {
			return nil, err
		}
		out[id] = totals
	}
	return out, nil
}

func normalizeBucket(bucket string) string {
	switch bucket {
	case "hour", "day", "week", "month":
		return bucket
	default:
		return "day"
	}
}

func nullableDevice(deviceID *uuid.UUID) pgtype.UUID {
	if deviceID == nil {
		return pgtype.UUID{}
	}
	return pgtype.UUID{Bytes: *deviceID, Valid: true}
}

func scanTotals(ctx context.Context, pool *pgxpool.Pool, query string, args ...any) (openapi.UsageTotals, error) {
	var totals openapi.UsageTotals
	var sum int64
	err := pool.QueryRow(ctx, query, args...).Scan(
		&totals.PuffCount, &sum, &totals.AvgDurationMs, &totals.MaxDurationMs, &totals.ActiveDays,
	)
	if err != nil {
		return openapi.UsageTotals{}, err
	}
	totals.TotalDurationMs = int(sum)
	return totals, nil
}

func scanPeriod(ctx context.Context, pool *pgxpool.Pool, userID uuid.UUID, device pgtype.UUID, from, to time.Time) (openapi.UsagePeriodTotals, error) {
	var prev openapi.UsagePeriodTotals
	var sum int64
	err := pool.QueryRow(ctx, `
SELECT count(*)::int, coalesce(sum(duration_ms),0)::bigint
FROM puffs
WHERE user_id = $1
  AND started_at >= $2
  AND started_at < $3
  AND ($4::uuid IS NULL OR device_id = $4)`, userID, from, to, device).Scan(&prev.PuffCount, &sum)
	if err != nil {
		return openapi.UsagePeriodTotals{}, err
	}
	prev.TotalDurationMs = int(sum)
	return prev, nil
}

func loadSeries(ctx context.Context, pool *pgxpool.Pool, userID uuid.UUID, device pgtype.UUID, from, to time.Time, tz, bucket string) ([]openapi.UsageSeriesPoint, error) {
	bucket = normalizeBucket(bucket)
	rows, err := pool.Query(ctx, fmt.Sprintf(`
SELECT
  (date_trunc('%s', started_at AT TIME ZONE $4) AT TIME ZONE $4),
  count(*)::int,
  coalesce(sum(duration_ms),0)::bigint,
  coalesce(avg(duration_ms),0)::int,
  coalesce(max(duration_ms),0)::int
FROM puffs
WHERE user_id = $1
  AND started_at >= $2
  AND started_at < $3
  AND ($5::uuid IS NULL OR device_id = $5)
GROUP BY 1
ORDER BY 1`, bucket), userID, from, to, tz, device)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	series := []openapi.UsageSeriesPoint{}
	for rows.Next() {
		var point openapi.UsageSeriesPoint
		var sum int64
		if err := rows.Scan(&point.BucketStart, &point.PuffCount, &sum, &point.AvgDurationMs, &point.MaxDurationMs); err != nil {
			return nil, err
		}
		point.BucketStart = point.BucketStart.UTC()
		point.TotalDurationMs = int(sum)
		series = append(series, point)
	}
	return series, rows.Err()
}

func loadHeatmap(ctx context.Context, pool *pgxpool.Pool, userID uuid.UUID, device pgtype.UUID, from, to time.Time, tz string) ([]openapi.HeatmapPoint, error) {
	rows, err := pool.Query(ctx, `
SELECT
  EXTRACT(ISODOW FROM started_at AT TIME ZONE $4)::int,
  EXTRACT(HOUR FROM started_at AT TIME ZONE $4)::int,
  count(*)::int,
  coalesce(sum(duration_ms),0)::bigint
FROM puffs
WHERE user_id = $1
  AND started_at >= $2
  AND started_at < $3
  AND ($5::uuid IS NULL OR device_id = $5)
GROUP BY 1, 2
ORDER BY 1, 2`, userID, from, to, tz, device)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	heatmap := []openapi.HeatmapPoint{}
	for rows.Next() {
		var point openapi.HeatmapPoint
		var sum int64
		if err := rows.Scan(&point.IsoWeekday, &point.Hour, &point.PuffCount, &sum); err != nil {
			return nil, err
		}
		point.TotalDurationMs = int(sum)
		heatmap = append(heatmap, point)
	}
	return heatmap, rows.Err()
}
