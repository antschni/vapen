# Vapen Web Dashboard

SvelteKit 3 + Svelte 5 BFF dashboard for [Vapen](../README.md). The browser talks only to this app; tokens stay in `httpOnly` cookies.

## Prerequisites

- Node.js 22.17+ (required by SvelteKit 3)
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

| Variable           | Purpose                                 |
| ------------------ | --------------------------------------- |
| `API_INTERNAL_URL` | Go API base (no `/api/v1` suffix)       |
| `ORIGIN`           | Public origin (CSRF via `paths.origin` at build time in Docker; also invite links at runtime) |
| `COOKIE_SECURE`    | `false` for local HTTP                  |
| `ANDROID_*`        | `assetlinks.json` for Android App Links |

See `.env.example`. Root `docker-compose.yml` and `.env.example` should mirror these for the `web` service (maintained by the API/deploy agent).

## Scripts

| Command                | Description                          |
| ---------------------- | ------------------------------------ |
| `npm run dev`          | Dev server                           |
| `npm run build`        | Production build (adapter-node)      |
| `npm run check`        | `svelte-check`                       |
| `npm run generate:api` | Regenerate `src/lib/api/schema.d.ts` |
| `npm test`             | Vitest unit tests                    |
| `npm run test:e2e`     | Playwright                           |

## Progressive Web App (PWA)

The dashboard is installable as a PWA (`@vite-pwa/sveltekit`): web manifest, service worker, and offline-friendly caching of static assets (JS/CSS). **HTML and API traffic stay network-first** so sessions and live data are not served from stale cache.

- Icons and source art: `static/pwa/` (regenerate PNGs from `icon.svg` with `npx @vite-pwa/assets-generator -r static -p minimal pwa/icon.svg`).
- After deploy, use Chrome DevTools → Application → Manifest / Service workers to verify installability.

## Architecture

- **BFF**: `hooks.server.ts` refreshes JWTs and attaches `locals.api`.
- **SSE**: Browser connects to `/stream/groups/{id}`; server proxies `/api/v1/groups/{id}/live`.
- **No `/api/*` routes** in SvelteKit (Caddy routes those to Go).
