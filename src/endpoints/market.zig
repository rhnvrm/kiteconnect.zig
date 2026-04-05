//! Market endpoint contracts, request builders, runtime execution helpers, and response decoders.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const models = @import("../models/market.zig");
const transport = @import("../transport.zig");

/// API path constants for market endpoints.
pub const Paths = struct {
    pub const quote = "/quote";
    pub const ltp = "/quote/ltp";
    pub const ohlc = "/quote/ohlc";
    pub const instruments = "/instruments";
    pub const mf_instruments = "/mf/instruments";
};

comptime {
    if (std.mem.eql(u8, Paths.quote, Paths.ltp) or
        std.mem.eql(u8, Paths.quote, Paths.ohlc) or
        std.mem.eql(u8, Paths.ltp, Paths.ohlc))
    {
        @compileError("Quote, LTP, and OHLC routes must remain distinct API endpoints.");
    }
}

/// Query parameters for historical-data fetches.
pub const HistoricalQuery = struct {
    from: []const u8,
    to: []const u8,
    continuous: bool = false,
    oi: bool = false,
};

/// Error set used when decoding non-envelope historical data.
pub const HistoricalParseError = http.JsonParseError || std.mem.Allocator.Error || error{
    InvalidEnvelope,
    InvalidHistoricalCandle,
};

/// Error set used when decoding CSV market payloads.
pub const CsvDecodeError = errors.TransportError || std.mem.Allocator.Error || error{
    EmptyCsv,
    MissingCsvColumn,
    InvalidCsvRow,
    InvalidCsvBoolean,
    InvalidCsvNumber,
};

/// Error set used by market execute+decode helpers.
pub const MarketDecodeError = http.DecodeResponseError || error{
    InvalidEnvelope,
    InvalidHistoricalCandle,
    EmptyCsv,
    MissingCsvColumn,
    InvalidCsvRow,
    InvalidCsvBoolean,
    InvalidCsvNumber,
};

/// Parsed candle response for `GET /instruments/historical/{instrument_token}/{interval}`.
pub const HistoricalDataResponse = struct {
    candles: []const models.HistoricalCandle,

    /// Frees the candle slice and all owned date strings.
    pub fn deinit(self: HistoricalDataResponse, allocator: std.mem.Allocator) void {
        for (self.candles) |candle| {
            allocator.free(candle.date);
        }
        allocator.free(self.candles);
    }
};

/// Parsed instrument rows for `GET /instruments` or `GET /instruments/{exchange}`.
pub const InstrumentsResponse = struct {
    instruments: []const models.Instrument,

    /// Frees all owned row strings and the instrument slice.
    pub fn deinit(self: InstrumentsResponse, allocator: std.mem.Allocator) void {
        for (self.instruments) |instrument| {
            allocator.free(instrument.tradingsymbol);
            allocator.free(instrument.name);
            allocator.free(instrument.expiry);
            allocator.free(instrument.instrument_type);
            allocator.free(instrument.segment);
            allocator.free(instrument.exchange);
        }
        allocator.free(self.instruments);
    }
};

/// Parsed mutual-fund instrument rows for `GET /mf/instruments`.
pub const MfInstrumentsResponse = struct {
    instruments: []const models.MfInstrument,

    /// Frees all owned row strings and the instrument slice.
    pub fn deinit(self: MfInstrumentsResponse, allocator: std.mem.Allocator) void {
        for (self.instruments) |instrument| {
            allocator.free(instrument.tradingsymbol);
            allocator.free(instrument.name);
            allocator.free(instrument.amc);
            allocator.free(instrument.dividend_type);
            allocator.free(instrument.scheme_type);
            allocator.free(instrument.plan);
            allocator.free(instrument.settlement_type);
            allocator.free(instrument.last_price_date);
        }
        allocator.free(self.instruments);
    }
};

/// Parsed success payload for `GET /quote` that retains response-body backing.
pub const QuoteSuccess = http.OwnedParsed(envelope.SuccessEnvelope(std.json.ArrayHashMap(models.QuoteItem)));

/// Parsed success payload for `GET /quote/ltp` that retains response-body backing.
pub const LtpSuccess = http.OwnedParsed(envelope.SuccessEnvelope(std.json.ArrayHashMap(models.LtpItem)));

/// Parsed success payload for `GET /quote/ohlc` that retains response-body backing.
pub const OhlcSuccess = http.OwnedParsed(envelope.SuccessEnvelope(std.json.ArrayHashMap(models.OhlcItem)));

