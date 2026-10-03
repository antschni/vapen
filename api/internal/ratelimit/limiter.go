package ratelimit

import (
	"sync"
	"time"

	"golang.org/x/time/rate"
)

type Limiter interface {
	Allow(key string) bool
}

type memory struct {
	mu       sync.Mutex
	limiters map[string]*rate.Limiter
	r        rate.Limit
	b        int
}

func New(perMinute int, burst int) Limiter {
	return &memory{
		limiters: make(map[string]*rate.Limiter),
		r:        rate.Every(time.Minute / time.Duration(perMinute)),
		b:        burst,
	}
}

func (m *memory) Allow(key string) bool {
	m.mu.Lock()
	defer m.mu.Unlock()
	lim, ok := m.limiters[key]
	if !ok {
		lim = rate.NewLimiter(m.r, m.b)
		m.limiters[key] = lim
	}
	return lim.Allow()
}
