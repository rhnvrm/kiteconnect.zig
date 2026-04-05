const std = @import("std");
const kite = @import("kiteconnect");

const RuntimeConfig = struct {
    run_live: bool,
    api_key: ?[]u8,
    access_token: ?[]u8,
    root_url: ?[]u8,
    order_id: ?[]u8,
    alert_uuid: ?[]u8,
    mf_isin: ?[]u8,
    mf_tradingsymbol: ?[]u8,
    gtt_status: ?[]u8,

    fn deinit(self: RuntimeConfig, allocator: std.mem.Allocator) void {
        freeOpt(allocator, self.api_key);
        freeOpt(allocator, self.access_token);
        freeOpt(allocator, self.root_url);
        freeOpt(allocator, self.order_id);
        freeOpt(allocator, self.alert_uuid);
        freeOpt(allocator, self.mf_isin);
        freeOpt(allocator, self.mf_tradingsymbol);
        freeOpt(allocator, self.gtt_status);
    }
};

pub fn main() !void {
    var gpa: std.heap.GeneralPurposeAllocator(.{}) = .init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var config = try loadConfig(allocator);
    defer config.deinit(allocator);

    std.debug.print(
        \\kiteconnect.zig advanced REST showcase
        \\====================================
        \\
    , .{});

    printEnvironmentGuide();
    try demonstrateOfflineBuilders(allocator);

    if (!config.run_live) {
        std.debug.print(
            \\\nSkipping live API calls (KITE_RUN_LIVE != 1).
            \\Set KITE_RUN_LIVE=1 along with KITE_API_KEY and KITE_ACCESS_TOKEN
            \\to run live read-only endpoint demonstrations.
            \\
        , .{});
        return;
    }

    const api_key = config.api_key orelse return error.MissingApiKey;
    const access_token = config.access_token orelse return error.MissingAccessToken;

    var client = kite.Client.init(.{
        .allocator = allocator,
        .api_key = api_key,
        .access_token = access_token,
        .root_url = config.root_url orelse "https://api.kite.trade",
    });
    defer client.deinit();

    var runtime_client: std.http.Client = .{ .allocator = allocator };
    defer runtime_client.deinit();

    std.debug.print("\nRunning live read-only endpoint groups...\n", .{});
    try runPortfolioExamples(client, &runtime_client);
    try runOrdersExamples(allocator, client, &runtime_client, config.order_id);
    try runGttExamples(allocator, client, &runtime_client, config.gtt_status);
    try runAlertsExamples(allocator, client, &runtime_client, config.alert_uuid);
    try runMutualFundsExamples(allocator, client, &runtime_client, config.mf_isin, config.mf_tradingsymbol);
}

fn loadConfig(allocator: std.mem.Allocator) !RuntimeConfig {
    const run_live = if (try envOwned(allocator, "KITE_RUN_LIVE")) |value|
        std.mem.eql(u8, value, "1")
    else
        false;

    return .{
        .run_live = run_live,
        .api_key = try envOwned(allocator, "KITE_API_KEY"),
        .access_token = try envOwned(allocator, "KITE_ACCESS_TOKEN"),
        .root_url = try envOwned(allocator, "KITE_ROOT_URL"),
        .order_id = try envOwned(allocator, "KITE_ORDER_ID"),
        .alert_uuid = try envOwned(allocator, "KITE_ALERT_UUID"),
        .mf_isin = try envOwned(allocator, "KITE_MF_ISIN"),
        .mf_tradingsymbol = try envOwned(allocator, "KITE_MF_TRADINGSYMBOL"),
        .gtt_status = try envOwned(allocator, "KITE_GTT_STATUS"),
    };
}

fn demonstrateOfflineBuilders(allocator: std.mem.Allocator) !void {
    std.debug.print("Builder showcase (safe to run without credentials):\n", .{});

    const gtt_form = try kite.gtt.buildTriggerForm(allocator, .{
        .type = "single",
        .condition_json = "{\"exchange\":\"NSE\",\"tradingsymbol\":\"INFY\",\"trigger_values\":[1510.0],\"last_price\":1508.0}",
        .orders_json = "[{\"exchange\":\"NSE\",\"tradingsymbol\":\"INFY\",\"transaction_type\":\"SELL\",\"quantity\":1,\"order_type\":\"LIMIT\",\"product\":\"CNC\",\"price\":1509.5}]",
    });
    defer allocator.free(gtt_form);
    std.debug.print("  • gtt.buildTriggerForm -> {s}\n", .{gtt_form});

    const alert_form = try kite.alerts.buildAlertForm(allocator, .{
        .name = "INFY breakout",
        .lhs_exchange = "NSE",
        .lhs_tradingsymbol = "INFY",
        .lhs_attribute = "last_price",
        .operator = ">",
        .rhs_type = "constant",
        .rhs_constant = 1520.0,
    });
    defer allocator.free(alert_form);
    std.debug.print("  • alerts.buildAlertForm -> {s}\n", .{alert_form});

    const mf_order_form = try kite.mutual_funds.buildOrderForm(allocator, .{
        .tradingsymbol = "INF090I01239",
        .transaction_type = "BUY",
        .amount = 5000,
        .tag = "long-term",
    });
    defer allocator.free(mf_order_form);
    std.debug.print("  • mutual_funds.buildOrderForm -> {s}\n", .{mf_order_form});

    const holdings_auth_form = try kite.portfolio.buildHoldingsAuthForm(allocator, .{
        .auth_type = kite.portfolio.HoldingsAuth.type_equity,
        .transfer_type = kite.portfolio.HoldingsAuth.transfer_type_off_market,
        .exec_date = "2026-04-06",
        .instruments = &.{
            .{ .isin = "INE009A01021", .quantity = 2 },
        },
    });
    defer allocator.free(holdings_auth_form);
    std.debug.print("  • portfolio.buildHoldingsAuthForm -> {s}\n", .{holdings_auth_form});
}

