FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /vapen-api ./cmd/vapen-api

FROM alpine:3.21 AS run
RUN apk add --no-cache ca-certificates wget
WORKDIR /app
COPY --from=build /vapen-api /app/vapen-api
COPY db/migrations /app/db/migrations
RUN adduser -D -u 65532 -g vapen vapen && chown -R vapen:vapen /app
ENV LISTEN_ADDR=:8080
EXPOSE 8080
USER vapen
HEALTHCHECK --interval=10s --timeout=5s --start-period=40s --retries=5 \
  CMD wget -q --spider http://127.0.0.1:8080/readyz || exit 1
ENTRYPOINT ["/app/vapen-api", "-migrations", "/app/db/migrations"]
