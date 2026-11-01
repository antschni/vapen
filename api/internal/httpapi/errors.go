package httpapi

import (
	"errors"
	"log/slog"
	"net/http"
	"strings"

	"github.com/jackc/pgx/v5/pgconn"
)

// WriteAPIError renders handler errors. Anything that is not an APIError is logged and answered
// generically so database and driver details never reach the client.
func WriteAPIError(w http.ResponseWriter, r *http.Request, err error) {
	var ae *APIError
	if errors.As(err, &ae) {
		WriteProblem(w, ae.Status, ae.Problem.Code, ae.Problem.Title, deref(ae.Problem.Detail), nil)
		return
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch {
		case pgErr.Code == "23505":
			WriteProblem(w, 409, "conflict", "Conflict", "Resource already exists", nil)
			return
		case pgErr.Code == "23503" || pgErr.Code == "23514" || strings.HasPrefix(pgErr.Code, "22"):
			WriteProblem(w, 400, "validation_failed", "Validation failed", "Invalid input", nil)
			return
		}
	}
	slog.ErrorContext(r.Context(), "request failed", "method", r.Method, "path", r.URL.Path, "err", err)
	WriteProblem(w, 500, "internal", "Internal error", "", nil)
}

// WriteRequestError renders request decoding failures (malformed JSON, oversized body, bad params).
func WriteRequestError(w http.ResponseWriter, _ *http.Request, err error) {
	var tooLarge *http.MaxBytesError
	if errors.As(err, &tooLarge) {
		WriteProblem(w, http.StatusRequestEntityTooLarge, "payload_too_large", "Payload too large", "Request body too large", nil)
		return
	}
	WriteProblem(w, 400, "validation_failed", "Validation failed", "Malformed request", nil)
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
