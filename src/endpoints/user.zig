//! User endpoint request descriptors, runtime execution helpers, and envelope parsers.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const margin_models = @import("../models/margins.zig");
const user_models = @import("../models/user.zig");
const transport = @import("../transport.zig");

/// Parsed success payload for `/user/profile` that retains the response body backing.
pub const ProfileSuccess = http.OwnedParsed(envelope.SuccessEnvelope(user_models.Profile));

/// Parsed success payload for `/user/profile/full` that retains the response body backing.
pub const FullProfileSuccess = http.OwnedParsed(envelope.SuccessEnvelope(user_models.FullProfile));

/// Parsed success payload for `/user/margins` that retains the response body backing.
pub const UserMarginsSuccess = http.OwnedParsed(envelope.SuccessEnvelope(margin_models.UserMargins));

/// Parsed success payload for `/user/margins/{segment}` that retains the response body backing.
pub const SegmentMarginsSuccess = http.OwnedParsed(envelope.SuccessEnvelope(margin_models.SegmentMargins));

/// Result of executing `/user/profile`.
pub const ProfileResult = union(enum) {
    success: ProfileSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: ProfileResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `/user/profile/full`.
pub const FullProfileResult = union(enum) {
    success: FullProfileSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: FullProfileResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `/user/margins`.
pub const UserMarginsResult = union(enum) {
    success: UserMarginsSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: UserMarginsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `/user/margins/{segment}`.
pub const SegmentMarginsResult = union(enum) {
    success: SegmentMarginsSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: SegmentMarginsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Request metadata for `GET /user/profile`.
pub fn profileRequestOptions() transport.RequestOptions {
    return .{
        .method = .get,
        .path = "/user/profile",
        .requires_auth = true,
    };
}

/// Build a `transport.RequestSpec` for `GET /user/profile`.
pub fn profileRequestSpec() transport.RequestSpec {
    return .{
        .options = profileRequestOptions(),
        .response_format = .json,
    };
}

/// Request metadata for `GET /user/profile/full`.
pub fn fullProfileRequestOptions() transport.RequestOptions {
    return .{
        .method = .get,
        .path = "/user/profile/full",
        .requires_auth = true,
    };
}

/// Build a `transport.RequestSpec` for `GET /user/profile/full`.
pub fn fullProfileRequestSpec() transport.RequestSpec {
    return .{
        .options = fullProfileRequestOptions(),
        .response_format = .json,
    };
}

/// Request metadata for `GET /user/margins`.
pub fn userMarginsRequestOptions() transport.RequestOptions {
    return .{
        .method = .get,
        .path = "/user/margins",
        .requires_auth = true,
    };
}

/// Build a `transport.RequestSpec` for `GET /user/margins`.
pub fn userMarginsRequestSpec() transport.RequestSpec {
    return .{
        .options = userMarginsRequestOptions(),
        .response_format = .json,
    };
}

/// Request metadata for `GET /user/margins/{segment}`.
pub fn userSegmentMarginsRequestOptions(segment: margin_models.Segment) transport.RequestOptions {
    return .{
        .method = .get,
        .path = switch (segment) {
            .equity => "/user/margins/equity",
            .commodity => "/user/margins/commodity",
        },
        .requires_auth = true,
    };
}

/// Build a `transport.RequestSpec` for `GET /user/margins/{segment}`.
pub fn userSegmentMarginsRequestSpec(segment: margin_models.Segment) transport.RequestSpec {
    return .{
        .options = userSegmentMarginsRequestOptions(segment),
        .response_format = .json,
    };
}

/// Executes `/user/profile` and decodes either success payload or owned API error.
pub fn executeProfile(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!ProfileResult {
    return decodeProfileExecuted(client.allocator, try client.execute(runtime_client, profileRequestSpec()));
}

/// Executes `/user/profile/full` and decodes either success payload or owned API error.
pub fn executeFullProfile(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!FullProfileResult {
    return decodeFullProfileExecuted(client.allocator, try client.execute(runtime_client, fullProfileRequestSpec()));
}

/// Executes `/user/margins` and decodes either success payload or owned API error.
pub fn executeUserMargins(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!UserMarginsResult {
    return decodeUserMarginsExecuted(client.allocator, try client.execute(runtime_client, userMarginsRequestSpec()));
}

/// Executes `/user/margins/{segment}` and decodes either success payload or owned API error.
pub fn executeSegmentMargins(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    segment: margin_models.Segment,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!SegmentMarginsResult {
    return decodeSegmentMarginsExecuted(client.allocator, try client.execute(runtime_client, userSegmentMarginsRequestSpec(segment)));
}

/// Parse a `/user/profile` success envelope.
/// Caller owns the parsed value and must call `deinit()` on the result.
pub fn parseProfile(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(user_models.Profile)) {
    return envelope.parseSuccessEnvelope(user_models.Profile, allocator, payload);
}

/// Parse a `/user/profile/full` success envelope.
/// Caller owns the parsed value and must call `deinit()` on the result.
pub fn parseFullProfile(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(user_models.FullProfile)) {
    return envelope.parseSuccessEnvelope(user_models.FullProfile, allocator, payload);
}

/// Parse a `/user/margins` success envelope.
/// Caller owns the parsed value and must call `deinit()` on the result.
pub fn parseUserMargins(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(margin_models.UserMargins)) {
    return envelope.parseSuccessEnvelope(margin_models.UserMargins, allocator, payload);
}

/// Parse a `/user/margins/{segment}` success envelope.
/// Caller owns the parsed value and must call `deinit()` on the result.
pub fn parseSegmentMargins(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(margin_models.SegmentMargins)) {
    return envelope.parseSuccessEnvelope(margin_models.SegmentMargins, allocator, payload);
}

fn decodeProfileExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!ProfileResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(user_models.Profile, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeFullProfileExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!FullProfileResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(user_models.FullProfile, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeUserMarginsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!UserMarginsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(margin_models.UserMargins, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeSegmentMarginsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!SegmentMarginsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(margin_models.SegmentMargins, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

test "decodeProfileExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":{\"user_id\":\"AB1234\",\"user_name\":\"Alice Trader\",\"user_shortname\":\"Alice\",\"email\":\"alice@example.com\",\"user_type\":\"individual\",\"broker\":\"zerodha\",\"exchanges\":[\"NSE\",\"BSE\"],\"products\":[\"CNC\",\"MIS\"],\"order_types\":[\"MARKET\",\"LIMIT\"],\"avatar_url\":\"https://example.com/avatar.png\"}}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeProfileExecuted(std.testing.allocator, .{
        .success = .{
            .status = 200,
            .content_type = content_type,
            .body = body,
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqualStrings("AB1234", result.success.parsed.value.data.user_id);
    try std.testing.expectEqual(@as(usize, 2), result.success.parsed.value.data.exchanges.len);
}

test "decodeProfileExecuted preserves owned api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "Forbidden",
        .error_type = "GeneralException",
    }, 403);

    const result = try decodeProfileExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("Forbidden", result.api_error.message);
}
