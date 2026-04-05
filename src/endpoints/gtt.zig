//! GTT endpoint contracts, runtime execution helpers, request builders, and envelope parsers.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const models = @import("../models/gtt.zig");
const transport = @import("../transport.zig");

/// API path constants for GTT endpoints.
pub const Paths = struct {
    pub const triggers = "/gtt/triggers";
};

/// Optional filters for list-triggers API.
pub const ListTriggersQuery = struct {
    status: ?[]const u8 = null,
    page: ?u32 = null,
    count: ?u32 = null,
};

/// Form payload contract for create/modify trigger APIs.
pub const TriggerForm = struct {
    type: []const u8,
    condition_json: []const u8,
    orders_json: []const u8,
};

pub const PathError = error{
    InvalidTriggerId,
    OutOfMemory,
};

pub const QueryError = error{
    EmptyStatus,
    OutOfMemory,
};

pub const FormError = error{
    EmptyType,
    EmptyConditionJson,
    EmptyOrdersJson,
    OutOfMemory,
};

/// Parsed success payload for `GET /gtt/triggers` that retains response-body backing.
pub const TriggersSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.Trigger));

/// Parsed success payload for `GET /gtt/triggers/{trigger_id}` that retains response-body backing.
pub const TriggerSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.Trigger));

/// Parsed success payload for create/modify/delete trigger APIs that retains response-body backing.
pub const TriggerMutationSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.TriggerMutationData));

/// Result of executing `GET /gtt/triggers`.
pub const TriggersResult = union(enum) {
    success: TriggersSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: TriggersResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `GET /gtt/triggers/{trigger_id}`.
pub const TriggerResult = union(enum) {
    success: TriggerSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: TriggerResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing create/modify/delete trigger APIs.
pub const TriggerMutationResult = union(enum) {
    success: TriggerMutationSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: TriggerMutationResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Request metadata for `GET /gtt/triggers`.
pub fn listTriggersRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.triggers };
}

/// Build a request spec for `GET /gtt/triggers`.
pub fn listTriggersRequestSpec(query: []const u8) transport.RequestSpec {
    return .{
        .options = listTriggersRequestOptions(),
        .query = query,
        .response_format = .json,
    };
}

/// Request metadata for `GET /gtt/triggers/{trigger_id}`.
pub fn getTriggerRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.triggers };
}

/// Build a request spec for `GET /gtt/triggers/{trigger_id}`.
pub fn getTriggerRequestSpec(path: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .get, .path = path },
        .response_format = .json,
    };
}

/// Request metadata for `POST /gtt/triggers`.
pub fn createTriggerRequestOptions() transport.RequestOptions {
    return .{ .method = .post, .path = Paths.triggers };
}

