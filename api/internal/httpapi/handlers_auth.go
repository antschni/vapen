package httpapi

import (
	"context"
	"errors"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"

	"github.com/antschni/vapen/api/internal/auth"
	"github.com/antschni/vapen/api/internal/openapi"
)

func (s *Server) AuthRegister(ctx context.Context, request openapi.AuthRegisterRequestObject) (openapi.AuthRegisterResponseObject, error) {
	body := request.Body
	if body == nil {
		return nil, errValidation("Request body is required")
	}
	email := strings.TrimSpace(string(body.Email))
	if len(body.Password) < 12 || len(body.Password) > 128 {
		return nil, errValidation("password must be 12 to 128 characters")
	}
	if !validTimezone(body.Timezone) {
		return nil, errValidation("invalid timezone")
	}
	ip := ""
	if r, ok := ctx.Value(http.LocalAddrContextKey).(interface{}); ok {
		_ = r
	}
	_ = ip
	if !s.loginEmail.Allow(email) {
		return nil, errRateLimited()
	}
	pair, u, err := s.auth.Register(ctx, email, body.Password, body.DisplayName, body.Timezone)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, errConflict("Email already registered")
		}
		return nil, err
	}
	tp := tokenPairToAPI(pair, userToAPI(*u))
	return openapi.AuthRegister201JSONResponse(tp), nil
}

func (s *Server) AuthLogin(ctx context.Context, request openapi.AuthLoginRequestObject) (openapi.AuthLoginResponseObject, error) {
	body := request.Body
	if body == nil {
		return nil, errValidation("Request body is required")
	}
	email := strings.TrimSpace(string(body.Email))
	pair, err := s.auth.Login(ctx, email, body.Password)
	if err != nil {
		if errors.Is(err, auth.ErrInvalidCredentials) {
			return nil, errInvalidCredentials()
		}
		return nil, err
	}
	u, err := s.q.GetUserByID(ctx, pgUUID(pair.UserID))
	if err != nil {
		return nil, err
	}
	return openapi.AuthLogin200JSONResponse(tokenPairToAPI(pair, userToAPI(u))), nil
}

func (s *Server) AuthRefresh(ctx context.Context, request openapi.AuthRefreshRequestObject) (openapi.AuthRefreshResponseObject, error) {
	body := request.Body
	if body == nil {
		return nil, errValidation("Request body is required")
	}
	pair, err := s.auth.Refresh(ctx, body.RefreshToken)
	if err != nil {
		if errors.Is(err, auth.ErrInvalidCredentials) || errors.Is(err, auth.ErrTokenReuse) {
			return nil, errUnauthorized("Invalid refresh token")
		}
		return nil, err
	}
	u, err := s.q.GetUserByID(ctx, pgUUID(pair.UserID))
	if err != nil {
		return nil, err
	}
	return openapi.AuthRefresh200JSONResponse(tokenPairToAPI(pair, userToAPI(u))), nil
}

func (s *Server) AuthLogout(ctx context.Context, _ openapi.AuthLogoutRequestObject) (openapi.AuthLogoutResponseObject, error) {
	uid, sid, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	_ = uid
	if err := s.auth.Logout(ctx, sid); err != nil {
		return nil, err
	}
	return openapi.AuthLogout204Response{}, nil
}
