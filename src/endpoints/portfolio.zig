//! Portfolio endpoint contracts, runtime execution helpers, request builders, and envelope parsers.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const models = @import("../models/portfolio.zig");
const transport = @import("../transport.zig");

/// API path constants for portfolio endpoints.
pub const Paths = struct {
    pub const holdings = "/portfolio/holdings";
    pub const holdings_summary = "/portfolio/holdings/summary";
    pub const holdings_compact = "/portfolio/holdings/compact";
    pub const holdings_authorise = "/portfolio/holdings/authorise";
    pub const auction_instruments = "/portfolio/holdings/auctions";
    pub const positions = "/portfolio/positions";
};

/// Shared constants for holdings authorisation form fields.
pub const HoldingsAuth = struct {
    pub const type_mf = "mf";
    pub const type_equity = "equity";

    pub const transfer_type_pre_trade = "pre";
    pub const transfer_type_post_trade = "post";
    pub const transfer_type_off_market = "off";
    pub const transfer_type_gift = "gift";
};

/// Individual ISIN and quantity pair used by holdings-authorisation initiation.
pub const HoldingsAuthInstrument = struct {
    isin: []const u8,
    quantity: f64,
};

/// Input parameters for `POST /portfolio/holdings/authorise`.
pub const HoldingsAuthParams = struct {
    auth_type: ?[]const u8 = null,
    transfer_type: ?[]const u8 = null,
    exec_date: ?[]const u8 = null,
    instruments: []const HoldingsAuthInstrument = &.{},
};

/// Response payload returned by `POST /portfolio/holdings/authorise`.
pub const HoldingsAuthResponse = struct {
    request_id: []const u8,
};

/// Parsed success payload for `GET /portfolio/holdings` that retains response-body backing.
pub const HoldingsSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.Holding));

/// Parsed success payload for `GET /portfolio/holdings/summary` that retains response-body backing.
pub const HoldingsSummarySuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.HoldingSummary));

/// Parsed success payload for `GET /portfolio/holdings/compact` that retains response-body backing.
pub const HoldingsCompactSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.HoldingCompact));

/// Parsed success payload for `POST /portfolio/holdings/authorise` that retains response-body backing.
pub const HoldingsAuthSuccess = http.OwnedParsed(envelope.SuccessEnvelope(HoldingsAuthResponse));

/// Parsed success payload for `GET /portfolio/holdings/auctions` that retains response-body backing.
pub const AuctionInstrumentsSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.AuctionInstrument));

/// Parsed success payload for `GET /portfolio/positions` that retains response-body backing.
pub const PositionsSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.Positions));

/// Parsed success payload for `PUT /portfolio/positions` that retains response-body backing.
pub const ConvertPositionSuccess = http.OwnedParsed(envelope.SuccessEnvelope(bool));

/// Result of executing `GET /portfolio/holdings`.
pub const HoldingsResult = union(enum) {
    success: HoldingsSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: HoldingsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /portfolio/holdings/summary`.
pub const HoldingsSummaryResult = union(enum) {
    success: HoldingsSummarySuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: HoldingsSummaryResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /portfolio/holdings/compact`.
pub const HoldingsCompactResult = union(enum) {
    success: HoldingsCompactSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: HoldingsCompactResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `POST /portfolio/holdings/authorise`.
pub const HoldingsAuthResult = union(enum) {
    success: HoldingsAuthSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: HoldingsAuthResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /portfolio/holdings/auctions`.
pub const AuctionInstrumentsResult = union(enum) {
    success: AuctionInstrumentsSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: AuctionInstrumentsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /portfolio/positions`.
pub const PositionsResult = union(enum) {
    success: PositionsSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: PositionsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `PUT /portfolio/positions`.
pub const ConvertPositionResult = union(enum) {
    success: ConvertPositionSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: ConvertPositionResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Request metadata for `GET /portfolio/holdings`.
pub fn holdingsRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.holdings };
}

/// Request metadata for `GET /portfolio/holdings/summary`.
pub fn holdingsSummaryRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.holdings_summary };
}

/// Request metadata for `GET /portfolio/holdings/compact`.
pub fn holdingsCompactRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.holdings_compact };
}

/// Request metadata for `POST /portfolio/holdings/authorise`.
pub fn holdingsAuthRequestOptions() transport.RequestOptions {
    return .{ .method = .post, .path = Paths.holdings_authorise };
}

/// Request metadata for `GET /portfolio/holdings/auctions`.
pub fn auctionInstrumentsRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.auction_instruments };
}

/// Request metadata for `GET /portfolio/positions`.
pub fn positionsRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.positions };
}

/// Request metadata for `PUT /portfolio/positions`.
pub fn convertPositionRequestOptions() transport.RequestOptions {
    return .{ .method = .put, .path = Paths.positions };
}

