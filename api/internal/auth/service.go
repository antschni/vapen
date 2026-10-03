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
	u, err := s.q.CreateUser(ctx, store.CreateUserParams{
		ID:           pgUUID(userID),
		Email:        email,
		DisplayName:  displayName,
		Timezone:     timezone,
		PasswordHash: hash,
	})
	if err != nil {
		return TokenPair{}, nil, err
	}
	_, _ = s.q.UpsertPrivacyDefaults(ctx, store.UpsertPrivacyDefaultsParams{
		UserID:            pgUUID(userID),
		ShareLiveStatus:   true,
		ShareUsageSummary: true,
		ShareUsageDetail:  false,
		ShareDeviceStats:  false,
		ShowInLeaderboard: true,
	})
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

func (s *Service) Refresh(ctx context.Context, refreshToken string) (TokenPair, error) {
	if err := ValidateRefreshPrefix(refreshToken); err != nil {
		return TokenPair{}, ErrInvalidCredentials
	}
	hash := HashOpaqueToken(refreshToken)
	rt, err := s.q.GetRefreshTokenByHash(ctx, hash)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			gr, err2 := s.q.GetRefreshTokenByGraceHash(ctx, hash)
			if err2 != nil {
				if errors.Is(err2, pgx.ErrNoRows) {
					return TokenPair{}, ErrInvalidCredentials
				}
				return TokenPair{}, err2
			}
			return s.rotateFromToken(ctx, gr, hash)
		}
		return TokenPair{}, err
	}
	if rt.ExpiresAt.Time.Before(time.Now()) {
		return TokenPair{}, ErrInvalidCredentials
	}
	sess, err := s.q.GetSession(ctx, rt.SessionID)
	if err != nil || sess.RevokedAt.Valid {
		return TokenPair{}, ErrInvalidCredentials
	}
	return s.rotateFromToken(ctx, rt, hash)
}

func (s *Service) rotateFromToken(ctx context.Context, rt store.RefreshToken, presentedHash []byte) (TokenPair, error) {
	if rt.RotatedAt.Valid {
		if rt.GraceExpiresAt.Valid && rt.GraceExpiresAt.Time.After(time.Now()) &&
			len(rt.GraceTokenHash) > 0 && equalBytes(rt.GraceTokenHash, presentedHash) {
			sess, err := s.q.GetSession(ctx, rt.SessionID)
			if err != nil || sess.RevokedAt.Valid {
				return TokenPair{}, ErrInvalidCredentials
			}
			return s.issueTokens(ctx, uuidFromPG(sess.UserID), uuidFromPG(rt.SessionID))
		}
		_ = s.q.RevokeSessionRefreshTokens(ctx, rt.SessionID)
		_ = s.q.RevokeSession(ctx, rt.SessionID)
		return TokenPair{}, ErrTokenReuse
	}
	sess, err := s.q.GetSession(ctx, rt.SessionID)
	if err != nil || sess.RevokedAt.Valid {
		return TokenPair{}, ErrInvalidCredentials
	}
	userID := uuidFromPG(sess.UserID)
	sid := uuidFromPG(rt.SessionID)
	access, exp, err := s.jwt.Issue(userID, sid)
	if err != nil {
		return TokenPair{}, err
	}
	newPlain, newHash, err := NewRefreshToken()
	if err != nil {
		return TokenPair{}, err
	}
	rtExp := time.Now().UTC().Add(s.cfg.RefreshTokenTTL)
	graceUntil := time.Now().UTC().Add(s.cfg.RefreshGracePeriod)
	_, err = s.q.RotateRefreshToken(ctx, store.RotateRefreshTokenParams{
		ID:             rt.ID,
		TokenHash:      newHash,
		ExpiresAt:      pgTime(rtExp),
		GraceTokenHash: presentedHash,
		GraceExpiresAt: pgTime(graceUntil),
	})
	if err != nil {
		return TokenPair{}, err
	}
	return TokenPair{
		AccessToken:           access,
		AccessTokenExpiresAt:  exp,
		RefreshToken:          newPlain,
		RefreshTokenExpiresAt: rtExp,
		SessionID:             sid,
		UserID:                userID,
	}, nil
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

func equalBytes(a, b []byte) bool {
	if len(a) != len(b) {
		return false
	}
	for i := range a {
		if a[i] != b[i] {
			return false
		}
	}
	return true
}
