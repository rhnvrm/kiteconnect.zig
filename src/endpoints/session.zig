//! Auth/session endpoint request contracts, runtime execution helpers, and envelope parsers.

const std = @import("std");
const auth = @import("../auth.zig");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const session_models = @import("../models/session.zig");
const transport = @import("../transport.zig");

/// Error set used by session request-form builders.
pub const FormBuildError = auth.AuthError || error{
    MissingRefreshToken,
    MissingChecksum,
    OutOfMemory,
};

/// Error set used by helpers that execute session calls and persist returned access tokens on the client.
pub const ExecuteAndStoreTokenError = client_mod.ExecuteRequestError || http.DecodeResponseError || std.mem.Allocator.Error;

/// Parsed success payload for `POST /session/token` that retains the response body backing.
pub const GenerateSessionSuccess = http.OwnedParsed(envelope.SuccessEnvelope(session_models.UserSession));

/// Parsed success payload for `POST /session/refresh_token` that retains the response body backing.
pub const RenewAccessTokenSuccess = http.OwnedParsed(envelope.SuccessEnvelope(session_models.UserSessionTokens));

/// Parsed success payload for `DELETE /session/token` that retains the response body backing.
pub const InvalidateTokenSuccess = http.OwnedParsed(envelope.SuccessEnvelope(bool));

