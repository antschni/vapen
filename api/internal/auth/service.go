package auth

import (
	"context"
	"errors"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/antschni/vapen/api/internal/config"
	"github.com/antschni/vapen/api/internal/store"
)

var (
	ErrInvalidCredentials = errors.New("invalid credentials")
	ErrTokenReuse         = errors.New("token reuse")
	ErrSessionRevoked     = errors.New("session revoked")
)

type Service struct {
	cfg  config.Config
	pool *pgxpool.Pool
	q    *store.Queries
	jwt  *JWT
}

func NewService(cfg config.Config, pool *pgxpool.Pool, q *store.Queries) (*Service, error) {
	jwt, err := NewJWT(cfg.JWTPrivateKey, cfg.AccessTokenTTL)
	if err != nil {
		return nil, err
	}
	return &Service{cfg: cfg, pool: pool, q: q, jwt: jwt}, nil
}

type TokenPair struct {
	AccessToken           string
	AccessTokenExpiresAt  time.Time
	RefreshToken          string
	RefreshTokenExpiresAt time.Time
	SessionID             uuid.UUID
	UserID                uuid.UUID
}

func (s *Service) JWT() *JWT { return s.jwt }

func (s *Service) Register(ctx context.Context, email, password, displayName, timezone string) (TokenPair, *store.User, error) {
	hash := HashPassword(password)
	userID := uuid.Must(uuid.NewV7())
	tx, err := s.pool.Begin(ctx)
	if err != nil {
		return TokenPair{}, nil, err
	}
	defer func() { _ = tx.Rollback(ctx) }()
	qtx := s.q.WithTx(tx)
	u, err := qtx.CreateUser(ctx, store.CreateUserParams{
		ID:           pgUUID(userID),
		Email:        email,
		DisplayName:  displayName,
		Timezone:     timezone,
		PasswordHash: hash,
	})
	if err != nil {
		return TokenPair{}, nil, err
	}
	_, err = qtx.UpsertPrivacyDefaults(ctx, store.UpsertPrivacyDefaultsParams{
		UserID:            pgUUID(userID),
		ShareLiveStatus:   true,
		ShareUsageSummary: true,
		ShareUsageDetail:  false,
		ShareDeviceStats:  false,
		ShowInLeaderboard: true,
	})
	if err != nil {
		return TokenPair{}, nil, err
	}
	if err := tx.Commit(ctx); err != nil {
		return TokenPair{}, nil, err
	}
	pair, err := s.createSession(ctx, userID)
	return pair, &u, err
}

func (s *Service) Login(ctx context.Context, email, password string) (TokenPair, error) {
	u, err := s.q.GetUserByEmailLower(ctx, email)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			TimingSafeDummyVerify()
			return TokenPair{}, ErrInvalidCredentials
		}
		return TokenPair{}, err
	}
	if !VerifyPassword(u.PasswordHash, password) {
		return TokenPair{}, ErrInvalidCredentials
	}
	pair, err := s.createSession(ctx, uuidFromPG(u.ID))
	return pair, err
}

func (s *Service) createSession(ctx context.Context, userID uuid.UUID) (TokenPair, error) {
	sid := uuid.Must(uuid.NewV7())
	_, err := s.q.CreateSession(ctx, store.CreateSessionParams{
		ID:     pgUUID(sid),
		UserID: pgUUID(userID),
	})
	if err != nil {
		return TokenPair{}, err
	}
	return s.issueTokens(ctx, userID, sid)
}

func (s *Service) issueTokens(ctx context.Context, userID, sid uuid.UUID) (TokenPair, error) {
	access, exp, err := s.jwt.Issue(userID, sid)
	if err != nil {
		return TokenPair{}, err
	}
	plain, hash, err := NewRefreshToken()
	if err != nil {
		return TokenPair{}, err
	}
	rtExp := time.Now().UTC().Add(s.cfg.RefreshTokenTTL)
	_, err = s.q.CreateRefreshToken(ctx, store.CreateRefreshTokenParams{
		ID:        pgUUID(uuid.Must(uuid.NewV7())),
		SessionID: pgUUID(sid),
		TokenHash: hash,
		ExpiresAt: pgTime(rtExp),
	})
	if err != nil {
		return TokenPair{}, err
	}
	return TokenPair{
		AccessToken:           access,
		AccessTokenExpiresAt:  exp,
		RefreshToken:          plain,
		RefreshTokenExpiresAt: rtExp,
		SessionID:             sid,
		UserID:                userID,
	}, nil
}