/// Backward-compatible alias for `holdingsRequestOptions`.
pub fn holdingsRequest() transport.RequestOptions {
    return holdingsRequestOptions();
}

/// Backward-compatible alias for `holdingsSummaryRequestOptions`.
pub fn holdingsSummaryRequest() transport.RequestOptions {
    return holdingsSummaryRequestOptions();
}

/// Backward-compatible alias for `holdingsCompactRequestOptions`.
pub fn holdingsCompactRequest() transport.RequestOptions {
    return holdingsCompactRequestOptions();
}

/// Backward-compatible alias for `holdingsAuthRequestOptions`.
pub fn holdingsAuthRequest() transport.RequestOptions {
    return holdingsAuthRequestOptions();
}

/// Backward-compatible alias for `auctionInstrumentsRequestOptions`.
pub fn auctionInstrumentsRequest() transport.RequestOptions {
    return auctionInstrumentsRequestOptions();
}

/// Backward-compatible alias for `positionsRequestOptions`.
pub fn positionsRequest() transport.RequestOptions {
    return positionsRequestOptions();
}

/// Backward-compatible alias for `convertPositionRequestOptions`.
pub fn convertPositionRequest() transport.RequestOptions {
    return convertPositionRequestOptions();
}

/// Build a request spec for `GET /portfolio/holdings`.
pub fn holdingsRequestSpec() transport.RequestSpec {
    return .{
        .options = holdingsRequestOptions(),
        .response_format = .json,
    };
}

/// Build a request spec for `GET /portfolio/holdings/summary`.
pub fn holdingsSummaryRequestSpec() transport.RequestSpec {
    return .{
        .options = holdingsSummaryRequestOptions(),
        .response_format = .json,
    };
}

/// Build a request spec for `GET /portfolio/holdings/compact`.
pub fn holdingsCompactRequestSpec() transport.RequestSpec {
    return .{
        .options = holdingsCompactRequestOptions(),
        .response_format = .json,
    };
}

