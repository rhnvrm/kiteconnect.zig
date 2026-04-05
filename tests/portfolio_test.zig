const std = @import("std");
const lib = @import("kiteconnect");
const portfolio = lib.portfolio;

test "portfolio request paths and request specs stay aligned with gokiteconnect" {
    const holdings = portfolio.holdingsRequestOptions();
    try std.testing.expectEqualStrings("/portfolio/holdings", holdings.path);
    try std.testing.expect(holdings.requires_auth);

    const holdings_spec = portfolio.holdingsRequestSpec();
    try std.testing.expectEqual(lib.transport.ResponseFormat.json, holdings_spec.response_format);
    try std.testing.expectEqual(.get, holdings_spec.options.method);

    const positions = portfolio.positionsRequestOptions();
    try std.testing.expectEqualStrings("/portfolio/positions", positions.path);

    const convert = portfolio.convertPositionRequestOptions();
    try std.testing.expectEqual(.put, convert.method);
    const convert_spec = portfolio.convertPositionRequestSpec("exchange=NSE");
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", convert_spec.contentType().?);
    try std.testing.expectEqualStrings("exchange=NSE", convert_spec.body.form);
}

test "portfolio positions envelope parses net/day groups" {
    const payload =
        \\{"status":"success","data":{"net":[{"tradingsymbol":"INFY","exchange":"NSE","instrument_token":408065,"product":"MIS","quantity":5,"overnight_quantity":0,"multiplier":1,"average_price":1500.2,"close_price":1491.4,"last_price":1511.8,"value":7559,"pnl":58,"m2m":43,"unrealised":43,"realised":15,"buy_quantity":5,"buy_price":1500.2,"buy_value":7501,"buy_m2m":0,"sell_quantity":0,"sell_price":0,"sell_value":0,"sell_m2m":0,"day_buy_quantity":5,"day_buy_price":1500.2,"day_buy_value":7501,"day_sell_quantity":0,"day_sell_price":0,"day_sell_value":0}],"day":[]}}
    ;

    const parsed = try portfolio.parsePositions(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.net.len);
    try std.testing.expectEqual(@as(usize, 0), parsed.value.data.day.len);
    try std.testing.expectEqualStrings("INFY", parsed.value.data.net[0].tradingsymbol);
}

test "portfolio convert-position parser handles bool success envelope" {
    const payload =
        \\{"status":"success","data":true}
    ;

    const parsed = try portfolio.parseConvertPosition(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqualStrings("success", parsed.value.status);
    try std.testing.expect(parsed.value.data);
}
