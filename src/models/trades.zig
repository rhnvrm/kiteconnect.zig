//! Trade-domain wire models used by trades endpoints.

/// Common trade payload returned by Kite trades endpoints.
pub const Trade = struct {
    trade_id: []const u8,
    order_id: []const u8,
    exchange: ?[]const u8 = null,
    tradingsymbol: ?[]const u8 = null,
    product: ?[]const u8 = null,
    order_type: ?[]const u8 = null,
    transaction_type: ?[]const u8 = null,
    exchange_order_id: ?[]const u8 = null,
    fill_timestamp: ?[]const u8 = null,
    exchange_timestamp: ?[]const u8 = null,
    instrument_token: ?u64 = null,
    quantity: ?i64 = null,
    average_price: ?f64 = null,
};
