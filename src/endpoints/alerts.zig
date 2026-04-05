//! Alerts endpoint contracts, runtime execution helpers, request builders, and envelope parsers.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const models = @import("../models/alerts.zig");
const transport = @import("../transport.zig");

/// API path constants for alerts endpoints.
pub const Paths = struct {
    pub const alerts = "/alerts";
};

/// Form payload for create/update alert APIs.
pub const AlertForm = struct {
    name: []const u8,
    lhs_exchange: []const u8,
    lhs_tradingsymbol: []const u8,
    lhs_attribute: []const u8,
    operator: []const u8,
    rhs_type: []const u8,
    rhs_constant: f64,
};

pub const PathError = error{
    EmptyUuid,
    OutOfMemory,
};

pub const FormError = error{
    EmptyName,
    EmptyExchange,
    EmptyTradingsymbol,
    EmptyLhsAttribute,
    EmptyOperator,
    EmptyRhsType,
    InvalidRhsConstant,
    OutOfMemory,
};

pub const QueryError = error{
    MissingUuids,
    EmptyUuid,
    OutOfMemory,
};

/// Parsed success payload for `GET /alerts` that retains response-body backing.
pub const AlertsSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.Alert));

/// Parsed success payload for `GET /alerts/{uuid}` that retains response-body backing.
pub const AlertSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.Alert));

/// Parsed success payload for alert mutation APIs that retains response-body backing.
/// `data` can be null for delete APIs.
pub const AlertMutationSuccess = http.OwnedParsed(envelope.SuccessEnvelope(?models.AlertMutationData));

/// Parsed success payload for `GET /alerts/{uuid}/history` that retains response-body backing.
pub const AlertHistorySuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.AlertHistoryEntry));

/// Result of executing `GET /alerts`.
pub const AlertsResult = union(enum) {
    success: AlertsSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: AlertsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /alerts/{uuid}`.
pub const AlertResult = union(enum) {
    success: AlertSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: AlertResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing alert create/update/delete APIs.
pub const AlertMutationResult = union(enum) {
    success: AlertMutationSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: AlertMutationResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /alerts/{uuid}/history`.
pub const AlertHistoryResult = union(enum) {
    success: AlertHistorySuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: AlertHistoryResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Request metadata for `GET /alerts`.
pub fn listAlertsRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.alerts };
}

/// Build a request spec for `GET /alerts`.
pub fn listAlertsRequestSpec() transport.RequestSpec {
    return .{
        .options = listAlertsRequestOptions(),
        .response_format = .json,
    };
}

/// Request metadata for `GET /alerts/{uuid}`.
pub fn getAlertRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.alerts };
}

/// Build a request spec for `GET /alerts/{uuid}`.
pub fn getAlertRequestSpec(path: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .get, .path = path },
        .response_format = .json,
    };
}

/// Request metadata for `POST /alerts`.
pub fn createAlertRequestOptions() transport.RequestOptions {
    return .{ .method = .post, .path = Paths.alerts };
}

