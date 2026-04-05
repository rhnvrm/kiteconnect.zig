# kiteconnect.zig

A Zig port of Zerodha's Kite Connect client libraries, targeting full feature parity with `gokiteconnect` while staying idiomatic in Zig.

## Status

Substantial standalone Zig port with broad pre-live parity coverage.

Current baseline includes:
- stdlib-first REST client/runtime with owned response decoding
- endpoint families for session, user, margins, orders/trades, portfolio, market, GTT, mutual funds, and alerts
- ticker parser/session runtime plus a concrete `websocket.zig` transport backend
- fixture-backed REST validation against `kiteconnect-mocks`
- post-audit parity follow-ups for alerts UUID/delete semantics, holdings authorisation, executable margins APIs, mutual-funds holdings/allotments coverage, and broader typed user/order/trade surfaces

Remaining work is mainly live Zerodha validation and any behavior confirmed only against real accounts / live websocket traffic.

## Toolchain

- Zig `0.15.2`
- Optional Nix dev shell via `flake.nix`
- Task runner via `justfile`

## Quickstart

### With Nix

```bash
nix --extra-experimental-features 'nix-command flakes' develop --impure path:$PWD
just check
```

### Without Nix

Install Zig `0.15.2`, then run:

```bash
just check
```

## Docs

- API docs: `zig build docs` then serve `zig-out/docs/`
- Project docs: `docs/`

## Examples

The repo now includes runnable examples under `examples/`:
- `basic_auth.zig` — login URL, request-token exchange, profile, and margins
- `advanced_rest.zig` — broader REST walkthrough across portfolio, orders/trades, GTT, alerts, and mutual funds
- `ticker.zig` — websocket ticker setup, subscriptions, mode changes, and callbacks

Useful commands:

```bash
zig build examples           # compile all examples
zig build example-basic      # run basic authenticated REST example
zig build example-advanced   # run broader REST showcase
zig build example-ticker     # run ticker/websocket example
```

Examples use environment variables for credentials and optional route-specific inputs. See the inline usage text in each example for the exact variables.

## Project documentation

- `docs/architecture.md` — top-level module and subsystem layout
- `docs/design-decisions.md` — compact record of key architectural choices
- `docs/design.md` — working implementation constraints and ownership rules
- `docs/parity-matrix.md` — feature tracking against upstream SDKs
- `docs/testing.md` — unit, fixture, mock, and live-test strategy
- `docs/contributing.md` — toolchain, doc policy, and review checklist
- `docs/tech-spike.md` — pre-implementation dependency and tooling decisions
- `docs/autonomous-status.md` — current autonomous execution status

## License

MIT
