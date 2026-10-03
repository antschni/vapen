# Vapen API

Go REST API for Vapen. The HTTP contract is defined in [`openapi.yaml`](openapi.yaml) (OpenAPI 3.0 for `oapi-codegen`; semantically aligned with the monorepo Part A spec).

## Setup

```bash
cp ../.env.example ../.env
# Set JWT_ED25519_PRIVATE_KEY (see keygen below)
docker compose up -d postgres api
```

Generate a JWT key:

```bash
go run ./cmd/vapen-api keygen
```

Health:

- `GET http://localhost:8080/healthz`
- `GET http://localhost:8080/readyz`

API base: `http://localhost:8080/api/v1`

## Development

```bash
export DATABASE_URL=postgres://vapen:vapen@localhost:5432/vapen?sslmode=disable
export JWT_ED25519_PRIVATE_KEY=<from keygen>
make generate
make run
```

## Contract

Regenerate server stubs after changing `openapi.yaml`:

```bash
make generate
```

Web and mobile clients should generate types from the same `openapi.yaml`.
