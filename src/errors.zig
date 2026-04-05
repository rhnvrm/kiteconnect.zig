//! Shared error structures for transport and API failures.

const std = @import("std");
const envelope = @import("models/envelope.zig");

/// Canonical Kite Connect error-type strings used by API error envelopes.
pub const ErrorType = struct {
    pub const general = "GeneralException";
    pub const token = "TokenException";
    pub const permission = "PermissionException";
    pub const user = "UserException";
    pub const two_fa = "TwoFAException";
    pub const order = "OrderException";
    pub const input = "InputException";
    pub const data = "DataException";
    pub const network = "NetworkException";
};

/// Error payload returned by Kite Connect envelopes.
pub const ApiError = struct {
    message: []u8,
    error_type: ?[]u8 = null,
    status: ?u16 = null,

    /// Frees heap-owned error strings.
    pub fn deinit(self: ApiError, allocator: std.mem.Allocator) void {
        allocator.free(self.message);
        if (self.error_type) |value| allocator.free(value);
    }

    /// Builds an owned API error view from a parsed error envelope plus optional HTTP status.
    pub fn fromEnvelope(
        allocator: std.mem.Allocator,
        parsed: envelope.ErrorEnvelope,
        status: ?u16,
    ) std.mem.Allocator.Error!ApiError {
        const message = try allocator.dupe(u8, parsed.message);
        errdefer allocator.free(message);

        const error_type_source = parsed.error_type orelse fallbackErrorType(status);
        const error_type = try allocator.dupe(u8, error_type_source);
        errdefer allocator.free(error_type);

        return .{
            .message = message,
            .error_type = error_type,
            .status = status,
        };
    }
};

/// Returns the default Kite-style error type for a given HTTP status code.
pub fn fallbackErrorType(status: ?u16) []const u8 {
    return switch (status orelse 500) {
        400 => ErrorType.input,
        401, 403 => ErrorType.token,
        408, 503, 504 => ErrorType.network,
        else => ErrorType.general,
    };
}

/// Common transport/runtime failures to preserve across endpoint waves.
pub const TransportError = error{
    MissingAccessToken,
    UnexpectedStatus,
    InvalidResponseContentType,
    InvalidRequestBodyForMethod,
};

test "fallbackErrorType maps documented runtime classes" {
    try std.testing.expectEqualStrings(ErrorType.input, fallbackErrorType(400));
    try std.testing.expectEqualStrings(ErrorType.token, fallbackErrorType(401));
    try std.testing.expectEqualStrings(ErrorType.token, fallbackErrorType(403));
    try std.testing.expectEqualStrings(ErrorType.network, fallbackErrorType(503));
    try std.testing.expectEqualStrings(ErrorType.general, fallbackErrorType(500));
}

test "ApiError.fromEnvelope duplicates strings and falls back error type from status" {
    const parsed: envelope.ErrorEnvelope = .{
        .status = "error",
        .message = "Token is invalid",
        .error_type = null,
    };

    const api_error = try ApiError.fromEnvelope(std.testing.allocator, parsed, 403);
    defer api_error.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings("Token is invalid", api_error.message);
    try std.testing.expectEqualStrings(ErrorType.token, api_error.error_type.?);
    try std.testing.expectEqual(@as(?u16, 403), api_error.status);
}
