const std = @import("std");
const lib = @import("kiteconnect");
const orders = lib.orders;
const transport = lib.transport;

test "orders endpoint request contracts" {
    const list = orders.ordersRequestOptions();
    try std.testing.expectEqual(transport.Method.get, list.method);
    try std.testing.expect(list.requires_auth);
    try std.testing.expectEqualStrings("/orders", list.path);

    const place_path = try orders.placeOrderPath(std.testing.allocator, "regular");
    defer std.testing.allocator.free(place_path);
    try std.testing.expectEqualStrings("/orders/regular", place_path);

    try std.testing.expectError(error.EmptyVariety, orders.placeOrderPath(std.testing.allocator, ""));
}

test "orders endpoint parses order list, history, and mutation payloads" {
    const payload =
        \\{"status":"success","data":[{"order_id":"220101000000001","status":"COMPLETE","exchange":"NSE","tradingsymbol":"INFY","transaction_type":"BUY","quantity":1,"filled_quantity":1,"pending_quantity":0,"average_price":1489.25,"order_timestamp":"2024-01-02 09:15:01"}]}
    ;

    const parsed = try orders.parseOrders(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.len);
    try std.testing.expectEqualStrings("220101000000001", parsed.value.data[0].order_id);

    const history_payload =
        \\{"status":"success","data":[{"order_id":"220101000000001","status":"OPEN"},{"order_id":"220101000000001","status":"COMPLETE"}]}
    ;

    const history = try orders.parseOrderHistory(std.testing.allocator, history_payload);
    defer history.deinit();

    try std.testing.expectEqual(@as(usize, 2), history.value.data.len);
    try std.testing.expectEqualStrings("OPEN", history.value.data[0].status);

    const mutation_payload =
        \\{"status":"success","data":{"order_id":"220101000000001"}}
    ;

    const mutation = try orders.parseOrderMutation(std.testing.allocator, mutation_payload);
    defer mutation.deinit();

    try std.testing.expectEqualStrings("220101000000001", mutation.value.data.order_id);
}
