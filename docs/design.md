# Design

## Goals
- Full feature parity with `zerodha/gokiteconnect`
- Zig-first implementation choices where they do not compromise protocol parity
- Autonomous execution through mock/reference validation, stopping only at live credential checks

## Frozen bootstrap decisions
- Zig version: `0.15.2`
- REST/core layers: stdlib-first
- Ticker runtime: parser/session logic stays transport-agnostic, with a narrow concrete backend adapter in `src/ticker/websocket_transport.zig`
- API docs: Zig autodoc
- Project docs: markdown in `docs/`, optionally rendered later with Moat

## Initial module layout
- `src/lib.zig`: public exports
- `src/client.zig`: high-level client configuration and state
- `src/auth.zig`: checksum and authorization helpers
- `src/http.zig`: request construction helpers
- `src/transport.zig`: URL-building and request contracts
- `src/time.zig`: shared time parsing helpers
- `src/errors.zig`: transport and API error types
- `src/constants.zig`: enums/constants
- `src/models/`: shared models and envelope helpers
- `src/endpoints/`: endpoint-family implementations
- `src/ticker/`: parser + session layers

## Ownership rules
- Caller-owned inputs are borrowed unless otherwise documented.
- Any heap-allocated return value must clearly document who frees it.
- Avoid hidden global state.
- Keep transport helpers reusable and side-effect-light.

## Core conventions frozen before parallel work
- Endpoint modules should build on shared client/auth/transport helpers rather than recreating request assembly logic.
- URL construction goes through `src/transport.zig`.
- Auth header formatting and checksum generation go through `src/auth.zig`.
- Success-envelope parsing goes through `src/models/envelope.zig` unless an endpoint has a documented shape exception.
- Time parsing helpers should accumulate in `src/time.zig` rather than per-endpoint ad hoc parsers.

## Phase 2A runtime contract freeze
- `transport.RequestSpec` is now the central request-description shape for executable REST work.
- `Client.prepareRequest(...)` is the shared bridge from endpoint metadata into an executable request plan.
- Prepared requests own their absolute URL and optional authorization header allocations; request-body slices remain borrowed from endpoint builders.
- Response expectations must be declared up front via `transport.ResponseFormat` (`json`, `csv`, `raw`) so later transport/runtime work can dispatch decoding consistently.
- Content type is inferred centrally from request-body kind (`form`, `json`, `raw`, or none`) rather than re-decided inside endpoint modules.
- Generic API error-envelope parsing lives in `src/models/envelope.zig`, while stable runtime-level failures live in `src/errors.zig`.
- Instruments-family CSV/runtime parsing remains deferred even though request-contract coverage exists.

## Phase 2B HTTP response baseline
- Success-response content-type validation now lives centrally in `src/http.zig` instead of being re-implemented per endpoint family.
- HTTP error responses are expected to be JSON envelopes and can be normalized through `http.parseApiError(...)` into a stable `ApiError` view.
- `errors.fallbackErrorType(...)` provides a deterministic fallback when a response omits `error_type`, matching the baseline error classes used by upstream SDKs.
- `transport.isSuccessStatus(...)` is the shared status classifier for future response-execution work.
- `http.classifyResponse(...)` and `Client.classifyResponse(...)` now provide a shared success-vs-error dispatch layer keyed off `transport.ResponseFormat`.

## Phase 2C HTTP execution baseline
- `http.executePrepared(...)` now turns `transport.PreparedRequest` into an actual stdlib HTTP request using `std.http.Client`.
- Runtime execution injects `Accept`, `User-Agent`, `Authorization`, and `X-Kite-Version: 3` headers from the shared request contract.
- Success bodies are returned as owned `http.OwnedResponse` values so later endpoint decoders can parse JSON/CSV/raw payloads without borrowing request internals.
- `http.executeClassified(...)` and `Client.execute(...)` compose preparation, execution, and response classification into one shared runtime path.
- Form payloads on `GET`/`DELETE` requests are normalized into query strings during execution, matching upstream Kite SDK request semantics.
- API-error classification now returns owned `ApiError` strings, avoiding the earlier dangling-slice risk from parsed JSON envelopes.
- `http.parseOwnedJson(...)` and `http.parseOwnedSuccessEnvelope(...)` now retain the backing response body so parsed JSON slices remain valid until explicit deinit.
- The session/auth family is the first pattern-setting endpoint wave migrated onto the new runtime path, using endpoint-local result unions that preserve either decoded success envelopes or owned API errors.
- The user/profile + margins family now follows the same execute+decode pattern, confirming that the approach generalizes beyond auth endpoints.
- The alerts family now also uses the same runtime shape for list/detail/history/mutation calls, showing the pattern works across both read and write JSON endpoints.
- The GTT family now follows the same path as well, including query-driven list operations and mutation endpoints with form bodies.
- The orders/trades family now also runs on the execute+decode path, covering list, history, per-order trades, and mutation flows with shared owned JSON decoding.
- The portfolio family now runs on the same execute+decode path too, covering holdings variants, auctions, positions, and convert-position flows.
- The mutual-funds family now also runs on the same execute+decode path, covering orders, SIPs, holdings, and instrument-info endpoints with the shared owned-response decode model.
- The market family now also runs on the shared runtime path end-to-end: quote/LTP/OHLC use owned JSON envelope decoding, historical data uses the shared execute/classify path plus endpoint-local candle decoding, and instruments / MF instruments use the shared runtime path with CSV content-type validation and owned CSV row parsing.
- Ticker work now has a runtime baseline with the parser/session split preserved: `src/ticker/parser.zig` owns binary packet splitting, mode-aware packet decoding, and text-envelope parsing; `src/ticker/session.zig` owns reconnect + resubscribe session behavior; and `src/ticker/websocket_transport.zig` provides a concrete `karlseguin/websocket.zig` adapter that wires the transport-agnostic loop to a real websocket client.

## Review requirements
- Every public module gets `//!` docs.
- Every public API declaration gets `///` docs.
- Public API changes require parity-matrix updates.
