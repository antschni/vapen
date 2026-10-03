package main

import (
	"context"
	"crypto/ed25519"
	"encoding/base64"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/antschni/vapen/api/internal/auth"
	"github.com/antschni/vapen/api/internal/config"
	"github.com/antschni/vapen/api/internal/httpapi"
	"github.com/antschni/vapen/api/internal/live"
	"github.com/antschni/vapen/api/internal/migrate"
	"github.com/antschni/vapen/api/internal/openapi"
	"github.com/antschni/vapen/api/internal/store"
)

func main() {
	if len(os.Args) > 1 && os.Args[1] == "keygen" {
		_, priv, err := ed25519.GenerateKey(nil)
		if err != nil {
			panic(err)
		}
		seed := priv.Seed()
		full := make([]byte, 64)
		copy(full, seed)
		copy(full[32:], priv.Public().(ed25519.PublicKey))
		fmt.Println(base64.StdEncoding.EncodeToString(full))
		return
	}

	cfg, err := config.Load()
	if err != nil {
		slog.Error("config", "err", err)
		os.Exit(1)
	}

	migrationsDir := flag.String("migrations", defaultMigrationsDir(), "path to SQL migrations")
	flag.Parse()

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		slog.Error("db", "err", err)
		os.Exit(1)
	}
	defer pool.Close()

	if err := migrate.Up(ctx, cfg.DatabaseURL, *migrationsDir); err != nil {
		slog.Error("migrate", "err", err)
		os.Exit(1)
	}

	q := store.New(pool)
	authSvc, err := auth.NewService(cfg, pool, q)
	if err != nil {
		slog.Error("auth", "err", err)
		os.Exit(1)
	}

	hub := live.New(pool)
	go hub.Run(ctx)

	srv := httpapi.NewServer(cfg, pool, authSvc, hub)
	strict := openapi.NewStrictHandlerWithOptions(srv, []openapi.StrictMiddlewareFunc{srv.StrictMiddleware()}, openapi.StrictHTTPServerOptions{
		ResponseErrorHandlerFunc: httpapi.WriteAPIError,
	})
	apiHandler := openapi.HandlerWithOptions(strict, openapi.StdHTTPServerOptions{
		BaseURL: "",
	})

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.HandleFunc("GET /readyz", func(w http.ResponseWriter, r *http.Request) {
		if err := pool.Ping(r.Context()); err != nil {
			httpapi.WriteProblem(w, 503, "internal", "Not ready", "database unreachable", nil)
			return
		}
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	mux.Handle("/api/v1/", http.StripPrefix("/api/v1", apiHandler))

	httpSrv := &http.Server{
		Addr:              cfg.ListenAddr,
		Handler:           securityHeaders(mux),
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		slog.Info("listening", "addr", cfg.ListenAddr)
		if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("serve", "err", err)
			os.Exit(1)
		}
	}()

	stop, _ := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	<-stop.Done()
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	_ = httpSrv.Shutdown(shutdownCtx)
}

func defaultMigrationsDir() string {
	if _, err := os.Stat("db/migrations"); err == nil {
		return "db/migrations"
	}
	exe, _ := os.Executable()
	return filepath.Join(filepath.Dir(exe), "db", "migrations")
}

func securityHeaders(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("X-Content-Type-Options", "nosniff")
		w.Header().Set("Referrer-Policy", "no-referrer")
		next.ServeHTTP(w, r)
	})
}
