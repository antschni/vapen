package httpapi

import (
	"encoding/json"
	"net/http"
)

const problemBase = "https://vapen.dev/problems/"

type FieldError struct {
	Field   string `json:"field"`
	Message string `json:"message"`
}

type Problem struct {
	Type   string       `json:"type"`
	Title  string       `json:"title"`
	Status int          `json:"status"`
	Code   string       `json:"code"`
	Detail string       `json:"detail,omitempty"`
	Errors []FieldError `json:"errors,omitempty"`
}

func WriteProblem(w http.ResponseWriter, status int, code, title, detail string, errors []FieldError) {
	w.Header().Set("Content-Type", "application/problem+json")
	w.Header().Set("Cache-Control", "no-store")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(Problem{
		Type:   problemBase + code,
		Title:  title,
		Status: status,
		Code:   code,
		Detail: detail,
		Errors: errors,
	})
}
