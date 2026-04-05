# Merge Notes

## Phase 0
- Fresh project scaffold created.
- Toolchain pinned to Zig `0.15.2`.
- Stdlib-first policy frozen for REST/core layers.
- Ticker kept parser-first with runtime dependency deferred to ticker phase.

## Phase 1 foundation
- Added shared auth, transport, envelope, and time helpers before endpoint parallelization.
- Froze shared-core conventions in `docs/design.md` so deckhands can reuse the same request/auth/parsing path.

## Wave 1: user and margins
- Added transport-agnostic request descriptors and envelope parsers for `/user/profile`, `/user/profile/full`, `/user/margins`, `/user/margins/{segment}`, `/margins/orders`, `/margins/basket`, and `/charges/orders`.
- Added typed wire models for user profiles, user-margin segments, order margins, basket totals, and order charges.
- Integration note: test imports were normalized through `@import("kiteconnect")` to avoid Zig module-collision errors in the shared smoke target.

## Wave 1: orders and trades
- Added transport-agnostic orders/trades endpoint helpers for request metadata, path building, and envelope parsing.
- Added order and trade wire models plus focused endpoint parsing tests.
- Public export wiring for orders/trades was landed centrally by bosun because `src/lib.zig` remained reserved.

## Wave 1: portfolio and market
- Added portfolio endpoint helpers for holdings, holdings summary/compact, auction instruments, positions, and convert-position form encoding.
- Added market endpoint helpers for quote/LTP/OHLC request contracts, historical path/query building, and historical envelope decoding.
- Added portfolio and market wire models with smoke-integrated tests routed through the shared `kiteconnect` module.

## Phase 2A: executable transport contract freeze
- Added `transport.RequestSpec`, `transport.RequestBody`, `transport.ResponseFormat`, and `transport.PreparedRequest` as the shared request-preparation contract for later runtime execution.
- Added `Client.prepareRequest(...)` to centralize URL assembly, auth-header injection, accept/content-type defaults, and query attachment.
- Added generic error-envelope parsing in `src/models/envelope.zig` plus a stable `TransportError` baseline in `src/errors.zig`.

## Wave 2: session/auth
- Added `src/endpoints/session.zig`, `src/models/session.zig`, and `tests/session_test.zig`.
- Implemented request contracts and form builders for `POST /session/token`, `POST /session/refresh_token`, and `DELETE /session/token`.
- Implemented success-envelope parsing for session creation, token renewal, and token invalidation payloads using the shared checksum/envelope helpers.

## Wave 2: market instruments CSV runtime
- Extended `src/endpoints/market.zig` with CSV-aware request specs and runtime parsers for `/instruments`, `/instruments/{exchange}`, and `/mf/instruments` payloads.
- Added owned response wrappers plus CSV parsing with quoted-field and escaped-quote handling.
- Tightened market model parity by changing instrument `lot_size` to `u64`.

## Wave 2: GTT, mutual funds, and alerts
- Added endpoint and model coverage for GTT, mutual funds, and alerts request metadata, paths, query/form builders, and success-envelope parsing.
- Kept bosun-owned export wiring and central docs reconciliation out of the deckhand scope, then integrated them centrally.

## Phase 2B: HTTP response and error-mapping baseline
- Added centralized success-response content-type validation in `src/http.zig` keyed off `transport.ResponseFormat`.
- Added `http.parseApiError(...)` to decode JSON error envelopes into a stable `ApiError` view.
- Added fallback HTTP-status-to-error-type mapping in `src/errors.zig` and shared success-status classification in `src/transport.zig`.
- Added shared response classification helpers so prepared request specs can drive success-vs-error dispatch without per-endpoint branching.

## Phase 2C: HTTP execution baseline
- Added `http.executePrepared(...)` to execute `transport.PreparedRequest` values with `std.http.Client` and return owned response bodies.
- Added `http.executeClassified(...)`, `Client.executePrepared(...)`, and `Client.execute(...)` as the shared runtime execution path.
- Added execution-time normalization for `GET`/`DELETE` form payloads so query-encoded endpoints match upstream SDK semantics.
- Fixed API-error ownership so classified errors now duplicate message/error-type strings instead of returning slices tied to a freed parsed envelope.
- Added owned JSON decoding helpers that retain response-body backing until explicit deinit, preventing dangling parsed slices.
- Migrated the session/auth family onto the new runtime path with endpoint-local execute+decode helpers and result unions.
- Migrated the user/profile + margins family onto the same runtime pattern, including auth-required JSON request specs and decoded success/error result unions.
- Migrated the alerts family onto the same runtime pattern, including request specs for list/detail/history/mutation APIs and decoded success/error result unions.
- Migrated the GTT family onto the same runtime pattern, including query-based list requests and mutation request specs with decoded success/error result unions.
- Migrated the orders/trades family onto the same runtime pattern, including list/history/per-order-trades flows plus place/modify/cancel request specs and decoded success/error result unions.
- Migrated the portfolio family onto the same runtime pattern, including holdings variants, auction instruments, positions, and convert-position request specs with decoded success/error result unions.
- Migrated the mutual-funds family onto the same runtime pattern, including orders, SIPs, holdings, and instrument-info request specs with decoded success/error result unions.
- Migrated the market family onto the shared runtime path too, including quote/LTP/OHLC owned JSON decoding, historical execute+decode coverage, and CSV-backed instruments / MF instruments execution with central content-type validation.
- Started the ticker subsystem proper with a parser/session split: binary packet decoding and text-envelope parsing now live in `src/ticker/parser.zig`, while `src/ticker/session.zig` now covers websocket URL/command encoding, reconnect backoff, subscription-state snapshots, resubscribe batch generation, and a transport-agnostic session loop for binary/text frame dispatch.

## Phase 2C+: ticker websocket backend + fixture-backed REST validation
- Added `src/ticker/websocket_transport.zig` as the concrete backend adapter over `karlseguin/websocket.zig`, wiring the transport-agnostic ticker session loop to a real websocket client while keeping parser/session contracts backend-neutral.
- Added `tests/mock_repo_test.zig` fixture-backed REST parser validation using the upstream `kiteconnect-mocks` corpus across session/user, orders/portfolio, market, GTT/alerts, and mutual-funds families.
- Fixture tests now intentionally skip (`error.SkipZigTest`) when the `kiteconnect-mocks` repo is absent from known local paths.
- Some upstream JSON fixtures require lightweight normalization for compatibility (notably bare `{"data": ...}` envelopes), so the harness prepends `"status":"success"` before parser assertions where needed.

## Notes for future deckhands
- Do not introduce shared helpers in endpoint modules if they are likely to be reused elsewhere; ask bosun to land shared abstractions first.
- Update `docs/parity-matrix.md` for every implemented public feature.
- Keep public API doc comments current.
