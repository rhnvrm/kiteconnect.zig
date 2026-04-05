# Parity Matrix

## Status legend
- `planned`
- `in-progress`
- `done`
- `deferred`

## Core
- client init/config: done
- login URL generation: done
- authorization header construction: done
- owned access-token storage / mutation ergonomics: done
- request preparation / executable transport contract: done
- response classification / dispatch baseline: done
- actual HTTP execution baseline: done
- shared owned JSON success decoding baseline: done
- session generation request contracts: done
- session generation execute+decode baseline: done
- session generation auto-store access token helper: done
- token renewal/invalidation request contracts: done
- token renewal/invalidation execute+decode baseline: done
- token renewal auto-store access token helper: done
- token invalidation success payload typed as `bool`: done
- envelope parsing: done
- error-envelope parsing baseline: done
- URL construction helpers: done
- API error mapping: done
- response content-type validation baseline: done
- time parsing baseline: done

## User
- profile request contracts: done
- profile execute+decode baseline: done
- full profile request contracts: done
- full profile execute+decode baseline: done
- margins request contracts: done
- margins execute+decode baseline: done
- segment margins request contracts: done
- segment margins execute+decode baseline: done

## Margins
- order margins: done
- basket margins: done
- order charges: done
- richer typed margin calculator models (`bo`, `cash`, `var`, PNL, leverage, nested charges/GST): done
- basket-level orders/charges fixture parity: done

## Orders / Trades
- orders request contracts: done
- orders execute+decode baseline: done
- trades request contracts: done
- trades execute+decode baseline: done
- order history request contracts: done
- order history execute+decode baseline: done
- order trades request contracts: done
- order trades execute+decode baseline: done
- place/modify/cancel request contracts: done
- place/modify/cancel execute+decode baseline: done
- Go-style order `meta` parity (`map[string]interface{}` equivalent via `std.json.ArrayHashMap(std.json.Value)`): done

## Portfolio
- holdings request contracts: done
- holdings execute+decode baseline: done
- holdings summary request contracts: done
- holdings summary execute+decode baseline: done
- holdings compact request contracts: done
- holdings compact execute+decode baseline: done
- holdings authorisation request contracts: done
- holdings authorisation execute+decode baseline: done
- holdings authorisation redirect URL helper: done
- auction instruments request contracts: done
- auction instruments execute+decode baseline: done
- positions request contracts: done
- positions execute+decode baseline: done
- convert position request contracts: done
- convert position execute+decode baseline: done
- convert position success payload typed as `bool`: done

## Market
- quote request contracts: done
- quote execute+decode baseline: done
- LTP request contracts: done
- LTP execute+decode baseline: done
- OHLC request contracts: done
- OHLC execute+decode baseline: done
- historical data request contracts: done
- historical data execute+decode baseline: done
- instruments request contracts: done
- instruments execute+decode baseline: done
- MF instruments request contracts: done
- MF instruments execute+decode baseline: done

## GTT
- CRUD request contracts: done
- CRUD execute+decode baseline: done
- typed GTT rejection metadata (`meta.rejection_reason`): done

## Mutual Funds
- orders request contracts: done
- orders execute+decode baseline: done
- SIPs request contracts: done
- SIPs execute+decode baseline: done
- holdings request contracts: done
- holdings execute+decode baseline: done
- holding info request contracts: done
- holding info execute+decode baseline: done
- allotments request contracts: done
- allotments execute+decode baseline: done
- instrument info request contracts: done
- instrument info execute+decode baseline: done
- richer typed order fields (`purchase_type`, `fund`, `status_message`, exchange/settlement metadata): done
- richer typed SIP fields (`sip_reg_num`, `dividend_type`, `trigger_price`, `step_up`, `fund_source`, completed/pending instalments): done
- Go-style typed SIP `step_up` map parity (`map[string]int` equivalent via `std.json.ArrayHashMap(i64)`): done
- richer typed holding fields (`fund`, `pledged_quantity`): done
- typed `/mf/holdings/{isin}` breakdown parity via `MfHoldingBreakdown` / `MfTrade`: done

## Alerts
- CRUD/history request contracts: done
- CRUD/history execute+decode baseline: done
- UUID detail/history route semantics: done
- query-based multi-UUID delete semantics: done
- delete `data: null` success-envelope handling: done
- typed alert-history `meta[]` parity: done

## Ticker
- parser: done
- session command/reconnect baseline: done
- subscription-state/resubscribe planning baseline: done
- websocket lifecycle/session runtime: done
- reconnect/resubscribe: done
- order/error/message text messages baseline: done
- malformed/unknown text-frame fallback handling: done
- concrete websocket backend adapter (`websocket.zig`): done