pub const QuoteResult = union(enum) {
    success: QuoteSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: QuoteResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const LtpResult = union(enum) {
    success: LtpSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: LtpResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const OhlcResult = union(enum) {
    success: OhlcSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: OhlcResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const HistoricalDataResult = union(enum) {
    success: HistoricalDataResponse,
    api_error: errors.ApiError,

    pub fn deinit(self: HistoricalDataResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const InstrumentsResult = union(enum) {
    success: InstrumentsResponse,
    api_error: errors.ApiError,

    pub fn deinit(self: InstrumentsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfInstrumentsResult = union(enum) {
    success: MfInstrumentsResponse,
    api_error: errors.ApiError,

    pub fn deinit(self: MfInstrumentsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Request metadata for `GET /quote`.
pub fn quoteRequest() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.quote };
}

/// Request metadata for `GET /quote/ltp`.
pub fn ltpRequest() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.ltp };
}

/// Request metadata for `GET /quote/ohlc`.
pub fn ohlcRequest() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.ohlc };
}

/// Request metadata for `GET /instruments`.
pub fn instrumentsRequest() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.instruments };
}

/// Request metadata for `GET /mf/instruments`.
pub fn mfInstrumentsRequest() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.mf_instruments };
}

/// Build a request spec for `GET /quote`.
pub fn quoteRequestSpec(query: []const u8) transport.RequestSpec {
    return .{ .options = quoteRequest(), .query = query, .response_format = .json };
}

/// Build a request spec for `GET /quote/ltp`.
pub fn ltpRequestSpec(query: []const u8) transport.RequestSpec {
    return .{ .options = ltpRequest(), .query = query, .response_format = .json };
}

/// Build a request spec for `GET /quote/ohlc`.
pub fn ohlcRequestSpec(query: []const u8) transport.RequestSpec {
    return .{ .options = ohlcRequest(), .query = query, .response_format = .json };
}

/// Build a request spec for `GET /instruments/historical/{instrument_token}/{interval}`.
pub fn historicalRequestSpec(path: []const u8, query: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .get, .path = path }, .query = query, .response_format = .json };
}

/// Request spec for `GET /instruments` with CSV response expectations.
pub fn instrumentsRequestSpec() transport.RequestSpec {
    return .{ .options = instrumentsRequest(), .response_format = .csv };
}

/// Request spec for `GET /instruments/{exchange}` with CSV response expectations.
pub fn instrumentsByExchangeRequestSpec(path: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .get, .path = path }, .response_format = .csv };
}

/// Request spec for `GET /mf/instruments` with CSV response expectations.
pub fn mfInstrumentsRequestSpec() transport.RequestSpec {
    return .{ .options = mfInstrumentsRequest(), .response_format = .csv };
}

/// Builds path for historical data endpoint.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn historicalPath(
    allocator: std.mem.Allocator,
    instrument_token: u64,
    interval: []const u8,
) ![]u8 {
    if (interval.len == 0) return error.EmptyInterval;
    return std.fmt.allocPrint(allocator, "/instruments/historical/{d}/{s}", .{ instrument_token, interval });
}

/// Builds path for exchange-specific instruments endpoint.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn instrumentsByExchangePath(
    allocator: std.mem.Allocator,
    exchange: []const u8,
) ![]u8 {
    if (exchange.len == 0) return error.EmptyExchange;

    const trimmed = std.mem.trim(u8, exchange, " ");
    if (trimmed.len == 0) return error.EmptyExchange;

    return std.fmt.allocPrint(allocator, "/instruments/{s}", .{trimmed});
}

/// Builds the repeated `i=<instrument>` query used by quote, LTP, and OHLC APIs.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildInstrumentsQuery(
    allocator: std.mem.Allocator,
    instruments: []const []const u8,
) ![]u8 {
    if (instruments.len == 0) return error.EmptyInstruments;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    for (instruments, 0..) |instrument, idx| {
        if (instrument.len == 0) return error.EmptyInstruments;
        if (idx != 0) try buffer.append(allocator, '&');
        try buffer.appendSlice(allocator, "i=");
        try percentEncodeInto(allocator, &buffer, instrument);
    }

    return buffer.toOwnedSlice(allocator);
}

/// Builds historical query string with `from`, `to`, `continuous`, and `oi`.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildHistoricalQuery(
    allocator: std.mem.Allocator,
    query: HistoricalQuery,
) ![]u8 {
    if (query.from.len == 0) return error.EmptyFrom;
    if (query.to.len == 0) return error.EmptyTo;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendQueryField(allocator, &buffer, "from", query.from, false);
    try appendQueryField(allocator, &buffer, "to", query.to, true);
    try appendQueryField(allocator, &buffer, "continuous", if (query.continuous) "1" else "0", true);
    try appendQueryField(allocator, &buffer, "oi", if (query.oi) "1" else "0", true);

    return buffer.toOwnedSlice(allocator);
}

