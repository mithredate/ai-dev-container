# PRD: Fix Container Shell and Git Access

## Introduction

Claude Code running inside the ai-dev-container fails with two errors:
1. "No suitable shell found. Claude CLI requires a Posix shell environment. Please ensure you have a valid shell installed and the SHELL environment variable set."
2. "Anthropic marketplace requires git"

The container is missing git installation and the SHELL environment variable is not set, preventing Claude Code from executing bash commands and using git.

## Goals

- Enable Claude Code to execute bash commands inside the container
- Enable Claude Code to use git for version control operations
- Maintain minimal container image size (Alpine-based)
- Keep changes focused and backward-compatible

## User Stories

### US-001: Install Git in Container
**Description:** As a user running Claude Code inside the container, I want git installed so that Claude Code can perform version control operations.

**Acceptance Criteria:**
- [ ] Git is installed in the container image
- [ ] `git --version` runs successfully inside the container
- [ ] Claude Code can execute git commands (git status, git log, etc.)
- [ ] Container build succeeds

### US-002: Set SHELL Environment Variable
**Description:** As a user running Claude Code inside the container, I want the SHELL environment variable set so that Claude Code's Bash tool works.

**Acceptance Criteria:**
- [ ] SHELL environment variable is set to `/bin/sh` in the container
- [ ] `echo $SHELL` returns `/bin/sh` inside the container
- [ ] Claude Code Bash tool executes commands successfully
- [ ] Container build succeeds

## Functional Requirements

- FR-1: Add `git` to the `apk add` command in Dockerfile (line 24)
- FR-2: Add `ENV SHELL=/bin/sh` to Dockerfile after the apk install
- FR-3: Ensure changes don't affect existing functionality (docker-cli, claude-code, bridge)

## Non-Goals

- No changes to compose.yaml or volume mounts
- No changes to entrypoint script
- No installation of additional shells (bash, zsh) - Alpine's /bin/sh is sufficient

## Technical Considerations

- Alpine Linux uses BusyBox ash as /bin/sh, which is POSIX-compliant
- Git package in Alpine is lightweight (~25MB installed)
- The SHELL variable needs to be set before Claude Code starts, so ENV in Dockerfile is appropriate
- No need to install bash - Claude Code works with any POSIX shell

## Success Metrics

- Claude Code starts without "requires git" warning
- Claude Code Bash tool executes commands without "No suitable shell found" error
- Container image size increase is minimal (under 30MB)

## Open Questions

None - the fix is straightforward.
