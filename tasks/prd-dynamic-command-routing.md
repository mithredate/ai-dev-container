# PRD: Dynamic Command Routing with Native Overrides

## Overview

Replace the manually-maintained wrapper scripts in `scripts/wrappers/` with a single dispatcher script and dynamically generated symlinks. The bridge configuration (`bridge.yaml`) becomes the single source of truth for command routing, with support for native overrides (e.g., `claude` runs locally while `node` routes to sidecar). This eliminates `BRIDGE_ENABLED` and simplifies the architecture.

## Goals

- Single dispatcher script replaces 18+ individual wrapper scripts
- All command routing configuration lives in `bridge.yaml`
- Native overrides allow specific commands (like `claude`) to run locally
- Symlinks auto-generated at container startup from config
- Commands not in config fall through to native binary lookup

## User Stories

### #9/US-001: Set up integration test infrastructure

**Description:** As a developer, I need a working integration test that validates the current bridge functionality so that subsequent changes can be verified.

**Invariants:**
- Test environment is isolated from main project
- Test cleans up after itself (containers stopped, network removed)
- Current functionality is captured as baseline

**Acceptance Criteria:**
- [ ] Create `.test/bridge.yaml` with:
  - Command `go` routing to `test-golang` container
  - Paths mapping `/workspace` → `/workspace` (identity for now)
  - Container mapping `golang: test-golang`
- [ ] Create `.test/workspace/` with a simple Go file (`main.go` that prints "Hello")
- [ ] Create `.test/run-tests.sh` script that:
  1. Builds the claude-sidecar image (`docker build -t claude-sidecar-test ..`)
  2. Starts containers (`docker compose -f compose.yaml up -d`)
  3. Waits for containers to be ready
  4. Copies test workspace into volume
  5. Runs test: `docker compose exec claude bridge go version` → succeeds
  6. Runs test: `docker compose exec claude bridge go build -o /dev/null ./main.go` → succeeds
  7. Tears down (`docker compose -f compose.yaml down -v`)
  8. Exits with appropriate code (0 = pass, 1 = fail)
- [ ] Test script is executable and passes on clean build
- [ ] Update `.test/compose.yaml` to use `test-golang` container name consistently

### #9/US-002: Add overrides section to bridge config schema

**Description:** As a developer, I need the bridge config to support native overrides so that specific commands can bypass sidecar routing.

**Invariants:**
- Existing `commands` section continues to work unchanged
- Config validation rejects invalid override entries

**Acceptance Criteria:**
- [ ] Add `overrides` map to Config struct in `cmd/bridge/config.go`
- [ ] Override entry has `native` field (path to native binary)
- [ ] Validation ensures `native` path is non-empty string
- [ ] Existing configs without `overrides` continue to work
- [ ] Unit tests cover override parsing and validation
- [ ] `go build ./cmd/bridge` succeeds
- [ ] `go vet ./...` passes
- [ ] `.test/run-tests.sh` passes (no regression)

### #9/US-003: Implement command resolution with override priority

**Description:** As a developer, I need the bridge to check overrides before routing to sidecar so that native commands execute locally.

**Invariants:**
- Override lookup happens before sidecar routing
- Commands in both `overrides` and `commands` use the override

**Acceptance Criteria:**
- [ ] Add `ResolveCommand(name string) (execPath string, isNative bool)` method to Config
- [ ] Method returns `(nativePath, true)` if command is in overrides
- [ ] Method returns `("", false)` if command should route to sidecar or fall through
- [ ] Unit tests cover: override hit, sidecar routing, unknown command fallthrough
- [ ] `go build ./cmd/bridge` succeeds
- [ ] `go vet ./...` passes
- [ ] `.test/run-tests.sh` passes (no regression)

### #9/US-004: Update bridge main to handle native execution

**Description:** As a user, I need the bridge to execute native binaries directly when configured so that `claude` runs without docker exec.

**Invariants:**
- Native execution uses `syscall.Exec` (replaces process)
- Arguments are passed through unchanged

**Acceptance Criteria:**
- [ ] Bridge checks `ResolveCommand` before building docker exec
- [ ] If native, exec the native binary with original args
- [ ] If not in config at all, exec native binary lookup (fall through behavior)
- [ ] Exit code from native binary propagates correctly
- [ ] `go build ./cmd/bridge` succeeds
- [ ] `go vet ./...` passes
- [ ] Add integration test: `docker compose exec claude bridge echo hello` → succeeds (fallthrough to native)
- [ ] `.test/run-tests.sh` passes

