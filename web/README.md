# Vapen Web Dashboard

SvelteKit 2 + Svelte 5 BFF dashboard for [Vapen](../README.md). The browser talks only to this app; tokens stay in `httpOnly` cookies.

## Prerequisites

- Node.js 22+
- Running API (`docker compose up -d postgres api` from repo root, or `API_INTERNAL_URL`)

## Setup

```bash
cd web
cp .env.example .env
npm install
npm run generate:api   # after api/openapi.yaml changes
npm run dev
```

Open [http://localhost:5173](http://localhost:5173). Demo users: `alice@example.com` / `vapen-demo-password` (after `go run ./cmd/seed` in `api/`).

## Environment

| Variable | Purpose |
|----------|---------|
| `API_INTERNAL_URL` | Go API base (no `/api/v1` suffix) |
| `ORIGIN` | Public origin for CSRF and invite links |
| `COOKIE_SECURE` | `false` for local HTTP |
| `ANDROID_*` | `assetlinks.json` for Android App Links |

See `.env.example`. Root `docker-compose.yml` and `.env.example` should mirror these for the `web` service (maintained by the API/deploy agent).

## Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Dev server |
| `npm run build` | Production build (adapter-node) |
| `npm run check` | `svelte-check` |
| `npm run generate:api` | Regenerate `src/lib/api/schema.d.ts` |
| `npm test` | Vitest unit tests |
| `npm run test:e2e` | Playwright |

## Architecture

- **BFF**: `hooks.server.ts` refreshes JWTs and attaches `locals.api`.
- **SSE**: Browser connects to `/stream/groups/{id}`; server proxies `/api/v1/groups/{id}/live`.
- **No `/api/*` routes** in SvelteKit (Caddy routes those to Go).
