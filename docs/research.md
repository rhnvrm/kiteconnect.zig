# Research Notes

## Source hierarchy
1. Official Kite Connect docs
2. `zerodha/gokiteconnect`
3. `zerodha/pykiteconnect`
4. `zerodha/kiteconnectjs`

## Confirmed protocol notes
- Login URL: `https://kite.zerodha.com/connect/login?v=3&api_key=...`
- Auth checksum: SHA-256 of `api_key + request_token + api_secret`
- Authorization header: `Authorization: token api_key:access_token`
- REST is form-encoded with JSON envelopes
- Upstream mock fixtures (`kiteconnect-mocks`) are useful for parser validation but not always shape-identical to live envelopes; compatibility normalization may be required in tests (e.g., bare `data` envelopes).
- Ticker uses binary packets plus JSON text frames
- Official WebSocket docs list text-frame `type` variants `order`, `error`, and `message` (`message` carries broker alert text)
- Upstream SDK behavior is conservative: Go/Python/JS special-case `order` (and `error` in Go/Python), while malformed or unknown text payloads are ignored

## Ticker spike summary
- Parser-first approach remains mandatory.
- Session/runtime layer should stay separate from parser logic; concrete websocket backends should remain adapter modules instead of leaking into parser/session contracts.
- Upstream Go parity buckets for ticker are now covered at baseline: binary frame packet splitting, mode-specific packet decoding, text-frame JSON handling for `order` / `error` / `message`, outbound subscribe/unsubscribe/mode command encoding, reconnect/resubscribe session behavior, and concrete websocket transport wiring.
- The concrete backend is now implemented via `src/ticker/websocket_transport.zig` on top of `karlseguin/websocket.zig`, with URL parsing and handshake header behavior tested locally.
- Remaining ticker research/validation work is mostly live-behavior validation: reconnect behavior under real network churn and confirmation that real traffic stays within the documented `order` / `error` / `message` text-frame set.
