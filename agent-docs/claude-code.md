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