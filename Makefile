check: lint test
lint:
	docker run --rm -v $$(pwd):/app -w /app golangci/golangci-lint:v1.42.1 golangci-lint run -v
.PHONY: test
test:
	go test ./... -v --bench . --benchmem --coverprofile=cover.out
testcovhttp:
	go test ./... --coverprofile=cover.out && go tool cover -html=cover.out
