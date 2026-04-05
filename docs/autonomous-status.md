# Autonomous Status

## Current phase
Post-audit parity closure after HTTP execution, ticker websocket backend, and fixture-backed validation

## Completed
- Fresh project scaffold created.
- Zig pinned to `0.15.2` in `build.zig.zon`, `flake.nix`, and CI.
- `flake.nix`, `justfile`, and CI baseline added.
- Core bootstrap modules added:
  - `src/lib.zig`
  - `src/client.zig`
  - `src/http.zig`
  - `src/auth.zig`
  - `src/transport.zig`
  - `src/time.zig`
  - `src/errors.zig`
  - `src/constants.zig`
  - `src/models/common.zig`
  - `src/models/envelope.zig`
- Wave 1 endpoint/model coverage landed for:
  - user + margins
  - orders + trades
  - portfolio
  - market historical/query helpers
- Shared smoke target now imports Wave 1 endpoint tests through `@import("kiteconnect")`.
- Docs skeleton added and Phase 1 parity/merge notes updated.
- Phase 2A executable request preparation landed via shared transport/client contracts.
- Generic error-envelope parsing baseline landed for later HTTP status/error mapping work.
- Wave 2 session/auth request-contract and parser coverage landed.
- Market instruments-family CSV/runtime parsing landed.
- GTT, mutual funds, and alerts endpoint-family coverage landed.
- Central HTTP response content-type validation and API-error normalization baseline landed.
- Shared response classification/dispatch baseline landed on top of prepared request specs.
- Actual stdlib HTTP execution landed on top of prepared requests, including owned response bodies and shared execute/classify helpers.
- Shared owned JSON decoding helpers landed so parsed success payloads can safely retain borrowed slices until explicit deinit.
- Session/auth is now the first endpoint family migrated onto the real execute+decode path, establishing the pattern for later families.
- User/profile + margins now also run on the same execute+decode baseline, confirming the pattern works for authenticated read endpoints too.
- Alerts now run on the same execute+decode baseline, confirming the pattern works for mixed read/write JSON endpoint families too.
- GTT now runs on the same execute+decode baseline, covering another mutation-heavy family with query and form request shapes.
- Orders/trades now run on the same execute+decode baseline, covering list, history, order-trades, and mutation endpoints on the shared runtime path.
- Portfolio now runs on the same execute+decode baseline, covering holdings variants, auctions, positions, and convert-position endpoints on the shared runtime path.
- Mutual funds now run on the same execute+decode baseline, covering orders, SIPs, holdings, and instrument-info endpoints on the shared runtime path.
- Market now also runs on the shared execute+decode baseline, covering quote/LTP/OHLC JSON envelopes, historical candle decoding, and CSV-backed instruments / MF instruments endpoints on the real runtime path.
- Ticker runtime now includes a concrete websocket backend via `src/ticker/websocket_transport.zig` (`karlseguin/websocket.zig`), on top of the existing parser/session split (binary packet splitting, mode-aware decode, typed `order` / `error` / `message` text handling with safe fallback, reconnect backoff, subscription-state snapshots, and resubscribe replay).
- Fixture-backed REST parser validation now runs through `tests/mock_repo_test.zig` against `kiteconnect-mocks` fixtures across all endpoint families.
- Fixture test behavior is resilient by design: the suite skips when `kiteconnect-mocks` is absent (`error.SkipZigTest`) and normalizes bare `{"data": ...}` JSON envelopes into success envelopes before assertions.
- Post-audit parity follow-ups landed for alerts UUID/history/delete semantics, query-based multi-UUID alert deletion, and null-data alert delete envelopes.
- Portfolio now includes holdings authorisation request/execute helpers plus redirect-URL construction.
- Session helpers now include access-token auto-persist ergonomics on successful generate/renew flows, backed by client-owned token storage.
- Session invalidation and portfolio convert-position success envelopes are now typed as `bool`, matching upstream fixture/Go behavior.
- Margins now expose execute+decode runtime coverage for order margins, basket margins, and order charges, including gokite-style compact / consider_positions query helpers.
- Mutual funds now include holdings-by-ISIN and allotments request/execute helpers, plus wider SIP form coverage.
- User, orders, and trades models now expose additional low-risk upstream fields needed for fuller typed parity.
- Orders now model Go-style `meta` payloads as `std.json.ArrayHashMap(std.json.Value)` rather than opaque top-level JSON values.
- GTT and alerts now expose stronger typed metadata for trigger rejection info and alert-history `meta[]` rows.
- Margins models now expose richer calculator parity fields, including `bo`, `cash`, `var`, nested PNL, leverage, and nested charges/GST breakdowns, with basket-level orders/charges coverage validated against upstream fixtures.
- Mutual-funds models now expose richer typed order, SIP, and holding fields from upstream mocks/reference SDKs, including purchase/status metadata, a Go-style typed SIP `step_up` map, `fund_source`, holding `pledged_quantity`, and typed `/mf/holdings/{isin}` breakdown trades.
- Runnable examples now live under `examples/`, with build-wired compile/run steps for a basic auth flow, broader REST showcase, and ticker/websocket usage.
- Example integration also flushed out and fixed Zig 0.15.2 compile issues in the shared HTTP decompression path and ticker websocket transport.

## Verified locally
- `nix --extra-experimental-features 'nix-command flakes' develop --impure path:$PWD -c just test`
- `nix --extra-experimental-features 'nix-command flakes' develop --impure path:$PWD -c just check`
- `nix --extra-experimental-features 'nix-command flakes' develop --impure path:$PWD -c just docs`
- `nix --extra-experimental-features 'nix-command flakes' develop --impure path:$PWD -c zig build examples`

## Remaining before next execution wave
- validate live Zerodha behavior for any semantics that cannot be proven from fixtures/reference code alone (especially ticker reconnect/resubscribe and any undocumented text-frame variants)
- confirm route behavior that may still depend on live server behavior rather than fixtures/reference SDKs
- decide whether to add broader endpoint-facing `Client` convenience methods beyond the currently landed parity helpers
- decide whether any remaining `std.json.Value` surfaces that intentionally mirror upstream `interface{}` payloads (ticker text `data`, alert `order_meta`, generic API error `data`, autoslice child error `data`) should stay dynamic or gain additional typed helper wrappers after live observation

## Review follow-ups applied
- Added public API doc comments for `src/lib.zig` re-exports.
- Marked login URL generation as `done` in `docs/parity-matrix.md`.
- Added tracked subtree docs in `src/endpoints/` and `src/ticker/`.
- Updated `README.md` to reflect current docs instead of planned docs.
- Clarified ownership for `http.loginUrl` and poison-only semantics for `Client.deinit`.
- Added `just docs` to CI.

## Live blockers
None yet. Live credentials are not required for current work.
