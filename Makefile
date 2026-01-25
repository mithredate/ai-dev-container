.PHONY: build vet fmt clean

# Build the bridge binary
build:
	go build -o bin/bridge ./cmd/bridge

# Run go vet
vet:
	go vet ./...

# Format code
fmt:
	go fmt ./...

# Clean build artifacts
clean:
	rm -rf bin/
