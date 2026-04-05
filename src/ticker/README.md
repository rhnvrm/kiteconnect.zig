# Ticker

This directory contains the current Kite ticker implementation split across parser, session, and transport layers.

Current split:
- `parser.zig`: binary packet splitting, mode-specific packet decoding, and text-envelope parsing (typed `order`, `error`, and `message` with fallback to a generic envelope when typed decoding fails)
- `session.zig`: websocket URL construction, outbound subscribe/unsubscribe/mode command encoding, reconnect backoff policy, subscription-state tracking, resubscribe batch generation, and a transport-agnostic session loop
- `websocket_transport.zig`: concrete websocket adapter over `karlseguin/websocket.zig` that wires the session transport contract to a real websocket client

Still remaining:
- broader live behavioral validation against the real Kite ticker service with real credentials/account state
- any additional hardening required if live traffic reveals new text-frame variants beyond the documented `order` / `error` / `message` set
