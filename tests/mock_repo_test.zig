const std = @import("std");
const lib = @import("kiteconnect");

const user = lib.user;
const session = lib.session;
const orders = lib.orders;
const portfolio = lib.portfolio;
const market = lib.market;
const margins = lib.margins;
const gtt = lib.gtt;
const alerts = lib.alerts;
const mutual_funds = lib.mutual_funds;

fn normalizeJsonFixture(allocator: std.mem.Allocator, payload: []u8, name: []const u8) ![]u8 {
    if (!std.mem.endsWith(u8, name, ".json")) return payload;

    const trimmed = std.mem.trim(u8, payload, &std.ascii.whitespace);
    if (trimmed.len == 0 or trimmed[0] != '{') return payload;

    const after_open = std.mem.trimLeft(u8, trimmed[1..], &std.ascii.whitespace);
    if (std.mem.startsWith(u8, after_open, "\"status\"")) return payload;
    if (std.mem.indexOf(u8, trimmed, "\"data\"") == null) return payload;

    const normalized = try std.fmt.allocPrint(allocator, "{{\"status\":\"success\",{s}", .{trimmed[1..]});
    allocator.free(payload);
    return normalized;
}

fn readMockFixture(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    const candidates = [_][]const u8{
        "../../zerodha/kiteconnect-mocks",
        "../zerodha/kiteconnect-mocks",
        "workspace/code/github.com/zerodha/kiteconnect-mocks",
    };

    for (candidates) |base| {
        const fixture_path = try std.fs.path.join(allocator, &.{ base, name });
        defer allocator.free(fixture_path);

        const data = std.fs.cwd().readFileAlloc(allocator, fixture_path, 16 * 1024 * 1024) catch |err| switch (err) {
            error.FileNotFound => continue,
            else => return err,
        };
        return try normalizeJsonFixture(allocator, data, name);
    }

    return error.SkipZigTest;
}

