//! Alerts-domain wire models.

const std = @import("std");

/// OHLC snapshot embedded in alert-history metadata.
pub const AlertHistoryOhlc = struct {
    open: ?f64 = null,
    high: ?f64 = null,
    low: ?f64 = null,
    close: ?f64 = null,
};

/// Metadata entry embedded inside alert history rows.
pub const AlertHistoryMeta = struct {
    instrument_token: ?i64 = null,
    tradingsymbol: ?[]const u8 = null,
    timestamp: ?[]const u8 = null,
    last_price: ?f64 = null,
    ohlc: ?AlertHistoryOhlc = null,
    net_change: ?f64 = null,
    exchange: ?[]const u8 = null,
    last_trade_time: ?[]const u8 = null,
    last_quantity: ?i64 = null,
    buy_quantity: ?i64 = null,
    sell_quantity: ?i64 = null,
    volume: ?i64 = null,
    volume_tick: ?i64 = null,
    average_price: ?f64 = null,
    oi: ?i64 = null,
    oi_day_high: ?i64 = null,
    oi_day_low: ?i64 = null,
    lower_circuit_limit: ?f64 = null,
    upper_circuit_limit: ?f64 = null,
};

/// Alert payload returned by list/detail APIs.
pub const Alert = struct {
    alert_id: ?i64 = null,
    uuid: ?[]const u8 = null,
    type: ?[]const u8 = null,
    user_id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    disabled_reason: ?[]const u8 = null,
    lhs_exchange: ?[]const u8 = null,
    lhs_tradingsymbol: ?[]const u8 = null,
    lhs_attribute: ?[]const u8 = null,
    operator: ?[]const u8 = null,
    rhs_type: ?[]const u8 = null,
    rhs_attribute: ?[]const u8 = null,
    rhs_exchange: ?[]const u8 = null,
    rhs_tradingsymbol: ?[]const u8 = null,
    rhs_constant: ?f64 = null,
    alert_count: ?i64 = null,
    status: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};

/// Alert history entry payload.
pub const AlertHistoryEntry = struct {
    alert_id: ?i64 = null,
    uuid: ?[]const u8 = null,
    type: ?[]const u8 = null,
    condition: ?[]const u8 = null,
    event: ?[]const u8 = null,
    note: ?[]const u8 = null,
    meta: ?[]const AlertHistoryMeta = null,
    order_meta: ?std.json.Value = null,
    created_at: ?[]const u8 = null,
};

/// Mutation envelope payload for alert create/update/delete APIs.
pub const AlertMutationData = struct {
    alert_id: ?i64 = null,
    uuid: ?[]const u8 = null,
    type: ?[]const u8 = null,
    user_id: ?[]const u8 = null,
    name: ?[]const u8 = null,
    status: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
};
