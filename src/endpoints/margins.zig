//! Margins endpoint request descriptors, runtime execute+decode helpers, and envelope parsers.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const margin_models = @import("../models/margins.zig");
const transport = @import("../transport.zig");

/// Query args for `POST /margins/orders`.
pub const OrderMarginsQuery = struct {
    compact: bool = false,
};

/// Query args for `POST /margins/basket`.
pub const BasketMarginsQuery = struct {
    compact: bool = false,
    consider_positions: bool = false,
};

/// Error set used by query builders.
pub const QueryError = error{OutOfMemory};

/// Parsed success payload for `POST /margins/orders` that retains response-body backing.
pub const OrderMarginsSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]margin_models.OrderMargin));

/// Parsed success payload for `POST /margins/basket` that retains response-body backing.
pub const BasketMarginsSuccess = http.OwnedParsed(envelope.SuccessEnvelope(margin_models.BasketMargins));

/// Parsed success payload for `POST /charges/orders` that retains response-body backing.
pub const OrderChargesSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]margin_models.OrderCharge));

/// Result of executing `POST /margins/orders`.
pub const OrderMarginsResult = union(enum) {
    success: OrderMarginsSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: OrderMarginsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `POST /margins/basket`.
pub const BasketMarginsResult = union(enum) {
    success: BasketMarginsSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: BasketMarginsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `POST /charges/orders`.
pub const OrderChargesResult = union(enum) {
    success: OrderChargesSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: OrderChargesResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Request metadata for `POST /margins/orders`.
pub fn orderMarginsRequestOptions() transport.RequestOptions {
    return .{
        .method = .post,
        .path = "/margins/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `POST /margins/orders`.
pub fn orderMarginsRequestSpec(body_json: []const u8, query: ?[]const u8) transport.RequestSpec {
    return .{
        .options = orderMarginsRequestOptions(),
        .query = query,
        .body = .{ .json = body_json },
        .response_format = .json,
    };
}

/// Request metadata for `POST /margins/basket`.
pub fn basketMarginsRequestOptions() transport.RequestOptions {
    return .{
        .method = .post,
        .path = "/margins/basket",
        .requires_auth = true,
    };
}

/// Build a request spec for `POST /margins/basket`.
pub fn basketMarginsRequestSpec(body_json: []const u8, query: ?[]const u8) transport.RequestSpec {
    return .{
        .options = basketMarginsRequestOptions(),
        .query = query,
        .body = .{ .json = body_json },
        .response_format = .json,
    };
}

/// Request metadata for `POST /charges/orders`.
pub fn orderChargesRequestOptions() transport.RequestOptions {
    return .{
        .method = .post,
        .path = "/charges/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `POST /charges/orders`.
pub fn orderChargesRequestSpec(body_json: []const u8) transport.RequestSpec {
    return .{
        .options = orderChargesRequestOptions(),
        .body = .{ .json = body_json },
        .response_format = .json,
    };
}

/// Build encoded query for `POST /margins/orders`.
/// Returns null when no query params are needed.
/// Caller owns returned slice when non-null.
pub fn buildOrderMarginsQuery(allocator: std.mem.Allocator, query: OrderMarginsQuery) QueryError!?[]u8 {
    if (!query.compact) return null;
    return try allocator.dupe(u8, "mode=compact");
}

/// Build encoded query for `POST /margins/basket`.
/// Returns null when no query params are needed.
/// Caller owns returned slice when non-null.
pub fn buildBasketMarginsQuery(allocator: std.mem.Allocator, query: BasketMarginsQuery) QueryError!?[]u8 {
    var encoded: std.ArrayList(u8) = .empty;
    defer encoded.deinit(allocator);

    var has_fields = false;
    if (query.compact) {
        try appendQueryPair(allocator, &encoded, "mode", "compact", has_fields);
        has_fields = true;
    }
    if (query.consider_positions) {
        try appendQueryPair(allocator, &encoded, "consider_positions", "true", has_fields);
        has_fields = true;
    }

    if (!has_fields) return null;
    return try encoded.toOwnedSlice(allocator);
}

/// Executes `POST /margins/orders` and decodes either success payload or owned API error.
pub fn executeOrderMargins(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    body_json: []const u8,
    query: ?[]const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrderMarginsResult {
    return decodeOrderMarginsExecuted(client.allocator, try client.execute(runtime_client, orderMarginsRequestSpec(body_json, query)));
}

/// Executes `POST /margins/basket` and decodes either success payload or owned API error.
pub fn executeBasketMargins(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    body_json: []const u8,
    query: ?[]const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!BasketMarginsResult {
    return decodeBasketMarginsExecuted(client.allocator, try client.execute(runtime_client, basketMarginsRequestSpec(body_json, query)));
}

/// Executes `POST /charges/orders` and decodes either success payload or owned API error.
pub fn executeOrderCharges(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    body_json: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrderChargesResult {
    return decodeOrderChargesExecuted(client.allocator, try client.execute(runtime_client, orderChargesRequestSpec(body_json)));
}

/// Parse a `/margins/orders` success envelope.
/// Caller owns the parsed value and must call `deinit()` on the result.
pub fn parseOrderMargins(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]margin_models.OrderMargin)) {
    return envelope.parseSuccessEnvelope([]margin_models.OrderMargin, allocator, payload);
}

/// Parse a `/margins/basket` success envelope.
/// Caller owns the parsed value and must call `deinit()` on the result.
pub fn parseBasketMargins(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(margin_models.BasketMargins)) {
    return envelope.parseSuccessEnvelope(margin_models.BasketMargins, allocator, payload);
}

/// Parse a `/charges/orders` success envelope.
/// Caller owns the parsed value and must call `deinit()` on the result.
pub fn parseOrderCharges(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]margin_models.OrderCharge)) {
    return envelope.parseSuccessEnvelope([]margin_models.OrderCharge, allocator, payload);
}

fn decodeOrderMarginsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!OrderMarginsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]margin_models.OrderMargin, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeBasketMarginsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!BasketMarginsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(margin_models.BasketMargins, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeOrderChargesExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!OrderChargesResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]margin_models.OrderCharge, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn appendQueryPair(
    allocator: std.mem.Allocator,
    encoded: *std.ArrayList(u8),
    key: []const u8,
    value: []const u8,
    prefix_ampersand: bool,
) !void {
    if (prefix_ampersand) try encoded.append(allocator, '&');
    try encoded.appendSlice(allocator, key);
    try encoded.append(allocator, '=');
    try encoded.appendSlice(allocator, value);
}

test "margins endpoint request options match Kite paths" {
    const order_margins = orderMarginsRequestOptions();
    try std.testing.expectEqual(.post, order_margins.method);
    try std.testing.expectEqualStrings("/margins/orders", order_margins.path);
    try std.testing.expect(order_margins.requires_auth);

    const basket_margins = basketMarginsRequestOptions();
    try std.testing.expectEqual(.post, basket_margins.method);
    try std.testing.expectEqualStrings("/margins/basket", basket_margins.path);
    try std.testing.expect(basket_margins.requires_auth);

    const order_charges = orderChargesRequestOptions();
    try std.testing.expectEqual(.post, order_charges.method);
    try std.testing.expectEqualStrings("/charges/orders", order_charges.path);
    try std.testing.expect(order_charges.requires_auth);

    const order_spec = orderMarginsRequestSpec("[]", null);
    try std.testing.expectEqualStrings("application/json", order_spec.contentType().?);

    const basket_spec = basketMarginsRequestSpec("[]", "mode=compact");
    try std.testing.expectEqualStrings("mode=compact", basket_spec.query.?);

    const charges_spec = orderChargesRequestSpec("[]");
    try std.testing.expectEqualStrings("application/json", charges_spec.contentType().?);
}

test "margins query builders encode gokite params" {
    const order_query = try buildOrderMarginsQuery(std.testing.allocator, .{ .compact = true });
    defer if (order_query) |value| std.testing.allocator.free(value);
    try std.testing.expect(order_query != null);
    try std.testing.expectEqualStrings("mode=compact", order_query.?);

    const basket_query = try buildBasketMarginsQuery(std.testing.allocator, .{ .compact = true, .consider_positions = true });
    defer if (basket_query) |value| std.testing.allocator.free(value);
    try std.testing.expect(basket_query != null);
    try std.testing.expectEqualStrings("mode=compact&consider_positions=true", basket_query.?);

    const empty_basket_query = try buildBasketMarginsQuery(std.testing.allocator, .{});
    try std.testing.expect(empty_basket_query == null);
}

test "parseOrderMargins decodes order margin rows" {
    const payload =
        \\{"status":"success","data":[{"type":"equity","tradingsymbol":"INFY","exchange":"NSE","span":1200.5,"exposure":300.25,"option_premium":0,"additional":100,"bo":0,"cash":0,"var":1498,"pnl":{"realised":25.5,"unrealised":-5.25},"leverage":1,"charges":{"transaction_tax":1.498,"transaction_tax_type":"stt","exchange_turnover_charge":0.051681,"sebi_turnover_charge":0.001498,"brokerage":0.01,"stamp_duty":0.22,"gst":{"igst":0.01137222,"cgst":0,"sgst":0,"total":0.01137222},"total":1.79255122},"total":1600.75},{"type":"commodity","tradingsymbol":"GOLDM","exchange":"MCX","span":7000,"exposure":1200,"option_premium":0,"additional":0,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":1,"charges":{"transaction_tax":0.5,"transaction_tax_type":"ctt","exchange_turnover_charge":0.1,"sebi_turnover_charge":0.01,"brokerage":1,"stamp_duty":0,"gst":{"igst":0.2,"cgst":0,"sgst":0,"total":0.2},"total":1.81},"total":8200}]}
    ;

    const parsed = try parseOrderMargins(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), parsed.value.data.len);
    try std.testing.expectEqualStrings("INFY", parsed.value.data[0].tradingsymbol.?);
    try std.testing.expectEqual(@as(f64, 1498), parsed.value.data[0].@"var");
    try std.testing.expectEqualStrings("stt", parsed.value.data[0].charges.transaction_tax_type.?);
    try std.testing.expectEqual(@as(f64, 8200), parsed.value.data[1].total);
}

test "parseBasketMargins decodes initial and final totals" {
    const payload =
        \\{"status":"success","data":{"initial":{"type":"","tradingsymbol":"","exchange":"","span":1500,"exposure":250,"option_premium":0,"additional":100,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":0,"charges":{"transaction_tax":0,"transaction_tax_type":"","exchange_turnover_charge":0,"sebi_turnover_charge":0,"brokerage":0,"stamp_duty":0,"gst":{"igst":0,"cgst":0,"sgst":0,"total":0},"total":0},"total":1850},"final":{"type":"","tradingsymbol":"","exchange":"","span":1200,"exposure":150,"option_premium":0,"additional":80,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":0,"charges":{"transaction_tax":0,"transaction_tax_type":"","exchange_turnover_charge":0,"sebi_turnover_charge":0,"brokerage":0,"stamp_duty":0,"gst":{"igst":0,"cgst":0,"sgst":0,"total":0},"total":0},"total":1430},"orders":[{"type":"equity","tradingsymbol":"INFY","exchange":"NSE","span":1500,"exposure":250,"option_premium":0,"additional":100,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":1,"charges":{"transaction_tax":1,"transaction_tax_type":"stt","exchange_turnover_charge":0.1,"sebi_turnover_charge":0.01,"brokerage":20,"stamp_duty":0.2,"gst":{"igst":3.6,"cgst":0,"sgst":0,"total":3.6},"total":24.91},"total":1850}],"charges":{"transaction_tax":0,"transaction_tax_type":"","exchange_turnover_charge":0,"sebi_turnover_charge":0.01,"brokerage":20,"stamp_duty":0,"gst":{"igst":0,"cgst":0,"sgst":0,"total":0},"total":20.01}}}
    ;

    const parsed = try parseBasketMargins(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(f64, 1850), parsed.value.data.initial.total);
    try std.testing.expectEqual(@as(f64, 1430), parsed.value.data.final.total);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.orders.len);
    try std.testing.expectEqual(@as(f64, 20), parsed.value.data.charges.brokerage);
}

test "parseOrderCharges decodes charge rows" {
    const payload =
        \\{"status":"success","data":[{"transaction_type":"BUY","tradingsymbol":"SBIN","exchange":"NSE","variety":"regular","product":"CNC","order_type":"MARKET","quantity":1,"price":560,"charges":{"transaction_tax":0.56,"transaction_tax_type":"stt","exchange_turnover_charge":0.01876,"sebi_turnover_charge":0.00056,"brokerage":0,"stamp_duty":0,"gst":{"igst":0.0033768,"cgst":0,"sgst":0,"total":0.0033768},"total":0.5826968}}]}
    ;

    const parsed = try parseOrderCharges(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.len);
    try std.testing.expectEqualStrings("SBIN", parsed.value.data[0].tradingsymbol.?);
    try std.testing.expectEqualStrings("stt", parsed.value.data[0].charges.transaction_tax_type.?);
    try std.testing.expectEqual(@as(f64, 0.5826968), parsed.value.data[0].charges.total);
}

test "decodeOrderMarginsExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":[{\"type\":\"equity\",\"tradingsymbol\":\"INFY\",\"exchange\":\"NSE\",\"span\":0,\"exposure\":0,\"option_premium\":0,\"additional\":0,\"bo\":0,\"cash\":0,\"var\":1498,\"pnl\":{\"realised\":0,\"unrealised\":0},\"leverage\":1,\"charges\":{\"transaction_tax\":1.498,\"transaction_tax_type\":\"stt\",\"exchange_turnover_charge\":0.051681,\"sebi_turnover_charge\":0.001498,\"brokerage\":0.01,\"stamp_duty\":0.22,\"gst\":{\"igst\":0.011372219999999999,\"cgst\":0,\"sgst\":0,\"total\":0.011372219999999999},\"total\":1.79255122},\"total\":1498}]}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeOrderMarginsExecuted(std.testing.allocator, .{
        .success = .{ .status = 200, .content_type = content_type, .body = body },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqual(@as(usize, 1), result.success.parsed.value.data.len);
    try std.testing.expectEqual(@as(f64, 1498), result.success.parsed.value.data[0].total);
}
