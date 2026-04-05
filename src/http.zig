//! HTTP helpers and request encoding.

const std = @import("std");
const errors = @import("errors.zig");
const envelope = @import("models/envelope.zig");
const transport = @import("transport.zig");

pub const RequestEncodingError = error{
    MissingApiKey,
    OutOfMemory,
};

/// JSON parsing error set used by shared response helpers.
pub const JsonParseError = std.json.ParseError(std.json.Scanner);

/// Lightweight HTTP response view consumed by shared runtime helpers.
pub const ResponseView = struct {
    status: u16,
    content_type: ?[]const u8,
    body: []const u8,
};

/// Owned HTTP response produced by the runtime execution layer.
pub const OwnedResponse = struct {
    status: u16,
    content_type: ?[]u8,
    body: []u8,

    /// Returns a borrowed view over the owned response.
    pub fn view(self: OwnedResponse) ResponseView {
        return .{
            .status = self.status,
            .content_type = self.content_type,
            .body = self.body,
        };
    }

    /// Frees response allocations.
    pub fn deinit(self: OwnedResponse, allocator: std.mem.Allocator) void {
        if (self.content_type) |value| allocator.free(value);
        allocator.free(self.body);
    }
};

/// Result of classifying a borrowed HTTP response against the shared transport contract.
pub const ClassifiedResponse = union(enum) {
    success: ResponseView,
    api_error: errors.ApiError,

    /// Frees owned error allocations when present.
    pub fn deinit(self: ClassifiedResponse, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => {},
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing and classifying an owned HTTP response.
pub const ExecutedResponse = union(enum) {
    success: OwnedResponse,
    api_error: errors.ApiError,

    /// Frees owned response or error allocations.
    pub fn deinit(self: ExecutedResponse, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Error set returned while decoding API error envelopes.
pub const ErrorResponseParseError = errors.TransportError || JsonParseError || std.mem.Allocator.Error;

/// Error set returned while classifying responses.
pub const ClassifyResponseError = ErrorResponseParseError;

/// Error set returned while executing network requests.
pub const ExecuteError = std.http.Client.FetchError || errors.TransportError || std.mem.Allocator.Error;

/// Error set returned while decoding successful response bodies.
pub const DecodeResponseError = errors.TransportError || JsonParseError || std.mem.Allocator.Error;

/// Parsed JSON payload that retains the owned response body backing borrowed slices.
pub fn OwnedParsed(comptime T: type) type {
    return struct {
        parsed: std.json.Parsed(T),
        response: OwnedResponse,

        /// Frees parsed JSON allocations plus the retained response body.
        pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
            self.parsed.deinit();
            self.response.deinit(allocator);
        }
    };
}

const kite_version_header_value = "3";

const EffectiveRequest = struct {
    url: []u8,
    payload: ?[]const u8,
    content_type: ?[]const u8,

    fn deinit(self: EffectiveRequest, allocator: std.mem.Allocator, original_url: []const u8) void {
        if (!std.mem.eql(u8, self.url, original_url.ptr[0..original_url.len]) or self.url.ptr != original_url.ptr) {
            allocator.free(self.url);
        }
    }
};

/// Encodes a login URL using the documented Kite Connect query shape.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn loginUrl(allocator: std.mem.Allocator, api_key: []const u8) RequestEncodingError![]u8 {
    if (api_key.len == 0) return error.MissingApiKey;
    return std.fmt.allocPrint(
        allocator,
        "https://kite.zerodha.com/connect/login?v=3&api_key={s}",
        .{api_key},
    );
}

/// Returns whether a response content type is compatible with the expected format.
pub fn contentTypeMatches(format: transport.ResponseFormat, content_type: ?[]const u8) bool {
    return switch (format) {
        .raw => true,
        .json => isJsonContentType(content_type),
        .csv => isCsvContentType(content_type),
    };
}

/// Validates the success-response content type against the expected format.
pub fn validateSuccessContentType(format: transport.ResponseFormat, content_type: ?[]const u8) errors.TransportError!void {
    if (!contentTypeMatches(format, content_type)) return error.InvalidResponseContentType;
}

/// Parses a documented Kite error envelope and maps it into a stable owned `ApiError` view.
pub fn parseApiError(
    allocator: std.mem.Allocator,
    status: u16,
    content_type: ?[]const u8,
    payload: []const u8,
) ErrorResponseParseError!errors.ApiError {
    try validateSuccessContentType(.json, content_type);

    const parsed = try envelope.parseErrorEnvelope(allocator, payload);
    defer parsed.deinit();

    return errors.ApiError.fromEnvelope(allocator, parsed.value, status);
}

/// Classifies a borrowed response as success or API error and validates content-type expectations.
pub fn classifyResponse(
    allocator: std.mem.Allocator,
    expected_format: transport.ResponseFormat,
    response: ResponseView,
) ClassifyResponseError!ClassifiedResponse {
    if (transport.isSuccessStatus(response.status)) {
        try validateSuccessContentType(expected_format, response.content_type);
        return .{ .success = response };
    }

    return .{ .api_error = try parseApiError(allocator, response.status, response.content_type, response.body) };
}

/// Classifies an owned response as success or API error.
/// On API-error classification the response body allocation is consumed and freed.
pub fn classifyOwnedResponse(
    allocator: std.mem.Allocator,
    expected_format: transport.ResponseFormat,
    response: OwnedResponse,
) ClassifyResponseError!ExecutedResponse {
    if (transport.isSuccessStatus(response.status)) {
        try validateSuccessContentType(expected_format, response.content_type);
        return .{ .success = response };
    }

    const api_error = try parseApiError(allocator, response.status, response.content_type, response.body);
    response.deinit(allocator);
    return .{ .api_error = api_error };
}

/// Executes a prepared request with the stdlib HTTP client and returns an owned response.
pub fn executePrepared(
    allocator: std.mem.Allocator,
    runtime_client: *std.http.Client,
    request: transport.PreparedRequest,
) ExecuteError!OwnedResponse {
    const effective = try buildEffectiveRequest(allocator, request);
    defer effective.deinit(allocator, request.url);

    const uri = try std.Uri.parse(effective.url);
    const extra_headers = [_]std.http.Header{
        .{ .name = "accept", .value = request.accept },
        .{ .name = "x-kite-version", .value = kite_version_header_value },
    };

    var runtime_request = try runtime_client.request(methodToStd(request.method), uri, .{
        .headers = .{
            .authorization = if (request.authorization) |value| .{ .override = value } else .omit,
            .user_agent = .{ .override = request.user_agent },
            .content_type = if (effective.content_type) |value| .{ .override = value } else .omit,
        },
        .extra_headers = extra_headers[0..],
        .keep_alive = true,
    });
    defer runtime_request.deinit();

    if (effective.payload) |payload| {
        runtime_request.transfer_encoding = .{ .content_length = payload.len };
        var body_writer = try runtime_request.sendBodyUnflushed(&.{});
        try body_writer.writer.writeAll(payload);
        try body_writer.end();
        try runtime_request.connection.?.flush();
    } else {
        try runtime_request.sendBodiless();
    }

    var redirect_buffer: [8 * 1024]u8 = undefined;
    var response = try runtime_request.receiveHead(&redirect_buffer);

    const content_type = if (response.head.content_type) |value|
        try allocator.dupe(u8, value)
    else
        null;
    errdefer if (content_type) |value| allocator.free(value);

    var empty_decompress_buffer: [0]u8 = .{};
    const decompress_buffer: []u8 = switch (response.head.content_encoding) {
        .identity => empty_decompress_buffer[0..],
        .zstd => try allocator.alloc(u8, std.compress.zstd.default_window_len),
        .deflate, .gzip => try allocator.alloc(u8, std.compress.flate.max_window_len),
        .compress => return error.UnsupportedCompressionMethod,
    };
    defer if (response.head.content_encoding != .identity) allocator.free(decompress_buffer);

    var transfer_buffer: [64]u8 = undefined;
    var decompress: std.http.Decompress = undefined;
    var body_writer: std.Io.Writer.Allocating = .init(allocator);
    defer body_writer.deinit();

    var reader = response.readerDecompressing(&transfer_buffer, &decompress, decompress_buffer);
    _ = reader.streamRemaining(&body_writer.writer) catch |err| switch (err) {
        error.ReadFailed => return response.bodyErr().?,
        else => |e| return e,
    };

    const body = try body_writer.toOwnedSlice();
    return .{
        .status = @intFromEnum(response.head.status),
        .content_type = content_type,
        .body = body,
    };
}

/// Executes and classifies a prepared request in one step.
pub fn executeClassified(
    allocator: std.mem.Allocator,
    runtime_client: *std.http.Client,
    expected_format: transport.ResponseFormat,
    request: transport.PreparedRequest,
) (ExecuteError || ClassifyResponseError)!ExecutedResponse {
    const response = try executePrepared(allocator, runtime_client, request);
    return classifyOwnedResponse(allocator, expected_format, response);
}

/// Parses an owned successful JSON payload into the provided type while retaining the response body backing.
pub fn parseOwnedJson(
    comptime T: type,
    allocator: std.mem.Allocator,
    response: OwnedResponse,
) DecodeResponseError!OwnedParsed(T) {
    try validateSuccessContentType(.json, response.content_type);
    return .{
        .parsed = try std.json.parseFromSlice(T, allocator, response.body, .{}),
        .response = response,
    };
}

/// Parses an owned successful JSON envelope into the provided data payload type while retaining the response body backing.
pub fn parseOwnedSuccessEnvelope(
    comptime Data: type,
    allocator: std.mem.Allocator,
    response: OwnedResponse,
) DecodeResponseError!OwnedParsed(envelope.SuccessEnvelope(Data)) {
    try validateSuccessContentType(.json, response.content_type);
    return .{
        .parsed = try envelope.parseSuccessEnvelope(Data, allocator, response.body),
        .response = response,
    };
}

fn buildEffectiveRequest(
    allocator: std.mem.Allocator,
    request: transport.PreparedRequest,
) (std.mem.Allocator.Error || errors.TransportError)!EffectiveRequest {
    return switch (request.body) {
        .none => .{ .url = request.url, .payload = null, .content_type = request.content_type },
        .form => |payload| switch (request.method) {
            .get, .delete => .{
                .url = try appendQueryToUrl(allocator, request.url, payload),
                .payload = null,
                .content_type = null,
            },
            .post, .put => .{
                .url = request.url,
                .payload = payload,
                .content_type = request.content_type,
            },
        },
        .json => |payload| switch (request.method) {
            .post, .put => .{ .url = request.url, .payload = payload, .content_type = request.content_type },
            .get, .delete => error.InvalidRequestBodyForMethod,
        },
        .raw => |payload| switch (request.method) {
            .post, .put => .{ .url = request.url, .payload = payload, .content_type = request.content_type },
            .get, .delete => error.InvalidRequestBodyForMethod,
        },
    };
}

fn appendQueryToUrl(allocator: std.mem.Allocator, url: []const u8, query: []const u8) std.mem.Allocator.Error![]u8 {
    if (query.len == 0) return allocator.dupe(u8, url);
    const separator: []const u8 = if (std.mem.indexOfScalar(u8, url, '?') == null) "?" else "&";
    return std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ url, separator, query });
}