### #9/US-005: Translate working directory using paths mapping

**Description:** As a user, I need the bridge to translate Claude's current working directory to the sidecar's equivalent path so that commands run in the correct location.

**Invariants:**
- Working directory translation uses the same `paths` mapping as argument translation
- If no mapping matches, falls back to static `workdir` or current directory

**Acceptance Criteria:**
- [ ] Bridge gets current working directory via `os.Getwd()`
- [ ] Apply `TranslatePath` to current working directory
- [ ] If translation produces different path, use as `-w` argument
- [ ] If no translation and `workdir` is set, use `workdir` as `-w` argument
- [ ] If no translation and no `workdir`, use current directory as `-w` argument
- [ ] Unit tests: CWD `/workspaces/project` with paths `{"/workspaces": "/app"}` → `-w /app/project`
- [ ] Unit tests: CWD `/other/path` with no matching paths → uses static `workdir` or CWD
- [ ] `go build ./cmd/bridge` succeeds
- [ ] `go vet ./...` passes
- [ ] Add integration test: run `go build` from subdirectory, verify it works
- [ ] `.test/run-tests.sh` passes

### #9/US-006: Create single dispatcher script

**Description:** As a developer, I need a single dispatcher script that routes all commands through the bridge.

**Invariants:**
- Dispatcher determines command name from `$0` (argv[0])
- All routing logic delegated to bridge binary

**Acceptance Criteria:**
- [ ] Create `scripts/wrappers/dispatcher` script
- [ ] Script extracts command name via `$(basename "$0")`
- [ ] Script execs `bridge <command> "$@"`
- [ ] Script is executable (chmod +x)
- [ ] Script has shellcheck-clean shebang: `#!/bin/sh`
- [ ] Manual test: create symlink `ln -s dispatcher test-cmd` and verify it calls `bridge test-cmd`
- [ ] `.test/run-tests.sh` passes (no regression)

### #9/US-007: Add --init-wrappers flag to generate symlinks

**Description:** As a developer, I need the bridge to generate dispatcher symlinks so that commands are intercepted at startup.

**Invariants:**
- Generated symlinks point to the dispatcher script
- Existing files in target directory are not deleted (only created/updated)

**Acceptance Criteria:**
- [ ] Add `--init-wrappers <dir>` flag to bridge CLI
- [ ] Flag reads config and creates symlink for each command in `commands` + `overrides`
- [ ] Symlinks point to `<dir>/dispatcher` (the single dispatcher script)
- [ ] If symlink exists and points to dispatcher, skip (idempotent)
- [ ] Print summary: "Created N symlinks in <dir>"
- [ ] `go build ./cmd/bridge` succeeds
- [ ] `go vet ./...` passes
- [ ] Add integration test: run `bridge --init-wrappers /tmp/test-wrappers` and verify symlinks created
- [ ] `.test/run-tests.sh` passes

### #9/US-008: Update entrypoint to initialize wrappers

**Description:** As a user, I need symlinks generated at container startup so that commands are routed correctly from first use.

**Invariants:**
- Wrapper initialization runs before any user commands
- Initialization is idempotent (safe to run multiple times)

**Acceptance Criteria:**
- [ ] Add `init_wrappers()` function to `scripts/entrypoint.sh`
- [ ] Function calls `bridge --init-wrappers /scripts/wrappers`
- [ ] Function runs after firewall init, before dropping to claude user
- [ ] Remove `CLAUDE_STARTING` environment variable logic (no longer needed)
- [ ] Add integration test: verify symlinks exist after container starts
- [ ] `.test/run-tests.sh` passes

### #9/US-009: Test native override execution end-to-end

**Description:** As a developer, I need to verify that native overrides work in the full container environment.

**Invariants:**
- Native override commands run locally without docker exec
- Override takes precedence over sidecar routing

**Acceptance Criteria:**
- [ ] Update `.test/bridge.yaml` to add `overrides` section with `echo` pointing to `/bin/echo`
- [ ] Add integration test: `docker compose exec claude echo hello` → outputs "hello" (native execution via symlink)
- [ ] Verify the echo command did NOT go through docker exec (check no "test-golang" involvement)
- [ ] `.test/run-tests.sh` passes