/// Executes `GET /quote` and decodes either success payload or owned API error.
pub fn executeQuote(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    query: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!QuoteResult {
    return decodeQuoteExecuted(client.allocator, try client.execute(runtime_client, quoteRequestSpec(query)));
}

/// Executes `GET /quote/ltp` and decodes either success payload or owned API error.
pub fn executeLtp(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    query: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!LtpResult {
    return decodeLtpExecuted(client.allocator, try client.execute(runtime_client, ltpRequestSpec(query)));
}

/// Executes `GET /quote/ohlc` and decodes either success payload or owned API error.
pub fn executeOhlc(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    query: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OhlcResult {
    return decodeOhlcExecuted(client.allocator, try client.execute(runtime_client, ohlcRequestSpec(query)));
}

/// Executes `GET /instruments/historical/{instrument_token}/{interval}` and decodes either success payload or owned API error.
pub fn executeHistoricalData(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
    query: []const u8,
) (client_mod.ExecuteRequestError || MarketDecodeError)!HistoricalDataResult {
    return decodeHistoricalDataExecuted(client.allocator, try client.execute(runtime_client, historicalRequestSpec(path, query)));
}

/// Executes `GET /instruments` and decodes either success payload or owned API error.
pub fn executeInstruments(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || MarketDecodeError)!InstrumentsResult {
    return decodeInstrumentsExecuted(client.allocator, try client.execute(runtime_client, instrumentsRequestSpec()));
}

/// Executes `GET /instruments/{exchange}` and decodes either success payload or owned API error.
pub fn executeInstrumentsByExchange(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || MarketDecodeError)!InstrumentsResult {
    return decodeInstrumentsExecuted(client.allocator, try client.execute(runtime_client, instrumentsByExchangeRequestSpec(path)));
}

/// Executes `GET /mf/instruments` and decodes either success payload or owned API error.
pub fn executeMfInstruments(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || MarketDecodeError)!MfInstrumentsResult {
    return decodeMfInstrumentsExecuted(client.allocator, try client.execute(runtime_client, mfInstrumentsRequestSpec()));
}

/// Parses `GET /quote` response data.
pub fn parseQuote(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(std.json.ArrayHashMap(models.QuoteItem))) {
    return envelope.parseSuccessEnvelope(std.json.ArrayHashMap(models.QuoteItem), allocator, payload);
}

/// Parses `GET /quote/ltp` response data.
pub fn parseLtp(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(std.json.ArrayHashMap(models.LtpItem))) {
    return envelope.parseSuccessEnvelope(std.json.ArrayHashMap(models.LtpItem), allocator, payload);
}

/// Parses `GET /quote/ohlc` response data.
pub fn parseOhlc(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(std.json.ArrayHashMap(models.OhlcItem))) {
    return envelope.parseSuccessEnvelope(std.json.ArrayHashMap(models.OhlcItem), allocator, payload);
}

/// Parses historical-candle envelope payload.
/// Caller owns the returned candle data and must call `deinit`.
pub fn parseHistoricalData(
    allocator: std.mem.Allocator,
    payload: []const u8,
) HistoricalParseError!HistoricalDataResponse {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, payload, .{});
    defer parsed.deinit();

    const root = try valueAsObject(parsed.value);
    const status_value = root.get("status") orelse return error.InvalidEnvelope;
    const status = try valueAsString(status_value);
    if (!std.mem.eql(u8, status, "success")) return error.InvalidEnvelope;

    const data_value = root.get("data") orelse return error.InvalidEnvelope;
    const data = try valueAsObject(data_value);
    const candles_value = data.get("candles") orelse return error.InvalidEnvelope;

    const candles = try valueAsArray(candles_value);
    var out = try allocator.alloc(models.HistoricalCandle, candles.items.len);
    var initialized: usize = 0;
    errdefer {
        for (out[0..initialized]) |candle| allocator.free(candle.date);
        allocator.free(out);
    }

    for (candles.items, 0..) |row_value, row_idx| {
        const row = try valueAsArray(row_value);
        if (row.items.len < 6) return error.InvalidHistoricalCandle;

        const date = try allocator.dupe(u8, try valueAsString(row.items[0]));
        errdefer allocator.free(date);

        out[row_idx] = .{
            .date = date,
            .open = try valueAsF64(row.items[1]),
            .high = try valueAsF64(row.items[2]),
            .low = try valueAsF64(row.items[3]),
            .close = try valueAsF64(row.items[4]),
            .volume = try valueAsU64(row.items[5]),
            .oi = if (row.items.len > 6) try valueAsU64(row.items[6]) else null,
        };
        initialized += 1;
    }

    return .{ .candles = out };
}

/// Parses CSV payload returned by `GET /instruments` and `GET /instruments/{exchange}`.
/// Caller owns the returned rows and must call `deinit`.
pub fn parseInstrumentsCsv(
    allocator: std.mem.Allocator,
    payload: []const u8,
) CsvDecodeError!InstrumentsResponse {
    var lines = std.mem.splitScalar(u8, payload, '\n');

    const header_fields = (try nextCsvRecord(allocator, &lines)) orelse return error.EmptyCsv;
    defer freeCsvFields(allocator, header_fields);

    const idx_instrument_token = try csvHeaderIndex(header_fields, "instrument_token");
    const idx_exchange_token = try csvHeaderIndex(header_fields, "exchange_token");
    const idx_tradingsymbol = try csvHeaderIndex(header_fields, "tradingsymbol");
    const idx_name = try csvHeaderIndex(header_fields, "name");
    const idx_last_price = try csvHeaderIndex(header_fields, "last_price");
    const idx_expiry = try csvHeaderIndex(header_fields, "expiry");
    const idx_strike = try csvHeaderIndex(header_fields, "strike");
    const idx_tick_size = try csvHeaderIndex(header_fields, "tick_size");
    const idx_lot_size = try csvHeaderIndex(header_fields, "lot_size");
    const idx_instrument_type = try csvHeaderIndex(header_fields, "instrument_type");
    const idx_segment = try csvHeaderIndex(header_fields, "segment");
    const idx_exchange = try csvHeaderIndex(header_fields, "exchange");

    var out: std.ArrayList(models.Instrument) = .empty;
    defer out.deinit(allocator);
    errdefer {
        for (out.items) |instrument| {
            allocator.free(instrument.tradingsymbol);
            allocator.free(instrument.name);
            allocator.free(instrument.expiry);
            allocator.free(instrument.instrument_type);
            allocator.free(instrument.segment);
            allocator.free(instrument.exchange);
        }
    }

    while (try nextCsvRecord(allocator, &lines)) |fields| {
        defer freeCsvFields(allocator, fields);

        const instrument = try parseInstrumentRow(
            allocator,
            fields,
            idx_instrument_token,
            idx_exchange_token,
            idx_tradingsymbol,
            idx_name,
            idx_last_price,
            idx_expiry,
            idx_strike,
            idx_tick_size,
            idx_lot_size,
            idx_instrument_type,
            idx_segment,
            idx_exchange,
        );
        try out.append(allocator, instrument);
    }

    return .{ .instruments = try out.toOwnedSlice(allocator) };
}

/// Parses CSV payload returned by `GET /mf/instruments`.
/// Caller owns the returned rows and must call `deinit`.
pub fn parseMfInstrumentsCsv(
    allocator: std.mem.Allocator,
    payload: []const u8,
) CsvDecodeError!MfInstrumentsResponse {
    var lines = std.mem.splitScalar(u8, payload, '\n');

    const header_fields = (try nextCsvRecord(allocator, &lines)) orelse return error.EmptyCsv;
    defer freeCsvFields(allocator, header_fields);

    const idx_tradingsymbol = try csvHeaderIndex(header_fields, "tradingsymbol");
    const idx_amc = try csvHeaderIndex(header_fields, "amc");
    const idx_name = try csvHeaderIndex(header_fields, "name");
    const idx_purchase_allowed = try csvHeaderIndex(header_fields, "purchase_allowed");
    const idx_redemption_allowed = try csvHeaderIndex(header_fields, "redemption_allowed");
    const idx_last_price = try csvHeaderIndex(header_fields, "last_price");
    const idx_purchase_amount_multiplier = try csvHeaderIndex(header_fields, "purchase_amount_multiplier");
    const idx_minimum_purchase_amount = try csvHeaderIndex(header_fields, "minimum_purchase_amount");
    const idx_minimum_additional_purchase_amount = try csvHeaderIndex(header_fields, "minimum_additional_purchase_amount");
    const idx_minimum_redemption_quantity = try csvHeaderIndex(header_fields, "minimum_redemption_quantity");
    const idx_redemption_quantity_multiplier = try csvHeaderIndex(header_fields, "redemption_quantity_multiplier");
    const idx_dividend_type = try csvHeaderIndex(header_fields, "dividend_type");
    const idx_scheme_type = try csvHeaderIndex(header_fields, "scheme_type");
    const idx_plan = try csvHeaderIndex(header_fields, "plan");
    const idx_settlement_type = try csvHeaderIndex(header_fields, "settlement_type");
    const idx_last_price_date = try csvHeaderIndex(header_fields, "last_price_date");

    var out: std.ArrayList(models.MfInstrument) = .empty;
    defer out.deinit(allocator);
    errdefer {
        for (out.items) |instrument| {
            allocator.free(instrument.tradingsymbol);
            allocator.free(instrument.name);
            allocator.free(instrument.amc);
            allocator.free(instrument.dividend_type);
            allocator.free(instrument.scheme_type);
            allocator.free(instrument.plan);
            allocator.free(instrument.settlement_type);
            allocator.free(instrument.last_price_date);
        }
    }

    while (try nextCsvRecord(allocator, &lines)) |fields| {
        defer freeCsvFields(allocator, fields);

        const instrument = try parseMfInstrumentRow(
            allocator,
            fields,
            idx_tradingsymbol,
            idx_name,
            idx_amc,
            idx_purchase_allowed,
            idx_redemption_allowed,
            idx_last_price,
            idx_purchase_amount_multiplier,
            idx_minimum_purchase_amount,
            idx_minimum_additional_purchase_amount,
            idx_minimum_redemption_quantity,
            idx_redemption_quantity_multiplier,
            idx_dividend_type,
            idx_scheme_type,
            idx_plan,
            idx_settlement_type,
            idx_last_price_date,
        );
        try out.append(allocator, instrument);
    }

    return .{ .instruments = try out.toOwnedSlice(allocator) };
}

fn decodeQuoteExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!QuoteResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(std.json.ArrayHashMap(models.QuoteItem), allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeLtpExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!LtpResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(std.json.ArrayHashMap(models.LtpItem), allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeOhlcExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!OhlcResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(std.json.ArrayHashMap(models.OhlcItem), allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeHistoricalDataExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) MarketDecodeError!HistoricalDataResult {
    return switch (executed) {
        .success => |response| blk: {
            defer response.deinit(allocator);
            try http.validateSuccessContentType(.json, response.content_type);
            break :blk .{ .success = try parseHistoricalData(allocator, response.body) };
        },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeInstrumentsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) MarketDecodeError!InstrumentsResult {
    return switch (executed) {
        .success => |response| blk: {
            defer response.deinit(allocator);
            try http.validateSuccessContentType(.csv, response.content_type);
            break :blk .{ .success = try parseInstrumentsCsv(allocator, response.body) };
        },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfInstrumentsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) MarketDecodeError!MfInstrumentsResult {
    return switch (executed) {
        .success => |response| blk: {
            defer response.deinit(allocator);
            try http.validateSuccessContentType(.csv, response.content_type);
            break :blk .{ .success = try parseMfInstrumentsCsv(allocator, response.body) };
        },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn parseInstrumentRow(
    allocator: std.mem.Allocator,
    fields: []const []const u8,
    idx_instrument_token: usize,
    idx_exchange_token: usize,
    idx_tradingsymbol: usize,
    idx_name: usize,
    idx_last_price: usize,
    idx_expiry: usize,
    idx_strike: usize,
    idx_tick_size: usize,
    idx_lot_size: usize,
    idx_instrument_type: usize,
    idx_segment: usize,
    idx_exchange: usize,
) !models.Instrument {
    try ensureCsvRowHasIndex(fields, idx_exchange);

    const tradingsymbol = try allocator.dupe(u8, fields[idx_tradingsymbol]);
    errdefer allocator.free(tradingsymbol);
    const name = try allocator.dupe(u8, fields[idx_name]);
    errdefer allocator.free(name);
    const expiry = try allocator.dupe(u8, fields[idx_expiry]);
    errdefer allocator.free(expiry);
    const instrument_type = try allocator.dupe(u8, fields[idx_instrument_type]);
    errdefer allocator.free(instrument_type);
    const segment = try allocator.dupe(u8, fields[idx_segment]);
    errdefer allocator.free(segment);
    const exchange = try allocator.dupe(u8, fields[idx_exchange]);
    errdefer allocator.free(exchange);

    return .{
        .instrument_token = try parseCsvU64(fields[idx_instrument_token]),
        .exchange_token = try parseCsvU64(fields[idx_exchange_token]),
        .tradingsymbol = tradingsymbol,
        .name = name,
        .last_price = try parseCsvF64(fields[idx_last_price]),
        .expiry = expiry,
        .strike = try parseCsvF64(fields[idx_strike]),
        .tick_size = try parseCsvF64(fields[idx_tick_size]),
        .lot_size = try parseCsvU64(fields[idx_lot_size]),
        .instrument_type = instrument_type,
        .segment = segment,
        .exchange = exchange,
    };
}

fn parseMfInstrumentRow(
    allocator: std.mem.Allocator,
    fields: []const []const u8,
    idx_tradingsymbol: usize,
    idx_name: usize,
    idx_amc: usize,
    idx_purchase_allowed: usize,
    idx_redemption_allowed: usize,
    idx_last_price: usize,
    idx_purchase_amount_multiplier: usize,
    idx_minimum_purchase_amount: usize,
    idx_minimum_additional_purchase_amount: usize,
    idx_minimum_redemption_quantity: usize,
    idx_redemption_quantity_multiplier: usize,
    idx_dividend_type: usize,
    idx_scheme_type: usize,
    idx_plan: usize,
    idx_settlement_type: usize,
    idx_last_price_date: usize,
) !models.MfInstrument {
    try ensureCsvRowHasIndex(fields, idx_last_price_date);

    const tradingsymbol = try allocator.dupe(u8, fields[idx_tradingsymbol]);
    errdefer allocator.free(tradingsymbol);
    const name = try allocator.dupe(u8, fields[idx_name]);
    errdefer allocator.free(name);
    const amc = try allocator.dupe(u8, fields[idx_amc]);
    errdefer allocator.free(amc);
    const dividend_type = try allocator.dupe(u8, fields[idx_dividend_type]);
    errdefer allocator.free(dividend_type);
    const scheme_type = try allocator.dupe(u8, fields[idx_scheme_type]);
    errdefer allocator.free(scheme_type);
    const plan = try allocator.dupe(u8, fields[idx_plan]);
    errdefer allocator.free(plan);
    const settlement_type = try allocator.dupe(u8, fields[idx_settlement_type]);
    errdefer allocator.free(settlement_type);
    const last_price_date = try allocator.dupe(u8, fields[idx_last_price_date]);
    errdefer allocator.free(last_price_date);

    return .{
        .tradingsymbol = tradingsymbol,
        .name = name,
        .last_price = try parseCsvF64(fields[idx_last_price]),
        .amc = amc,
        .purchase_allowed = try parseCsvBool(fields[idx_purchase_allowed]),
        .redemption_allowed = try parseCsvBool(fields[idx_redemption_allowed]),
        .minimum_purchase_amount = try parseCsvF64(fields[idx_minimum_purchase_amount]),
        .purchase_amount_multiplier = try parseCsvF64(fields[idx_purchase_amount_multiplier]),
        .minimum_additional_purchase_amount = try parseCsvF64(fields[idx_minimum_additional_purchase_amount]),
        .minimum_redemption_quantity = try parseCsvF64(fields[idx_minimum_redemption_quantity]),
        .redemption_quantity_multiplier = try parseCsvF64(fields[idx_redemption_quantity_multiplier]),
        .dividend_type = dividend_type,
        .scheme_type = scheme_type,
        .plan = plan,
        .settlement_type = settlement_type,
        .last_price_date = last_price_date,
    };
}

fn ensureCsvRowHasIndex(fields: []const []const u8, idx: usize) !void {
    if (fields.len <= idx) return error.InvalidCsvRow;
}

fn csvHeaderIndex(header: []const []const u8, name: []const u8) !usize {
    for (header, 0..) |field, idx| {
        if (std.mem.eql(u8, field, name)) return idx;
    }
    return error.MissingCsvColumn;
}

fn nextCsvRecord(
    allocator: std.mem.Allocator,
    lines: *std.mem.SplitIterator(u8, .scalar),
) !?[][]const u8 {
    while (lines.next()) |raw_line| {
        const line = std.mem.trimRight(u8, raw_line, "\r");
        if (std.mem.trim(u8, line, " \t").len == 0) continue;
        return try parseCsvLine(allocator, line);
    }
    return null;
}

fn parseCsvLine(allocator: std.mem.Allocator, line: []const u8) ![][]const u8 {
    var fields: std.ArrayList([]const u8) = .empty;
    errdefer {
        for (fields.items) |field| allocator.free(field);
        fields.deinit(allocator);
    }

    var idx: usize = 0;
    while (true) {
        var field: std.ArrayList(u8) = .empty;
        errdefer field.deinit(allocator);

        if (idx < line.len and line[idx] == '"') {
            idx += 1;
            while (true) {
                if (idx >= line.len) return error.InvalidCsvRow;
                const ch = line[idx];
                if (ch == '"') {
                    if (idx + 1 < line.len and line[idx + 1] == '"') {
                        try field.append(allocator, '"');
                        idx += 2;
                        continue;
                    }
                    idx += 1;
                    break;
                }
                try field.append(allocator, ch);
                idx += 1;
            }

            if (idx < line.len and line[idx] != ',') return error.InvalidCsvRow;
        } else {
            while (idx < line.len and line[idx] != ',') : (idx += 1) {
                try field.append(allocator, line[idx]);
            }
        }

        try fields.append(allocator, try field.toOwnedSlice(allocator));

        if (idx >= line.len) break;
        idx += 1;

        if (idx == line.len) {
            try fields.append(allocator, try allocator.dupe(u8, ""));
            break;
        }
    }

    return fields.toOwnedSlice(allocator);
}

fn freeCsvFields(allocator: std.mem.Allocator, fields: []const []const u8) void {
    for (fields) |field| allocator.free(field);
    allocator.free(fields);
}

fn parseCsvBool(raw: []const u8) !bool {
    const value = std.mem.trim(u8, raw, " ");
    if (std.mem.eql(u8, value, "1") or std.ascii.eqlIgnoreCase(value, "true")) return true;
    if (std.mem.eql(u8, value, "0") or std.ascii.eqlIgnoreCase(value, "false")) return false;
    return error.InvalidCsvBoolean;
}

fn parseCsvU64(raw: []const u8) !u64 {
    const value = std.mem.trim(u8, raw, " ");
    return std.fmt.parseInt(u64, value, 10) catch error.InvalidCsvNumber;
}

fn parseCsvF64(raw: []const u8) !f64 {
    const value = std.mem.trim(u8, raw, " ");
    return std.fmt.parseFloat(f64, value) catch error.InvalidCsvNumber;
}

fn valueAsObject(value: std.json.Value) !std.json.ObjectMap {
    return switch (value) {
        .object => |object| object,
        else => error.InvalidEnvelope,
    };
}

fn valueAsArray(value: std.json.Value) !std.json.Array {
    return switch (value) {
        .array => |array| array,
        else => error.InvalidHistoricalCandle,
    };
}

fn valueAsString(value: std.json.Value) ![]const u8 {
    return switch (value) {
        .string => |string| string,
        else => error.InvalidHistoricalCandle,
    };
}

fn valueAsF64(value: std.json.Value) !f64 {
    return switch (value) {
        .float => |float| float,
        .integer => |integer| @as(f64, @floatFromInt(integer)),
        .number_string => |number_string| std.fmt.parseFloat(f64, number_string) catch error.InvalidHistoricalCandle,
        else => error.InvalidHistoricalCandle,
    };
}

fn valueAsU64(value: std.json.Value) !u64 {
    return switch (value) {
        .integer => |integer| if (integer >= 0) @as(u64, @intCast(integer)) else error.InvalidHistoricalCandle,
        .float => |float| if (float >= 0) @as(u64, @intFromFloat(float)) else error.InvalidHistoricalCandle,
        .number_string => |number_string| std.fmt.parseInt(u64, number_string, 10) catch error.InvalidHistoricalCandle,
        else => error.InvalidHistoricalCandle,
    };
}

fn appendQueryField(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), key: []const u8, value: []const u8, prefix_ampersand: bool) !void {
    if (prefix_ampersand) try buffer.append(allocator, '&');
    try percentEncodeInto(allocator, buffer, key);
    try buffer.append(allocator, '=');
    try percentEncodeInto(allocator, buffer, value);
}

fn percentEncodeInto(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), value: []const u8) !void {
    for (value) |ch| {
        if (isUnreserved(ch)) {
            try buffer.append(allocator, ch);
            continue;
        }

        var encoded: [3]u8 = undefined;
        encoded[0] = '%';
        encoded[1] = "0123456789ABCDEF"[ch >> 4];
        encoded[2] = "0123456789ABCDEF"[ch & 0x0f];
        try buffer.appendSlice(allocator, &encoded);
    }
}

fn isUnreserved(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or
        (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9') or
        ch == '-' or ch == '.' or ch == '_' or ch == '~';
}

test "buildInstrumentsQuery encodes repeated i parameters" {
    const query = try buildInstrumentsQuery(std.testing.allocator, &.{ "NSE:INFY", "NSE:TCS" });
    defer std.testing.allocator.free(query);

    try std.testing.expectEqualStrings("i=NSE%3AINFY&i=NSE%3ATCS", query);
}

test "historicalPath uses instrument token and interval in path" {
    const path = try historicalPath(std.testing.allocator, 408065, "day");
    defer std.testing.allocator.free(path);

    try std.testing.expectEqualStrings("/instruments/historical/408065/day", path);
}

test "parseLtp parses map payload" {
    const payload =
        \\{"status":"success","data":{"NSE:INFY":{"instrument_token":408065,"last_price":1542.25}}}
    ;

    const parsed = try parseLtp(std.testing.allocator, payload);
    defer parsed.deinit();

    const entry = parsed.value.data.map.get("NSE:INFY") orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(u64, 408065), entry.instrument_token);
    try std.testing.expectApproxEqAbs(@as(f64, 1542.25), entry.last_price, 0.0001);
}

test "market request specs set expected response format" {
    const query = "i=NSE%3AINFY";
    try std.testing.expectEqual(transport.ResponseFormat.json, quoteRequestSpec(query).response_format);
    try std.testing.expectEqual(transport.ResponseFormat.json, ltpRequestSpec(query).response_format);
    try std.testing.expectEqual(transport.ResponseFormat.json, ohlcRequestSpec(query).response_format);

    const historical_spec = historicalRequestSpec("/instruments/historical/408065/day", "from=x&to=y");
    try std.testing.expectEqual(transport.ResponseFormat.json, historical_spec.response_format);
    try std.testing.expectEqualStrings("from=x&to=y", historical_spec.query.?);

    const instruments_spec = instrumentsRequestSpec();
    try std.testing.expectEqual(transport.ResponseFormat.csv, instruments_spec.response_format);

    const exchange_spec = instrumentsByExchangeRequestSpec("/instruments/NSE");
    try std.testing.expectEqual(transport.ResponseFormat.csv, exchange_spec.response_format);
    try std.testing.expectEqualStrings("/instruments/NSE", exchange_spec.options.path);

    const mf_spec = mfInstrumentsRequestSpec();
    try std.testing.expectEqual(transport.ResponseFormat.csv, mf_spec.response_format);
}

test "decodeQuoteExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":{\"NSE:INFY\":{\"instrument_token\":408065,\"last_price\":1542.25,\"ohlc\":{\"open\":1500.0,\"high\":1550.0,\"low\":1490.0,\"close\":1510.0}}}}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeQuoteExecuted(std.testing.allocator, .{
        .success = .{ .status = 200, .content_type = content_type, .body = body },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    const entry = result.success.parsed.value.data.map.get("NSE:INFY") orelse return error.TestExpectedEqual;
    try std.testing.expectEqual(@as(u64, 408065), entry.instrument_token);
}

test "decodeHistoricalDataExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":{\"candles\":[[\"2026-04-01T09:15:00+0530\",1500.0,1510.0,1498.0,1508.0,12000,3400]]}}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeHistoricalDataExecuted(std.testing.allocator, .{
        .success = .{ .status = 200, .content_type = content_type, .body = body },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqual(@as(usize, 1), result.success.candles.len);
    try std.testing.expectEqualStrings("2026-04-01T09:15:00+0530", result.success.candles[0].date);
}

test "decodeInstrumentsExecuted preserves owned api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "Forbidden",
        .error_type = "PermissionException",
    }, 403);

    const result = try decodeInstrumentsExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("Forbidden", result.api_error.message);
}

test "instruments request specs set CSV response format" {
    const instruments_spec = instrumentsRequestSpec();
    try std.testing.expectEqual(transport.ResponseFormat.csv, instruments_spec.response_format);
    try std.testing.expectEqualStrings("/instruments", instruments_spec.options.path);

    const mf_spec = mfInstrumentsRequestSpec();
    try std.testing.expectEqual(transport.ResponseFormat.csv, mf_spec.response_format);
    try std.testing.expectEqualStrings("/mf/instruments", mf_spec.options.path);
}

test "parseInstrumentsCsv parses documented instrument columns" {
    const payload =
        \\instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,exchange
        \\408065,1594,INFY,INFOSYS,1542.25,2026-04-30,0,0.05,1,EQ,NSE,NSE
    ;

    const parsed = try parseInstrumentsCsv(std.testing.allocator, payload);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.instruments.len);
    try std.testing.expectEqual(@as(u64, 408065), parsed.instruments[0].instrument_token);
    try std.testing.expectEqual(@as(u64, 1), parsed.instruments[0].lot_size);
    try std.testing.expectEqualStrings("INFY", parsed.instruments[0].tradingsymbol);
    try std.testing.expectEqualStrings("NSE", parsed.instruments[0].exchange);
}

test "parseMfInstrumentsCsv parses bools numerics and quoted fields" {
    const payload =
        \\tradingsymbol,amc,name,purchase_allowed,redemption_allowed,last_price,purchase_amount_multiplier,minimum_purchase_amount,minimum_additional_purchase_amount,minimum_redemption_quantity,redemption_quantity_multiplier,dividend_type,scheme_type,plan,settlement_type,last_price_date
        \\INF200K01XY1,INFOSYS AMC,"Balanced ""Growth"" Fund",true,false,34.125,1,5000,1000,0.001,0.001,growth,open,regular,T+2,2026-04-04
    ;

    const parsed = try parseMfInstrumentsCsv(std.testing.allocator, payload);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.instruments.len);
    try std.testing.expect(parsed.instruments[0].purchase_allowed);
    try std.testing.expect(!parsed.instruments[0].redemption_allowed);
    try std.testing.expectApproxEqAbs(@as(f64, 34.125), parsed.instruments[0].last_price, 0.0001);
    try std.testing.expectEqualStrings("Balanced \"Growth\" Fund", parsed.instruments[0].name);
    try std.testing.expectEqualStrings("2026-04-04", parsed.instruments[0].last_price_date);
}
