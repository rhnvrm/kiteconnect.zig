//! Ticker-domain models shared by binary parser and session/runtime layers.

const std = @import("std");

/// Market depth entry for one side of the order book.
pub const DepthItem = struct {
    price: f64,
    quantity: u32,
    orders: u32,
};

/// Fixed-depth market book snapshot.
pub const Depth = struct {
    buy: [5]DepthItem = [_]DepthItem{.{ .price = 0, .quantity = 0, .orders = 0 }} ** 5,
    sell: [5]DepthItem = [_]DepthItem{.{ .price = 0, .quantity = 0, .orders = 0 }} ** 5,
};

/// Open-high-low-close snapshot embedded in quote/full packets.
pub const Ohlc = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

/// Known ticker modes.
pub const Mode = enum {
    ltp,
    quote,
    full,

    pub fn asString(self: Mode) []const u8 {
        return switch (self) {
            .ltp => "ltp",
            .quote => "quote",
            .full => "full",
        };
    }
};

/// Decoded ticker packet.
pub const Tick = struct {
    mode: Mode,
    instrument_token: u32,
    is_tradable: bool,
    is_index: bool,

    timestamp_unix: ?i64 = null,
    last_trade_time_unix: ?i64 = null,
    last_price: f64,
    last_traded_quantity: ?u32 = null,
    total_buy_quantity: ?u32 = null,
    total_sell_quantity: ?u32 = null,
    volume_traded: ?u32 = null,
    average_trade_price: ?f64 = null,
    oi: ?u32 = null,
    oi_day_high: ?u32 = null,
    oi_day_low: ?u32 = null,
    net_change: ?f64 = null,

    ohlc: ?Ohlc = null,
    depth: ?Depth = null,
};

/// Generic text-frame envelope used by error and order-update messages.
pub const TextEnvelope = struct {
    type: []const u8,
    data: std.json.Value,
};
