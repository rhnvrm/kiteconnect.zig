//! kiteconnect.zig public library entrypoint.

const std = @import("std");

/// Main Kite Connect client type.
pub const Client = @import("client.zig").Client;
/// Environment-driven client configuration.
pub const Config = @import("client.zig").Config;
/// Error set used while preparing executable requests.
pub const PrepareRequestError = @import("client.zig").PrepareRequestError;
/// Error set used while classifying executed responses.
pub const ClassifyResponseError = @import("client.zig").ClassifyResponseError;
/// Error set used while executing prepared requests.
pub const ExecutePreparedError = @import("client.zig").ExecutePreparedError;
/// Error set used while preparing, executing, and classifying requests.
pub const ExecuteRequestError = @import("client.zig").ExecuteRequestError;
/// Shared HTTP helpers and request encoding utilities.
pub const http = @import("http.zig");
/// Owned runtime response returned by the execution layer.
pub const OwnedResponse = @import("http.zig").OwnedResponse;
/// Classified runtime response returned by `Client.execute(...)`.
pub const ExecutedResponse = @import("http.zig").ExecutedResponse;
/// Shared authentication and authorization helpers.
pub const auth = @import("auth.zig");
/// Shared transport contracts and URL helpers.
pub const transport = @import("transport.zig");
/// Shared time helpers and conventions.
pub const time = @import("time.zig");
/// Shared envelope models and parsers.
pub const envelope = @import("models/envelope.zig");
/// User endpoint helpers.
pub const user = @import("endpoints/user.zig");
/// Margins endpoint helpers.
pub const margins = @import("endpoints/margins.zig");
/// Orders and trades endpoint helpers.
pub const orders = @import("endpoints/orders.zig");
/// Session/auth endpoint helpers.
pub const session = @import("endpoints/session.zig");
/// Portfolio endpoint helpers.
pub const portfolio = @import("endpoints/portfolio.zig");
/// Market-data endpoint helpers.
pub const market = @import("endpoints/market.zig");
/// GTT endpoint helpers.
pub const gtt = @import("endpoints/gtt.zig");
/// Mutual-funds endpoint helpers.
pub const mutual_funds = @import("endpoints/mutual_funds.zig");
/// Alerts endpoint helpers.
pub const alerts = @import("endpoints/alerts.zig");
/// Ticker binary/text parser helpers.
pub const ticker = @import("ticker/parser.zig");
/// Ticker session/runtime helpers.
pub const ticker_session = @import("ticker/session.zig");
/// Concrete websocket transport backend for the ticker runtime.
pub const ticker_websocket = @import("ticker/websocket_transport.zig");
/// User-domain wire models.
pub const user_models = @import("models/user.zig");
/// Margin-domain wire models.
pub const margin_models = @import("models/margins.zig");
/// Order-domain wire models.
pub const order_models = @import("models/orders.zig");
/// Trade-domain wire models.
pub const trade_models = @import("models/trades.zig");
/// Session/auth-domain wire models.
pub const session_models = @import("models/session.zig");
/// Portfolio-domain wire models.
pub const portfolio_models = @import("models/portfolio.zig");
/// Market-domain wire models.
pub const market_models = @import("models/market.zig");
/// GTT-domain wire models.
pub const gtt_models = @import("models/gtt.zig");
/// Mutual-funds domain wire models.
pub const mutual_fund_models = @import("models/mutual_funds.zig");
/// Alerts-domain wire models.
pub const alert_models = @import("models/alerts.zig");
/// Ticker-domain wire models.
pub const ticker_models = @import("models/ticker.zig");
/// Error set used by request encoding helpers.
pub const RequestEncodingError = http.RequestEncodingError;
/// Error set used by auth helpers.
pub const AuthError = auth.AuthError;
/// Error set used by URL-building helpers.
pub const UrlError = transport.UrlError;
/// Common transport/runtime failures.
pub const TransportError = @import("errors.zig").TransportError;
/// Structured API error payload.
pub const ApiError = @import("errors.zig").ApiError;
/// Known runtime environments.
pub const Environment = @import("constants.zig").Environment;
/// Minimal client state used for bootstrap diagnostics.
pub const ClientState = @import("models/common.zig").ClientState;

test {
    std.testing.refAllDecls(@This());
}
