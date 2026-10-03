package live

import (
	"context"
	"encoding/json"
	"log/slog"
	"sync"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Event struct {
	GroupID  uuid.UUID `json:"group_id"`
	UserID   uuid.UUID `json:"user_id"`
	Kind     string    `json:"kind"`
	DeviceID uuid.UUID `json:"device_id,omitempty"`
}

type Hub struct {
	pool *pgxpool.Pool
	mu   sync.RWMutex
	subs map[uuid.UUID]map[chan Event]struct{}
}

func New(pool *pgxpool.Pool) *Hub {
	return &Hub{
		pool: pool,
		subs: make(map[uuid.UUID]map[chan Event]struct{}),
	}
}

func (h *Hub) Run(ctx context.Context) {
	for {
		if err := h.listen(ctx); err != nil {
			slog.Error("live listen failed", "err", err)
			time.Sleep(time.Second)
		}
		if ctx.Err() != nil {
			return
		}
	}
}

func (h *Hub) listen(ctx context.Context) error {
	conn, err := h.pool.Acquire(ctx)
	if err != nil {
		return err
	}
	defer conn.Release()
	_, err = conn.Exec(ctx, "LISTEN vapen_live")
	if err != nil {
		return err
	}
	for {
		n, err := conn.Conn().WaitForNotification(ctx)
		if err != nil {
			return err
		}
		var ev Event
		if err := json.Unmarshal([]byte(n.Payload), &ev); err != nil {
			continue
		}
		h.broadcast(ev)
	}
}

func (h *Hub) broadcast(ev Event) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for ch := range h.subs[ev.GroupID] {
		select {
		case ch <- ev:
		default:
		}
	}
}

func (h *Hub) Subscribe(groupID uuid.UUID) (chan Event, func()) {
	ch := make(chan Event, 16)
	h.mu.Lock()
	if h.subs[groupID] == nil {
		h.subs[groupID] = make(map[chan Event]struct{})
	}
	h.subs[groupID][ch] = struct{}{}
	h.mu.Unlock()
	return ch, func() {
		h.mu.Lock()
		delete(h.subs[groupID], ch)
		h.mu.Unlock()
		close(ch)
	}
}

func Notify(ctx context.Context, pool *pgxpool.Pool, payload Event) error {
	b, err := json.Marshal(payload)
	if err != nil {
		return err
	}
	_, err = pool.Exec(ctx, "SELECT pg_notify('vapen_live', $1)", string(b))
	return err
}