fn methodToStd(method: transport.Method) std.http.Method {
    return switch (method) {
        .get => .GET,
        .post => .POST,
        .put => .PUT,
        .delete => .DELETE,
    };
}

fn isJsonContentType(content_type: ?[]const u8) bool {
    const value = content_type orelse return false;
    const media_type = normalizedMediaType(value);
    return std.ascii.eqlIgnoreCase(media_type, "application/json") or
        std.ascii.eqlIgnoreCase(media_type, "text/json") or
        endsWithIgnoreCase(media_type, "+json");
}

fn isCsvContentType(content_type: ?[]const u8) bool {
    const value = content_type orelse return false;
    const media_type = normalizedMediaType(value);
    return std.ascii.eqlIgnoreCase(media_type, "text/csv") or
        std.ascii.eqlIgnoreCase(media_type, "application/csv");
}

fn normalizedMediaType(content_type: []const u8) []const u8 {
    const trimmed = std.mem.trim(u8, content_type, " \t\r\n");
    const semicolon_index = std.mem.indexOfScalar(u8, trimmed, ';') orelse trimmed.len;
    return std.mem.trimRight(u8, trimmed[0..semicolon_index], " \t\r\n");
}

fn endsWithIgnoreCase(value: []const u8, suffix: []const u8) bool {
    if (value.len < suffix.len) return false;
    return std.ascii.eqlIgnoreCase(value[value.len - suffix.len ..], suffix);
}

