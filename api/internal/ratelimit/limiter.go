package ratelimit

import (
	"sync"
	"time"

	"golang.org/x/time/rate"
)

// idleTTL is how long an unused key is kept; a limiter idle this long has refilled anyway.
const idleTTL = 10 * time.Minute

type Limiter interface {
	Allow(key string) bool
}

type entry struct {
	lim      *rate.Limiter
	lastSeen time.Time
}

type memory struct {
	mu        sync.Mutex
	limiters  map[string]*entry
	r         rate.Limit
	b         int
	lastSweep time.Time
}

func New(perMinute int, burst int) Limiter {
	return &memory{
		limiters:  make(map[string]*entry),
		r:         rate.Every(time.Minute / time.Duration(perMinute)),
		b:         burst,
		lastSweep: time.Now(),
	}
}

func (m *memory) Allow(key string) bool {
	now := time.Now()
	m.mu.Lock()
	defer m.mu.Unlock()
	if now.Sub(m.lastSweep) > time.Minute {
		for k, e := range m.limiters {
			if now.Sub(e.lastSeen) > idleTTL {
				delete(m.limiters, k)
			}
		}
		m.lastSweep = now
	}
	e, ok := m.limiters[key]
	if !ok {
		e = &entry{lim: rate.NewLimiter(m.r, m.b)}
		m.limiters[key] = e
	}
	e.lastSeen = now
	return e.lim.AllowN(now, 1)
}
