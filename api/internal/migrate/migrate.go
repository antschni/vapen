package migrate

import (
	"context"
	"database/sql"
	"fmt"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/pressly/goose/v3"
)

func Up(ctx context.Context, databaseURL string, migrationsDir string) error {
	if err := goose.SetDialect("postgres"); err != nil {
		return err
	}
	db, err := sql.Open("pgx", databaseURL)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer db.Close()
	if err := goose.UpContext(ctx, db, migrationsDir); err != nil {
		return fmt.Errorf("migrate up: %w", err)
	}
	return nil
}