### #9/US-010: Remove BRIDGE_ENABLED checks and legacy wrappers

**Description:** As a developer, I need to clean up the old wrapper scripts and BRIDGE_ENABLED logic to simplify the codebase.

**Invariants:**
- No references to BRIDGE_ENABLED remain in codebase
- Dispatcher is the only script in wrappers directory (plus symlinks)

**Acceptance Criteria:**
- [ ] Delete all files in `scripts/wrappers/` except `dispatcher`
- [ ] Remove BRIDGE_ENABLED from `scripts/entrypoint.sh`
- [ ] Remove BRIDGE_ENABLED from documentation
- [ ] Update `CLAUDE.md` environment variables table
- [ ] Grep for BRIDGE_ENABLED returns no results
- [ ] `.test/run-tests.sh` passes (full regression test)

### #9/US-011: Update example configs and documentation

**Description:** As a user, I need example configuration showing how to use native overrides.

**Invariants:**
- Example demonstrates common use case (claude native override)

**Acceptance Criteria:**
- [ ] Update `examples/claude-bridge.yaml` with `overrides` section
- [ ] Add `claude` override pointing to `/usr/local/bin/claude`
- [ ] Add comments explaining override behavior
- [ ] Update `.sidecar/bridge.yaml` for project use
- [ ] Update CLAUDE.md to remove BRIDGE_ENABLED and document new architecture
- [ ] `.test/run-tests.sh` passes

## Functional Requirements

- FR-1: Config schema adds `overrides` map with `native` string field per entry
- FR-2: Bridge resolves command by checking: overrides (native) → commands (sidecar) → fallthrough (native lookup)
- FR-3: Native execution uses `syscall.Exec` to replace bridge process with target binary
- FR-4: `bridge --init-wrappers <dir>` creates symlinks for all configured commands
- FR-5: Single `dispatcher` script routes all commands through bridge
- FR-6: Entrypoint calls `bridge --init-wrappers` at startup
- FR-7: BRIDGE_ENABLED environment variable is removed entirely
- FR-8: Working directory translation uses `paths` mapping: Claude's CWD is translated using the same path mappings as arguments, then used as docker exec `-w` flag
- FR-9: Integration test validates full flow: build image → start compose → exec bridged commands → verify outputs → teardown

## Non-Goals

- Pattern-based overrides (e.g., `node */claude-code/*`) - only exact command names
- Runtime reloading of config (restart required for config changes)
- Automatic discovery of commands to intercept
- Backward compatibility shim for BRIDGE_ENABLED

## Example Config

```yaml
version: "1"

overrides:
  # Commands that run natively (not routed to sidecar)
  claude:
    native: /usr/local/bin/claude

commands:
  go:
    container: golang
    exec: go
    # Path mappings: Claude container path → Sidecar container path
    # Used for both argument translation AND working directory translation
    paths:
      /workspaces/sample-project: /workspace

  node:
    container: app
    exec: node
    paths:
      /workspaces/sample-project: /app

# Example flow:
# 1. Claude runs `go fmt ./...` from /workspaces/sample-project/cmd
# 2. Bridge gets CWD: /workspaces/sample-project/cmd
# 3. Bridge applies paths mapping: /workspace/cmd
# 4. Executes: docker exec -w /workspace/cmd golang go fmt ./...
```

## Technical Considerations

- **Config version**: Keep "1" with optional `overrides` field for backward compatibility
- **Fallthrough behavior**: When command not in config, bridge should `exec` with PATH lookup (`exec.LookPath`)
- **Symlink conflicts**: If a real binary exists at symlink path, `--init-wrappers` should warn but not overwrite
- **PATH ordering**: `/scripts/wrappers` must come before other paths to intercept commands
- **Working directory priority**: CWD translation via `paths` takes precedence over static `workdir` field. If paths translates CWD, use that; otherwise fall back to `workdir`; if neither, use untranslated CWD

## Success Metrics

- Zero manual wrapper scripts (only dispatcher + symlinks)
- Adding new intercepted command requires only bridge.yaml edit
- Claude starts and runs successfully with native override
- All existing bridge functionality preserved
- Integration test (`.test/run-tests.sh`) passes on clean build

## Open Questions

- Should `--init-wrappers` have a `--force` flag to overwrite existing files?
- Should fallthrough behavior be configurable (strict mode that errors on unknown commands)?
