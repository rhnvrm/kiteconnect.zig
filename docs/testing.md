# Testing

## Layers
1. Unit tests for helpers, request builders, parsing, error mapping, and endpoint-local runtime contracts.
2. Fixture-backed REST parser validation using upstream `kiteconnect-mocks` payloads.
3. Mock integration tests for HTTP/ticker runtime behavior without live credentials.
4. Optional live tests behind environment variables.

## Fixture-backed REST validation (`tests/mock_repo_test.zig`)
- The suite reads JSON/CSV fixtures from one of:
  - `../../zerodha/kiteconnect-mocks`
  - `../zerodha/kiteconnect-mocks`
  - `workspace/code/github.com/zerodha/kiteconnect-mocks`
- If none of those paths exist, tests return `error.SkipZigTest` (skip rather than fail).
- Some upstream JSON fixtures use bare `{"data": ...}` envelopes without an explicit status field. The harness applies lightweight normalization by prepending `"status":"success"` when needed before handing payloads to endpoint parsers.
- Coverage spans session/user, orders/portfolio, market (JSON + CSV), GTT/alerts, and mutual-funds payload families.
- The fixture suite now also validates alert mutation parsing against optional `data` payloads, which keeps delete-style `{"status":"success","data":null}` envelopes compatible with shared success parsing.
- The fixture suite also now asserts Go-shaped bool success envelopes for session invalidation and convert-position responses.
- The fixture suite also now asserts richer margins parity (nested charges/GST, `var`, leverage, basket-level orders/charges) and richer mutual-funds parity (purchase/status metadata, fully typed SIP `step_up` maps and fund-source fields, holding `fund` / `pledged_quantity`, and typed holding-breakdown trades for `/mf/holdings/{isin}`).
- The fixture suite now also asserts typed GTT metadata, typed alert-history metadata, and Go-style order `meta` map decoding.

## Ticker coverage
- `src/ticker/parser.zig` tests validate binary packet splitting/decoding and typed text message parsing.
- `src/ticker/session.zig` tests validate websocket command encoding, reconnect backoff, state replay, and runtime dispatch hooks.
- `src/ticker/websocket_transport.zig` tests validate websocket URL path/query handling and handshake host-header construction for the concrete backend.

## Endpoint-local parity coverage highlights
- alerts route/query tests cover UUID detail/history paths, repeated `uuid` delete query params, and null-data delete envelopes
- portfolio tests cover holdings-authorisation request/redirect helpers and payload encoding
- margins tests cover order/basket/charges request specs plus gokite-compatible compact / consider_positions query builders and richer calculator payload shapes
- mutual-funds tests cover holdings-info/allotments request specs plus newer SIP optional form fields, typed `step_up` map decoding, typed holding-breakdown decoding, and expanded fixture assertions
- session/portfolio tests cover bool success envelopes for invalidate-token and convert-position
- GTT/alerts tests cover typed trigger metadata and alert-history metadata decoding

## Current coverage summary
- login URL smoke test
- JSON parsing smoke test
- basic client bootstrap state test
- fixture-backed REST parser validation against `kiteconnect-mocks`
- ticker session/runtime and websocket transport baseline tests
- endpoint-local parity tests for alerts, portfolio holdings authorisation, margins, and mutual funds
- compile-checked runnable examples via `zig build examples` (`basic_auth.zig`, `advanced_rest.zig`, `ticker.zig`)
