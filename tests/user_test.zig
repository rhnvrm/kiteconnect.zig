const std = @import("std");
const lib = @import("kiteconnect");
const user_endpoint = lib.user;

test "user endpoint request options match Kite paths" {
    const profile = user_endpoint.profileRequestOptions();
    try std.testing.expectEqual(.get, profile.method);
    try std.testing.expectEqualStrings("/user/profile", profile.path);
    try std.testing.expect(profile.requires_auth);

    const profile_spec = user_endpoint.profileRequestSpec();
    try std.testing.expectEqual(.get, profile_spec.options.method);
    try std.testing.expectEqual(lib.transport.ResponseFormat.json, profile_spec.response_format);

    const full_profile = user_endpoint.fullProfileRequestOptions();
    try std.testing.expectEqual(.get, full_profile.method);
    try std.testing.expectEqualStrings("/user/profile/full", full_profile.path);
    try std.testing.expect(full_profile.requires_auth);

    const full_profile_spec = user_endpoint.fullProfileRequestSpec();
    try std.testing.expectEqual(.get, full_profile_spec.options.method);
    try std.testing.expectEqual(lib.transport.ResponseFormat.json, full_profile_spec.response_format);

    const user_margins = user_endpoint.userMarginsRequestOptions();
    try std.testing.expectEqual(.get, user_margins.method);
    try std.testing.expectEqualStrings("/user/margins", user_margins.path);
    try std.testing.expect(user_margins.requires_auth);

    const user_margins_spec = user_endpoint.userMarginsRequestSpec();
    try std.testing.expectEqual(.get, user_margins_spec.options.method);
    try std.testing.expectEqual(lib.transport.ResponseFormat.json, user_margins_spec.response_format);

    const equity_margins = user_endpoint.userSegmentMarginsRequestOptions(.equity);
    try std.testing.expectEqual(.get, equity_margins.method);
    try std.testing.expectEqualStrings("/user/margins/equity", equity_margins.path);
    try std.testing.expect(equity_margins.requires_auth);

    const equity_margins_spec = user_endpoint.userSegmentMarginsRequestSpec(.equity);
    try std.testing.expectEqual(.get, equity_margins_spec.options.method);
    try std.testing.expectEqual(lib.transport.ResponseFormat.json, equity_margins_spec.response_format);

    const commodity_margins = user_endpoint.userSegmentMarginsRequestOptions(.commodity);
    try std.testing.expectEqual(.get, commodity_margins.method);
    try std.testing.expectEqualStrings("/user/margins/commodity", commodity_margins.path);
    try std.testing.expect(commodity_margins.requires_auth);
}

test "parseProfile decodes profile envelope" {
    const payload =
        \\{"status":"success","data":{"user_id":"AB1234","user_name":"Alice Trader","user_shortname":"Alice","email":"alice@example.com","user_type":"individual","broker":"zerodha","exchanges":["NSE","BSE"],"products":["CNC","MIS"],"order_types":["MARKET","LIMIT"],"avatar_url":"https://example.com/avatar.png"}}
    ;

    const parsed = try user_endpoint.parseProfile(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expectEqualStrings("AB1234", parsed.value.data.user_id);
    try std.testing.expectEqual(@as(usize, 2), parsed.value.data.exchanges.len);
}

test "parseFullProfile decodes full profile envelope" {
    const payload =
        \\{"status":"success","data":{"user_id":"AB1234","user_name":"Alice Trader","user_shortname":"Alice","email":"alice@example.com","user_type":"individual","broker":"zerodha","exchanges":["NSE","BSE"],"products":["CNC","MIS"],"order_types":["MARKET","LIMIT"],"avatar_url":null,"pan":"ABCDE1234F","demat_consent":true,"bank_accounts":[{"bank_name":"HDFC","account_type":"Savings","account":"xxxx1234","ifsc":"HDFC0000001","primary":true}]}}
    ;

    const parsed = try user_endpoint.parseFullProfile(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("ABCDE1234F", parsed.value.data.pan.?);
    try std.testing.expectEqual(true, parsed.value.data.demat_consent.?);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.bank_accounts.len);
    try std.testing.expect(parsed.value.data.bank_accounts[0].primary);
}

test "parseUserMargins decodes both segments" {
    const payload =
        \\{"status":"success","data":{"equity":{"enabled":true,"net":100000.5,"available":{"adhoc_margin":0,"cash":10000,"collateral":25000,"intraday_payin":0,"live_balance":35000,"opening_balance":10000,"span":0},"utilised":{"debits":0,"exposure":2000,"m2m_realised":0,"m2m_unrealised":0,"option_premium":0,"payout":0,"span":0,"holding_sales":0,"turnover":0,"liquid_collateral":0,"stock_collateral":0}},"commodity":{"enabled":false,"net":0,"available":{"adhoc_margin":0,"cash":0,"collateral":0,"intraday_payin":0,"live_balance":0,"opening_balance":0,"span":0},"utilised":{"debits":0,"exposure":0,"m2m_realised":0,"m2m_unrealised":0,"option_premium":0,"payout":0,"span":0,"holding_sales":0,"turnover":0,"liquid_collateral":0,"stock_collateral":0}}}}
    ;

    const parsed = try user_endpoint.parseUserMargins(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expect(parsed.value.data.equity != null);
    try std.testing.expect(parsed.value.data.commodity != null);
    try std.testing.expectEqual(@as(f64, 100000.5), parsed.value.data.equity.?.net);
    try std.testing.expectEqual(false, parsed.value.data.commodity.?.enabled);
}

test "parseSegmentMargins decodes single segment envelope" {
    const payload =
        \\{"status":"success","data":{"enabled":true,"net":42000,"available":{"adhoc_margin":0,"cash":15000,"collateral":10000,"intraday_payin":0,"live_balance":25000,"opening_balance":15000,"span":0},"utilised":{"debits":0,"exposure":500,"m2m_realised":0,"m2m_unrealised":0,"option_premium":0,"payout":0,"span":0,"holding_sales":0,"turnover":0,"liquid_collateral":0,"stock_collateral":0}}}
    ;

    const parsed = try user_endpoint.parseSegmentMargins(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expect(parsed.value.data.enabled);
    try std.testing.expectEqual(@as(f64, 42000), parsed.value.data.net);
    try std.testing.expectEqual(@as(f64, 500), parsed.value.data.utilised.exposure);
}
