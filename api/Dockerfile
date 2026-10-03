FROM golang:1.26-bookworm AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -trimpath -ldflags="-s -w" -o /vapen-api ./cmd/vapen-api

FROM gcr.io/distroless/static-debian12:nonroot
WORKDIR /app
COPY --from=build /vapen-api /app/vapen-api
COPY db/migrations /app/db/migrations
ENV LISTEN_ADDR=:8080
EXPOSE 8080
USER nonroot:nonroot
ENTRYPOINT ["/app/vapen-api", "-migrations", "/app/db/migrations"]