test "kiteconnect-mocks session and user fixtures parse cleanly" {
    const generate_session_payload = try readMockFixture(std.testing.allocator, "generate_session.json");
    defer std.testing.allocator.free(generate_session_payload);
    const generate_session = try session.parseGenerateSession(std.testing.allocator, generate_session_payload);
    defer generate_session.deinit();
    try std.testing.expect(generate_session.value.data.user_id.len > 0);
    try std.testing.expectEqualStrings("physical", generate_session.value.data.meta.?.demat_consent.?);

    const logout_payload = try readMockFixture(std.testing.allocator, "session_logout.json");
    defer std.testing.allocator.free(logout_payload);
    const logout = try session.parseInvalidateToken(std.testing.allocator, logout_payload);
    defer logout.deinit();
    try std.testing.expectEqualStrings("success", logout.value.status);
    try std.testing.expect(logout.value.data);

    const profile_payload = try readMockFixture(std.testing.allocator, "profile.json");
    defer std.testing.allocator.free(profile_payload);
    const profile = try user.parseProfile(std.testing.allocator, profile_payload);
    defer profile.deinit();
    try std.testing.expectEqualStrings("AB1234", profile.value.data.user_id);
    try std.testing.expectEqualStrings("ZERODHA", profile.value.data.broker);

    const full_profile_payload = try readMockFixture(std.testing.allocator, "full_profile.json");
    defer std.testing.allocator.free(full_profile_payload);
    const full_profile = try user.parseFullProfile(std.testing.allocator, full_profile_payload);
    defer full_profile.deinit();
    try std.testing.expect(full_profile.value.data.user_id.len > 0);

    const margins_payload = try readMockFixture(std.testing.allocator, "margins.json");
    defer std.testing.allocator.free(margins_payload);
    const user_margins = try user.parseUserMargins(std.testing.allocator, margins_payload);
    defer user_margins.deinit();
    try std.testing.expect(user_margins.value.data.equity != null);
    try std.testing.expect(user_margins.value.data.equity.?.enabled);

    const equity_payload = try readMockFixture(std.testing.allocator, "margins_equity.json");
    defer std.testing.allocator.free(equity_payload);
    const equity = try user.parseSegmentMargins(std.testing.allocator, equity_payload);
    defer equity.deinit();
    try std.testing.expect(equity.value.data.enabled);

    const commodity_payload = try readMockFixture(std.testing.allocator, "margin_commodity.json");
    defer std.testing.allocator.free(commodity_payload);
    const commodity = try user.parseSegmentMargins(std.testing.allocator, commodity_payload);
    defer commodity.deinit();
    try std.testing.expect(commodity.value.data.enabled);

    const order_margins_payload = try readMockFixture(std.testing.allocator, "order_margins.json");
    defer std.testing.allocator.free(order_margins_payload);
    const order_margins = try margins.parseOrderMargins(std.testing.allocator, order_margins_payload);
    defer order_margins.deinit();
    try std.testing.expectEqual(@as(usize, 1), order_margins.value.data.len);
    try std.testing.expectEqual(@as(f64, 1498), order_margins.value.data[0].@"var");
    try std.testing.expectEqual(@as(f64, 1), order_margins.value.data[0].leverage);
    try std.testing.expectEqualStrings("stt", order_margins.value.data[0].charges.transaction_tax_type.?);
    try std.testing.expect(order_margins.value.data[0].charges.gst.total > 0);

    const basket_margins_payload = try readMockFixture(std.testing.allocator, "basket_margins.json");
    defer std.testing.allocator.free(basket_margins_payload);
    const basket_margins = try margins.parseBasketMargins(std.testing.allocator, basket_margins_payload);
    defer basket_margins.deinit();
    try std.testing.expectEqual(@as(usize, 2), basket_margins.value.data.orders.len);
    try std.testing.expectEqual(@as(f64, 40), basket_margins.value.data.charges.brokerage);
    try std.testing.expect(basket_margins.value.data.initial.span > basket_margins.value.data.final.span);

    const order_charges_payload = try readMockFixture(std.testing.allocator, "virtual_contract_note.json");
    defer std.testing.allocator.free(order_charges_payload);
    const order_charges = try margins.parseOrderCharges(std.testing.allocator, order_charges_payload);
    defer order_charges.deinit();
    try std.testing.expectEqual(@as(usize, 3), order_charges.value.data.len);
    try std.testing.expectEqualStrings("SBIN", order_charges.value.data[0].tradingsymbol.?);
    try std.testing.expectEqualStrings("stt", order_charges.value.data[0].charges.transaction_tax_type.?);
    try std.testing.expect(order_charges.value.data[2].charges.total > 20);
}