// Refresh rotates a refresh token. Each issued token is its own row: rotation marks the presented
// row as rotated and inserts a fresh one. A rotated token presented again within the grace period
// (concurrent requests, lost response) gets a new pair; after that it counts as reuse and the whole
// session is revoked.
func (s *Service) Refresh(ctx context.Context, refreshToken string) (TokenPair, error) {
	if err := ValidateRefreshPrefix(refreshToken); err != nil {
		return TokenPair{}, ErrInvalidCredentials
	}
	rt, err := s.q.GetRefreshTokenByHash(ctx, HashOpaqueToken(refreshToken))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return TokenPair{}, ErrInvalidCredentials
		}
		return TokenPair{}, err
	}
	now := time.Now()
	if rt.ExpiresAt.Time.Before(now) {
		return TokenPair{}, ErrInvalidCredentials
	}
	sess, err := s.q.GetSession(ctx, rt.SessionID)
	if err != nil || sess.RevokedAt.Valid {
		return TokenPair{}, ErrInvalidCredentials
	}
	if !rt.RotatedAt.Valid {
		_, err = s.q.MarkRefreshTokenRotated(ctx, store.MarkRefreshTokenRotatedParams{
			ID:             rt.ID,
			GraceExpiresAt: pgTime(now.UTC().Add(s.cfg.RefreshGracePeriod)),
		})
		if err == nil {
			return s.issueTokens(ctx, uuidFromPG(sess.UserID), uuidFromPG(rt.SessionID))
		}
		if !errors.Is(err, pgx.ErrNoRows) {
			return TokenPair{}, err
		}
		// A concurrent request rotated this token first; fall through to the grace check.
		if rt, err = s.q.GetRefreshTokenByHash(ctx, rt.TokenHash); err != nil {
			return TokenPair{}, ErrInvalidCredentials
		}
	}
	if rt.GraceExpiresAt.Valid && rt.GraceExpiresAt.Time.After(now) {
		return s.issueTokens(ctx, uuidFromPG(sess.UserID), uuidFromPG(rt.SessionID))
	}
	_ = s.q.RevokeSessionRefreshTokens(ctx, rt.SessionID)
	_ = s.q.RevokeSession(ctx, rt.SessionID)
	return TokenPair{}, ErrTokenReuse
}

func (s *Service) Logout(ctx context.Context, sessionID uuid.UUID) error {
	_ = s.q.RevokeSessionRefreshTokens(ctx, pgUUID(sessionID))
	return s.q.RevokeSession(ctx, pgUUID(sessionID))
}

func (s *Service) RevokeOtherSessions(ctx context.Context, userID, keepSession uuid.UUID) error {
	return s.q.RevokeOtherSessions(ctx, store.RevokeOtherSessionsParams{
		UserID:  pgUUID(userID),
		ID:      pgUUID(keepSession),
	})
}

func (s *Service) SessionActive(ctx context.Context, sessionID uuid.UUID) bool {
	sess, err := s.q.GetSession(ctx, pgUUID(sessionID))
	if err != nil || sess.RevokedAt.Valid {
		return false
	}
	return true
}

func pgUUID(id uuid.UUID) pgtype.UUID {
	var u pgtype.UUID
	_ = u.Scan(id.String())
	return u
}

func pgTime(t time.Time) pgtype.Timestamptz {
	return pgtype.Timestamptz{Time: t, Valid: true}
}

func uuidFromPG(u pgtype.UUID) uuid.UUID {
	id, _ := uuid.Parse(u.String())
	return id
}
