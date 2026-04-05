//! Portfolio domain models used by portfolio endpoints.

/// Margin-trading-facility details for a holding.
pub const MtfHolding = struct {
    quantity: i64,
    used_quantity: i64,
    average_price: f64,
    value: f64,
    initial_margin: f64,
};

/// Full holding entry returned by `/portfolio/holdings`.
pub const Holding = struct {
    tradingsymbol: []const u8,
    exchange: []const u8,
    instrument_token: u64,
    isin: []const u8,
    product: []const u8,

    price: f64,
    used_quantity: i64,
    quantity: i64,
    t1_quantity: i64,
    realised_quantity: i64,
    authorised_quantity: i64,
    authorised_date: []const u8,
    opening_quantity: i64,
    collateral_quantity: i64,
    collateral_type: []const u8,

    discrepancy: bool,
    average_price: f64,
    last_price: f64,
    close_price: f64,
    pnl: f64,
    day_change: f64,
    day_change_percentage: f64,

    mtf: ?MtfHolding = null,
};

/// Compact holding entry returned by `/portfolio/holdings/compact`.
pub const HoldingCompact = struct {
    exchange: []const u8,
    tradingsymbol: []const u8,
    instrument_token: u64,
    t1_quantity: i64,
    quantity: i64,
};

/// Aggregate holdings summary returned by `/portfolio/holdings/summary`.
pub const HoldingSummary = struct {
    total_pnl: f64,
    total_pnl_percent: f64,
    today_pnl: f64,
    today_pnl_percent: f64,
    invested_amount: f64,
    current_value: f64,
};

/// Auction instrument entry returned by `/portfolio/holdings/auctions`.
pub const AuctionInstrument = struct {
    tradingsymbol: []const u8,
    exchange: []const u8,
    instrument_token: u64,
    isin: []const u8,
    product: []const u8,
    price: f64,
    quantity: i64,
    t1_quantity: i64,
    realised_quantity: i64,
    authorised_quantity: i64,
    authorised_date: []const u8,
    opening_quantity: i64,
    collateral_quantity: i64,
    collateral_type: []const u8,
    discrepancy: bool,
    average_price: f64,
    last_price: f64,
    close_price: f64,
    pnl: f64,
    day_change: f64,
    day_change_percentage: f64,
    auction_number: []const u8,
};

/// Position entry returned by `/portfolio/positions` under `net` and `day` groups.
pub const Position = struct {
    tradingsymbol: []const u8,
    exchange: []const u8,
    instrument_token: u64,
    product: []const u8,

    quantity: i64,
    overnight_quantity: i64,
    multiplier: f64,

    average_price: f64,
    close_price: f64,
    last_price: f64,
    value: f64,
    pnl: f64,
    m2m: f64,
    unrealised: f64,
    realised: f64,

    buy_quantity: i64,
    buy_price: f64,
    buy_value: f64,
    buy_m2m: f64,

    sell_quantity: i64,
    sell_price: f64,
    sell_value: f64,
    sell_m2m: f64,

    day_buy_quantity: i64,
    day_buy_price: f64,
    day_buy_value: f64,

    day_sell_quantity: i64,
    day_sell_price: f64,
    day_sell_value: f64,
};

/// Grouped positions response payload from `/portfolio/positions`.
pub const Positions = struct {
    net: []const Position,
    day: []const Position,
};

/// Input parameters for converting position product type.
pub const ConvertPositionParams = struct {
    exchange: []const u8,
    tradingsymbol: []const u8,
    old_product: []const u8,
    new_product: []const u8,
    position_type: []const u8,
    transaction_type: []const u8,
    quantity: i64,
};
