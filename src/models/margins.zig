//! Margin-domain models used by user and margin endpoints.

/// Segment selector used by `/user/margins/{segment}`.
pub const Segment = enum {
    equity,
    commodity,

    /// Return the API path component for the selected segment.
    pub fn asPath(self: Segment) []const u8 {
        return switch (self) {
            .equity => "equity",
            .commodity => "commodity",
        };
    }
};

/// Available margin buckets in user margin payloads.
pub const AvailableMargins = struct {
    adhoc_margin: f64 = 0,
    cash: f64 = 0,
    collateral: f64 = 0,
    intraday_payin: f64 = 0,
    live_balance: f64 = 0,
    opening_balance: f64 = 0,
    span: f64 = 0,
};

/// Utilised margin buckets in user margin payloads.
pub const UtilisedMargins = struct {
    debits: f64 = 0,
    exposure: f64 = 0,
    m2m_realised: f64 = 0,
    m2m_unrealised: f64 = 0,
    option_premium: f64 = 0,
    payout: f64 = 0,
    span: f64 = 0,
    holding_sales: f64 = 0,
    turnover: f64 = 0,
    liquid_collateral: f64 = 0,
    stock_collateral: f64 = 0,
};

/// Segment-specific margin snapshot used by `/user/margins` responses.
pub const SegmentMargins = struct {
    enabled: bool,
    net: f64,
    available: AvailableMargins,
    utilised: UtilisedMargins,
};

/// Margin payload returned by `/user/margins`.
pub const UserMargins = struct {
    equity: ?SegmentMargins = null,
    commodity: ?SegmentMargins = null,
};

/// Realised/unrealised PNL breakdown returned by margin calculator APIs.
pub const Pnl = struct {
    realised: f64 = 0,
    unrealised: f64 = 0,
};

/// GST sub-breakdown returned inside margin and charge payloads.
pub const GstBreakdown = struct {
    igst: f64 = 0,
    cgst: f64 = 0,
    sgst: f64 = 0,
    total: f64 = 0,
};

/// Detailed charge breakdown returned by margin and charges APIs.
pub const ChargeBreakdown = struct {
    transaction_tax: f64 = 0,
    transaction_tax_type: ?[]const u8 = null,
    exchange_turnover_charge: f64 = 0,
    sebi_turnover_charge: f64 = 0,
    brokerage: f64 = 0,
    stamp_duty: f64 = 0,
    gst: GstBreakdown = .{},
    total: f64 = 0,
};

/// Per-order margin breakdown returned by `/margins/orders`.
pub const OrderMargin = struct {
    type: []const u8 = "",
    tradingsymbol: ?[]const u8 = null,
    exchange: ?[]const u8 = null,
    span: f64 = 0,
    exposure: f64 = 0,
    option_premium: f64 = 0,
    additional: f64 = 0,
    bo: f64 = 0,
    cash: f64 = 0,
    @"var": f64 = 0,
    pnl: Pnl = .{},
    leverage: f64 = 0,
    charges: ChargeBreakdown = .{},
    total: f64 = 0,
};

/// Aggregate margin totals used in basket margin responses.
pub const BasketMarginTotals = OrderMargin;

/// Basket margin payload returned by `/margins/basket`.
pub const BasketMargins = struct {
    initial: BasketMarginTotals,
    final: BasketMarginTotals,
    orders: []const OrderMargin = &.{},
    charges: ChargeBreakdown = .{},
};

/// Charge-line payload returned by `/charges/orders`.
pub const OrderCharge = struct {
    exchange: ?[]const u8 = null,
    tradingsymbol: ?[]const u8 = null,
    transaction_type: ?[]const u8 = null,
    variety: ?[]const u8 = null,
    product: ?[]const u8 = null,
    order_type: ?[]const u8 = null,
    quantity: f64 = 0,
    price: f64 = 0,
    charges: ChargeBreakdown = .{},
};
