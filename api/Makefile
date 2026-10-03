.PHONY: generate build test run lint

generate:
	go generate ./...

build:
	go build -o bin/vapen-api ./cmd/vapen-api

test:
	go test -race ./...

run:
	go run ./cmd/vapen-api

lint:
	go vet ./...
	golangci-lint run ./...