test "loginUrl encodes documented login endpoint" {
    const allocator = std.testing.allocator;
    const url = try loginUrl(allocator, "kite_key");
    defer allocator.free(url);

    try std.testing.expectEqualStrings(
        "https://kite.zerodha.com/connect/login?v=3&api_key=kite_key",
        url,
    );
}

test "contentTypeMatches accepts JSON CSV and raw expectations" {
    try std.testing.expect(contentTypeMatches(.json, "application/json; charset=utf-8"));
    try std.testing.expect(contentTypeMatches(.json, "application/problem+json"));
    try std.testing.expect(contentTypeMatches(.csv, "text/csv; charset=utf-8"));
    try std.testing.expect(contentTypeMatches(.raw, null));
    try std.testing.expect(!contentTypeMatches(.json, "text/plain"));
    try std.testing.expect(!contentTypeMatches(.csv, "application/json"));
}

test "validateSuccessContentType rejects mismatched success payloads" {
    try std.testing.expectError(error.InvalidResponseContentType, validateSuccessContentType(.json, "text/csv"));
    try std.testing.expectError(error.InvalidResponseContentType, validateSuccessContentType(.csv, null));
}

test "parseApiError decodes error envelope and falls back error type from status" {
    const payload =
        \\{"status":"error","message":"Token is invalid"}
    ;

    const parsed = try parseApiError(std.testing.allocator, 403, "application/json", payload);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("Token is invalid", parsed.message);
    try std.testing.expectEqualStrings(errors.ErrorType.token, parsed.error_type.?);
    try std.testing.expectEqual(@as(?u16, 403), parsed.status);
}

