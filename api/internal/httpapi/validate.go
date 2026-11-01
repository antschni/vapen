package httpapi

import (
	"time"
	"unicode/utf8"
)

// maxStatsRange bounds from/to on aggregate endpoints so one request cannot scan years of data.
const maxStatsRange = 366 * 24 * time.Hour

func validLen(s string, minRunes, maxRunes int) bool {
	n := utf8.RuneCountInString(s)
	return n >= minRunes && n <= maxRunes
}

func validStatsRange(from, to time.Time) bool {
	return !to.Before(from) && to.Sub(from) <= maxStatsRange
}
