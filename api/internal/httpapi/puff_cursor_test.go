package httpapi

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestPuffCursorRoundTrip(t *testing.T) {
	started := time.Date(2026, 10, 5, 17, 46, 1, 234000000, time.UTC)
	id := uuid.MustParse("6ba7b810-9dad-11d1-80b4-00c04fd430c8")
	encoded := formatPuffCursor(started, id)
	gotAt, gotID, err := puffCursorParams(&encoded)
	if err != nil {
		t.Fatal(err)
	}
	if !gotAt.Valid || !gotAt.Time.Equal(started) {
		t.Fatalf("started_at = %v, want %v", gotAt.Time, started)
	}
	if !gotID.Valid || uuid.UUID(gotID.Bytes) != id {
		t.Fatalf("id = %v, want %s", gotID.Bytes, id)
	}
}

func TestPuffCursorTimestampOnly(t *testing.T) {
	raw := "2026-10-05T17:46:01.234Z"
	gotAt, gotID, err := puffCursorParams(&raw)
	if err != nil {
		t.Fatal(err)
	}
	if !gotAt.Valid || !gotID.Valid || uuid.UUID(gotID.Bytes) != uuid.Nil {
		t.Fatalf("cursor = %+v %+v", gotAt, gotID)
	}
}

func TestPuffCursorEmpty(t *testing.T) {
	gotAt, gotID, err := puffCursorParams(nil)
	if err != nil {
		t.Fatal(err)
	}
	if gotAt.Valid || gotID.Valid {
		t.Fatal("empty cursor should be unset")
	}
}