test "parseApiError rejects non-json error payloads" {
    const payload =
        \\{"status":"error","message":"Token is invalid"}
    ;

    try std.testing.expectError(error.InvalidResponseContentType, parseApiError(std.testing.allocator, 403, "text/plain", payload));
}

test "classifyResponse validates successful JSON responses" {
    const response: ResponseView = .{
        .status = 200,
        .content_type = "application/json; charset=utf-8",
        .body = "{\"status\":\"success\",\"data\":{}}",
    };

    const classified = try classifyResponse(std.testing.allocator, .json, response);
    defer classified.deinit(std.testing.allocator);

    try std.testing.expect(classified == .success);
    try std.testing.expectEqual(@as(u16, 200), classified.success.status);
}

test "classifyResponse maps error responses into ApiError" {
    const response: ResponseView = .{
        .status = 400,
        .content_type = "application/json",
        .body = "{\"status\":\"error\",\"message\":\"Bad input\",\"error_type\":\"InputException\"}",
    };

    const classified = try classifyResponse(std.testing.allocator, .json, response);
    defer classified.deinit(std.testing.allocator);

    try std.testing.expect(classified == .api_error);
    try std.testing.expectEqualStrings("Bad input", classified.api_error.message);
    try std.testing.expectEqualStrings(errors.ErrorType.input, classified.api_error.error_type.?);
}

test "classifyResponse rejects mismatched success content type" {
    const response: ResponseView = .{
        .status = 200,
        .content_type = "text/plain",
        .body = "ok",
    };

    try std.testing.expectError(error.InvalidResponseContentType, classifyResponse(std.testing.allocator, .json, response));
}

test "classifyOwnedResponse frees error response body on api error path" {
    const body = try std.testing.allocator.dupe(u8, "{\"status\":\"error\",\"message\":\"Bad input\"}");
    errdefer std.testing.allocator.free(body);
    const content_type = try std.testing.allocator.dupe(u8, "application/json");
    errdefer std.testing.allocator.free(content_type);

    const classified = try classifyOwnedResponse(std.testing.allocator, .json, .{
        .status = 400,
        .content_type = content_type,
        .body = body,
    });
    defer classified.deinit(std.testing.allocator);

    try std.testing.expect(classified == .api_error);
    try std.testing.expectEqualStrings("Bad input", classified.api_error.message);
}

test "buildEffectiveRequest appends form payload to DELETE query string" {
    const url = try std.testing.allocator.dupe(u8, "https://api.kite.trade/session/token");
    defer std.testing.allocator.free(url);

    const effective = try buildEffectiveRequest(std.testing.allocator, .{
        .method = .delete,
        .url = url,
        .requires_auth = false,
        .authorization = null,
        .user_agent = "kiteconnect.zig/test",
        .accept = "application/json",
        .content_type = "application/x-www-form-urlencoded",
        .body = .{ .form = "api_key=kite_key&access_token=abc" },
    });
    defer effective.deinit(std.testing.allocator, url);

    try std.testing.expectEqualStrings(
        "https://api.kite.trade/session/token?api_key=kite_key&access_token=abc",
        effective.url,
    );
    try std.testing.expect(effective.payload == null);
    try std.testing.expect(effective.content_type == null);
}

test "buildEffectiveRequest rejects JSON payload on GET" {
    const url = try std.testing.allocator.dupe(u8, "https://api.kite.trade/quote");
    defer std.testing.allocator.free(url);

    try std.testing.expectError(error.InvalidRequestBodyForMethod, buildEffectiveRequest(std.testing.allocator, .{
        .method = .get,
        .url = url,
        .requires_auth = true,
        .authorization = null,
        .user_agent = "kiteconnect.zig/test",
        .accept = "application/json",
        .content_type = "application/json",
        .body = .{ .json = "{}" },
    }));
}

test "parseOwnedJson retains owned response body backing" {
    const body = try std.testing.allocator.dupe(u8, "{\"answer\":42}");
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const parsed = try parseOwnedJson(struct { answer: i32 }, std.testing.allocator, .{
        .status = 200,
        .content_type = content_type,
        .body = body,
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(i32, 42), parsed.parsed.value.answer);
}

test "parseOwnedSuccessEnvelope retains owned envelope response body backing" {
    const body = try std.testing.allocator.dupe(u8, "{\"status\":\"success\",\"data\":{\"order_id\":\"123\"}}");
    const content_type = try std.testing.allocator.dupe(u8, "application/json; charset=utf-8");

    const parsed = try parseOwnedSuccessEnvelope(struct { order_id: []const u8 }, std.testing.allocator, .{
        .status = 200,
        .content_type = content_type,
        .body = body,
    });
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("success", parsed.parsed.value.status);
    try std.testing.expectEqualStrings("123", parsed.parsed.value.data.order_id);
}