/// Build a request spec for `POST /alerts`.
pub fn createAlertRequestSpec(form: []const u8) transport.RequestSpec {
    return .{
        .options = createAlertRequestOptions(),
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Request metadata for `PUT /alerts/{uuid}`.
pub fn modifyAlertRequestOptions() transport.RequestOptions {
    return .{ .method = .put, .path = Paths.alerts };
}

/// Build a request spec for `PUT /alerts/{uuid}`.
pub fn modifyAlertRequestSpec(path: []const u8, form: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .put, .path = path },
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Request metadata for `DELETE /alerts`.
pub fn deleteAlertRequestOptions() transport.RequestOptions {
    return .{ .method = .delete, .path = Paths.alerts };
}

/// Build a request spec for `DELETE /alerts?uuid=...`.
pub fn deleteAlertRequestSpec(query: []const u8) transport.RequestSpec {
    return .{
        .options = deleteAlertRequestOptions(),
        .query = query,
        .response_format = .json,
    };
}

/// Request metadata for `GET /alerts/{uuid}/history`.
pub fn alertHistoryRequestOptions(path: []const u8) transport.RequestOptions {
    return .{ .method = .get, .path = path };
}

/// Build a request spec for `GET /alerts/{uuid}/history`.
pub fn alertHistoryRequestSpec(path: []const u8) transport.RequestSpec {
    return .{
        .options = alertHistoryRequestOptions(path),
        .response_format = .json,
    };
}

/// Builds `/alerts/{uuid}` path.
/// Caller owns returned slice and must free it with the same allocator.
pub fn alertPath(allocator: std.mem.Allocator, uuid: []const u8) PathError![]u8 {
    if (uuid.len == 0) return error.EmptyUuid;
    return std.fmt.allocPrint(allocator, "/alerts/{s}", .{uuid});
}

/// Builds `/alerts/{uuid}/history` path.
/// Caller owns returned slice and must free it with the same allocator.
pub fn alertHistoryPath(allocator: std.mem.Allocator, uuid: []const u8) PathError![]u8 {
    if (uuid.len == 0) return error.EmptyUuid;
    return std.fmt.allocPrint(allocator, "/alerts/{s}/history", .{uuid});
}

/// Executes `GET /alerts` and decodes either success payload or owned API error.
pub fn executeListAlerts(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!AlertsResult {
    return decodeAlertsExecuted(client.allocator, try client.execute(runtime_client, listAlertsRequestSpec()));
}

/// Executes `GET /alerts/{uuid}` and decodes either success payload or owned API error.
pub fn executeGetAlert(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!AlertResult {
    return decodeAlertExecuted(client.allocator, try client.execute(runtime_client, getAlertRequestSpec(path)));
}

/// Executes `POST /alerts` and decodes either success payload or owned API error.
pub fn executeCreateAlert(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!AlertMutationResult {
    return decodeAlertMutationExecuted(client.allocator, try client.execute(runtime_client, createAlertRequestSpec(form)));
}

/// Executes `PUT /alerts/{uuid}` and decodes either success payload or owned API error.
pub fn executeModifyAlert(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!AlertMutationResult {
    return decodeAlertMutationExecuted(client.allocator, try client.execute(runtime_client, modifyAlertRequestSpec(path, form)));
}

/// Executes `DELETE /alerts?uuid=...` and decodes either success payload or owned API error.
pub fn executeDeleteAlert(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    query: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!AlertMutationResult {
    return decodeAlertMutationExecuted(client.allocator, try client.execute(runtime_client, deleteAlertRequestSpec(query)));
}

/// Executes `GET /alerts/{uuid}/history` and decodes either success payload or owned API error.
pub fn executeAlertHistory(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!AlertHistoryResult {
    return decodeAlertHistoryExecuted(client.allocator, try client.execute(runtime_client, alertHistoryRequestSpec(path)));
}

/// Builds form body for create/update alert APIs.
/// Caller owns returned slice and must free it with the same allocator.
pub fn buildAlertForm(allocator: std.mem.Allocator, form: AlertForm) FormError![]u8 {
    if (form.name.len == 0) return error.EmptyName;
    if (form.lhs_exchange.len == 0) return error.EmptyExchange;
    if (form.lhs_tradingsymbol.len == 0) return error.EmptyTradingsymbol;
    if (form.lhs_attribute.len == 0) return error.EmptyLhsAttribute;
    if (form.operator.len == 0) return error.EmptyOperator;
    if (form.rhs_type.len == 0) return error.EmptyRhsType;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendField(allocator, &buffer, "name", form.name, false);
    try appendField(allocator, &buffer, "lhs_exchange", form.lhs_exchange, true);
    try appendField(allocator, &buffer, "lhs_tradingsymbol", form.lhs_tradingsymbol, true);
    try appendField(allocator, &buffer, "lhs_attribute", form.lhs_attribute, true);
    try appendField(allocator, &buffer, "operator", form.operator, true);
    try appendField(allocator, &buffer, "rhs_type", form.rhs_type, true);

    const rhs_constant = try std.fmt.allocPrint(allocator, "{d}", .{form.rhs_constant});
    defer allocator.free(rhs_constant);
    try appendField(allocator, &buffer, "rhs_constant", rhs_constant, true);

    return buffer.toOwnedSlice(allocator);
}

/// Builds query string for `DELETE /alerts?uuid=...`.
/// Caller owns returned slice and must free it with the same allocator.
pub fn buildDeleteAlertsQuery(
    allocator: std.mem.Allocator,
    uuids: []const []const u8,
) QueryError![]u8 {
    if (uuids.len == 0) return error.MissingUuids;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    for (uuids, 0..) |uuid, index| {
        if (uuid.len == 0) return error.EmptyUuid;
        try appendField(allocator, &buffer, "uuid", uuid, index > 0);
    }

    return buffer.toOwnedSlice(allocator);
}

/// Parses `GET /alerts` success payload.
pub fn parseAlerts(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.Alert)) {
    return envelope.parseSuccessEnvelope([]const models.Alert, allocator, payload);
}

/// Parses `GET /alerts/{uuid}` success payload.
pub fn parseAlert(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.Alert)) {
    return envelope.parseSuccessEnvelope(models.Alert, allocator, payload);
}

/// Parses create/update/delete alert success payload.
pub fn parseAlertMutation(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(?models.AlertMutationData)) {
    return envelope.parseSuccessEnvelope(?models.AlertMutationData, allocator, payload);
}

/// Parses `GET /alerts/{uuid}/history` success payload.
pub fn parseAlertHistory(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.AlertHistoryEntry)) {
    return envelope.parseSuccessEnvelope([]const models.AlertHistoryEntry, allocator, payload);
}

fn decodeAlertsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!AlertsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.Alert, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeAlertExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!AlertResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.Alert, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeAlertMutationExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!AlertMutationResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(?models.AlertMutationData, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeAlertHistoryExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!AlertHistoryResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.AlertHistoryEntry, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn appendField(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), key: []const u8, value: []const u8, prefix_ampersand: bool) !void {
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

test "alerts request metadata and request specs" {
    const list = listAlertsRequestOptions();
    try std.testing.expectEqual(transport.Method.get, list.method);
    try std.testing.expectEqualStrings(Paths.alerts, list.path);

    const list_spec = listAlertsRequestSpec();
    try std.testing.expectEqual(transport.Method.get, list_spec.options.method);
    try std.testing.expectEqual(transport.ResponseFormat.json, list_spec.response_format);

    const create = createAlertRequestOptions();
    try std.testing.expectEqual(transport.Method.post, create.method);
    const create_spec = createAlertRequestSpec("name=x");
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", create_spec.contentType().?);

    const modify = modifyAlertRequestOptions();
    try std.testing.expectEqual(transport.Method.put, modify.method);
    const modify_spec = modifyAlertRequestSpec("/alerts/550e8400-e29b-41d4-a716-446655440000", "name=x");
    try std.testing.expectEqualStrings("/alerts/550e8400-e29b-41d4-a716-446655440000", modify_spec.options.path);

    const delete_spec = deleteAlertRequestSpec("uuid=550e8400-e29b-41d4-a716-446655440000");
    try std.testing.expectEqual(transport.Method.delete, delete_spec.options.method);
    try std.testing.expectEqualStrings(Paths.alerts, delete_spec.options.path);
    try std.testing.expectEqualStrings("uuid=550e8400-e29b-41d4-a716-446655440000", delete_spec.query.?);

    const path = try alertPath(std.testing.allocator, "550e8400-e29b-41d4-a716-446655440000");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/alerts/550e8400-e29b-41d4-a716-446655440000", path);

    const history_path = try alertHistoryPath(std.testing.allocator, "550e8400-e29b-41d4-a716-446655440000");
    defer std.testing.allocator.free(history_path);
    try std.testing.expectEqualStrings("/alerts/550e8400-e29b-41d4-a716-446655440000/history", history_path);

    const history = alertHistoryRequestOptions(history_path);
    try std.testing.expectEqualStrings("/alerts/550e8400-e29b-41d4-a716-446655440000/history", history.path);
    const history_spec = alertHistoryRequestSpec(history_path);
    try std.testing.expect(history_spec.query == null);
}

test "alerts form and delete query builders encode payloads" {
    const form = try buildAlertForm(std.testing.allocator, .{
        .name = "INFY breakout",
        .lhs_exchange = "NSE",
        .lhs_tradingsymbol = "INFY",
        .lhs_attribute = "last_price",
        .operator = ">",
        .rhs_type = "constant",
        .rhs_constant = 1550.5,
    });
    defer std.testing.allocator.free(form);

    try std.testing.expect(std.mem.indexOf(u8, form, "name=INFY%20breakout") != null);
    try std.testing.expect(std.mem.indexOf(u8, form, "operator=%3E") != null);

    const query = try buildDeleteAlertsQuery(std.testing.allocator, &.{
        "550e8400-e29b-41d4-a716-446655440000",
        "e888ed4a-6801-406f-bdc2-002db5a8411d",
    });
    defer std.testing.allocator.free(query);

    try std.testing.expectEqualStrings("uuid=550e8400-e29b-41d4-a716-446655440000&uuid=e888ed4a-6801-406f-bdc2-002db5a8411d", query);
}

test "alerts parsers decode list and history envelopes" {
    const alerts_payload =
        \\{"status":"success","data":[{"alert_id":9,"name":"INFY breakout","lhs_exchange":"NSE","lhs_tradingsymbol":"INFY","lhs_attribute":"last_price","operator":">","rhs_type":"constant","rhs_constant":1550.5,"status":"enabled"}]}
    ;

    const alerts = try parseAlerts(std.testing.allocator, alerts_payload);
    defer alerts.deinit();
    try std.testing.expectEqual(@as(usize, 1), alerts.value.data.len);
    try std.testing.expectEqual(@as(i64, 9), alerts.value.data[0].alert_id);

    const history_payload =
        \\{"status":"success","data":[{"uuid":"550e8400-e29b-41d4-a716-446655440000","type":"simple","meta":[{"instrument_token":270857}],"condition":"LastTradedPrice(\"INDICES:NIFTY NEXT 50\") <= 58290.35","created_at":"2025-02-17 09:16:46","order_meta":null}]}
    ;

    const history = try parseAlertHistory(std.testing.allocator, history_payload);
    defer history.deinit();
    try std.testing.expectEqual(@as(usize, 1), history.value.data.len);
    try std.testing.expectEqualStrings("550e8400-e29b-41d4-a716-446655440000", history.value.data[0].uuid.?);
    try std.testing.expect(history.value.data[0].meta != null);
    try std.testing.expectEqual(@as(i64, 270857), history.value.data[0].meta.?[0].instrument_token.?);
}

test "decodeAlertsExecuted decodes owned list payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":[{\"alert_id\":9,\"name\":\"INFY breakout\",\"lhs_exchange\":\"NSE\",\"lhs_tradingsymbol\":\"INFY\",\"lhs_attribute\":\"last_price\",\"operator\":\">\",\"rhs_type\":\"constant\",\"rhs_constant\":1550.5,\"status\":\"enabled\"}]}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeAlertsExecuted(std.testing.allocator, .{
        .success = .{
            .status = 200,
            .content_type = content_type,
            .body = body,
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqual(@as(usize, 1), result.success.parsed.value.data.len);
    try std.testing.expectEqual(@as(i64, 9), result.success.parsed.value.data[0].alert_id);
}

test "parseAlertMutation accepts null data for delete responses" {
    const payload =
        \\{"status":"success","data":null}
    ;

    const parsed = try parseAlertMutation(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expect(parsed.value.data == null);
}

test "decodeAlertMutationExecuted preserves api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "Alert not found",
        .error_type = "GeneralException",
    }, 404);

    const result = try decodeAlertMutationExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("Alert not found", result.api_error.message);
}
