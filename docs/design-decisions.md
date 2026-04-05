# Design Decisions

## DD-001: Stdlib-first bootstrap
Use Zig stdlib for REST/core infrastructure unless a concrete gap forces a dependency.

## DD-002: Parser-first ticker
Implement ticker packet parsing independently of the network runtime.

## DD-003: Dual docs surfaces
Use Zig autodoc for API reference and markdown docs for project/development documentation.