test "kiteconnect-mocks order and portfolio fixtures parse cleanly" {
    const orders_payload = try readMockFixture(std.testing.allocator, "orders.json");
    defer std.testing.allocator.free(orders_payload);
    const order_list = try orders.parseOrders(std.testing.allocator, orders_payload);
    defer order_list.deinit();
    try std.testing.expect(order_list.value.data.len > 0);
    try std.testing.expectEqualStrings("100000000000000", order_list.value.data[0].order_id);
    try std.testing.expect(order_list.value.data[0].meta != null);
    try std.testing.expectEqual(@as(usize, 0), order_list.value.data[0].meta.?.map.count());

    const trades_payload = try readMockFixture(std.testing.allocator, "trades.json");
    defer std.testing.allocator.free(trades_payload);
    const trades = try orders.parseTrades(std.testing.allocator, trades_payload);
    defer trades.deinit();
    try std.testing.expect(trades.value.data.len > 0);

    const order_info_payload = try readMockFixture(std.testing.allocator, "order_info.json");
    defer std.testing.allocator.free(order_info_payload);
    const order_history = try orders.parseOrderHistory(std.testing.allocator, order_info_payload);
    defer order_history.deinit();
    try std.testing.expect(order_history.value.data.len > 0);

    const order_trades_payload = try readMockFixture(std.testing.allocator, "order_trades.json");
    defer std.testing.allocator.free(order_trades_payload);
    const order_trades = try orders.parseOrderTrades(std.testing.allocator, order_trades_payload);
    defer order_trades.deinit();
    try std.testing.expect(order_trades.value.data.len > 0);

    const order_response_payload = try readMockFixture(std.testing.allocator, "order_response.json");
    defer std.testing.allocator.free(order_response_payload);
    const order_response = try orders.parseOrderMutation(std.testing.allocator, order_response_payload);
    defer order_response.deinit();
    try std.testing.expect(order_response.value.data.order_id.len > 0);

    const holdings_payload = try readMockFixture(std.testing.allocator, "holdings.json");
    defer std.testing.allocator.free(holdings_payload);
    const holdings = try portfolio.parseHoldings(std.testing.allocator, holdings_payload);
    defer holdings.deinit();
    try std.testing.expect(holdings.value.data.len > 0);

    const holdings_compact_payload = try readMockFixture(std.testing.allocator, "holdings_compact.json");
    defer std.testing.allocator.free(holdings_compact_payload);
    const holdings_compact = try portfolio.parseHoldingsCompact(std.testing.allocator, holdings_compact_payload);
    defer holdings_compact.deinit();
    try std.testing.expect(holdings_compact.value.data.len > 0);

    const holdings_summary_payload = try readMockFixture(std.testing.allocator, "holdings_summary.json");
    defer std.testing.allocator.free(holdings_summary_payload);
    const holdings_summary = try portfolio.parseHoldingsSummary(std.testing.allocator, holdings_summary_payload);
    defer holdings_summary.deinit();
    try std.testing.expect(holdings_summary.value.data.total_pnl != 0 or holdings_summary.value.data.invested_amount != 0);

    const auctions_payload = try readMockFixture(std.testing.allocator, "auctions_list.json");
    defer std.testing.allocator.free(auctions_payload);
    const auctions = try portfolio.parseAuctionInstruments(std.testing.allocator, auctions_payload);
    defer auctions.deinit();
    try std.testing.expect(auctions.value.data.len > 0);

    const positions_payload = try readMockFixture(std.testing.allocator, "positions.json");
    defer std.testing.allocator.free(positions_payload);
    const positions = try portfolio.parsePositions(std.testing.allocator, positions_payload);
    defer positions.deinit();
    try std.testing.expect(positions.value.data.net.len > 0 or positions.value.data.day.len > 0);

    const convert_position_payload = try readMockFixture(std.testing.allocator, "convert_position.json");
    defer std.testing.allocator.free(convert_position_payload);
    const convert_position = try portfolio.parseConvertPosition(std.testing.allocator, convert_position_payload);
    defer convert_position.deinit();
    try std.testing.expectEqualStrings("success", convert_position.value.status);
    try std.testing.expect(convert_position.value.data);
}

test "kiteconnect-mocks market fixtures parse cleanly" {
    const quote_payload = try readMockFixture(std.testing.allocator, "quote.json");
    defer std.testing.allocator.free(quote_payload);
    const quote = try market.parseQuote(std.testing.allocator, quote_payload);
    defer quote.deinit();
    try std.testing.expect(quote.value.data.map.count() > 0);

    const ltp_payload = try readMockFixture(std.testing.allocator, "ltp.json");
    defer std.testing.allocator.free(ltp_payload);
    const ltp = try market.parseLtp(std.testing.allocator, ltp_payload);
    defer ltp.deinit();
    try std.testing.expect(ltp.value.data.map.count() > 0);

    const ohlc_payload = try readMockFixture(std.testing.allocator, "ohlc.json");
    defer std.testing.allocator.free(ohlc_payload);
    const ohlc = try market.parseOhlc(std.testing.allocator, ohlc_payload);
    defer ohlc.deinit();
    try std.testing.expect(ohlc.value.data.map.count() > 0);

    const historical_payload = try readMockFixture(std.testing.allocator, "historical_minute.json");
    defer std.testing.allocator.free(historical_payload);
    const historical = try market.parseHistoricalData(std.testing.allocator, historical_payload);
    defer historical.deinit(std.testing.allocator);
    try std.testing.expect(historical.candles.len > 0);

    const instruments_payload = try readMockFixture(std.testing.allocator, "instruments_all.csv");
    defer std.testing.allocator.free(instruments_payload);
    const instruments = try market.parseInstrumentsCsv(std.testing.allocator, instruments_payload);
    defer instruments.deinit(std.testing.allocator);
    try std.testing.expect(instruments.instruments.len > 0);

    const mf_instruments_payload = try readMockFixture(std.testing.allocator, "mf_instruments.csv");
    defer std.testing.allocator.free(mf_instruments_payload);
    const mf_instruments = try market.parseMfInstrumentsCsv(std.testing.allocator, mf_instruments_payload);
    defer mf_instruments.deinit(std.testing.allocator);
    try std.testing.expect(mf_instruments.instruments.len > 0);
}