fn runPortfolioExamples(client: kite.Client, runtime_client: *std.http.Client) !void {
    std.debug.print("\n[portfolio]\n", .{});

    const holdings_result = kite.portfolio.executeHoldings(client, runtime_client) catch |err| {
        std.debug.print("  ! holdings failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer holdings_result.deinit(client.allocator);

    switch (holdings_result) {
        .success => |success| std.debug.print("  holdings count: {d}\n", .{success.parsed.value.data.len}),
        .api_error => |api_err| std.debug.print("  holdings api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }

    const compact_result = kite.portfolio.executeHoldingsCompact(client, runtime_client) catch |err| {
        std.debug.print("  ! holdings compact failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer compact_result.deinit(client.allocator);

    switch (compact_result) {
        .success => |success| std.debug.print("  holdings compact count: {d}\n", .{success.parsed.value.data.len}),
        .api_error => |api_err| std.debug.print("  holdings compact api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }
}

fn runOrdersExamples(
    allocator: std.mem.Allocator,
    client: kite.Client,
    runtime_client: *std.http.Client,
    order_id: ?[]const u8,
) !void {
    std.debug.print("\n[orders + trades]\n", .{});

    const orders_result = kite.orders.executeOrders(client, runtime_client) catch |err| {
        std.debug.print("  ! orders failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer orders_result.deinit(client.allocator);

    switch (orders_result) {
        .success => |success| std.debug.print("  orders count: {d}\n", .{success.parsed.value.data.len}),
        .api_error => |api_err| std.debug.print("  orders api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }

    const trades_result = kite.orders.executeTrades(client, runtime_client) catch |err| {
        std.debug.print("  ! trades failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer trades_result.deinit(client.allocator);

    switch (trades_result) {
        .success => |success| std.debug.print("  trades count: {d}\n", .{success.parsed.value.data.len}),
        .api_error => |api_err| std.debug.print("  trades api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }

    if (order_id) |id| {
        const path = try kite.orders.orderHistoryPath(allocator, id);
        defer allocator.free(path);

        const history_result = kite.orders.executeOrderHistory(client, runtime_client, path) catch |err| {
            std.debug.print("  ! order history failed: {s}\n", .{@errorName(err)});
            return;
        };
        defer history_result.deinit(client.allocator);

        switch (history_result) {
            .success => |success| std.debug.print("  order history entries for {s}: {d}\n", .{ id, success.parsed.value.data.len }),
            .api_error => |api_err| std.debug.print("  order history api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
        }
    } else {
        std.debug.print("  (set KITE_ORDER_ID for order history/order trades lookup)\n", .{});
    }
}

fn runGttExamples(
    allocator: std.mem.Allocator,
    client: kite.Client,
    runtime_client: *std.http.Client,
    gtt_status: ?[]const u8,
) !void {
    std.debug.print("\n[gtt]\n", .{});

    const query = try kite.gtt.buildListTriggersQuery(allocator, .{
        .status = gtt_status orelse "active",
        .page = 1,
        .count = 20,
    });
    defer allocator.free(query);

    const triggers_result = kite.gtt.executeListTriggers(client, runtime_client, query) catch |err| {
        std.debug.print("  ! gtt list failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer triggers_result.deinit(client.allocator);

    switch (triggers_result) {
        .success => |success| std.debug.print("  triggers returned: {d} (query: {s})\n", .{ success.parsed.value.data.len, query }),
        .api_error => |api_err| std.debug.print("  gtt api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }
}

fn runAlertsExamples(
    allocator: std.mem.Allocator,
    client: kite.Client,
    runtime_client: *std.http.Client,
    alert_uuid: ?[]const u8,
) !void {
    std.debug.print("\n[alerts]\n", .{});

    const alerts_result = kite.alerts.executeListAlerts(client, runtime_client) catch |err| {
        std.debug.print("  ! alerts list failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer alerts_result.deinit(client.allocator);

    switch (alerts_result) {
        .success => |success| std.debug.print("  alerts count: {d}\n", .{success.parsed.value.data.len}),
        .api_error => |api_err| std.debug.print("  alerts api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }

    if (alert_uuid) |uuid| {
        const history_path = try kite.alerts.alertHistoryPath(allocator, uuid);
        defer allocator.free(history_path);

        const history_result = kite.alerts.executeAlertHistory(client, runtime_client, history_path) catch |err| {
            std.debug.print("  ! alert history failed: {s}\n", .{@errorName(err)});
            return;
        };
        defer history_result.deinit(client.allocator);

        switch (history_result) {
            .success => |success| std.debug.print("  history entries for alert {s}: {d}\n", .{ uuid, success.parsed.value.data.len }),
            .api_error => |api_err| std.debug.print("  alert history api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
        }
    } else {
        std.debug.print("  (set KITE_ALERT_UUID for alert history lookup)\n", .{});
    }
}

fn runMutualFundsExamples(
    allocator: std.mem.Allocator,
    client: kite.Client,
    runtime_client: *std.http.Client,
    mf_isin: ?[]const u8,
    mf_tradingsymbol: ?[]const u8,
) !void {
    std.debug.print("\n[mutual_funds]\n", .{});

    const holdings_result = kite.mutual_funds.executeHoldings(client, runtime_client) catch |err| {
        std.debug.print("  ! mf holdings failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer holdings_result.deinit(client.allocator);

    switch (holdings_result) {
        .success => |success| std.debug.print("  mf holdings count: {d}\n", .{success.parsed.value.data.len}),
        .api_error => |api_err| std.debug.print("  mf holdings api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }

    const allotments_result = kite.mutual_funds.executeAllotments(client, runtime_client) catch |err| {
        std.debug.print("  ! mf allotments failed: {s}\n", .{@errorName(err)});
        return;
    };
    defer allotments_result.deinit(client.allocator);

    switch (allotments_result) {
        .success => |success| std.debug.print("  mf allotments entries: {d}\n", .{success.parsed.value.data.len}),
        .api_error => |api_err| std.debug.print("  mf allotments api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
    }

    if (mf_isin) |isin| {
        const path = try kite.mutual_funds.holdingInfoPath(allocator, isin);
        defer allocator.free(path);

        const info_result = kite.mutual_funds.executeHoldingInfo(client, runtime_client, path) catch |err| {
            std.debug.print("  ! mf holding info failed: {s}\n", .{@errorName(err)});
            return;
        };
        defer info_result.deinit(client.allocator);

        switch (info_result) {
            .success => |success| std.debug.print("  mf holding breakdown rows for {s}: {d}\n", .{ isin, success.parsed.value.data.len }),
            .api_error => |api_err| std.debug.print("  mf holding info api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
        }
    } else {
        std.debug.print("  (set KITE_MF_ISIN for mf holding breakdown lookup)\n", .{});
    }

    if (mf_tradingsymbol) |symbol| {
        const path = try kite.mutual_funds.instrumentInfoPath(allocator, symbol);
        defer allocator.free(path);

        const instrument_result = kite.mutual_funds.executeInstrumentInfo(client, runtime_client, path) catch |err| {
            std.debug.print("  ! mf instrument info failed: {s}\n", .{@errorName(err)});
            return;
        };
        defer instrument_result.deinit(client.allocator);

        switch (instrument_result) {
            .success => |success| std.debug.print("  mf instrument info for {s}: purchase_allowed={any} last_price={any}\n", .{ symbol, success.parsed.value.data.purchase_allowed, success.parsed.value.data.last_price }),
            .api_error => |api_err| std.debug.print("  mf instrument info api error [{?d}]: {s}\n", .{ api_err.status, api_err.message }),
        }
    } else {
        std.debug.print("  (set KITE_MF_TRADINGSYMBOL for mf instrument info lookup)\n", .{});
    }
}

fn printEnvironmentGuide() void {
    std.debug.print(
        \\Environment variables used by this example:
        \\  KITE_RUN_LIVE=1              -> run live endpoint calls
        \\  KITE_API_KEY                 -> required when live mode is on
        \\  KITE_ACCESS_TOKEN            -> required when live mode is on
        \\  KITE_ROOT_URL                -> optional API root override
        \\  KITE_ORDER_ID                -> optional order history/trades demo
        \\  KITE_ALERT_UUID              -> optional alert history demo
        \\  KITE_GTT_STATUS              -> optional GTT status filter (default: active)
        \\  KITE_MF_ISIN                 -> optional MF holding breakdown demo
        \\  KITE_MF_TRADINGSYMBOL        -> optional MF instrument info demo
        \\
    , .{});
}

fn envOwned(allocator: std.mem.Allocator, key: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, key) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => err,
    };
}

fn freeOpt(allocator: std.mem.Allocator, value: ?[]u8) void {
    if (value) |slice| allocator.free(slice);
}
