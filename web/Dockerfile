# Build context must be the repository root (see docker-compose.yml) so api/openapi.yaml is available.
FROM node:22.17-alpine AS build
WORKDIR /app/web
ARG ORIGIN=http://localhost:3000
ENV ORIGIN=$ORIGIN
COPY web/package.json web/package-lock.json web/.npmrc ./
RUN npm ci
COPY web/ .
COPY api/openapi.yaml ../api/openapi.yaml
RUN npm run generate:api
RUN npm run build

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
HEALTHCHECK --interval=10s --timeout=5s --start-period=60s --retries=5 \
  CMD wget -q --spider http://127.0.0.1:3000/ || exit 1
CMD ["node", "build"]
