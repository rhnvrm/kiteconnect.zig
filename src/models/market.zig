//! Market domain models used by market endpoints.

/// Open-high-low-close snapshot.
pub const Ohlc = struct {
    open: f64,
    high: f64,
    low: f64,
    close: f64,
};

/// One side of market depth.
pub const DepthLevel = struct {
    price: f64,
    quantity: u64,
    orders: u64,
};

/// Buy and sell depth snapshots.
pub const MarketDepth = struct {
    buy: []const DepthLevel,
    sell: []const DepthLevel,
};

/// Full quote payload for one instrument.
pub const QuoteItem = struct {
    instrument_token: u64,
    timestamp: ?[]const u8 = null,
    last_price: f64,
    last_quantity: ?u64 = null,
    last_trade_time: ?[]const u8 = null,
    average_price: ?f64 = null,
    volume: ?u64 = null,
    buy_quantity: ?u64 = null,
    sell_quantity: ?u64 = null,
    ohlc: Ohlc,
    net_change: ?f64 = null,
    oi: ?f64 = null,
    oi_day_high: ?f64 = null,
    oi_day_low: ?f64 = null,
    lower_circuit_limit: ?f64 = null,
    upper_circuit_limit: ?f64 = null,
    depth: ?MarketDepth = null,
};

/// LTP quote payload for one instrument.
pub const LtpItem = struct {
    instrument_token: u64,
    last_price: f64,
};

/// OHLC quote payload for one instrument.
pub const OhlcItem = struct {
    instrument_token: u64,
    last_price: f64,
    ohlc: Ohlc,
};

/// One candle row in historical data response.
pub const HistoricalCandle = struct {
    date: []const u8,
    open: f64,
    high: f64,
    low: f64,
    close: f64,
    volume: u64,
    oi: ?u64 = null,
};

/// CSV instrument row returned by `/instruments` endpoints.
pub const Instrument = struct {
    instrument_token: u64,
    exchange_token: u64,
    tradingsymbol: []const u8,
    name: []const u8,
    last_price: f64,
    expiry: []const u8,
    strike: f64,
    tick_size: f64,
    lot_size: u64,
    instrument_type: []const u8,
    segment: []const u8,
    exchange: []const u8,
};

/// CSV mutual-fund instrument row returned by `/mf/instruments`.
pub const MfInstrument = struct {
    tradingsymbol: []const u8,
    name: []const u8,
    last_price: f64,
    amc: []const u8,

    purchase_allowed: bool,
    redemption_allowed: bool,
    minimum_purchase_amount: f64,
    purchase_amount_multiplier: f64,
    minimum_additional_purchase_amount: f64,
    minimum_redemption_quantity: f64,
    redemption_quantity_multiplier: f64,
    dividend_type: []const u8,
    scheme_type: []const u8,
    plan: []const u8,
    settlement_type: []const u8,
    last_price_date: []const u8,
};
