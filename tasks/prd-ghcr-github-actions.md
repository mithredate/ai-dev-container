# PRD: Push Container to GitHub Container Registry via GitHub Actions

## Introduction

Automate the building and publishing of the Docker container to GitHub Container Registry (GHCR) using GitHub Actions. This enables consistent, reproducible container builds with proper tagging, multi-platform support, and security scanning. The workflow triggers on pushes to main (producing `:latest`) and on version tags (producing semantic version tags).

## Goals

- Automatically build and push container images on main branch pushes and version tag releases
- Support multi-platform builds (linux/amd64 and linux/arm64) for broad compatibility
- Implement comprehensive tagging strategy (latest, SHA, semantic version)
- Use registry-based caching for fast, efficient builds
- Scan images for vulnerabilities and block pushes with critical issues
- Require zero manual intervention for standard releases

## User Stories

### US-001: Create GitHub Actions workflow file
**Description:** As a developer, I need a GitHub Actions workflow file that triggers on the correct events so that container builds happen automatically.

**Acceptance Criteria:**
- [ ] Create `.github/workflows/docker-publish.yml` workflow file
- [ ] Workflow triggers on push to `main` branch
- [ ] Workflow triggers on push of version tags matching `v*.*.*` pattern
- [ ] Workflow triggers on `workflow_dispatch` for manual runs
- [ ] Workflow has appropriate name and job names for clarity

### US-002: Configure GHCR authentication
**Description:** As a developer, I need the workflow to authenticate with GHCR so that it can push images to the registry.

**Acceptance Criteria:**
- [ ] Workflow uses `GITHUB_TOKEN` for authentication (no manual secrets needed)
- [ ] Login step uses `docker/login-action` with `ghcr.io` registry
- [ ] Permissions are set correctly (`contents: read`, `packages: write`)
- [ ] Image is pushed to `ghcr.io/<owner>/<repo>` namespace

### US-003: Implement image tagging strategy
**Description:** As a developer, I want images tagged with multiple identifiers so that I can reference specific versions or always get the latest.

**Acceptance Criteria:**
- [ ] Use `docker/metadata-action` to generate tags
- [ ] Push to `main` produces `:latest` tag
- [ ] Push to `main` produces `:sha-<short-sha>` tag (e.g., `sha-abc1234`)
- [ ] Push of `v1.2.3` tag produces `:1.2.3`, `:1.2`, and `:1` tags
- [ ] Push of `v1.2.3` tag also produces `:sha-<short-sha>` tag
- [ ] All images include OCI labels (created date, revision, description)

### US-004: Configure multi-platform builds
**Description:** As a developer, I want the container built for both AMD64 and ARM64 architectures so that it runs natively on Intel/AMD and Apple Silicon machines.

**Acceptance Criteria:**
- [ ] Use `docker/setup-qemu-action` for cross-platform emulation
- [ ] Use `docker/setup-buildx-action` for BuildKit builder
- [ ] Build targets both `linux/amd64` and `linux/arm64` platforms
- [ ] Single manifest list created containing both architectures
- [ ] Verify Dockerfile is compatible with multi-arch build (no hardcoded arch downloads)

### US-005: Implement registry-based build caching
**Description:** As a developer, I want builds to use GHCR-based caching so that subsequent builds are faster.

**Acceptance Criteria:**
- [ ] Configure `cache-from` with `type=registry` pointing to cache image
- [ ] Configure `cache-to` with `type=registry,mode=max` for maximum cache layers
- [ ] Cache image uses separate tag (e.g., `buildcache`) to avoid polluting release tags
- [ ] Verify cache is used on subsequent builds (check build logs)

### US-006: Add security scanning with Trivy
**Description:** As a developer, I want images scanned for vulnerabilities before push so that we don't publish containers with critical security issues.

**Acceptance Criteria:**
- [ ] Use `aquasecurity/trivy-action` to scan the built image
- [ ] Scan runs before the push step
- [ ] Workflow fails if CRITICAL vulnerabilities are found
- [ ] Scan results uploaded as SARIF to GitHub Security tab
- [ ] HIGH vulnerabilities logged as warnings but don't fail the build

### US-007: Update Dockerfile for multi-arch compatibility
**Description:** As a developer, I need the Dockerfile to support multi-architecture builds so that the same Dockerfile works for both AMD64 and ARM64.

**Acceptance Criteria:**
- [ ] Replace hardcoded `yq_linux_amd64` with architecture-aware download
- [ ] Use `TARGETARCH` build argument to select correct binary
- [ ] Verify build succeeds for both `linux/amd64` and `linux/arm64`
- [ ] Verify yq binary works correctly in final image on both architectures

### US-008: Add workflow status badge to README
**Description:** As a user viewing the repository, I want to see the build status so that I know if the latest image is healthy.

**Acceptance Criteria:**
- [ ] Add workflow status badge to README.md (if README exists)
- [ ] Badge links to the Actions workflow runs
- [ ] Badge shows current status (passing/failing)

## Functional Requirements

- FR-1: The workflow MUST trigger on pushes to the `main` branch
- FR-2: The workflow MUST trigger on version tags matching pattern `v[0-9]+.[0-9]+.[0-9]+`
- FR-3: The workflow MUST support manual triggering via `workflow_dispatch`
- FR-4: The workflow MUST authenticate to GHCR using the repository's `GITHUB_TOKEN`
- FR-5: The workflow MUST build images for both `linux/amd64` and `linux/arm64` platforms
- FR-6: The workflow MUST tag images with `:latest` on main branch pushes
- FR-7: The workflow MUST tag images with `:sha-<7-char-sha>` on all builds
- FR-8: The workflow MUST tag images with semantic version tags (`:X.Y.Z`, `:X.Y`, `:X`) on version tag pushes
- FR-9: The workflow MUST use GHCR as the build cache backend
- FR-10: The workflow MUST scan images with Trivy before pushing
- FR-11: The workflow MUST fail if Trivy finds CRITICAL vulnerabilities
- FR-12: The workflow MUST upload scan results to GitHub Security tab in SARIF format
- FR-13: The Dockerfile MUST download architecture-appropriate binaries using `TARGETARCH`

## Non-Goals

- No support for pushing to registries other than GHCR (Docker Hub, ECR, etc.)
- No automatic versioning/tag creation (tags must be created manually or via separate workflow)
- No deployment or rollout after push (this PRD covers CI only, not CD)
- No build matrix for different Node.js versions
- No Windows container support
- No signing of container images (can be added later)

## Technical Considerations

- **GITHUB_TOKEN permissions:** The default token has `packages: write` when explicitly granted in workflow
- **QEMU for ARM64:** ARM64 builds on AMD64 runners use QEMU emulation, which is slower but works
- **Trivy scan timing:** Scan happens on the multi-arch manifest; both platforms are checked
- **Cache tag:** Using `buildcache` tag keeps cache separate from release images
- **yq binary:** Currently downloads `yq_linux_amd64` hardcoded; needs `TARGETARCH` variable
- **Existing Dockerfile location:** `./Dockerfile` in repository root

## Success Metrics

- Container images successfully pushed to GHCR on every main branch merge
- Version-tagged releases produce correctly tagged images within 10 minutes
- Build cache reduces subsequent build times by at least 50%
- Zero critical vulnerabilities in published images
- Both AMD64 and ARM64 images function correctly when pulled

## Open Questions

- Should we add a scheduled build (e.g., weekly) to catch new vulnerabilities in base images?
- Should HIGH vulnerabilities also fail the build, or just CRITICAL?
- Do we want to add image signing with Sigstore/cosign in a future iteration?
