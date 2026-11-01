package httpapi

import (
	"context"
	"net"
	"net/http"
	"net/netip"
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
	cfg          config.Config
	pool         *pgxpool.Pool
	q            *store.Queries
	auth         *auth.Service
	privacy      *privacy.Resolver
	live         *live.Hub
	loginIP      ratelimit.Limiter
	loginEmail   ratelimit.Limiter
	registerIP   ratelimit.Limiter
	refreshIP    ratelimit.Limiter
	passwordUser ratelimit.Limiter
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
		loginIP:      ratelimit.New(10, 10),
		loginEmail:   ratelimit.New(5, 5),
		registerIP:   ratelimit.New(5, 5),
		refreshIP:    ratelimit.New(30, 30),
		passwordUser: ratelimit.New(5, 5),
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
			ctx = withClientIP(ctx, clientIP(r, s.cfg.TrustedProxies))
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
			if operation == "GetGroupLive" {
				// The SSE stream is long-lived; lift the server-wide write timeout for it.
				_ = http.NewResponseController(w).SetWriteDeadline(time.Time{})
			}
			return next(ctx, w, r, request)
		}
	}
}

// clientIP returns the peer address, or, when the peer is a trusted proxy, the right-most
// X-Forwarded-For entry that is not itself a trusted proxy.
func clientIP(r *http.Request, trusted []netip.Prefix) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	peer, err := netip.ParseAddr(host)
	if err != nil {
		return host
	}
	peer = peer.Unmap()
	if !isTrusted(peer, trusted) {
		return peer.String()
	}
	hops := strings.Split(strings.Join(r.Header.Values("X-Forwarded-For"), ","), ",")
	for i := len(hops) - 1; i >= 0; i-- {
		addr, err := netip.ParseAddr(strings.TrimSpace(hops[i]))
		if err != nil {
			break
		}
		addr = addr.Unmap()
		if !isTrusted(addr, trusted) {
			return addr.String()
		}
		peer = addr
	}
	return peer.String()
}

func isTrusted(addr netip.Addr, trusted []netip.Prefix) bool {
	for _, p := range trusted {
		if p.Contains(addr) {
			return true
		}
	}
	return false
}

func validTimezone(tz string) bool {
	if tz == "" {
		return false
	}
	_, err := time.LoadLocation(tz)
	return err == nil
}

// inTx runs fn with queries bound to one transaction, committing only when fn succeeds.
func (s *Server) inTx(ctx context.Context, fn func(q *store.Queries) error) error {
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	if err := fn(s.q.WithTx(tx)); err != nil {
		return err
	}
	return tx.Commit(ctx)
}
