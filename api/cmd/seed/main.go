package main

import (
	"context"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/antschni/vapen/api/internal/auth"
	"github.com/antschni/vapen/api/internal/config"
	"github.com/antschni/vapen/api/internal/groups"
	"github.com/antschni/vapen/api/internal/store"
)

func main() {
	ctx := context.Background()
	cfg, err := config.Load()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	defer pool.Close()
	q := store.New(pool)
	svc, err := auth.NewService(cfg, pool, q)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	for _, u := range []struct {
		email, name, tz string
	}{
		{"alice@example.com", "Alice", "Europe/Berlin"},
		{"bob@example.com", "Bob", "Europe/Berlin"},
	} {
		_, _, err := svc.Register(ctx, u.email, "vapen-demo-password", u.name, u.tz)
		if err != nil {
			fmt.Fprintf(os.Stderr, "register %s: %v\n", u.email, err)
		}
	}
	code, _ := groups.NewInviteCode()
	fmt.Println("seed complete (users alice@example.com / bob@example.com, password vapen-demo-password)")
	fmt.Println("sample invite code placeholder:", code)
}
