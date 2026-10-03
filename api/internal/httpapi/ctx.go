package httpapi

import (
	"context"

	"github.com/google/uuid"
)

type authKind int

const (
	authNone authKind = 0
	authUser authKind = 1
	authDevice authKind = 2
)

type authInfo struct {
	Kind     authKind
	UserID   uuid.UUID
	SessionID uuid.UUID
	DeviceID uuid.UUID
	DeviceTokenID uuid.UUID
}

type ctxKey struct{}

func withAuth(ctx context.Context, a authInfo) context.Context {
	return context.WithValue(ctx, ctxKey{}, a)
}

func authFrom(ctx context.Context) (authInfo, bool) {
	a, ok := ctx.Value(ctxKey{}).(authInfo)
	return a, ok
}

func mustUser(ctx context.Context) (uuid.UUID, uuid.UUID, bool) {
	a, ok := authFrom(ctx)
	if !ok || a.Kind != authUser {
		return uuid.Nil, uuid.Nil, false
	}
	return a.UserID, a.SessionID, true
}
