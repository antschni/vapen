package httpapi

import (
	"context"
	"net/http"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/antschni/vapen/api/internal/auth"
	"github.com/antschni/vapen/api/internal/config"
	"github.com/antschni/vapen/api/internal/live"
	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/privacy"
	"github.com/antschni/vapen/api/internal/ratelimit"
	"github.com/antschni/vapen/api/internal/store"
)

type Server struct {
	cfg      config.Config
	pool     *pgxpool.Pool
	q        *store.Queries
	auth     *auth.Service
	privacy  *privacy.Resolver
	live     *live.Hub
	loginIP  ratelimit.Limiter
	loginEmail ratelimit.Limiter
	refreshIP ratelimit.Limiter
	ingestDevice ratelimit.Limiter
}

func NewServer(cfg config.Config, pool *pgxpool.Pool, authSvc *auth.Service, hub *live.Hub) *Server {
	q := store.New(pool)
	return &Server{
		cfg:          cfg,
		pool:         pool,
		q:            q,
		auth:         authSvc,
		privacy:      privacy.New(q),
		live:         hub,
		loginIP:      ratelimit.New(5, 5),
		loginEmail:   ratelimit.New(5, 5),
		refreshIP:    ratelimit.New(30, 30),
		ingestDevice: ratelimit.New(120, 120),
	}
}

func (s *Server) StrictMiddleware() openapi.StrictMiddlewareFunc {
	public := map[string]bool{
		"AuthLogin": true, "AuthRegister": true, "AuthRefresh": true,
	}
	deviceOnly := map[string]bool{"IngestEvents": true}
	return func(next openapi.StrictHandlerFunc, operation string) openapi.StrictHandlerFunc {
		return func(ctx context.Context, w http.ResponseWriter, r *http.Request, request interface{}) (interface{}, error) {
			if public[operation] {
				return next(ctx, w, r, request)
			}
			h := r.Header.Get("Authorization")
			if !strings.HasPrefix(h, "Bearer ") {
				return nil, errUnauthorized("Missing bearer token")
			}
			tok := strings.TrimSpace(h[7:])
			if deviceOnly[operation] {
				if err := auth.ValidateDevicePrefix(tok); err != nil {
					return nil, errUnauthorized("Invalid device token")
				}
				row, err := s.q.GetDeviceTokenByHash(ctx, auth.HashOpaqueToken(tok))
				if err != nil {
					return nil, errUnauthorized("Invalid device token")
				}
				_ = s.q.TouchDeviceTokenLastUsed(ctx, row.ID)
				ctx = withAuth(ctx, authInfo{
					Kind:          authDevice,
					DeviceID:      uuidFromPG(row.DeviceID),
					DeviceTokenID: uuidFromPG(row.ID),
					UserID:        uuidFromPG(row.OwnerUserID),
				})
				return next(ctx, w, r, request)
			}
			if strings.HasPrefix(tok, "vpd_") {
				return nil, errUnauthorized("Device token not valid for this endpoint")
			}
			userID, sid, err := s.auth.JWT().Verify(tok)
			if err != nil {
				return nil, errUnauthorized("Invalid or expired access token")
			}
			if !s.auth.SessionActive(ctx, sid) {
				return nil, errUnauthorized("Session revoked")
			}
			ctx = withAuth(ctx, authInfo{Kind: authUser, UserID: userID, SessionID: sid})
			w.Header().Set("Cache-Control", "no-store")
			return next(ctx, w, r, request)
		}
	}
}

func clientIP(r *http.Request, trusted []string) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		parts := strings.Split(xff, ",")
		return strings.TrimSpace(parts[0])
	}
	host, _, _ := strings.Cut(r.RemoteAddr, ":")
	return host
}

func validTimezone(tz string) bool {
	if tz == "" {
		return false
	}
	_, err := time.LoadLocation(tz)
	return err == nil
}
