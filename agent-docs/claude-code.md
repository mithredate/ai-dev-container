# Claude Code

## Distribution Model

Claude Code has evolved from a pure Node.js CLI tool to a **hybrid distribution**:

1. **npm package** (deprecated): `@anthropic-ai/claude-code` - requires Node.js 18+ installed
2. **Native binaries** (primary): Self-contained executables via curl/brew/winget installers

## Native Binary Architecture

The native builds:

- **Do NOT require Node.js to be pre-installed** by end users
- Bundle necessary runtime components directly
- Include **Rust-based components** for performance (fuzzy finder, etc.)
- Have platform-specific builds (macOS, Windows, Linux, ARM64)

## Build Tooling

The build process uses multiple tools:

- **TypeScript** for the main codebase
- **Bun** as an alternative JS runtime (mentioned in CHANGELOG for performance)
- **Rust** for performance-critical native components
- **Node.js 20** as the base for container/devcontainer builds

## No Standard SEA/pkg

Notably, there's no `sea-config.json` or `pkg` configuration in the repo. This suggests the native binary build uses **custom/proprietary tooling** rather than Node.js Single Executable Application (SEA) or the `pkg` bundler.

## Key Evidence from CHANGELOG

- "Native binary installs now launch quicker"
- "Improved file path suggestion performance with native Rust-based fuzzy finder"
- "Improved terminal rendering performance when using native installer or Bun"
- "New syntax highlighting engine for native build"

## Summary

The shift from npm to native installers reflects optimization for startup performance and user convenience—users no longer need Node.js installed to run Claude Code.

## Credential Storage

### OAuth Tokens

**macOS:**
- Stored in macOS Keychain (Apple's native encrypted credential store)
- Encrypted at rest with OS-level security
- Thread-safe with proper locking mechanisms
- If keychain is locked, Claude Code hints to run `security unlock-keychain`

**Linux:**
- No native keyring integration (GNOME Keyring, KWallet not used)
- Tokens rely on environment variables or file-based storage
- Stored in the config directory structure

### API Key Storage

| Platform | Storage Mechanism |
|----------|-------------------|
| macOS | macOS Keychain (since v0.2.30) |
| Linux | Environment variables (`ANTHROPIC_API_KEY`, etc.) |

### Configuration Directories

**macOS:**
```
~/.claude/                    # Main config directory
~/.claude/settings.json       # Settings
~/.claude/skills/             # Custom skills
~/.claude/commands/           # Slash commands
~/.claude.json                # Legacy config file
```

**Linux (XDG-compliant since v1.0.28):**
```
$XDG_CONFIG_HOME/claude/      # If XDG_CONFIG_HOME is set
~/.config/claude/             # Default XDG location
~/.claude/                    # Legacy fallback (still supported)
```

### MCP Server Credentials

Three auth methods supported:

1. **OAuth (automatic)** - Token stored in Keychain (macOS) or config files
2. **Bearer tokens** - Via environment variable substitution: `"Authorization": "Bearer ${API_TOKEN}"`
3. **Environment variables** - Passed to stdio servers via `env` config

### Fallback Mechanisms

- **Dynamic header helpers**: Scripts that generate fresh tokens per-request
  ```json
  { "headersHelper": "${CLAUDE_PLUGIN_ROOT}/scripts/get-headers.sh" }
  ```
- **Environment variable substitution**: `${VARIABLE_NAME}` pattern in configs
- **Automatic OAuth refresh**: Proactively refreshes tokens before expiration

### Security Features

- OAuth tokens, API keys, and passwords sanitized from debug logs (v2.1.0 fix)
- Race condition fixes for concurrent keychain access
- Credentials not accessible to plugins
- Automatic clearing on sign-out

### Platform Comparison

| Feature | macOS | Linux |
|---------|-------|-------|
| Primary credential store | Keychain (encrypted) | Environment variables / files |
| XDG support | No | Yes |
| Token encryption at rest | Yes (OS-level) | No (file permissions only) |
| OAuth token storage | Keychain | Config directory |