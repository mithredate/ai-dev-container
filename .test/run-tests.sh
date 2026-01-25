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

# Test 1: go version via bridge
echo ""
echo "Test 1: go version via bridge"
if docker compose exec -T claude go version 2>&1 | grep -q "go version"; then
    pass "bridge go version"
else
    fail "bridge go version"
fi

# Test 2: go build via bridge
echo ""
echo "Test 2: go build via bridge"
if docker compose exec -T -w /workspaces/test/go-test-app claude go build -o /dev/null ./main.go 2>&1; then
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
if docker compose exec -T -w /workspaces/test/go-test-app/cmd claude go build ./... 2>&1; then
    pass "bridge go build from subdirectory"
else
    fail "bridge go build from subdirectory"
fi

# Test 5: init-wrappers creates symlinks
echo ""
echo "Test 5: bridge --init-wrappers creates symlinks"
TEST_WRAPPERS_DIR="/tmp/test-wrappers"
# Create the directory and dispatcher
docker compose exec -T claude mkdir -p "$TEST_WRAPPERS_DIR"
docker compose exec -T claude cp /scripts/wrappers/dispatcher "$TEST_WRAPPERS_DIR/dispatcher"
# Run init-wrappers
if docker compose exec -T claude bridge --init-wrappers "$TEST_WRAPPERS_DIR" 2>&1 | grep -q "Created"; then
    # Verify symlinks exist and point to dispatcher
    GO_TARGET=$(docker compose exec -T claude readlink "$TEST_WRAPPERS_DIR/go" 2>/dev/null)
    if [ "$GO_TARGET" = "dispatcher" ]; then
        pass "bridge --init-wrappers creates symlinks"
    else
        fail "bridge --init-wrappers: symlink points to '$GO_TARGET', expected 'dispatcher'"
    fi
else
    fail "bridge --init-wrappers did not report creation"
fi

# Test 6: symlinks exist after container starts (entrypoint init_wrappers)
echo ""
echo "Test 6: symlinks exist after container starts (entrypoint init_wrappers)"
# The entrypoint should have called init_wrappers at startup
# Check that symlinks exist in /scripts/wrappers
GO_SYMLINK_TARGET=$(docker compose exec -T claude readlink /scripts/wrappers/go 2>/dev/null || echo "")
if [ "$GO_SYMLINK_TARGET" = "dispatcher" ]; then
    pass "entrypoint init_wrappers created symlinks"
else
    fail "entrypoint init_wrappers: /scripts/wrappers/go not pointing to dispatcher (got '$GO_SYMLINK_TARGET')"
fi

# Test 7: native override execution via symlink (echo)
echo ""
echo "Test 7: native override execution via symlink (echo)"
# The echo command is in overrides with native: /bin/echo
# It should have a symlink from init_wrappers
ECHO_SYMLINK_TARGET=$(docker compose exec -T claude readlink /scripts/wrappers/echo 2>/dev/null || echo "")
if [ "$ECHO_SYMLINK_TARGET" != "dispatcher" ]; then
    fail "echo symlink not created (expected 'dispatcher', got '$ECHO_SYMLINK_TARGET')"
else
    # Run echo through the symlink to test native override execution
    # The symlink calls dispatcher -> bridge -> executes /bin/echo natively (not docker exec)
    OUTPUT=$(docker compose exec -T claude /scripts/wrappers/echo hello 2>&1)
    if [ "$OUTPUT" = "hello" ]; then
        pass "native override echo via symlink"
    else
        fail "native override echo via symlink (expected 'hello', got '$OUTPUT')"
    fi
fi

# Test 8: native override with node (claude test script)
echo ""
echo "Test 8: native override runs node locally (not via sidecar)"
# Stop the node sidecar to prove native execution works
docker compose stop node 2>/dev/null

echo "Node service stopped"
# The claude override points to our test script which requires node
# If this works, it proves node runs natively (not routed to the stopped sidecar)
WHICH_CLAUDE_TARGET=$(docker compose exec -T claude which claude 2>/dev/null || echo "")
if [ "$WHICH_CLAUDE_TARGET" != "/scripts/wrappers/claude" ]; then
    fail "incorrect claude reference (expected '/scripts/wrappers/claude', got '$WHICH_CLAUDE_TARGET')"
else
    CLAUDE_SYMLINK_TARGET=$(docker compose exec -T claude readlink /scripts/wrappers/claude 2>/dev/null || echo "")
    if [ "$CLAUDE_SYMLINK_TARGET" != "dispatcher" ]; then
        fail "claude symlink not created (expected 'dispatcher', got '$CLAUDE_SYMLINK_TARGET')"
    else
        OUTPUT=$(docker compose exec -T claude /scripts/wrappers/claude 2>&1)
        if [ "$OUTPUT" = "native-node-ok" ]; then
            pass "native override runs node locally"
        else
            fail "native override runs node locally (expected 'native-node-ok', got '$OUTPUT')"
        fi
    fi
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