/// Build a request spec for `POST /portfolio/holdings/authorise`.
pub fn holdingsAuthRequestSpec(form: []const u8) transport.RequestSpec {
    return .{
        .options = holdingsAuthRequestOptions(),
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Build a request spec for `GET /portfolio/holdings/auctions`.
pub fn auctionInstrumentsRequestSpec() transport.RequestSpec {
    return .{
        .options = auctionInstrumentsRequestOptions(),
        .response_format = .json,
    };
}

/// Build a request spec for `GET /portfolio/positions`.
pub fn positionsRequestSpec() transport.RequestSpec {
    return .{
        .options = positionsRequestOptions(),
        .response_format = .json,
    };
}

/// Build a request spec for `PUT /portfolio/positions`.
pub fn convertPositionRequestSpec(form: []const u8) transport.RequestSpec {
    return .{
        .options = convertPositionRequestOptions(),
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Executes `GET /portfolio/holdings` and decodes either success payload or owned API error.
pub fn executeHoldings(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!HoldingsResult {
    return decodeHoldingsExecuted(client.allocator, try client.execute(runtime_client, holdingsRequestSpec()));
}

/// Executes `GET /portfolio/holdings/summary` and decodes either success payload or owned API error.
pub fn executeHoldingsSummary(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!HoldingsSummaryResult {
    return decodeHoldingsSummaryExecuted(client.allocator, try client.execute(runtime_client, holdingsSummaryRequestSpec()));
}

/// Executes `GET /portfolio/holdings/compact` and decodes either success payload or owned API error.
pub fn executeHoldingsCompact(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!HoldingsCompactResult {
    return decodeHoldingsCompactExecuted(client.allocator, try client.execute(runtime_client, holdingsCompactRequestSpec()));
}

/// Executes `POST /portfolio/holdings/authorise` and decodes either success payload or owned API error.
pub fn executeHoldingsAuth(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!HoldingsAuthResult {
    return decodeHoldingsAuthExecuted(client.allocator, try client.execute(runtime_client, holdingsAuthRequestSpec(form)));
}

/// Executes `GET /portfolio/holdings/auctions` and decodes either success payload or owned API error.
pub fn executeAuctionInstruments(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!AuctionInstrumentsResult {
    return decodeAuctionInstrumentsExecuted(client.allocator, try client.execute(runtime_client, auctionInstrumentsRequestSpec()));
}

/// Executes `GET /portfolio/positions` and decodes either success payload or owned API error.
pub fn executePositions(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!PositionsResult {
    return decodePositionsExecuted(client.allocator, try client.execute(runtime_client, positionsRequestSpec()));
}

/// Executes `PUT /portfolio/positions` and decodes either success payload or owned API error.
pub fn executeConvertPosition(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!ConvertPositionResult {
    return decodeConvertPositionExecuted(client.allocator, try client.execute(runtime_client, convertPositionRequestSpec(form)));
}

/// Builds form-urlencoded payload for holdings-authorisation initiation.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildHoldingsAuthForm(
    allocator: std.mem.Allocator,
    params: HoldingsAuthParams,
) ![]u8 {
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    var has_fields = false;

    if (params.auth_type) |auth_type| {
        if (auth_type.len != 0) {
            try appendFormField(allocator, &buffer, "type", auth_type, has_fields);
            has_fields = true;
        }
    }

    if (params.transfer_type) |transfer_type| {
        if (transfer_type.len != 0) {
            try appendFormField(allocator, &buffer, "transfer_type", transfer_type, has_fields);
            has_fields = true;
        }
    }

    if (params.exec_date) |exec_date| {
        if (exec_date.len != 0) {
            try appendFormField(allocator, &buffer, "exec_date", exec_date, has_fields);
            has_fields = true;
        }
    }

    for (params.instruments) |instrument| {
        if (instrument.isin.len == 0) return error.EmptyIsin;

        try appendFormField(allocator, &buffer, "isin", instrument.isin, has_fields);
        has_fields = true;

        const quantity = try std.fmt.allocPrint(allocator, "{d:.6}", .{instrument.quantity});
        defer allocator.free(quantity);
        try appendFormField(allocator, &buffer, "quantity", quantity, true);
    }

    return buffer.toOwnedSlice(allocator);
}

/// Build holdings-authorisation redirect URL from API key and request ID.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn holdingsAuthRedirectUrl(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    request_id: []const u8,
) ![]u8 {
    if (api_key.len == 0) return error.EmptyApiKey;
    if (request_id.len == 0) return error.EmptyRequestId;

    return std.fmt.allocPrint(
        allocator,
        "https://kite.zerodha.com/connect/portfolio/authorise/holdings/{s}/{s}",
        .{ api_key, request_id },
    );
}

/// Builds form-urlencoded payload for position conversion.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildConvertPositionForm(
    allocator: std.mem.Allocator,
    params: models.ConvertPositionParams,
) ![]u8 {
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendFormField(allocator, &buffer, "exchange", params.exchange, false);
    try appendFormField(allocator, &buffer, "tradingsymbol", params.tradingsymbol, true);
    try appendFormField(allocator, &buffer, "old_product", params.old_product, true);
    try appendFormField(allocator, &buffer, "new_product", params.new_product, true);
    try appendFormField(allocator, &buffer, "position_type", params.position_type, true);
    try appendFormField(allocator, &buffer, "transaction_type", params.transaction_type, true);

    const quantity = try std.fmt.allocPrint(allocator, "{d}", .{params.quantity});
    defer allocator.free(quantity);
    try appendFormField(allocator, &buffer, "quantity", quantity, true);

    return buffer.toOwnedSlice(allocator);
}

/// Parses an envelope payload returned by `GET /portfolio/holdings`.
pub fn parseHoldings(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.Holding)) {
    return envelope.parseSuccessEnvelope([]const models.Holding, allocator, payload);
}

/// Parses an envelope payload returned by `GET /portfolio/holdings/summary`.
pub fn parseHoldingsSummary(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.HoldingSummary)) {
    return envelope.parseSuccessEnvelope(models.HoldingSummary, allocator, payload);
}

/// Parses an envelope payload returned by `GET /portfolio/holdings/compact`.
pub fn parseHoldingsCompact(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.HoldingCompact)) {
    return envelope.parseSuccessEnvelope([]const models.HoldingCompact, allocator, payload);
}

/// Parses an envelope payload returned by `POST /portfolio/holdings/authorise`.
pub fn parseHoldingsAuth(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(HoldingsAuthResponse)) {
    return envelope.parseSuccessEnvelope(HoldingsAuthResponse, allocator, payload);
}

/// Parses an envelope payload returned by `GET /portfolio/holdings/auctions`.
pub fn parseAuctionInstruments(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.AuctionInstrument)) {
    return envelope.parseSuccessEnvelope([]const models.AuctionInstrument, allocator, payload);
}

/// Parses an envelope payload returned by `GET /portfolio/positions`.
pub fn parsePositions(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.Positions)) {
    return envelope.parseSuccessEnvelope(models.Positions, allocator, payload);
}

/// Parses an envelope payload returned by `PUT /portfolio/positions`.
pub fn parseConvertPosition(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(bool)) {
    return envelope.parseSuccessEnvelope(bool, allocator, payload);
}

fn decodeHoldingsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!HoldingsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.Holding, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeHoldingsSummaryExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!HoldingsSummaryResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.HoldingSummary, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeHoldingsCompactExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!HoldingsCompactResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.HoldingCompact, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeHoldingsAuthExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!HoldingsAuthResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(HoldingsAuthResponse, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeAuctionInstrumentsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!AuctionInstrumentsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.AuctionInstrument, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodePositionsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!PositionsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.Positions, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeConvertPositionExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!ConvertPositionResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(bool, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn appendFormField(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), key: []const u8, value: []const u8, prefix_ampersand: bool) !void {
    if (prefix_ampersand) {
        try buffer.append(allocator, '&');
    }
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

test "portfolio request options and request specs" {
    const holdings = holdingsRequestOptions();
    try std.testing.expectEqual(transport.Method.get, holdings.method);
    try std.testing.expectEqualStrings(Paths.holdings, holdings.path);

    const holdings_spec = holdingsRequestSpec();
    try std.testing.expectEqual(transport.Method.get, holdings_spec.options.method);
    try std.testing.expectEqual(transport.ResponseFormat.json, holdings_spec.response_format);

    const positions = positionsRequestOptions();
    try std.testing.expectEqual(transport.Method.get, positions.method);
    try std.testing.expectEqualStrings(Paths.positions, positions.path);

    const convert = convertPositionRequestOptions();
    try std.testing.expectEqual(transport.Method.put, convert.method);
    try std.testing.expectEqualStrings(Paths.positions, convert.path);

    const convert_spec = convertPositionRequestSpec("exchange=NSE");
    try std.testing.expectEqual(transport.Method.put, convert_spec.options.method);
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", convert_spec.contentType().?);
    try std.testing.expectEqualStrings("exchange=NSE", convert_spec.body.form);
    try std.testing.expectEqual(transport.ResponseFormat.json, convert_spec.response_format);
}

test "buildConvertPositionForm encodes documented parameter names" {
    const form = try buildConvertPositionForm(std.testing.allocator, .{
        .exchange = "NSE",
        .tradingsymbol = "INFY",
        .old_product = "CNC",
        .new_product = "MIS",
        .position_type = "day",
        .transaction_type = "BUY",
        .quantity = 5,
    });
    defer std.testing.allocator.free(form);

    try std.testing.expectEqualStrings(
        "exchange=NSE&tradingsymbol=INFY&old_product=CNC&new_product=MIS&position_type=day&transaction_type=BUY&quantity=5",
        form,
    );
}

test "parseHoldings parses success envelope data" {
    const payload =
        \\{"status":"success","data":[{"tradingsymbol":"INFY","exchange":"NSE","instrument_token":408065,"isin":"INE009A01021","product":"CNC","price":1200.5,"used_quantity":0,"quantity":10,"t1_quantity":0,"realised_quantity":10,"authorised_quantity":10,"authorised_date":"2026-04-05","opening_quantity":10,"collateral_quantity":0,"collateral_type":"","discrepancy":false,"average_price":1188.2,"last_price":1201.0,"close_price":1197.9,"pnl":128.0,"day_change":3.1,"day_change_percentage":0.26,"mtf":{"quantity":0,"used_quantity":0,"average_price":0,"value":0,"initial_margin":0}}]}
    ;

    const parsed = try parseHoldings(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.len);
    try std.testing.expectEqualStrings("INFY", parsed.value.data[0].tradingsymbol);
}

test "decodeHoldingsExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":[{\"tradingsymbol\":\"INFY\",\"exchange\":\"NSE\",\"instrument_token\":408065,\"isin\":\"INE009A01021\",\"product\":\"CNC\",\"price\":1200.5,\"used_quantity\":0,\"quantity\":10,\"t1_quantity\":0,\"realised_quantity\":10,\"authorised_quantity\":10,\"authorised_date\":\"2026-04-05\",\"opening_quantity\":10,\"collateral_quantity\":0,\"collateral_type\":\"\",\"discrepancy\":false,\"average_price\":1188.2,\"last_price\":1201.0,\"close_price\":1197.9,\"pnl\":128.0,\"day_change\":3.1,\"day_change_percentage\":0.26}]}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeHoldingsExecuted(std.testing.allocator, .{
        .success = .{
            .status = 200,
            .content_type = content_type,
            .body = body,
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqual(@as(usize, 1), result.success.parsed.value.data.len);
    try std.testing.expectEqualStrings("INFY", result.success.parsed.value.data[0].tradingsymbol);
}

test "decodeConvertPositionExecuted decodes bool success payload" {
    const body = try std.testing.allocator.dupe(u8, "{\"status\":\"success\",\"data\":true}");
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeConvertPositionExecuted(std.testing.allocator, .{
        .success = .{
            .status = 200,
            .content_type = content_type,
            .body = body,
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expect(result.success.parsed.value.data);
}

test "decodeConvertPositionExecuted preserves owned api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "Invalid position conversion",
        .error_type = "InputException",
    }, 400);

    const result = try decodeConvertPositionExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("Invalid position conversion", result.api_error.message);
    try std.testing.expectEqualStrings(errors.ErrorType.input, result.api_error.error_type.?);
}
