package httpapi

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"github.com/antschni/vapen/api/internal/auth"
	openapi_types "github.com/oapi-codegen/runtime/types"

	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/store"
)

func (s *Server) ListDevices(ctx context.Context, _ openapi.ListDevicesRequestObject) (openapi.ListDevicesResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	devs, err := s.q.ListDevicesByUser(ctx, pgUUID(userID))
	if err != nil {
		return nil, err
	}
	out := make([]openapi.Device, 0, len(devs))
	for _, d := range devs {
		out = append(out, deviceToAPI(d))
	}
	return openapi.ListDevices200JSONResponse(out), nil
}

func (s *Server) CreateDevice(ctx context.Context, request openapi.CreateDeviceRequestObject) (openapi.CreateDeviceResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("body required")
	}
	existing, err := s.q.GetDeviceByUserHardware(ctx, store.GetDeviceByUserHardwareParams{
		UserID:     pgUUID(userID),
		HardwareID: body.HardwareId,
	})
	if err == nil {
		return openapi.CreateDevice200JSONResponse(deviceToAPI(existing)), nil
	}
	if !errors.Is(err, pgx.ErrNoRows) {
		return nil, err
	}
	id := uuid.Must(uuid.NewV7())
	d, err := s.q.CreateDevice(ctx, store.CreateDeviceParams{
		ID:              pgUUID(id),
		UserID:          pgUUID(userID),
		Model:           string(body.Model),
		Name:            body.Name,
		HardwareID:      body.HardwareId,
		FirmwareVersion: pgTextPtr(body.FirmwareVersion),
	})
	if err != nil {
		return nil, err
	}
	return openapi.CreateDevice201JSONResponse(deviceToAPI(d)), nil
}

func (s *Server) GetDevice(ctx context.Context, request openapi.GetDeviceRequestObject) (openapi.GetDeviceResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	d, err := s.q.GetDeviceByID(ctx, pgUUID(uuid.UUID(request.Id)))
	if err != nil || uuidFromPG(d.UserID) != userID {
		return nil, errNotFound()
	}
	return openapi.GetDevice200JSONResponse(deviceToAPI(d)), nil
}

func (s *Server) PatchDevice(ctx context.Context, request openapi.PatchDeviceRequestObject) (openapi.PatchDeviceResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("body required")
	}
	d, err := s.q.UpdateDeviceName(ctx, store.UpdateDeviceNameParams{
		ID:     pgUUID(uuid.UUID(request.Id)),
		Name:   body.Name,
		UserID: pgUUID(userID),
	})
	if err != nil {
		return nil, errNotFound()
	}
	return openapi.PatchDevice200JSONResponse(deviceToAPI(d)), nil
}

func (s *Server) DeleteDevice(ctx context.Context, request openapi.DeleteDeviceRequestObject) (openapi.DeleteDeviceResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	devID := pgUUID(uuid.UUID(request.Id))
	_ = s.q.RevokeAllDeviceTokens(ctx, devID)
	if err := s.q.DeleteDevice(ctx, store.DeleteDeviceParams{ID: devID, UserID: pgUUID(userID)}); err != nil {
		return nil, errNotFound()
	}
	return openapi.DeleteDevice204Response{}, nil
}

func (s *Server) ListIngestTokens(ctx context.Context, request openapi.ListIngestTokensRequestObject) (openapi.ListIngestTokensResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	dev, err := s.q.GetDeviceByID(ctx, pgUUID(uuid.UUID(request.Id)))
	if err != nil || uuidFromPG(dev.UserID) != userID {
		return nil, errNotFound()
	}
	tokens, err := s.q.ListDeviceTokens(ctx, dev.ID)
	if err != nil {
		return nil, err
	}
	out := make([]openapi.IngestTokenMeta, 0, len(tokens))
	for _, t := range tokens {
		meta := openapi.IngestTokenMeta{
			Id:        openapi_types.UUID(uuidFromPG(t.ID)),
			Name:      t.Name,
			CreatedAt: t.CreatedAt.Time.UTC(),
		}
		if t.LastUsedAt.Valid {
			meta.LastUsedAt = &t.LastUsedAt.Time
		}
		if t.RevokedAt.Valid {
			meta.RevokedAt = &t.RevokedAt.Time
		}
		out = append(out, meta)
	}
	return openapi.ListIngestTokens200JSONResponse(out), nil
}

func (s *Server) CreateIngestToken(ctx context.Context, request openapi.CreateIngestTokenRequestObject) (openapi.CreateIngestTokenResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	dev, err := s.q.GetDeviceByID(ctx, pgUUID(uuid.UUID(request.Id)))
	if err != nil || uuidFromPG(dev.UserID) != userID {
		return nil, errNotFound()
	}
	body := request.Body
	if body == nil {
		return nil, errValidation("name required")
	}
	plain, hash, err := auth.NewDeviceToken()
	if err != nil {
		return nil, err
	}
	tid := uuid.Must(uuid.NewV7())
	t, err := s.q.CreateDeviceToken(ctx, store.CreateDeviceTokenParams{
		ID:        pgUUID(tid),
		DeviceID:  dev.ID,
		Name:      body.Name,
		TokenHash: hash,
	})
	if err != nil {
		return nil, err
	}
	return openapi.CreateIngestToken201JSONResponse(openapi.IngestTokenCreated{
		Id:        openapi_types.UUID(tid),
		Name:      t.Name,
		Token:     plain,
		CreatedAt: t.CreatedAt.Time.UTC(),
	}), nil
}

func (s *Server) RevokeIngestToken(ctx context.Context, request openapi.RevokeIngestTokenRequestObject) (openapi.RevokeIngestTokenResponseObject, error) {
	userID, _, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	dev, err := s.q.GetDeviceByID(ctx, pgUUID(uuid.UUID(request.Id)))
	if err != nil || uuidFromPG(dev.UserID) != userID {
		return nil, errNotFound()
	}
	if err := s.q.RevokeDeviceToken(ctx, store.RevokeDeviceTokenParams{
		ID:       pgUUID(uuid.UUID(request.TokenId)),
		DeviceID: dev.ID,
	}); err != nil {
		return nil, errNotFound()
	}
	return openapi.RevokeIngestToken204Response{}, nil
}