test "kiteconnect-mocks gtt alerts and mutual-funds fixtures parse cleanly" {
    const triggers_payload = try readMockFixture(std.testing.allocator, "gtt_get_orders.json");
    defer std.testing.allocator.free(triggers_payload);
    const triggers = try gtt.parseTriggers(std.testing.allocator, triggers_payload);
    defer triggers.deinit();
    try std.testing.expect(triggers.value.data.len > 0);
    try std.testing.expect(triggers.value.data[0].meta != null);

    const trigger_payload = try readMockFixture(std.testing.allocator, "gtt_get_order.json");
    defer std.testing.allocator.free(trigger_payload);
    const trigger = try gtt.parseTrigger(std.testing.allocator, trigger_payload);
    defer trigger.deinit();
    try std.testing.expect(trigger.value.data.id > 0);
    try std.testing.expect(trigger.value.data.meta == null);

    const trigger_place_payload = try readMockFixture(std.testing.allocator, "gtt_place_order.json");
    defer std.testing.allocator.free(trigger_place_payload);
    const trigger_place = try gtt.parseTriggerMutation(std.testing.allocator, trigger_place_payload);
    defer trigger_place.deinit();
    try std.testing.expect(trigger_place.value.data.trigger_id > 0);

    const alerts_payload = try readMockFixture(std.testing.allocator, "alerts_get.json");
    defer std.testing.allocator.free(alerts_payload);
    const alert_list = try alerts.parseAlerts(std.testing.allocator, alerts_payload);
    defer alert_list.deinit();
    try std.testing.expect(alert_list.value.data.len > 0);

    const alert_payload = try readMockFixture(std.testing.allocator, "alerts_get_one.json");
    defer std.testing.allocator.free(alert_payload);
    const alert = try alerts.parseAlert(std.testing.allocator, alert_payload);
    defer alert.deinit();
    try std.testing.expect(alert.value.data.uuid != null or alert.value.data.alert_id != null);

    const alert_mutation_payload = try readMockFixture(std.testing.allocator, "alerts_create.json");
    defer std.testing.allocator.free(alert_mutation_payload);
    const alert_mutation = try alerts.parseAlertMutation(std.testing.allocator, alert_mutation_payload);
    defer alert_mutation.deinit();
    try std.testing.expect(alert_mutation.value.data != null);
    try std.testing.expect(alert_mutation.value.data.?.uuid != null or alert_mutation.value.data.?.alert_id != null);

    const alert_history_payload = try readMockFixture(std.testing.allocator, "alerts_history.json");
    defer std.testing.allocator.free(alert_history_payload);
    const alert_history = try alerts.parseAlertHistory(std.testing.allocator, alert_history_payload);
    defer alert_history.deinit();
    try std.testing.expect(alert_history.value.data.len > 0);
    try std.testing.expect(alert_history.value.data[0].meta != null);
    try std.testing.expectEqual(@as(i64, 270857), alert_history.value.data[0].meta.?[0].instrument_token.?);

    const mf_orders_payload = try readMockFixture(std.testing.allocator, "mf_orders.json");
    defer std.testing.allocator.free(mf_orders_payload);
    const mf_orders = try mutual_funds.parseOrders(std.testing.allocator, mf_orders_payload);
    defer mf_orders.deinit();
    try std.testing.expect(mf_orders.value.data.len > 0);
    try std.testing.expectEqualStrings("FRESH", mf_orders.value.data[0].purchase_type.?);
    try std.testing.expectEqualStrings("HDFC Balanced Advantage Fund - Direct Plan", mf_orders.value.data[0].fund.?);
    try std.testing.expectEqualStrings("AMC SIP: Insufficient balance.", mf_orders.value.data[0].status_message.?);

    const mf_order_payload = try readMockFixture(std.testing.allocator, "mf_orders_info.json");
    defer std.testing.allocator.free(mf_order_payload);
    const mf_order = try mutual_funds.parseOrder(std.testing.allocator, mf_order_payload);
    defer mf_order.deinit();
    try std.testing.expect(mf_order.value.data.order_id.len > 0);
    try std.testing.expectEqualStrings("regular", mf_order.value.data.variety.?);
    try std.testing.expectEqualStrings("Insufficient fund. 1/5", mf_order.value.data.status_message.?);

    const mf_order_mutation_payload = try readMockFixture(std.testing.allocator, "mf_order_response.json");
    defer std.testing.allocator.free(mf_order_mutation_payload);
    const mf_order_mutation = try mutual_funds.parseOrderMutation(std.testing.allocator, mf_order_mutation_payload);
    defer mf_order_mutation.deinit();
    try std.testing.expect(mf_order_mutation.value.data.order_id.len > 0);

    const mf_sips_payload = try readMockFixture(std.testing.allocator, "mf_sips.json");
    defer std.testing.allocator.free(mf_sips_payload);
    const mf_sips = try mutual_funds.parseSips(std.testing.allocator, mf_sips_payload);
    defer mf_sips.deinit();
    try std.testing.expect(mf_sips.value.data.len > 0);
    try std.testing.expectEqual(@as(i64, -1), mf_sips.value.data[0].instalments.?);
    try std.testing.expect(mf_sips.value.data[0].step_up != null);
    try std.testing.expectEqual(@as(?i64, 10), mf_sips.value.data[0].step_up.?.map.get("05-05"));
    try std.testing.expectEqualStrings("15158182", mf_sips.value.data[2].sip_reg_num.?);

    const mf_sip_payload = try readMockFixture(std.testing.allocator, "mf_sip_info.json");
    defer std.testing.allocator.free(mf_sip_payload);
    const mf_sip = try mutual_funds.parseSip(std.testing.allocator, mf_sip_payload);
    defer mf_sip.deinit();
    try std.testing.expect(mf_sip.value.data.sip_id.len > 0);
    try std.testing.expectEqualStrings("pool", mf_sip.value.data.fund_source.?);
    try std.testing.expectEqual(@as(i64, -1), mf_sip.value.data.pending_instalments.?);
    try std.testing.expectEqual(@as(?i64, 10), mf_sip.value.data.step_up.?.map.get("15-02"));

    const mf_sip_mutation_payload = try readMockFixture(std.testing.allocator, "mf_sip_place.json");
    defer std.testing.allocator.free(mf_sip_mutation_payload);
    const mf_sip_mutation = try mutual_funds.parseSipMutation(std.testing.allocator, mf_sip_mutation_payload);
    defer mf_sip_mutation.deinit();
    try std.testing.expect(mf_sip_mutation.value.data.sip_id.len > 0);

    const mf_holdings_payload = try readMockFixture(std.testing.allocator, "mf_holdings.json");
    defer std.testing.allocator.free(mf_holdings_payload);
    const mf_holdings = try mutual_funds.parseHoldings(std.testing.allocator, mf_holdings_payload);
    defer mf_holdings.deinit();
    try std.testing.expect(mf_holdings.value.data.len > 0);
    try std.testing.expectEqualStrings("INVESCO INDIA TAX PLAN - DIRECT PLAN", mf_holdings.value.data[0].fund.?);
    try std.testing.expectEqual(@as(f64, 0), mf_holdings.value.data[0].pledged_quantity.?);

    const mf_holding_info_payload =
        \\{"status":"success","data":[{"fund":"INVESCO INDIA TAX PLAN - DIRECT PLAN","tradingsymbol":"INF205K01NT8","average_price":78.43,"variety":"regular","exchange_timestamp":"2021-02-15 10:00:00","amount":30000,"folio":"3108290884","quantity":382.488}]}
    ;
    const mf_holding_info = try mutual_funds.parseHoldingInfo(std.testing.allocator, mf_holding_info_payload);
    defer mf_holding_info.deinit();
    try std.testing.expectEqual(@as(usize, 1), mf_holding_info.value.data.len);
    try std.testing.expectEqualStrings("regular", mf_holding_info.value.data[0].variety.?);
    try std.testing.expectEqualStrings("3108290884", mf_holding_info.value.data[0].folio.?);
}
