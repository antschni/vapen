package auth

import (
	"crypto/ed25519"
	"fmt"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
)

const issuer = "vapen"
const audience = "vapen-api"

type AccessClaims struct {
	jwt.RegisteredClaims
	SID string `json:"sid"`
}

type JWT struct {
	priv ed25519.PrivateKey
	pub  ed25519.PublicKey
	ttl  time.Duration
}

func NewJWT(seed []byte, ttl time.Duration) (*JWT, error) {
	if len(seed) != 64 {
		return nil, fmt.Errorf("ed25519 seed must be 64 bytes")
	}
	priv := ed25519.PrivateKey(seed)
	pub := priv.Public().(ed25519.PublicKey)
	return &JWT{priv: priv, pub: pub, ttl: ttl}, nil
}

func (j *JWT) Issue(userID, sessionID uuid.UUID) (string, time.Time, error) {
	now := time.Now().UTC()
	exp := now.Add(j.ttl)
	claims := AccessClaims{
		SID: sessionID.String(),
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID.String(),
			IssuedAt:  jwt.NewNumericDate(now),
			ExpiresAt: jwt.NewNumericDate(exp),
			Issuer:    issuer,
			Audience:  jwt.ClaimStrings{audience},
		},
	}
	tok := jwt.NewWithClaims(jwt.SigningMethodEdDSA, claims)
	signed, err := tok.SignedString(j.priv)
	if err != nil {
		return "", time.Time{}, err
	}
	return signed, exp, nil
}

func (j *JWT) Verify(token string) (userID uuid.UUID, sessionID uuid.UUID, err error) {
	parsed, err := jwt.ParseWithClaims(token, &AccessClaims{}, func(t *jwt.Token) (interface{}, error) {
		if t.Method.Alg() != jwt.SigningMethodEdDSA.Alg() {
			return nil, fmt.Errorf("unexpected alg")
		}
		return j.pub, nil
	}, jwt.WithIssuer(issuer), jwt.WithAudience(audience))
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	claims, ok := parsed.Claims.(*AccessClaims)
	if !ok || !parsed.Valid {
		return uuid.Nil, uuid.Nil, fmt.Errorf("invalid token")
	}
	userID, err = uuid.Parse(claims.Subject)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	sessionID, err = uuid.Parse(claims.SID)
	if err != nil {
		return uuid.Nil, uuid.Nil, err
	}
	return userID, sessionID, nil
}
