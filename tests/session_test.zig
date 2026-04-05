const std = @import("std");
const lib = @import("kiteconnect");
const session_endpoint = lib.session;

fn expectFormContainsAll(form: []const u8, parts: []const []const u8) !void {
    for (parts) |part| {
        try std.testing.expect(std.mem.indexOf(u8, form, part) != null);
    }
}

test "session endpoint request options and request specs match Kite contracts" {
    const generate = session_endpoint.generateSessionRequestOptions();
    try std.testing.expectEqual(.post, generate.method);
    try std.testing.expectEqualStrings("/session/token", generate.path);
    try std.testing.expect(!generate.requires_auth);

    const renew = session_endpoint.renewAccessTokenRequestOptions();
    try std.testing.expectEqual(.post, renew.method);
    try std.testing.expectEqualStrings("/session/refresh_token", renew.path);
    try std.testing.expect(!renew.requires_auth);

    const invalidate = session_endpoint.invalidateTokenRequestOptions();
    try std.testing.expectEqual(.delete, invalidate.method);
    try std.testing.expectEqualStrings("/session/token", invalidate.path);
    try std.testing.expect(!invalidate.requires_auth);

    const generate_spec = session_endpoint.generateSessionRequestSpec("api_key=kite_key");
    try std.testing.expectEqual(.post, generate_spec.options.method);
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", generate_spec.contentType().?);
    try std.testing.expectEqualStrings("api_key=kite_key", generate_spec.body.form);

    const renew_spec = session_endpoint.renewAccessTokenRequestSpec("api_key=kite_key");
    try std.testing.expectEqual(.post, renew_spec.options.method);
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", renew_spec.contentType().?);

    const invalidate_spec = session_endpoint.invalidateTokenRequestSpec("api_key=kite_key");
    try std.testing.expectEqual(.delete, invalidate_spec.options.method);
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", invalidate_spec.contentType().?);
    try std.testing.expectEqual(lib.transport.ResponseFormat.json, generate_spec.response_format);
}

test "buildGenerateSessionForm encodes required fields and checksum" {
    const form = try session_endpoint.buildGenerateSessionForm(
        std.testing.allocator,
        "kite_key",
        "request token",
        "secret",
    );
    defer std.testing.allocator.free(form);

    try expectFormContainsAll(form, &.{
        "api_key=kite_key",
        "request_token=request%20token",
        "checksum=6f3e9fa819cfc36dcbfc38978c5e7d4d86f26c08ace414469536c19fcca0bfc2",
    });
}

test "buildRenewAccessTokenForm encodes required fields and checksum" {
    const form = try session_endpoint.buildRenewAccessTokenForm(
        std.testing.allocator,
        "kite_key",
        "refresh token",
        "secret",
    );
    defer std.testing.allocator.free(form);

    const expected_checksum =
        "bd851309f032034dc37a6e0ce29e7ac07c9874a6b973de94de22f789fa370a20";

    try expectFormContainsAll(form, &.{
        "api_key=kite_key",
        "refresh_token=refresh%20token",
        "checksum=" ++ expected_checksum,
    });
}

test "buildInvalidateTokenForm encodes access and refresh invalidation payloads" {
    const access_form = try session_endpoint.buildInvalidateTokenForm(
        std.testing.allocator,
        "kite_key",
        .access_token,
        "access123",
    );
    defer std.testing.allocator.free(access_form);

    try std.testing.expectEqualStrings("api_key=kite_key&access_token=access123", access_form);

    const refresh_form = try session_endpoint.buildInvalidateTokenForm(
        std.testing.allocator,
        "kite_key",
        .refresh_token,
        "refresh123",
    );
    defer std.testing.allocator.free(refresh_form);

    try std.testing.expectEqualStrings("api_key=kite_key&refresh_token=refresh123", refresh_form);
}

test "parseGenerateSession decodes session envelope" {
    const payload =
        \\{"status":"success","data":{"user_id":"AB1234","user_name":"Alice Trader","user_shortname":"Alice","email":"alice@example.com","user_type":"individual","broker":"zerodha","exchanges":["NSE","BSE"],"products":["CNC","MIS"],"order_types":["MARKET","LIMIT"],"avatar_url":"https://example.com/avatar.png","meta":{"demat_consent":"granted"},"api_key":"kite_key","public_token":"pub123","access_token":"access123","refresh_token":"refresh123","login_time":"2026-04-05 09:15:01"}}
    ;

    const parsed = try session_endpoint.parseGenerateSession(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqualStrings("AB1234", parsed.value.data.user_id);
    try std.testing.expectEqualStrings("access123", parsed.value.data.access_token);
    try std.testing.expectEqualStrings("granted", parsed.value.data.meta.?.demat_consent.?);
}

test "parseRenewAccessToken decodes token envelope" {
    const payload =
        \\{"status":"success","data":{"user_id":"AB1234","access_token":"new_access","refresh_token":"refresh123"}}
    ;

    const parsed = try session_endpoint.parseRenewAccessToken(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("AB1234", parsed.value.data.user_id);
    try std.testing.expectEqualStrings("new_access", parsed.value.data.access_token);
}

test "parseInvalidateToken decodes bool success envelope" {
    const payload =
        \\{"status":"success","data":true}
    ;

    const parsed = try session_endpoint.parseInvalidateToken(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expect(parsed.value.data);
}
