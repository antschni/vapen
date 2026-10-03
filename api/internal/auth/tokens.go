package auth

import (
	"crypto/sha256"
	"encoding/base64"
	"fmt"
)

func HashOpaqueToken(token string) []byte {
	sum := sha256.Sum256([]byte(token))
	return sum[:]
}

func NewRefreshToken() (plain string, hash []byte, err error) {
	return newOpaqueToken("vpr_")
}

func NewDeviceToken() (plain string, hash []byte, err error) {
	return newOpaqueToken("vpd_")
}

func newOpaqueToken(prefix string) (string, []byte, error) {
	raw := make([]byte, 32)
	if _, err := readRand(raw); err != nil {
		return "", nil, err
	}
	plain := prefix + base64.RawURLEncoding.EncodeToString(raw)
	return plain, HashOpaqueToken(plain), nil
}

func ValidateRefreshPrefix(token string) error {
	if len(token) < 5 || token[:4] != "vpr_" {
		return fmt.Errorf("invalid refresh token")
	}
	return nil
}

func ValidateDevicePrefix(token string) error {
	if len(token) < 5 || token[:4] != "vpd_" {
		return fmt.Errorf("invalid device token")
	}
	return nil
}
