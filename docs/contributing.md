# Contributing

## Toolchain
- Required Zig version: `0.15.2`
- Recommended workflow:
  - `nix develop`
  - `just check`

## Documentation policy
- Use `//!` for public module docs.
- Use `///` for public declarations.
- Document params, return behavior, errors, ownership, and domain-specific semantics where relevant.

## Review checklist
- `just check` passes.
- Public API docs are present.
- `docs/parity-matrix.md` reflects implementation state.
- `docs/merge-notes.md` captures assumptions and unresolved issues.
