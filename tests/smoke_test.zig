const std = @import("std");
const lib = @import("kiteconnect");

comptime {
    _ = @import("user_test.zig");
    _ = @import("margins_test.zig");
    _ = @import("orders_test.zig");
    _ = @import("trades_test.zig");
    _ = @import("portfolio_test.zig");
    _ = @import("market_test.zig");
    _ = @import("session_test.zig");
    _ = @import("mock_repo_test.zig");
}

test "client exposes stable bootstrap state" {
    const client = lib.Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
    });

    const state = client.state();
    try std.testing.expectEqualStrings("kite_key", state.api_key);
    try std.testing.expect(!state.has_access_token);
    try std.testing.expectEqualStrings("https://api.kite.trade", state.root_url);
}

test "login url smoke test" {
    const url = try lib.http.loginUrl(std.testing.allocator, "kite_key");
    defer std.testing.allocator.free(url);

    try std.testing.expect(std.mem.indexOf(u8, url, "api_key=kite_key") != null);
}

test "json parse smoke test" {
    const payload =
        \\{"status":"success","data":{"access_token":"abc123"}}
    ;

    const parsed = try lib.envelope.parseSuccessEnvelope(struct {
        access_token: []const u8,
    }, std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqualStrings("abc123", parsed.value.data.access_token);
}

test "auth checksum and client auth header smoke test" {
    const checksum = try lib.auth.generateChecksum(std.testing.allocator, "kite_key", "request_token", "secret");
    defer std.testing.allocator.free(checksum);

    try std.testing.expect(checksum.len == 64);

    const client = lib.Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
        .access_token = "access",
    });
    const header = try client.authorizationHeader();
    defer std.testing.allocator.free(header);

    try std.testing.expectEqualStrings("token kite_key:access", header);
}
