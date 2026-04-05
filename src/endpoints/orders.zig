//! Orders and trades endpoint-family request contracts, runtime execute+decode helpers,
//! path builders, and envelope parsers.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const order_models = @import("../models/orders.zig");
const trade_models = @import("../models/trades.zig");
const transport = @import("../transport.zig");

/// Parsed success payload for `GET /orders` that retains response-body backing.
pub const OrdersSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]order_models.Order));

/// Parsed success payload for `GET /trades` that retains response-body backing.
pub const TradesSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]trade_models.Trade));

/// Parsed success payload for `GET /orders/{order_id}` that retains response-body backing.
pub const OrderHistorySuccess = http.OwnedParsed(envelope.SuccessEnvelope([]order_models.OrderHistoryEntry));

/// Parsed success payload for `GET /orders/{order_id}/trades` that retains response-body backing.
pub const OrderTradesSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]trade_models.Trade));

/// Parsed success payload for place/modify/cancel order APIs that retains response-body backing.
pub const OrderMutationSuccess = http.OwnedParsed(envelope.SuccessEnvelope(order_models.OrderMutationData));

/// Result of executing `GET /orders`.
pub const OrdersResult = union(enum) {
    success: OrdersSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: OrdersResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /trades`.
pub const TradesResult = union(enum) {
    success: TradesSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: TradesResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /orders/{order_id}`.
pub const OrderHistoryResult = union(enum) {
    success: OrderHistorySuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: OrderHistoryResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /orders/{order_id}/trades`.
pub const OrderTradesResult = union(enum) {
    success: OrderTradesSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: OrderTradesResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing order mutation APIs.
pub const OrderMutationResult = union(enum) {
    success: OrderMutationSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: OrderMutationResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Error set used by orders/trades path builders.
pub const PathError = error{
    EmptyVariety,
    EmptyOrderId,
    OutOfMemory,
};

/// Request metadata for `GET /orders`.
pub fn ordersRequestOptions() transport.RequestOptions {
    return .{
        .method = .get,
        .path = "/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `GET /orders`.
pub fn ordersRequestSpec() transport.RequestSpec {
    return .{
        .options = ordersRequestOptions(),
        .response_format = .json,
    };
}

/// Request metadata for `GET /trades`.
pub fn tradesRequestOptions() transport.RequestOptions {
    return .{
        .method = .get,
        .path = "/trades",
        .requires_auth = true,
    };
}

/// Build a request spec for `GET /trades`.
pub fn tradesRequestSpec() transport.RequestSpec {
    return .{
        .options = tradesRequestOptions(),
        .response_format = .json,
    };
}

/// Request metadata for `GET /orders/{order_id}`.
pub fn orderHistoryRequestOptions() transport.RequestOptions {
    return .{
        .method = .get,
        .path = "/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `GET /orders/{order_id}`.
pub fn orderHistoryRequestSpec(path: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .get, .path = path, .requires_auth = true },
        .response_format = .json,
    };
}

/// Request metadata for `GET /orders/{order_id}/trades`.
pub fn orderTradesRequestOptions() transport.RequestOptions {
    return .{
        .method = .get,
        .path = "/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `GET /orders/{order_id}/trades`.
pub fn orderTradesRequestSpec(path: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .get, .path = path, .requires_auth = true },
        .response_format = .json,
    };
}

/// Request metadata for `POST /orders/{variety}`.
pub fn placeOrderRequestOptions() transport.RequestOptions {
    return .{
        .method = .post,
        .path = "/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `POST /orders/{variety}`.
pub fn placeOrderRequestSpec(path: []const u8, form: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .post, .path = path, .requires_auth = true },
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Request metadata for `PUT /orders/{variety}/{order_id}`.
pub fn modifyOrderRequestOptions() transport.RequestOptions {
    return .{
        .method = .put,
        .path = "/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `PUT /orders/{variety}/{order_id}`.
pub fn modifyOrderRequestSpec(path: []const u8, form: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .put, .path = path, .requires_auth = true },
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Request metadata for `DELETE /orders/{variety}/{order_id}`.
pub fn cancelOrderRequestOptions() transport.RequestOptions {
    return .{
        .method = .delete,
        .path = "/orders",
        .requires_auth = true,
    };
}

/// Build a request spec for `DELETE /orders/{variety}/{order_id}`.
pub fn cancelOrderRequestSpec(path: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .delete, .path = path, .requires_auth = true },
        .response_format = .json,
    };
}

/// Executes `GET /orders` and decodes either success payload or owned API error.
pub fn executeOrders(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrdersResult {
    return decodeOrdersExecuted(client.allocator, try client.execute(runtime_client, ordersRequestSpec()));
}

/// Executes `GET /trades` and decodes either success payload or owned API error.
pub fn executeTrades(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!TradesResult {
    return decodeTradesExecuted(client.allocator, try client.execute(runtime_client, tradesRequestSpec()));
}

/// Executes `GET /orders/{order_id}` and decodes either success payload or owned API error.
pub fn executeOrderHistory(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrderHistoryResult {
    return decodeOrderHistoryExecuted(client.allocator, try client.execute(runtime_client, orderHistoryRequestSpec(path)));
}

/// Executes `GET /orders/{order_id}/trades` and decodes either success payload or owned API error.
pub fn executeOrderTrades(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrderTradesResult {
    return decodeOrderTradesExecuted(client.allocator, try client.execute(runtime_client, orderTradesRequestSpec(path)));
}

/// Executes `POST /orders/{variety}` and decodes either success payload or owned API error.
pub fn executePlaceOrder(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrderMutationResult {
    return decodeOrderMutationExecuted(client.allocator, try client.execute(runtime_client, placeOrderRequestSpec(path, form)));
}

/// Executes `PUT /orders/{variety}/{order_id}` and decodes either success payload or owned API error.
pub fn executeModifyOrder(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrderMutationResult {
    return decodeOrderMutationExecuted(client.allocator, try client.execute(runtime_client, modifyOrderRequestSpec(path, form)));
}

/// Executes `DELETE /orders/{variety}/{order_id}` and decodes either success payload or owned API error.
pub fn executeCancelOrder(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!OrderMutationResult {
    return decodeOrderMutationExecuted(client.allocator, try client.execute(runtime_client, cancelOrderRequestSpec(path)));
}

/// Builds `/orders/{variety}` used by place-order requests.
/// Caller owns the returned path and must free it with the same allocator.
pub fn placeOrderPath(allocator: std.mem.Allocator, variety: []const u8) PathError![]u8 {
    if (variety.len == 0) return error.EmptyVariety;
    return std.fmt.allocPrint(allocator, "/orders/{s}", .{variety});
}

/// Builds `/orders/{variety}/{order_id}` used by modify-order requests.
/// Caller owns the returned path and must free it with the same allocator.
pub fn modifyOrderPath(
    allocator: std.mem.Allocator,
    variety: []const u8,
    order_id: []const u8,
) PathError![]u8 {
    if (variety.len == 0) return error.EmptyVariety;
    if (order_id.len == 0) return error.EmptyOrderId;
    return std.fmt.allocPrint(allocator, "/orders/{s}/{s}", .{ variety, order_id });
}

/// Builds `/orders/{variety}/{order_id}` used by cancel-order requests.
/// Caller owns the returned path and must free it with the same allocator.
pub fn cancelOrderPath(
    allocator: std.mem.Allocator,
    variety: []const u8,
    order_id: []const u8,
) PathError![]u8 {
    return modifyOrderPath(allocator, variety, order_id);
}

/// Builds `/orders/{order_id}` used by order-history requests.
/// Caller owns the returned path and must free it with the same allocator.
pub fn orderHistoryPath(allocator: std.mem.Allocator, order_id: []const u8) PathError![]u8 {
    if (order_id.len == 0) return error.EmptyOrderId;
    return std.fmt.allocPrint(allocator, "/orders/{s}", .{order_id});
}

/// Builds `/orders/{order_id}/trades` used by order-trades requests.
/// Caller owns the returned path and must free it with the same allocator.
pub fn orderTradesPath(allocator: std.mem.Allocator, order_id: []const u8) PathError![]u8 {
    if (order_id.len == 0) return error.EmptyOrderId;
    return std.fmt.allocPrint(allocator, "/orders/{s}/trades", .{order_id});
}

/// Parses a `GET /orders` success envelope.
/// Caller owns the parsed result and must call `deinit()`.
pub fn parseOrders(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]order_models.Order)) {
    return envelope.parseSuccessEnvelope([]order_models.Order, allocator, payload);
}

/// Parses a `GET /trades` success envelope.
/// Caller owns the parsed result and must call `deinit()`.
pub fn parseTrades(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]trade_models.Trade)) {
    return envelope.parseSuccessEnvelope([]trade_models.Trade, allocator, payload);
}

/// Parses a `GET /orders/{order_id}` success envelope.
/// Caller owns the parsed result and must call `deinit()`.
pub fn parseOrderHistory(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]order_models.OrderHistoryEntry)) {
    return envelope.parseSuccessEnvelope([]order_models.OrderHistoryEntry, allocator, payload);
}

/// Parses a `GET /orders/{order_id}/trades` success envelope.
/// Caller owns the parsed result and must call `deinit()`.
pub fn parseOrderTrades(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]trade_models.Trade)) {
    return envelope.parseSuccessEnvelope([]trade_models.Trade, allocator, payload);
}

/// Parses place/modify/cancel order mutation success envelopes.
/// Caller owns the parsed result and must call `deinit()`.
pub fn parseOrderMutation(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(order_models.OrderMutationData)) {
    return envelope.parseSuccessEnvelope(order_models.OrderMutationData, allocator, payload);
}

/// Back-compat alias for request naming during Wave 1 integration.
pub fn listOrdersRequest() transport.RequestOptions {
    return ordersRequestOptions();
}

/// Back-compat alias for request naming during Wave 1 integration.
pub fn listTradesRequest() transport.RequestOptions {
    return tradesRequestOptions();
}

/// Back-compat alias for parser naming during Wave 1 integration.
pub fn parseOrdersResponse(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]order_models.Order)) {
    return parseOrders(allocator, payload);
}

/// Back-compat alias for parser naming during Wave 1 integration.
pub fn parseTradesResponse(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]trade_models.Trade)) {
    return parseTrades(allocator, payload);
}

/// Back-compat alias for parser naming during Wave 1 integration.
pub fn parseOrderHistoryResponse(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]order_models.OrderHistoryEntry)) {
    return parseOrderHistory(allocator, payload);
}

/// Back-compat alias for parser naming during Wave 1 integration.
pub fn parseOrderTradesResponse(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]trade_models.Trade)) {
    return parseOrderTrades(allocator, payload);
}

/// Back-compat alias for parser naming during Wave 1 integration.
pub fn parseOrderMutationResponse(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(order_models.OrderMutationData)) {
    return parseOrderMutation(allocator, payload);
}

fn decodeOrdersExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!OrdersResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]order_models.Order, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeTradesExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!TradesResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]trade_models.Trade, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeOrderHistoryExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!OrderHistoryResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]order_models.OrderHistoryEntry, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeOrderTradesExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!OrderTradesResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]trade_models.Trade, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeOrderMutationExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!OrderMutationResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(order_models.OrderMutationData, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

test "orders/trades request metadata, request specs, and path builders" {
    const allocator = std.testing.allocator;

    const orders_request = ordersRequestOptions();
    try std.testing.expectEqual(transport.Method.get, orders_request.method);
    try std.testing.expect(orders_request.requires_auth);
    try std.testing.expectEqualStrings("/orders", orders_request.path);

    const orders_spec = ordersRequestSpec();
    try std.testing.expectEqual(transport.Method.get, orders_spec.options.method);
    try std.testing.expectEqual(transport.ResponseFormat.json, orders_spec.response_format);

    const trades_request = tradesRequestOptions();
    try std.testing.expectEqual(transport.Method.get, trades_request.method);
    try std.testing.expect(trades_request.requires_auth);
    try std.testing.expectEqualStrings("/trades", trades_request.path);

    const trades_spec = tradesRequestSpec();
    try std.testing.expectEqual(transport.Method.get, trades_spec.options.method);
    try std.testing.expectEqual(transport.ResponseFormat.json, trades_spec.response_format);

    const place_spec = placeOrderRequestSpec("/orders/regular", "exchange=NSE");
    try std.testing.expectEqual(transport.Method.post, place_spec.options.method);
    try std.testing.expectEqualStrings("/orders/regular", place_spec.options.path);
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", place_spec.contentType().?);

    const modify_spec = modifyOrderRequestSpec("/orders/regular/220101000000001", "quantity=2");
    try std.testing.expectEqual(transport.Method.put, modify_spec.options.method);
    try std.testing.expectEqualStrings("/orders/regular/220101000000001", modify_spec.options.path);

    const cancel_spec = cancelOrderRequestSpec("/orders/regular/220101000000001");
    try std.testing.expectEqual(transport.Method.delete, cancel_spec.options.method);
    try std.testing.expectEqualStrings("/orders/regular/220101000000001", cancel_spec.options.path);

    const history_spec = orderHistoryRequestSpec("/orders/220101000000001");
    try std.testing.expectEqual(transport.Method.get, history_spec.options.method);
    try std.testing.expectEqualStrings("/orders/220101000000001", history_spec.options.path);

    const order_trades_spec = orderTradesRequestSpec("/orders/220101000000001/trades");
    try std.testing.expectEqual(transport.Method.get, order_trades_spec.options.method);
    try std.testing.expectEqualStrings("/orders/220101000000001/trades", order_trades_spec.options.path);

    const place_path = try placeOrderPath(allocator, "regular");
    defer allocator.free(place_path);
    try std.testing.expectEqualStrings("/orders/regular", place_path);

    const modify_path = try modifyOrderPath(allocator, "regular", "220101000000001");
    defer allocator.free(modify_path);
    try std.testing.expectEqualStrings("/orders/regular/220101000000001", modify_path);

    const cancel_path = try cancelOrderPath(allocator, "amo", "220101000000009");
    defer allocator.free(cancel_path);
    try std.testing.expectEqualStrings("/orders/amo/220101000000009", cancel_path);

    const history_path = try orderHistoryPath(allocator, "220101000000001");
    defer allocator.free(history_path);
    try std.testing.expectEqualStrings("/orders/220101000000001", history_path);

    const order_trades_path = try orderTradesPath(allocator, "220101000000001");
    defer allocator.free(order_trades_path);
    try std.testing.expectEqualStrings("/orders/220101000000001/trades", order_trades_path);
}

test "orders/trades path builders reject empty required values" {
    const allocator = std.testing.allocator;

    try std.testing.expectError(error.EmptyVariety, placeOrderPath(allocator, ""));
    try std.testing.expectError(error.EmptyVariety, modifyOrderPath(allocator, "", "220101000000001"));
    try std.testing.expectError(error.EmptyOrderId, modifyOrderPath(allocator, "regular", ""));
    try std.testing.expectError(error.EmptyOrderId, orderHistoryPath(allocator, ""));
    try std.testing.expectError(error.EmptyOrderId, orderTradesPath(allocator, ""));
}

test "orders endpoint parses list and mutation responses" {
    const allocator = std.testing.allocator;
    const orders_payload =
        \\{"status":"success","data":[{"order_id":"220101000000001","status":"COMPLETE","variety":"regular","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":1,"filled_quantity":1,"pending_quantity":0,"price":0,"average_price":1489.25,"order_timestamp":"2024-01-02 09:15:01"}]}
    ;

    const orders = try parseOrders(allocator, orders_payload);
    defer orders.deinit();

    try std.testing.expectEqualStrings("success", orders.value.status);
    try std.testing.expectEqual(@as(usize, 1), orders.value.data.len);
    try std.testing.expectEqualStrings("220101000000001", orders.value.data[0].order_id);

    const mutation_payload =
        \\{"status":"success","data":{"order_id":"220101000000001"}}
    ;

    const mutation = try parseOrderMutation(allocator, mutation_payload);
    defer mutation.deinit();

    try std.testing.expectEqualStrings("220101000000001", mutation.value.data.order_id);
}

test "orders endpoint parses trades and order history responses" {
    const allocator = std.testing.allocator;
    const history_payload =
        \\{"status":"success","data":[{"order_id":"220101000000001","status":"OPEN","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":2,"filled_quantity":0,"pending_quantity":2,"price":1500.0,"average_price":0.0,"order_timestamp":"2024-01-02 09:16:00"},{"order_id":"220101000000001","status":"COMPLETE","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":2,"filled_quantity":2,"pending_quantity":0,"price":1500.0,"average_price":1498.75,"order_timestamp":"2024-01-02 09:16:05"}]}
    ;

    const history = try parseOrderHistory(allocator, history_payload);
    defer history.deinit();

    try std.testing.expectEqual(@as(usize, 2), history.value.data.len);
    try std.testing.expectEqualStrings("OPEN", history.value.data[0].status);
    try std.testing.expectEqualStrings("COMPLETE", history.value.data[1].status);

    const order_trades_payload =
        \\{"status":"success","data":[{"trade_id":"10000001","order_id":"220101000000001","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":1,"average_price":1498.5,"fill_timestamp":"2024-01-02 09:16:03"}]}
    ;

    const order_trades = try parseOrderTrades(allocator, order_trades_payload);
    defer order_trades.deinit();

    try std.testing.expectEqual(@as(usize, 1), order_trades.value.data.len);
    try std.testing.expectEqualStrings("10000001", order_trades.value.data[0].trade_id);

    const all_trades_payload =
        \\{"status":"success","data":[{"trade_id":"10000001","order_id":"220101000000001","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":1,"average_price":1498.5,"fill_timestamp":"2024-01-02 09:16:03"},{"trade_id":"10000002","order_id":"220101000000002","exchange":"NSE","tradingsymbol":"TCS","transaction_type":"SELL","quantity":3,"average_price":3500.0,"fill_timestamp":"2024-01-02 09:20:14"}]}
    ;

    const all_trades = try parseTrades(allocator, all_trades_payload);
    defer all_trades.deinit();

    try std.testing.expectEqual(@as(usize, 2), all_trades.value.data.len);
    try std.testing.expectEqualStrings("10000002", all_trades.value.data[1].trade_id);
}

test "decodeOrdersExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":[{\"order_id\":\"220101000000001\",\"status\":\"COMPLETE\",\"exchange\":\"NSE\",\"tradingsymbol\":\"INFY\",\"transaction_type\":\"BUY\",\"quantity\":1,\"filled_quantity\":1,\"pending_quantity\":0,\"average_price\":1489.25,\"order_timestamp\":\"2024-01-02 09:15:01\"}]}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeOrdersExecuted(std.testing.allocator, .{
        .success = .{
            .status = 200,
            .content_type = content_type,
            .body = body,
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqual(@as(usize, 1), result.success.parsed.value.data.len);
    try std.testing.expectEqualStrings("220101000000001", result.success.parsed.value.data[0].order_id);
}

test "decodeOrderMutationExecuted preserves owned api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "Order not found",
        .error_type = "GeneralException",
    }, 404);

    const result = try decodeOrderMutationExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("Order not found", result.api_error.message);
}
