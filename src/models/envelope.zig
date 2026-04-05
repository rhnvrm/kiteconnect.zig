//! Generic Kite Connect response-envelope helpers.

const std = @import("std");

/// Generic success envelope used by most REST endpoints.
pub fn SuccessEnvelope(comptime Data: type) type {
    return struct {
        status: []const u8,
        data: Data,
    };
}

/// Generic error envelope returned by Kite Connect failures.
pub const ErrorEnvelope = struct {
    status: []const u8,
    message: []const u8,
    error_type: ?[]const u8 = null,
    data: ?std.json.Value = null,
};

/// Parses a success envelope into the provided payload type.
pub fn parseSuccessEnvelope(
    comptime Data: type,
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(SuccessEnvelope(Data)) {
    return std.json.parseFromSlice(SuccessEnvelope(Data), allocator, payload, .{
        .ignore_unknown_fields = true,
    });
}

/// Parses an error envelope without committing to endpoint-specific payload data.
pub fn parseErrorEnvelope(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(ErrorEnvelope) {
    return std.json.parseFromSlice(ErrorEnvelope, allocator, payload, .{
        .ignore_unknown_fields = true,
    });
}

test "parseSuccessEnvelope decodes a basic payload" {
    const allocator = std.testing.allocator;
    const payload =
        \\{"status":"success","data":{"user_id":"AB1234"}}
    ;

    const parsed = try parseSuccessEnvelope(struct { user_id: []const u8 }, allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqualStrings("AB1234", parsed.value.data.user_id);
}

test "parseErrorEnvelope decodes documented error shape" {
    const allocator = std.testing.allocator;
    const payload =
        \\{"status":"error","message":"Token is invalid","error_type":"TokenException"}
    ;

    const parsed = try parseErrorEnvelope(allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("error", parsed.value.status);
    try std.testing.expectEqualStrings("Token is invalid", parsed.value.message);
    try std.testing.expectEqualStrings("TokenException", parsed.value.error_type.?);
}
