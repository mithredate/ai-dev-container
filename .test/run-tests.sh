#!/bin/sh
# Integration tests for claude-sidecar bridge
# Runs from the .test directory
set -e

cd "$(dirname "$0")"

echo "=== Claude Sidecar Integration Tests ==="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

pass() {
    printf "${GREEN}PASS${NC}: %s\n" "$1"
}

fail() {
    printf "${RED}FAIL${NC}: %s\n" "$1"
    FAILED=1
}

FAILED=0

# Build the test image
echo "Building claude-sidecar-test image..."
docker compose build

# Start containers
echo "Starting test containers..."
docker compose up -d

# Wait for containers to be ready
echo "Waiting for containers..."
sleep 3

# Copy test files into volume
echo "Copying test files..."
docker compose exec -T claude mkdir -p /workspace/.test
docker compose cp bridge.yaml claude:/workspace/.test/bridge.yaml
docker compose cp workspace/. claude:/workspace/

# Test 1: go version via bridge
echo ""
echo "Test 1: go version via bridge"
if docker compose exec -T claude bridge go version 2>&1 | grep -q "go version"; then
    pass "bridge go version"
else
    fail "bridge go version"
fi

# Test 2: go build via bridge
echo ""
echo "Test 2: go build via bridge"
if docker compose exec -T claude bridge go build -o /dev/null ./main.go 2>&1; then
    pass "bridge go build"
else
    fail "bridge go build"
fi

# Test 3: native fallthrough (command not in config, but available natively)
echo ""
echo "Test 3: echo fallthrough (native execution)"
OUTPUT=$(docker compose exec -T claude bridge echo hello 2>&1)
if [ "$OUTPUT" = "hello" ]; then
    pass "bridge echo fallthrough"
else
    fail "bridge echo fallthrough (expected 'hello', got '$OUTPUT')"
fi

# Test 4: go build from subdirectory (tests CWD translation)
echo ""
echo "Test 4: go build from subdirectory (CWD translation)"
if docker compose exec -T -w /workspace/subpkg claude bridge go build ./... 2>&1; then
    pass "bridge go build from subdirectory"
else
    fail "bridge go build from subdirectory"
fi

# Cleanup
echo ""
echo "Cleaning up..."
docker compose down -v --remove-orphans

# Report results
echo ""
echo "=== Test Results ==="
if [ "$FAILED" -eq 0 ]; then
    echo "All tests passed!"
    exit 0
else
    echo "Some tests failed!"
    exit 1
fi
