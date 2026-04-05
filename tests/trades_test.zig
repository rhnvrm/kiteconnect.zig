const std = @import("std");
const lib = @import("kiteconnect");
const orders = lib.orders;

test "trades endpoint request contracts" {
    const list = orders.tradesRequestOptions();
    try std.testing.expect(list.requires_auth);
    try std.testing.expectEqualStrings("/trades", list.path);

    const order_trades_path = try orders.orderTradesPath(std.testing.allocator, "220101000000001");
    defer std.testing.allocator.free(order_trades_path);
    try std.testing.expectEqualStrings("/orders/220101000000001/trades", order_trades_path);

    try std.testing.expectError(error.EmptyOrderId, orders.orderTradesPath(std.testing.allocator, ""));
}

test "trades endpoint parses list and order-trades payloads" {
    const list_payload =
        \\{"status":"success","data":[{"trade_id":"10000001","order_id":"220101000000001","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":1,"average_price":1498.5,"fill_timestamp":"2024-01-02 09:16:03"},{"trade_id":"10000002","order_id":"220101000000002","exchange":"NSE","tradingsymbol":"TCS","transaction_type":"SELL","quantity":3,"average_price":3500.0,"fill_timestamp":"2024-01-02 09:20:14"}]}
    ;

    const list = try orders.parseTrades(std.testing.allocator, list_payload);
    defer list.deinit();

    try std.testing.expectEqual(@as(usize, 2), list.value.data.len);
    try std.testing.expectEqualStrings("10000002", list.value.data[1].trade_id);

    const order_payload =
        \\{"status":"success","data":[{"trade_id":"10000001","order_id":"220101000000001","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":1,"average_price":1498.5,"fill_timestamp":"2024-01-02 09:16:03"}]}
    ;

    const order_trades = try orders.parseOrderTrades(std.testing.allocator, order_payload);
    defer order_trades.deinit();

    try std.testing.expectEqual(@as(usize, 1), order_trades.value.data.len);
    try std.testing.expectEqualStrings("220101000000001", order_trades.value.data[0].order_id);
}
