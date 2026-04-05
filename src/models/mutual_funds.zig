//! Mutual-funds domain wire models.

const std = @import("std");

/// Go-style SIP step-up map keyed by day-month (`DD-MM`) with percentage values.
pub const MfSipStepUp = std.json.ArrayHashMap(i64);

/// Individual mutual-fund trade row returned by holding-breakdown APIs.
pub const MfTrade = struct {
    fund: ?[]const u8 = null,
    tradingsymbol: ?[]const u8 = null,
    average_price: ?f64 = null,
    variety: ?[]const u8 = null,
    exchange_timestamp: ?[]const u8 = null,
    amount: ?f64 = null,
    folio: ?[]const u8 = null,
    quantity: ?f64 = null,
};

/// Mutual-fund order payload.
pub const MfOrder = struct {
    order_id: []const u8,
    exchange_order_id: ?[]const u8 = null,
    tradingsymbol: ?[]const u8 = null,
    status: ?[]const u8 = null,
    status_message: ?[]const u8 = null,
    folio: ?[]const u8 = null,
    fund: ?[]const u8 = null,
    order_timestamp: ?[]const u8 = null,
    exchange_timestamp: ?[]const u8 = null,
    settlement_id: ?[]const u8 = null,
    transaction_type: ?[]const u8 = null,
    variety: ?[]const u8 = null,
    purchase_type: ?[]const u8 = null,
    quantity: ?f64 = null,
    amount: ?f64 = null,
    last_price: ?f64 = null,
    average_price: ?f64 = null,
    placed_by: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    last_price_date: ?[]const u8 = null,
};

/// Mutual-fund SIP payload.
pub const MfSip = struct {
    sip_id: []const u8,
    tradingsymbol: ?[]const u8 = null,
    fund: ?[]const u8 = null,
    fund_source: ?[]const u8 = null,
    sip_reg_num: ?[]const u8 = null,
    dividend_type: ?[]const u8 = null,
    transaction_type: ?[]const u8 = null,
    status: ?[]const u8 = null,
    sip_type: ?[]const u8 = null,
    frequency: ?[]const u8 = null,
    amount: ?f64 = null,
    instalment_amount: ?f64 = null,
    instalments: ?i64 = null,
    pending_instalments: ?i64 = null,
    completed_instalments: ?i64 = null,
    instalment_day: ?i64 = null,
    trigger_price: ?f64 = null,
    next_instalment: ?[]const u8 = null,
    created: ?[]const u8 = null,
    last_instalment: ?[]const u8 = null,
    tag: ?[]const u8 = null,
    step_up: ?MfSipStepUp = null,
};

/// Mutual-fund holding payload.
pub const MfHolding = struct {
    tradingsymbol: []const u8,
    folio: ?[]const u8 = null,
    fund: ?[]const u8 = null,
    quantity: ?f64 = null,
    average_price: ?f64 = null,
    last_price: ?f64 = null,
    pnl: ?f64 = null,
    pledged_quantity: ?f64 = null,
    last_price_date: ?[]const u8 = null,
};

/// Holding-breakdown payload returned by `/mf/holdings/{isin}`.
pub const MfHoldingBreakdown = []const MfTrade;

/// Supplemental instrument info payload for `/mf/instruments/{tradingsymbol}`.
pub const MfInstrumentInfo = struct {
    tradingsymbol: []const u8,
    name: ?[]const u8 = null,
    minimum_purchase_amount: ?f64 = null,
    purchase_allowed: ?bool = null,
    redemption_allowed: ?bool = null,
    last_price: ?f64 = null,
    last_price_date: ?[]const u8 = null,
};

/// Mutation envelope payload for MF order APIs.
pub const MfOrderMutationData = struct {
    order_id: []const u8,
};

/// Mutation envelope payload for MF SIP APIs.
pub const MfSipMutationData = struct {
    sip_id: []const u8,
    order_id: ?[]const u8 = null,
};
