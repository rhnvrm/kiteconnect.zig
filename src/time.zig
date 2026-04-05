//! Shared time parsing helpers and conventions.

const std = @import("std");

/// Error set used by lightweight time helpers.
pub const TimeError = error{
    EmptyValue,
    InvalidUnixSeconds,
};

/// Parses a decimal Unix-seconds string into an integer.
pub fn parseUnixSeconds(value: []const u8) TimeError!i64 {
    if (value.len == 0) return error.EmptyValue;
    return std.fmt.parseInt(i64, value, 10) catch error.InvalidUnixSeconds;
}

test "parseUnixSeconds parses decimal strings" {
    try std.testing.expectEqual(@as(i64, 1712345678), try parseUnixSeconds("1712345678"));
}
