package config

import (
	"encoding/base64"
	"fmt"
	"net/netip"
	"os"
	"strings"
	"time"
)

type Config struct {
	DatabaseURL          string
	ListenAddr           string
	PublicBaseURL        string
	JWTPrivateKey        []byte
	AccessTokenTTL       time.Duration
	RefreshTokenTTL      time.Duration
	CORSAllowedOrigins   []string
	TrustedProxies       []netip.Prefix
	LogLevel             string
	RefreshGracePeriod   time.Duration
}

func Load() (Config, error) {
	cfg := Config{
		ListenAddr:         envOr("LISTEN_ADDR", ":8080"),
		PublicBaseURL:      envOr("PUBLIC_BASE_URL", "http://localhost:8080"),
		AccessTokenTTL:     durationEnv("ACCESS_TOKEN_TTL", 15*time.Minute),
		RefreshTokenTTL:    durationEnv("REFRESH_TOKEN_TTL", 180*24*time.Hour),
		LogLevel:           envOr("LOG_LEVEL", "info"),
		RefreshGracePeriod: 30 * time.Second,
	}
	cfg.DatabaseURL = os.Getenv("DATABASE_URL")
	if cfg.DatabaseURL == "" {
		return cfg, fmt.Errorf("DATABASE_URL is required")
	}
	keyB64 := os.Getenv("JWT_ED25519_PRIVATE_KEY")
	if keyB64 == "" {
		return cfg, fmt.Errorf("JWT_ED25519_PRIVATE_KEY is required")
	}
	key, err := base64.StdEncoding.DecodeString(keyB64)
	if err != nil {
		return cfg, fmt.Errorf("JWT_ED25519_PRIVATE_KEY: invalid base64")
	}
	if len(key) != 64 {
		return cfg, fmt.Errorf("JWT_ED25519_PRIVATE_KEY must be 64 bytes (Ed25519 seed+public)")
	}
	cfg.JWTPrivateKey = key
	if v := os.Getenv("CORS_ALLOWED_ORIGINS"); v != "" {
		cfg.CORSAllowedOrigins = splitList(v)
	}
	for _, p := range splitList(os.Getenv("TRUSTED_PROXIES")) {
		prefix, err := parsePrefix(p)
		if err != nil {
			return cfg, fmt.Errorf("TRUSTED_PROXIES: invalid entry %q", p)
		}
		cfg.TrustedProxies = append(cfg.TrustedProxies, prefix)
	}
	return cfg, nil
}

func envOr(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func durationEnv(key string, def time.Duration) time.Duration {
	v := os.Getenv(key)
	if v == "" {
		return def
	}
	d, err := time.ParseDuration(v)
	if err != nil {
		return def
	}
	return d
}

func splitList(v string) []string {
	var out []string
	for _, p := range strings.Split(v, ",") {
		if p = strings.TrimSpace(p); p != "" {
			out = append(out, p)
		}
	}
	return out
}

// parsePrefix accepts a CIDR or a single IP address.
func parsePrefix(s string) (netip.Prefix, error) {
	if strings.Contains(s, "/") {
		p, err := netip.ParsePrefix(s)
		return p.Masked(), err
	}
	addr, err := netip.ParseAddr(s)
	if err != nil {
		return netip.Prefix{}, err
	}
	addr = addr.Unmap()
	return netip.PrefixFrom(addr, addr.BitLen()), nil
}
