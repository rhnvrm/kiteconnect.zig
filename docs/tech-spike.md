# Technical Spike Summary

## Decisions

### Toolchain
- Pin Zig to `0.15.2`.
- Enforce the version in:
  - `build.zig.zon`
  - `flake.nix`
  - CI
- Add explicit `zig version` checks in CI because `minimum_zig_version` is advisory.

### Developer environment
- Use a fresh-project baseline with:
  - `flake.nix`
  - `justfile`
  - GitHub Actions CI
  - docs skeleton
- Initial `just` commands:
  - `fmt`
  - `fmt-check`
  - `build`
  - `test`
  - `test-release`
  - `docs`
  - `check`
  - `ci`

### Documentation
- Zig autodoc is the canonical API reference path.
- Narrative docs stay in `docs/`.
- Moat may be added as a rendering layer for project docs, but is not required for initial execution.
- Do not build a custom autodoc-to-Markdown bridge now.

### Core dependency policy
- Stdlib-first for:
  - HTTP
  - gzip/deflate
  - JSON
  - crypto/auth helpers
  - tests/build
- No third-party deps should be introduced during REST/core bootstrap.

### Ticker dependency policy
- Keep ticker protocol logic local to the project.
- Current preferred runtime backend for the WebSocket phase: `karlseguin/websocket.zig`.
- Re-evaluate only if live validation exposes TLS/runtime incompatibility.

## Rejected alternatives
- Nightly/master Zig for baseline development.
- Premature third-party HTTP/JSON frameworks.
- Custom docs pipeline before API/docs foundations exist.
- Starting ticker with a WebSocket dependency before parser-first validation is in place.

## Risks
- Zig stdlib/build APIs may shift with version changes.
- WebSocket backend choice remains the biggest implementation risk until live validation.
- Dual doc surfaces can drift if the docs checklist is not enforced in review.
