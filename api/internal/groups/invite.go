package groups

import (
	"crypto/rand"
	"strings"
)

const crockford = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

func NewInviteCode() (string, error) {
	var b [10]byte
	if _, err := rand.Read(b[:]); err != nil {
		return "", err
	}
	out := make([]byte, 10)
	for i := 0; i < 10; i++ {
		out[i] = crockford[int(b[i])%len(crockford)]
	}
	return string(out), nil
}

func NormalizeInviteCode(code string) string {
	return strings.ToUpper(strings.TrimSpace(code))
}
