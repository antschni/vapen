package httpapi

import "testing"

func TestValidTimezone(t *testing.T) {
	if !validTimezone("Europe/Vienna") {
		t.Fatal("expected Europe/Vienna to be valid (requires tzdata in production image)")
	}
}
