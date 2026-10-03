package httpapi

import "net/http"

func WriteAPIError(w http.ResponseWriter, _ *http.Request, err error) {
	if ae, ok := err.(*APIError); ok {
		WriteProblem(w, ae.Status, ae.Problem.Code, ae.Problem.Title, deref(ae.Problem.Detail), nil)
		return
	}
	WriteProblem(w, 500, "internal", "Internal error", err.Error(), nil)
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
