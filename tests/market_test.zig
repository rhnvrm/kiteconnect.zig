const std = @import("std");
const lib = @import("kiteconnect");
const market = lib.market;

test "market quote endpoint paths stay aligned with gokiteconnect" {
    try std.testing.expectEqualStrings("/quote", market.quoteRequest().path);
    try std.testing.expectEqualStrings("/quote/ltp", market.ltpRequest().path);
    try std.testing.expectEqualStrings("/quote/ohlc", market.ohlcRequest().path);
}

test "market instruments-family request specs expect csv responses" {
    const instruments_spec = market.instrumentsRequestSpec();
    try std.testing.expectEqual(lib.transport.ResponseFormat.csv, instruments_spec.response_format);
    try std.testing.expectEqualStrings("/instruments", instruments_spec.options.path);

    const mf_spec = market.mfInstrumentsRequestSpec();
    try std.testing.expectEqual(lib.transport.ResponseFormat.csv, mf_spec.response_format);
    try std.testing.expectEqualStrings("/mf/instruments", mf_spec.options.path);
}

test "market historical query encodes booleans as 0/1" {
    const query = try market.buildHistoricalQuery(std.testing.allocator, .{
        .from = "2026-04-01 09:15:00",
        .to = "2026-04-01 15:30:00",
        .continuous = true,
        .oi = false,
    });
    defer std.testing.allocator.free(query);

    try std.testing.expectEqualStrings(
        "from=2026-04-01%2009%3A15%3A00&to=2026-04-01%2015%3A30%3A00&continuous=1&oi=0",
        query,
    );
}

test "market historical parser converts candle rows" {
    const payload =
        \\{"status":"success","data":{"candles":[["2026-04-01T09:15:00+0530",1500.0,1510.0,1498.0,1508.0,12000,3400],["2026-04-01T09:20:00+0530",1508.0,1511.0,1504.0,1506.0,3400]]}}
    ;

    const parsed = try market.parseHistoricalData(std.testing.allocator, payload);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), parsed.candles.len);
    try std.testing.expectEqualStrings("2026-04-01T09:15:00+0530", parsed.candles[0].date);
    try std.testing.expectEqual(@as(u64, 12000), parsed.candles[0].volume);
    try std.testing.expectEqual(@as(?u64, 3400), parsed.candles[0].oi);
    try std.testing.expectEqual(@as(?u64, null), parsed.candles[1].oi);
}

test "market instruments csv parser baseline" {
    const payload =
        \\instrument_token,exchange_token,tradingsymbol,name,last_price,expiry,strike,tick_size,lot_size,instrument_type,segment,exchange
        \\738561,2885,RELIANCE,RELIANCE INDUSTRIES,2856.15,,0,0.05,1,EQ,NSE,NSE
    ;

    const parsed = try market.parseInstrumentsCsv(std.testing.allocator, payload);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.instruments.len);
    try std.testing.expectEqual(@as(u64, 738561), parsed.instruments[0].instrument_token);
    try std.testing.expectEqual(@as(u64, 1), parsed.instruments[0].lot_size);
    try std.testing.expectEqualStrings("", parsed.instruments[0].expiry);
}

test "market mf instruments csv parser baseline" {
    const payload =
        \\tradingsymbol,amc,name,purchase_allowed,redemption_allowed,last_price,purchase_amount_multiplier,minimum_purchase_amount,minimum_additional_purchase_amount,minimum_redemption_quantity,redemption_quantity_multiplier,dividend_type,scheme_type,plan,settlement_type,last_price_date
        \\INF209KB15D0,Some AMC,"Fund, Direct Growth",1,0,128.5,1,100,100,0.001,0.001,growth,open,direct,T+2,2026-04-03
    ;

    const parsed = try market.parseMfInstrumentsCsv(std.testing.allocator, payload);
    defer parsed.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 1), parsed.instruments.len);
    try std.testing.expect(parsed.instruments[0].purchase_allowed);
    try std.testing.expect(!parsed.instruments[0].redemption_allowed);
    try std.testing.expectEqualStrings("Fund, Direct Growth", parsed.instruments[0].name);
}
