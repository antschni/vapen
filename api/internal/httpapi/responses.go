package httpapi

import "github.com/antschni/vapen/api/internal/openapi"

type APIError struct {
	Status  int
	Problem openapi.Problem
}

func (e *APIError) Error() string {
	if e.Problem.Detail != nil {
		return *e.Problem.Detail
	}
	return e.Problem.Code
}

func apiErr(status int, code, title, detail string) *APIError {
	return &APIError{
		Status: status,
		Problem: prob(code, title, status, detail),
	}
}

func errValidation(detail string) *APIError {
	return apiErr(400, "validation_failed", "Validation failed", detail)
}

func errUnauthorized(detail string) *APIError {
	return apiErr(401, "unauthorized", "Unauthorized", detail)
}

func errInvalidCredentials() *APIError {
	return apiErr(401, "invalid_credentials", "Invalid credentials", "Invalid email or password")
}

func errNotFound() *APIError {
	return apiErr(404, "not_found", "Not found", "Resource not found")
}

func errForbidden() *APIError {
	return apiErr(403, "forbidden", "Forbidden", "Not allowed")
}

func errConflict(detail string) *APIError {
	return apiErr(409, "conflict", "Conflict", detail)
}

func errRateLimited() *APIError {
	return apiErr(429, "rate_limited", "Rate limited", "Too many requests")
}

func ptr(s string) *string { return &s }

func prob(code, title string, status int, detail string) openapi.Problem {
	return openapi.Problem{
		Type:   problemBase + code,
		Title:  title,
		Status: status,
		Code:   code,
		Detail: ptr(detail),
	}
}
