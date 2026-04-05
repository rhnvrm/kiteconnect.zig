const std = @import("std");
const lib = @import("kiteconnect");
const margins_endpoint = lib.margins;

test "margins endpoint request options match Kite paths" {
    const order_margins = margins_endpoint.orderMarginsRequestOptions();
    try std.testing.expectEqual(.post, order_margins.method);
    try std.testing.expectEqualStrings("/margins/orders", order_margins.path);
    try std.testing.expect(order_margins.requires_auth);

    const basket_margins = margins_endpoint.basketMarginsRequestOptions();
    try std.testing.expectEqual(.post, basket_margins.method);
    try std.testing.expectEqualStrings("/margins/basket", basket_margins.path);
    try std.testing.expect(basket_margins.requires_auth);

    const order_charges = margins_endpoint.orderChargesRequestOptions();
    try std.testing.expectEqual(.post, order_charges.method);
    try std.testing.expectEqualStrings("/charges/orders", order_charges.path);
    try std.testing.expect(order_charges.requires_auth);
}

test "parseOrderMargins decodes order margin rows" {
    const payload =
        \\{"status":"success","data":[{"type":"equity","tradingsymbol":"INFY","exchange":"NSE","span":1200.5,"exposure":300.25,"option_premium":0,"additional":100,"bo":0,"cash":0,"var":1498,"pnl":{"realised":25.5,"unrealised":-5.25},"leverage":1,"charges":{"transaction_tax":1.498,"transaction_tax_type":"stt","exchange_turnover_charge":0.051681,"sebi_turnover_charge":0.001498,"brokerage":0.01,"stamp_duty":0.22,"gst":{"igst":0.01137222,"cgst":0,"sgst":0,"total":0.01137222},"total":1.79255122},"total":1600.75},{"type":"commodity","tradingsymbol":"GOLDM","exchange":"MCX","span":7000,"exposure":1200,"option_premium":0,"additional":0,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":1,"charges":{"transaction_tax":0.5,"transaction_tax_type":"ctt","exchange_turnover_charge":0.1,"sebi_turnover_charge":0.01,"brokerage":1,"stamp_duty":0,"gst":{"igst":0.2,"cgst":0,"sgst":0,"total":0.2},"total":1.81},"total":8200}]}
    ;

    const parsed = try margins_endpoint.parseOrderMargins(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), parsed.value.data.len);
    try std.testing.expectEqualStrings("INFY", parsed.value.data[0].tradingsymbol.?);
    try std.testing.expectEqual(@as(f64, 1498), parsed.value.data[0].@"var");
    try std.testing.expectEqualStrings("stt", parsed.value.data[0].charges.transaction_tax_type.?);
    try std.testing.expectEqual(@as(f64, 8200), parsed.value.data[1].total);
}

test "parseBasketMargins decodes initial and final totals" {
    const payload =
        \\{"status":"success","data":{"initial":{"type":"","tradingsymbol":"","exchange":"","span":1500,"exposure":250,"option_premium":0,"additional":100,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":0,"charges":{"transaction_tax":0,"transaction_tax_type":"","exchange_turnover_charge":0,"sebi_turnover_charge":0,"brokerage":0,"stamp_duty":0,"gst":{"igst":0,"cgst":0,"sgst":0,"total":0},"total":0},"total":1850},"final":{"type":"","tradingsymbol":"","exchange":"","span":1200,"exposure":150,"option_premium":0,"additional":80,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":0,"charges":{"transaction_tax":0,"transaction_tax_type":"","exchange_turnover_charge":0,"sebi_turnover_charge":0,"brokerage":0,"stamp_duty":0,"gst":{"igst":0,"cgst":0,"sgst":0,"total":0},"total":0},"total":1430},"orders":[{"type":"equity","tradingsymbol":"INFY","exchange":"NSE","span":1500,"exposure":250,"option_premium":0,"additional":100,"bo":0,"cash":0,"var":0,"pnl":{"realised":0,"unrealised":0},"leverage":1,"charges":{"transaction_tax":1,"transaction_tax_type":"stt","exchange_turnover_charge":0.1,"sebi_turnover_charge":0.01,"brokerage":20,"stamp_duty":0.2,"gst":{"igst":3.6,"cgst":0,"sgst":0,"total":3.6},"total":24.91},"total":1850}],"charges":{"transaction_tax":0,"transaction_tax_type":"","exchange_turnover_charge":0,"sebi_turnover_charge":0.01,"brokerage":20,"stamp_duty":0,"gst":{"igst":0,"cgst":0,"sgst":0,"total":0},"total":20.01}}}
    ;

    const parsed = try margins_endpoint.parseBasketMargins(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(f64, 1850), parsed.value.data.initial.total);
    try std.testing.expectEqual(@as(f64, 1430), parsed.value.data.final.total);
    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.orders.len);
    try std.testing.expectEqual(@as(f64, 20), parsed.value.data.charges.brokerage);
}

test "parseOrderCharges decodes charge rows" {
    const payload =
        \\{"status":"success","data":[{"transaction_type":"BUY","tradingsymbol":"SBIN","exchange":"NSE","variety":"regular","product":"CNC","order_type":"MARKET","quantity":1,"price":560,"charges":{"transaction_tax":0.56,"transaction_tax_type":"stt","exchange_turnover_charge":0.01876,"sebi_turnover_charge":0.00056,"brokerage":0,"stamp_duty":0,"gst":{"igst":0.0033768,"cgst":0,"sgst":0,"total":0.0033768},"total":0.5826968}}]}
    ;

    const parsed = try margins_endpoint.parseOrderCharges(std.testing.allocator, payload);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 1), parsed.value.data.len);
    try std.testing.expectEqualStrings("SBIN", parsed.value.data[0].tradingsymbol.?);
    try std.testing.expectEqualStrings("stt", parsed.value.data[0].charges.transaction_tax_type.?);
    try std.testing.expectEqual(@as(f64, 0.5826968), parsed.value.data[0].charges.total);
}
