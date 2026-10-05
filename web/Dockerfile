# Build context must be the repository root (see docker-compose.yml) so api/openapi.yaml is available.
FROM node:22.17-alpine AS build
WORKDIR /app/web
ARG ORIGIN=http://localhost:3000
ARG COOLIFY_FQDN=
ENV ORIGIN=$ORIGIN
COPY web/package.json web/package-lock.json web/.npmrc ./
RUN npm ci
COPY web/ .
COPY api/openapi.yaml ../api/openapi.yaml
RUN npm run generate:api
RUN set -e; \
  BUILD_ORIGIN="$ORIGIN"; \
  if [ -n "$COOLIFY_FQDN" ] && { [ -z "$BUILD_ORIGIN" ] || [ "$BUILD_ORIGIN" = "http://localhost:3000" ]; }; then \
    BUILD_ORIGIN="https://$COOLIFY_FQDN"; \
  fi; \
  ORIGIN="$BUILD_ORIGIN" npm run build

FROM node:22.17-alpine AS run
# SvelteKit 3 requires Node.js >= 22.17 (see web/package.json engines).
WORKDIR /app
ENV NODE_ENV=production
RUN apk add --no-cache wget \
  && addgroup -S vapen && adduser -S vapen -G vapen
COPY --from=build /app/web/build ./build
COPY --from=build /app/web/package.json ./
COPY --from=build /app/web/package-lock.json ./
COPY --from=build /app/web/.npmrc ./
RUN npm ci --omit=dev && chown -R vapen:vapen /app
USER vapen
EXPOSE 3000
ENV PORT=3000
ENV HOST=0.0.0.0
# Liveness: /health and /healthz skip auth in hooks.server.ts. Use $PORT (Coolify may override).
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
  CMD wget -qO- "http://127.0.0.1:${PORT:-3000}/health" | grep -qx ok || exit 1
CMD ["node", "build/index.js"]
