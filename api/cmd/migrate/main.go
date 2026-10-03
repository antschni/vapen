package main

import (
	"context"
	"flag"
	"fmt"
	"os"

	"github.com/antschni/vapen/api/internal/migrate"
)

func main() {
	dir := flag.String("dir", "db/migrations", "migrations directory")
	flag.Parse()
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		fmt.Fprintln(os.Stderr, "DATABASE_URL required")
		os.Exit(1)
	}
	if err := migrate.Up(context.Background(), url, *dir); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
