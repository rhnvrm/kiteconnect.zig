//! GTT-domain wire models.

/// Rejection metadata attached to triggered GTT rows.
pub const TriggerMeta = struct {
    rejection_reason: ?[]const u8 = null,
};

/// Trigger condition payload used by GTT create/modify/list responses.
pub const TriggerCondition = struct {
    exchange: ?[]const u8 = null,
    tradingsymbol: ?[]const u8 = null,
    instrument_token: ?u64 = null,
    trigger_values: ?[]const f64 = null,
    last_price: ?f64 = null,
};

/// Order leg payload embedded within a trigger.
pub const TriggerOrder = struct {
    exchange: ?[]const u8 = null,
    tradingsymbol: ?[]const u8 = null,
    transaction_type: ?[]const u8 = null,
    quantity: ?i64 = null,
    order_type: ?[]const u8 = null,
    product: ?[]const u8 = null,
    price: ?f64 = null,
};

/// GTT trigger payload returned by list and detail APIs.
pub const Trigger = struct {
    id: i64,
    user_id: ?[]const u8 = null,
    type: ?[]const u8 = null,
    status: ?[]const u8 = null,
    created_at: ?[]const u8 = null,
    updated_at: ?[]const u8 = null,
    expires_at: ?[]const u8 = null,
    condition: ?TriggerCondition = null,
    orders: ?[]const TriggerOrder = null,
    meta: ?TriggerMeta = null,
};

/// Mutation envelope payload for create/modify/delete trigger APIs.
pub const TriggerMutationData = struct {
    trigger_id: i64,
};
