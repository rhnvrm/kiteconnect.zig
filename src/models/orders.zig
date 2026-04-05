//! Order-domain wire models used by order and order-history endpoints.

const std = @import("std");

/// Go-style `map[string]interface{}` metadata used by order payloads.
pub const OrderMeta = std.json.ArrayHashMap(std.json.Value);

/// Common order payload returned by Kite orders endpoints.
pub const Order = struct {
    order_id: []const u8,
    status: []const u8,
    account_id: ?[]const u8 = null,
    placed_by: ?[]const u8 = null,
    variety: ?[]const u8 = null,
    exchange: ?[]const u8 = null,
    tradingsymbol: ?[]const u8 = null,
    product: ?[]const u8 = null,
    order_type: ?[]const u8 = null,
    transaction_type: ?[]const u8 = null,
    validity: ?[]const u8 = null,
    validity_ttl: ?i64 = null,
    parent_order_id: ?[]const u8 = null,
    exchange_order_id: ?[]const u8 = null,
    status_message: ?[]const u8 = null,
    status_message_raw: ?[]const u8 = null,
    order_timestamp: ?[]const u8 = null,
    exchange_timestamp: ?[]const u8 = null,
    exchange_update_timestamp: ?[]const u8 = null,
    modified: ?bool = null,
    meta: ?OrderMeta = null,
    instrument_token: ?u64 = null,
    quantity: ?i64 = null,
    disclosed_quantity: ?i64 = null,
    filled_quantity: ?i64 = null,
    pending_quantity: ?i64 = null,
    cancelled_quantity: ?i64 = null,
    price: ?f64 = null,
    trigger_price: ?f64 = null,
    average_price: ?f64 = null,
    auction_number: ?[]const u8 = null,
    market_protection: ?f64 = null,
    tag: ?[]const u8 = null,
    tags: ?[][]const u8 = null,
    guid: ?[]const u8 = null,
};

/// Order-history payload entries use the same wire shape as orders.
pub const OrderHistoryEntry = Order;

/// Child-order error payload in autoslice order responses.
pub const OrderMutationChildError = struct {
    code: ?i64 = null,
    error_type: ?[]const u8 = null,
    message: ?[]const u8 = null,
    data: ?std.json.Value = null,
};

/// Child-order payload in autoslice order responses.
pub const OrderMutationChild = struct {
    order_id: ?[]const u8 = null,
    @"error": ?OrderMutationChildError = null,
};

/// Mutation endpoints (place/modify/cancel) return an order ID envelope.
pub const OrderMutationData = struct {
    order_id: []const u8,
    children: ?[]OrderMutationChild = null,
};