/// Build a request spec for `POST /gtt/triggers`.
pub fn createTriggerRequestSpec(form: []const u8) transport.RequestSpec {
    return .{
        .options = createTriggerRequestOptions(),
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Request metadata for `PUT /gtt/triggers/{trigger_id}`.
pub fn modifyTriggerRequestOptions() transport.RequestOptions {
    return .{ .method = .put, .path = Paths.triggers };
}

/// Build a request spec for `PUT /gtt/triggers/{trigger_id}`.
pub fn modifyTriggerRequestSpec(path: []const u8, form: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .put, .path = path },
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Request metadata for `DELETE /gtt/triggers/{trigger_id}`.
pub fn deleteTriggerRequestOptions() transport.RequestOptions {
    return .{ .method = .delete, .path = Paths.triggers };
}

/// Build a request spec for `DELETE /gtt/triggers/{trigger_id}`.
pub fn deleteTriggerRequestSpec(path: []const u8) transport.RequestSpec {
    return .{
        .options = .{ .method = .delete, .path = path },
        .response_format = .json,
    };
}

/// Builds `/gtt/triggers/{trigger_id}` path.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn triggerPath(allocator: std.mem.Allocator, trigger_id: i64) PathError![]u8 {
    if (trigger_id <= 0) return error.InvalidTriggerId;
    return std.fmt.allocPrint(allocator, "/gtt/triggers/{d}", .{trigger_id});
}

/// Executes `GET /gtt/triggers` and decodes either success payload or owned API error.
pub fn executeListTriggers(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    query: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!TriggersResult {
    return decodeTriggersExecuted(client.allocator, try client.execute(runtime_client, listTriggersRequestSpec(query)));
}

/// Executes `GET /gtt/triggers/{trigger_id}` and decodes either success payload or owned API error.
pub fn executeGetTrigger(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!TriggerResult {
    return decodeTriggerExecuted(client.allocator, try client.execute(runtime_client, getTriggerRequestSpec(path)));
}

/// Executes `POST /gtt/triggers` and decodes either success payload or owned API error.
pub fn executeCreateTrigger(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!TriggerMutationResult {
    return decodeTriggerMutationExecuted(client.allocator, try client.execute(runtime_client, createTriggerRequestSpec(form)));
}

/// Executes `PUT /gtt/triggers/{trigger_id}` and decodes either success payload or owned API error.
pub fn executeModifyTrigger(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!TriggerMutationResult {
    return decodeTriggerMutationExecuted(client.allocator, try client.execute(runtime_client, modifyTriggerRequestSpec(path, form)));
}

/// Executes `DELETE /gtt/triggers/{trigger_id}` and decodes either success payload or owned API error.
pub fn executeDeleteTrigger(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!TriggerMutationResult {
    return decodeTriggerMutationExecuted(client.allocator, try client.execute(runtime_client, deleteTriggerRequestSpec(path)));
}

/// Builds list query string for `GET /gtt/triggers`.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildListTriggersQuery(
    allocator: std.mem.Allocator,
    query: ListTriggersQuery,
) QueryError![]u8 {
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    var has_fields = false;

    if (query.status) |status| {
        if (status.len == 0) return error.EmptyStatus;
        try appendField(allocator, &buffer, "status", status, has_fields);
        has_fields = true;
    }

    if (query.page) |page| {
        const page_str = try std.fmt.allocPrint(allocator, "{d}", .{page});
        defer allocator.free(page_str);
        try appendField(allocator, &buffer, "page", page_str, has_fields);
        has_fields = true;
    }

    if (query.count) |count| {
        const count_str = try std.fmt.allocPrint(allocator, "{d}", .{count});
        defer allocator.free(count_str);
        try appendField(allocator, &buffer, "count", count_str, has_fields);
    }

    return buffer.toOwnedSlice(allocator);
}

/// Builds form body for create/modify trigger APIs.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildTriggerForm(allocator: std.mem.Allocator, form: TriggerForm) FormError![]u8 {
    if (form.type.len == 0) return error.EmptyType;
    if (form.condition_json.len == 0) return error.EmptyConditionJson;
    if (form.orders_json.len == 0) return error.EmptyOrdersJson;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendField(allocator, &buffer, "type", form.type, false);
    try appendField(allocator, &buffer, "condition", form.condition_json, true);
    try appendField(allocator, &buffer, "orders", form.orders_json, true);

    return buffer.toOwnedSlice(allocator);
}

/// Parses `GET /gtt/triggers` success payload.
pub fn parseTriggers(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.Trigger)) {
    return envelope.parseSuccessEnvelope([]const models.Trigger, allocator, payload);
}

/// Parses `GET /gtt/triggers/{trigger_id}` success payload.
pub fn parseTrigger(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.Trigger)) {
    return envelope.parseSuccessEnvelope(models.Trigger, allocator, payload);
}

/// Parses create/modify/delete trigger success payload.
pub fn parseTriggerMutation(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.TriggerMutationData)) {
    return envelope.parseSuccessEnvelope(models.TriggerMutationData, allocator, payload);
}

fn decodeTriggersExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!TriggersResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.Trigger, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeTriggerExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!TriggerResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.Trigger, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeTriggerMutationExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!TriggerMutationResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.TriggerMutationData, allocator, response) },
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

