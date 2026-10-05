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

	"github.com/antschni/vapen/api/internal/live"
	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/store"
)

func (s *Server) IngestEvents(ctx context.Context, request openapi.IngestEventsRequestObject) (openapi.IngestEventsResponseObject, error) {
	a, ok := authFrom(ctx)
	if !ok || a.Kind != authDevice {
		return nil, errUnauthorized("device token required")
	}
	if !s.ingestDevice.Allow(a.DeviceID.String()) {
		return nil, errRateLimited()
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("body required")
	}
	if uuid.UUID(body.DeviceId) != a.DeviceID {
		return nil, errForbidden()
	}
	now := time.Now().UTC()
	maxFuture := now.Add(5 * time.Minute)
	var accepted, duplicates int
	rejected := []openapi.IngestRejectedEvent{}
	for _, rawEv := range body.Events {
		disc, err := rawEv.Discriminator()
		if err != nil {
			continue
		}
		switch disc {
		case "puff_started":
			ev, err := rawEv.AsIngestPuffStartedEvent()
			if err != nil {
				continue
			}
			occ := ev.OccurredAt.UTC()
			if occ.Before(now.Add(-30 * time.Second)) {
				continue
			}
			if occ.After(maxFuture) {
				rejected = append(rejected, rejEvent(ev.ClientEventId, "occurred_at too far in future"))
				continue
			}
			_ = s.q.UpdateDeviceLiveState(ctx, store.UpdateDeviceLiveStateParams{
				ID:          pgUUID(a.DeviceID),
				VapingSince: pgTime(occ),
			})
			s.notifyLive(ctx, a.UserID, a.DeviceID, "puff_started")
			accepted++
		case "puff":
			ev, err := rawEv.AsIngestPuffEvent()
			if err != nil {
				continue
			}
			if ev.DurationMs < 1 || ev.DurationMs > 60000 {
				rejected = append(rejected, rejEvent(ev.ClientEventId, "duration_ms out of range"))
				continue
			}
			started := ev.StartedAt.UTC()
			if started.After(maxFuture) {
				rejected = append(rejected, rejEvent(ev.ClientEventId, "started_at too far in future"))
				continue
			}
			var raw []byte
			if ev.Raw != nil {
				raw, _ = json.Marshal(ev.Raw)
			}
			_, err = s.q.InsertPuff(ctx, store.InsertPuffParams{
				ID:            pgUUID(uuid.Must(uuid.NewV7())),
				UserID:        pgUUID(a.UserID),
				DeviceID:      pgUUID(a.DeviceID),
				ClientEventID: pgUUID(uuid.UUID(ev.ClientEventId)),
				StartedAt:     pgTime(started),
				DurationMs:    int32(ev.DurationMs),
				Source:        string(ev.Source),
				Raw:           raw,
			})
			if errors.Is(err, pgx.ErrNoRows) {
				duplicates++
				continue
			}
			if err != nil {
				return nil, err
			}
			accepted++
			clearVS := pgtype.Timestamptz{}
			_ = s.q.UpdateDeviceLiveState(ctx, store.UpdateDeviceLiveStateParams{
				ID:          pgUUID(a.DeviceID),
				LastPuffAt:  pgTime(started),
				LastSeenAt:  pgTime(now),
				VapingSince: clearVS,
			})
			s.notifyLive(ctx, a.UserID, a.DeviceID, "puff")
		case "status":
			ev, err := rawEv.AsIngestStatusEvent()
			if err != nil {
				continue
			}
			rec := ev.RecordedAt.UTC()
			if rec.After(maxFuture) {
				rejected = append(rejected, rejEvent(ev.ClientEventId, "recorded_at too far in future"))
				continue
			}
			st := map[string]interface{}{"recorded_at": rec.Format(time.RFC3339Nano)}
			if ev.BleConnected != nil {
				st["ble_connected"] = *ev.BleConnected
			}
			if ev.BatteryPercent != nil {
				st["battery_percent"] = *ev.BatteryPercent
			}
			if ev.IsCharging != nil {
				st["is_charging"] = *ev.IsCharging
			}
			if ev.LiquidPercent != nil {
				st["liquid_percent"] = *ev.LiquidPercent
			}
			if ev.PuffCounterTotal != nil {
				st["puff_counter_total"] = *ev.PuffCounterTotal
			}
			if ev.PowerMode != nil {
				st["power_mode"] = *ev.PowerMode
			}
			if ev.ChildLock != nil {
				st["child_lock"] = *ev.ChildLock
			}
			if ev.FirmwareVersion != nil {
				st["firmware_version"] = *ev.FirmwareVersion
			}
			statusJSON, _ := json.Marshal(st)
			_, err = s.q.InsertStatusSnapshot(ctx, store.InsertStatusSnapshotParams{
				ID:            pgUUID(uuid.Must(uuid.NewV7())),
				DeviceID:      pgUUID(a.DeviceID),
				UserID:        pgUUID(a.UserID),
				ClientEventID: pgUUID(uuid.UUID(ev.ClientEventId)),
				RecordedAt:    pgTime(rec),
				Status:        statusJSON,
			})
			if errors.Is(err, pgx.ErrNoRows) {
				duplicates++
				continue
			}
			if err != nil {
				return nil, err
			}
			accepted++
			_ = s.q.UpdateDeviceLiveState(ctx, store.UpdateDeviceLiveStateParams{
				ID:           pgUUID(a.DeviceID),
				LastSeenAt:   pgTime(now),
				LatestStatus: statusJSON,
			})
		default:
			rejected = append(rejected, rejEvent(openapi_types.UUID(uuid.Nil), "unknown event type"))
		}
	}
	return openapi.IngestEvents200JSONResponse(openapi.IngestResponse{
		Accepted:   accepted,
		Duplicates: duplicates,
		Rejected:   rejected,
	}), nil
}

func rejEvent(id openapi_types.UUID, msg string) openapi.IngestRejectedEvent {
	return openapi.IngestRejectedEvent{
		ClientEventId: id,
		Code:          "validation_failed",
		Message:       msg,
	}
}

func (s *Server) notifyLive(ctx context.Context, userID, deviceID uuid.UUID, kind string) {
	rows, err := s.pool.Query(ctx, `SELECT group_id FROM group_members WHERE user_id = $1`, userID)
	if err != nil {
		return
	}
	defer rows.Close()
	for rows.Next() {
		var gid uuid.UUID
		if err := rows.Scan(&gid); err != nil {
			continue
		}
		_ = live.Notify(ctx, s.pool, live.Event{GroupID: gid, UserID: userID, DeviceID: deviceID, Kind: kind})
	}
}