/// Result of executing `POST /session/token`.
pub const GenerateSessionResult = union(enum) {
    success: GenerateSessionSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: GenerateSessionResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `POST /session/refresh_token`.
pub const RenewAccessTokenResult = union(enum) {
    success: RenewAccessTokenSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: RenewAccessTokenResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Result of executing `DELETE /session/token`.
pub const InvalidateTokenResult = union(enum) {
    success: InvalidateTokenSuccess,
    api_error: errors.ApiError,

    /// Frees retained success payloads or owned API errors.
    pub fn deinit(self: InvalidateTokenResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Token kind used by `/session/token` invalidation.
pub const InvalidateTokenKind = enum {
    access_token,
    refresh_token,
};

/// Request metadata for `POST /session/token`.
pub fn generateSessionRequestOptions() transport.RequestOptions {
    return .{
        .method = .post,
        .path = "/session/token",
        .requires_auth = false,
    };
}

/// Request metadata for `POST /session/refresh_token`.
pub fn renewAccessTokenRequestOptions() transport.RequestOptions {
    return .{
        .method = .post,
        .path = "/session/refresh_token",
        .requires_auth = false,
    };
}

/// Request metadata for `DELETE /session/token`.
pub fn invalidateTokenRequestOptions() transport.RequestOptions {
    return .{
        .method = .delete,
        .path = "/session/token",
        .requires_auth = false,
    };
}

/// Build a `transport.RequestSpec` for session generation.
pub fn generateSessionRequestSpec(form: []const u8) transport.RequestSpec {
    return .{
        .options = generateSessionRequestOptions(),
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Build a `transport.RequestSpec` for access-token renewal.
pub fn renewAccessTokenRequestSpec(form: []const u8) transport.RequestSpec {
    return .{
        .options = renewAccessTokenRequestOptions(),
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Build a `transport.RequestSpec` for token invalidation.
pub fn invalidateTokenRequestSpec(form: []const u8) transport.RequestSpec {
    return .{
        .options = invalidateTokenRequestOptions(),
        .body = .{ .form = form },
        .response_format = .json,
    };
}

/// Executes `POST /session/token` and decodes either success payload or owned API error.
pub fn executeGenerateSession(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!GenerateSessionResult {
    return decodeGenerateSessionExecuted(client.allocator, try client.execute(runtime_client, generateSessionRequestSpec(form)));
}

/// Executes `POST /session/token`, then stores returned access token on the client when successful.
pub fn executeGenerateSessionAndSetAccessToken(
    client: *client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) ExecuteAndStoreTokenError!GenerateSessionResult {
    var result = try executeGenerateSession(client.*, runtime_client, form);
    errdefer result.deinit(client.allocator);

    if (result == .success) {
        const access_token = result.success.parsed.value.data.access_token;
        if (access_token.len != 0) {
            try client.setAccessTokenOwned(access_token);
        }
    }

    return result;
}

/// Executes `POST /session/refresh_token` and decodes either success payload or owned API error.
pub fn executeRenewAccessToken(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!RenewAccessTokenResult {
    return decodeRenewAccessTokenExecuted(client.allocator, try client.execute(runtime_client, renewAccessTokenRequestSpec(form)));
}

/// Executes `POST /session/refresh_token`, then stores returned access token on the client when successful.
pub fn executeRenewAccessTokenAndSetAccessToken(
    client: *client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) ExecuteAndStoreTokenError!RenewAccessTokenResult {
    var result = try executeRenewAccessToken(client.*, runtime_client, form);
    errdefer result.deinit(client.allocator);

    if (result == .success) {
        const access_token = result.success.parsed.value.data.access_token;
        if (access_token.len != 0) {
            try client.setAccessTokenOwned(access_token);
        }
    }

    return result;
}

/// Executes `DELETE /session/token` and decodes either success payload or owned API error.
pub fn executeInvalidateToken(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!InvalidateTokenResult {
    return decodeInvalidateTokenExecuted(client.allocator, try client.execute(runtime_client, invalidateTokenRequestSpec(form)));
}

/// Builds form payload for `POST /session/token`.
/// Caller owns the returned payload and must free it with the same allocator.
pub fn buildGenerateSessionForm(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    request_token: []const u8,
    api_secret: []const u8,
) FormBuildError![]u8 {
    const checksum = try auth.generateChecksum(allocator, api_key, request_token, api_secret);
    defer allocator.free(checksum);

    return buildGenerateSessionFormWithChecksum(allocator, api_key, request_token, checksum);
}

/// Builds form payload for `POST /session/token` using a precomputed checksum.
/// Caller owns the returned payload and must free it with the same allocator.
pub fn buildGenerateSessionFormWithChecksum(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    request_token: []const u8,
    checksum: []const u8,
) FormBuildError![]u8 {
    if (api_key.len == 0) return error.MissingApiKey;
    if (request_token.len == 0) return error.MissingRequestToken;
    if (checksum.len == 0) return error.MissingChecksum;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendFormField(allocator, &buffer, "api_key", api_key, false);
    try appendFormField(allocator, &buffer, "request_token", request_token, true);
    try appendFormField(allocator, &buffer, "checksum", checksum, true);

    return buffer.toOwnedSlice(allocator);
}

/// Builds form payload for `POST /session/refresh_token`.
/// Caller owns the returned payload and must free it with the same allocator.
pub fn buildRenewAccessTokenForm(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    refresh_token: []const u8,
    api_secret: []const u8,
) FormBuildError![]u8 {
    if (refresh_token.len == 0) return error.MissingRefreshToken;

    const checksum = try auth.generateChecksum(allocator, api_key, refresh_token, api_secret);
    defer allocator.free(checksum);

    return buildRenewAccessTokenFormWithChecksum(allocator, api_key, refresh_token, checksum);
}

/// Builds form payload for `POST /session/refresh_token` using a precomputed checksum.
/// Caller owns the returned payload and must free it with the same allocator.
pub fn buildRenewAccessTokenFormWithChecksum(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    refresh_token: []const u8,
    checksum: []const u8,
) FormBuildError![]u8 {
    if (api_key.len == 0) return error.MissingApiKey;
    if (refresh_token.len == 0) return error.MissingRefreshToken;
    if (checksum.len == 0) return error.MissingChecksum;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendFormField(allocator, &buffer, "api_key", api_key, false);
    try appendFormField(allocator, &buffer, "refresh_token", refresh_token, true);
    try appendFormField(allocator, &buffer, "checksum", checksum, true);

    return buffer.toOwnedSlice(allocator);
}

/// Builds form payload for `DELETE /session/token` invalidation requests.
/// Caller owns the returned payload and must free it with the same allocator.
pub fn buildInvalidateTokenForm(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    token_kind: InvalidateTokenKind,
    token: []const u8,
) FormBuildError![]u8 {
    if (api_key.len == 0) return error.MissingApiKey;
    if (token.len == 0) {
        return switch (token_kind) {
            .access_token => error.MissingAccessToken,
            .refresh_token => error.MissingRefreshToken,
        };
    }

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendFormField(allocator, &buffer, "api_key", api_key, false);
    try appendFormField(allocator, &buffer, switch (token_kind) {
        .access_token => "access_token",
        .refresh_token => "refresh_token",
    }, token, true);

    return buffer.toOwnedSlice(allocator);
}

/// Parse a `POST /session/token` success envelope.
/// Caller owns the parsed value and must call `deinit()`.
pub fn parseGenerateSession(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(session_models.UserSession)) {
    return envelope.parseSuccessEnvelope(session_models.UserSession, allocator, payload);
}

/// Parse a `POST /session/refresh_token` success envelope.
/// Caller owns the parsed value and must call `deinit()`.
pub fn parseRenewAccessToken(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(session_models.UserSessionTokens)) {
    return envelope.parseSuccessEnvelope(session_models.UserSessionTokens, allocator, payload);
}

/// Parse a `DELETE /session/token` success envelope.
/// Caller owns the parsed value and must call `deinit()`.
pub fn parseInvalidateToken(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(bool)) {
    return envelope.parseSuccessEnvelope(bool, allocator, payload);
}

fn decodeGenerateSessionExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!GenerateSessionResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(session_models.UserSession, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeRenewAccessTokenExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!RenewAccessTokenResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(session_models.UserSessionTokens, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeInvalidateTokenExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!InvalidateTokenResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(bool, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn appendFormField(
    allocator: std.mem.Allocator,
    buffer: *std.ArrayList(u8),
    key: []const u8,
    value: []const u8,
    prefix_ampersand: bool,
) !void {
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

test "decodeGenerateSessionExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":{\"user_id\":\"AB1234\",\"user_name\":\"Alice Trader\",\"user_shortname\":\"Alice\",\"email\":\"alice@example.com\",\"user_type\":\"individual\",\"broker\":\"zerodha\",\"exchanges\":[\"NSE\"],\"products\":[\"CNC\"],\"order_types\":[\"MARKET\"],\"api_key\":\"kite_key\",\"public_token\":\"pub123\",\"access_token\":\"access123\",\"refresh_token\":\"refresh123\",\"login_time\":\"2026-04-05 09:15:01\"}}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeGenerateSessionExecuted(std.testing.allocator, .{
        .success = .{
            .status = 200,
            .content_type = content_type,
            .body = body,
        },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqualStrings("AB1234", result.success.parsed.value.data.user_id);
    try std.testing.expectEqualStrings("access123", result.success.parsed.value.data.access_token);
}

test "decodeInvalidateTokenExecuted decodes bool success payload" {
    const body = try std.testing.allocator.dupe(u8, "{\"status\":\"success\",\"data\":true}");
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeInvalidateTokenExecuted(std.testing.allocator, .{
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

test "decodeGenerateSessionExecuted preserves owned api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "Bad token",
        .error_type = "TokenException",
    }, 403);

    const result = try decodeGenerateSessionExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("Bad token", result.api_error.message);
    try std.testing.expectEqualStrings(errors.ErrorType.token, result.api_error.error_type.?);
}