test "gtt request metadata path and request specs" {
    const list = listTriggersRequestOptions();
    try std.testing.expectEqual(transport.Method.get, list.method);
    try std.testing.expectEqualStrings(Paths.triggers, list.path);

    const list_spec = listTriggersRequestSpec("status=active");
    try std.testing.expectEqual(transport.ResponseFormat.json, list_spec.response_format);
    try std.testing.expectEqualStrings("status=active", list_spec.query.?);

    const create = createTriggerRequestOptions();
    try std.testing.expectEqual(transport.Method.post, create.method);
    const create_spec = createTriggerRequestSpec("type=single");
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", create_spec.contentType().?);

    const modify = modifyTriggerRequestOptions();
    try std.testing.expectEqual(transport.Method.put, modify.method);
    const modify_spec = modifyTriggerRequestSpec("/gtt/triggers/42", "type=single");
    try std.testing.expectEqualStrings("/gtt/triggers/42", modify_spec.options.path);

    const delete = deleteTriggerRequestOptions();
    try std.testing.expectEqual(transport.Method.delete, delete.method);
    const delete_spec = deleteTriggerRequestSpec("/gtt/triggers/42");
    try std.testing.expectEqualStrings("/gtt/triggers/42", delete_spec.options.path);

    const path = try triggerPath(std.testing.allocator, 42);
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("/gtt/triggers/42", path);

    try std.testing.expectError(error.InvalidTriggerId, triggerPath(std.testing.allocator, 0));
}

test "gtt query and form builders percent-encode payload" {
    const query = try buildListTriggersQuery(std.testing.allocator, .{
        .status = "active pending",
        .page = 2,
        .count = 25,
    });
    defer std.testing.allocator.free(query);

    try std.testing.expectEqualStrings("status=active%20pending&page=2&count=25", query);

    const form = try buildTriggerForm(std.testing.allocator, .{
        .type = "single",
        .condition_json = "{\"exchange\":\"NSE\",\"tradingsymbol\":\"INFY\"}",
        .orders_json = "[{\"transaction_type\":\"SELL\",\"quantity\":1}]",
    });
    defer std.testing.allocator.free(form);

    try std.testing.expect(std.mem.indexOf(u8, form, "type=single") != null);
    try std.testing.expect(std.mem.indexOf(u8, form, "condition=%7B%22exchange%22") != null);
    try std.testing.expect(std.mem.indexOf(u8, form, "orders=%5B%7B%22transaction_type%22") != null);
}

test "gtt parser decodes list and mutation envelopes" {
    const list_payload =
        \\{"status":"success","data":[{"id":42,"type":"single","status":"active","condition":{"exchange":"NSE","tradingsymbol":"INFY","trigger_values":[1520.5]},"orders":[{"exchange":"NSE","tradingsymbol":"INFY","transaction_type":"SELL","quantity":1,"product":"CNC","order_type":"LIMIT","price":1519.0}]}]}
    ;

    const parsed_list = try parseTriggers(std.testing.allocator, list_payload);
    defer parsed_list.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed_list.value.data.len);
    try std.testing.expectEqual(@as(i64, 42), parsed_list.value.data[0].id);
    try std.testing.expect(parsed_list.value.data[0].meta == null);

    const mutation_payload =
        \\{"status":"success","data":{"trigger_id":42}}
    ;

    const parsed_mutation = try parseTriggerMutation(std.testing.allocator, mutation_payload);
    defer parsed_mutation.deinit();

    try std.testing.expectEqual(@as(i64, 42), parsed_mutation.value.data.trigger_id);
}

test "decodeTriggersExecuted decodes owned list payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":[{\"id\":42,\"type\":\"single\",\"status\":\"active\",\"condition\":{\"exchange\":\"NSE\",\"tradingsymbol\":\"INFY\",\"trigger_values\":[1520.5]},\"orders\":[{\"exchange\":\"NSE\",\"tradingsymbol\":\"INFY\",\"transaction_type\":\"SELL\",\"quantity\":1,\"product\":\"CNC\",\"order_type\":\"LIMIT\",\"price\":1519.0}]}]}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeTriggersExecuted(std.testing.allocator, .{
        .success = .{
            .status = 200,
            .content_type = content_type,
            .body = body,
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqual(@as(usize, 1), result.success.parsed.value.data.len);
    try std.testing.expectEqual(@as(i64, 42), result.success.parsed.value.data[0].id);
}

test "decodeTriggerMutationExecuted preserves api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "Trigger not found",
        .error_type = "GeneralException",
    }, 404);

    const result = try decodeTriggerMutationExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("Trigger not found", result.api_error.message);
}
