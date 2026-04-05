//! Authentication and authorization helpers.

const std = @import("std");

/// Error set used by auth helper functions.
pub const AuthError = error{
    MissingApiKey,
    MissingRequestToken,
    MissingApiSecret,
    MissingAccessToken,
    OutOfMemory,
};

/// Builds the documented request-token checksum as lowercase SHA-256 hex.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn generateChecksum(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    request_token: []const u8,
    api_secret: []const u8,
) AuthError![]u8 {
    if (api_key.len == 0) return error.MissingApiKey;
    if (request_token.len == 0) return error.MissingRequestToken;
    if (api_secret.len == 0) return error.MissingApiSecret;

    const payload = try std.fmt.allocPrint(allocator, "{s}{s}{s}", .{ api_key, request_token, api_secret });
    defer allocator.free(payload);

    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(payload, &digest, .{});
    const encoded = std.fmt.bytesToHex(digest, .lower);
    return allocator.dupe(u8, &encoded);
}

/// Builds the documented authorization header value.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn authorizationHeader(
    allocator: std.mem.Allocator,
    api_key: []const u8,
    access_token: []const u8,
) AuthError![]u8 {
    if (api_key.len == 0) return error.MissingApiKey;
    if (access_token.len == 0) return error.MissingAccessToken;
    return std.fmt.allocPrint(allocator, "token {s}:{s}", .{ api_key, access_token });
}

test "generateChecksum matches known SHA-256 hex" {
    const allocator = std.testing.allocator;
    const checksum = try generateChecksum(allocator, "kite_key", "request_token", "secret");
    defer allocator.free(checksum);

    try std.testing.expectEqualStrings(
        "28e5b0b5ab790536a5c46493362b6e507e4b8effa747f5382202716dbd8e3403",
        checksum,
    );
}

test "authorizationHeader matches documented format" {
    const allocator = std.testing.allocator;
    const header = try authorizationHeader(allocator, "kite_key", "access");
    defer allocator.free(header);

    try std.testing.expectEqualStrings("token kite_key:access", header);
}
