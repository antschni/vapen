package stats

import "testing"

func TestNormalizeBucket(t *testing.T) {
	if got := normalizeBucket("hour"); got != "hour" {
		t.Fatalf("got %q", got)
	}
	if got := normalizeBucket("invalid"); got != "day" {
		t.Fatalf("got %q", got)
	}
}
