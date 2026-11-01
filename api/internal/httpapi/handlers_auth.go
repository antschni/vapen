package httpapi

import (
	"context"
	"errors"
	"strings"
	"unicode/utf8"

	"github.com/jackc/pgx/v5/pgconn"

	"github.com/antschni/vapen/api/internal/auth"
	"github.com/antschni/vapen/api/internal/openapi"
)

const (
	minPasswordLen = 12
	maxPasswordLen = 128
)

func validPassword(p string) bool {
	return len(p) >= minPasswordLen && len(p) <= maxPasswordLen
}

func validDisplayName(name string) bool {
	n := utf8.RuneCountInString(name)
	return n >= 2 && n <= 40
}

func (s *Server) AuthRegister(ctx context.Context, request openapi.AuthRegisterRequestObject) (openapi.AuthRegisterResponseObject, error) {
	body := request.Body
	if body == nil {
		return nil, errValidation("Request body is required")
	}
	email := strings.TrimSpace(string(body.Email))
	if !validPassword(body.Password) {
		return nil, errValidation("password must be 12 to 128 characters")
	}
	if !validDisplayName(body.DisplayName) {
		return nil, errValidation("display_name must be 2 to 40 characters")
	}
	if !validTimezone(body.Timezone) {
		return nil, errValidation("invalid timezone")
	}
	if !s.registerIP.Allow(clientIPFrom(ctx)) || !s.loginEmail.Allow(strings.ToLower(email)) {
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
	if !s.loginIP.Allow(clientIPFrom(ctx)) || !s.loginEmail.Allow(strings.ToLower(email)) {
		return nil, errRateLimited()
	}
	if len(body.Password) > maxPasswordLen {
		return nil, errInvalidCredentials()
	}
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
	if !s.refreshIP.Allow(clientIPFrom(ctx)) {
		return nil, errRateLimited()
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
	_, sid, ok := mustUser(ctx)
	if !ok {
		return nil, errUnauthorized("Unauthorized")
	}
	if err := s.auth.Logout(ctx, sid); err != nil {
		return nil, err
	}
	return openapi.AuthLogout204Response{}, nil
}
