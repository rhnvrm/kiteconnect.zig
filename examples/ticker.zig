const std = @import("std");
const kite = @import("kiteconnect");

const AppConfig = struct {
    api_key: []const u8,
    access_token: []const u8,
    root_url: []const u8,
    tokens: []u32,
    initial_mode: kite.ticker_session.Mode,

    fn deinit(self: AppConfig, allocator: std.mem.Allocator) void {
        allocator.free(self.api_key);
        allocator.free(self.access_token);
        allocator.free(self.root_url);
        allocator.free(self.tokens);
    }
};

const CallbackState = struct {
    allocator: std.mem.Allocator,
    session: *kite.ticker_session.Session,
    connection: ?kite.ticker_session.Connection = null,
    tokens: []const u32,

    tick_count: usize = 0,
    switched_to_quote: bool = false,
    unsubscribed: bool = false,
    callback_error: ?anyerror = null,

    fn onConnect(ctx: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        std.debug.print("connected; subscribed instruments={d}\n", .{self.tokens.len});
    }

    fn onDisconnect(ctx: *anyopaque) void {
        _ = ctx;
        std.debug.print("disconnected\n", .{});
    }

    fn onTick(ctx: *anyopaque, tick: kite.ticker_session.Tick) void {
        const self: *@This() = @ptrCast(@alignCast(ctx));
        self.tick_count += 1;
        std.debug.print(
            "tick #{d}: token={d} mode={s} ltp={d:.2}\n",
            .{ self.tick_count, tick.instrument_token, tick.mode.asString(), tick.last_price },
        );

        const conn = self.connection orelse return;

        // Demonstrate live mode-switch once we have seen a few ticks.
        if (!self.switched_to_quote and self.tick_count >= 5) {
            self.session.setMode(conn, .quote, self.tokens) catch |err| {
                self.callback_error = err;
                std.debug.print("setMode(.quote) failed: {s}\n", .{@errorName(err)});
                return;
            };
            self.switched_to_quote = true;
            std.debug.print("switched mode to QUOTE for {d} token(s)\n", .{self.tokens.len});
        }

        // Demonstrate unsubscribe after some traffic, then exit naturally.
        if (!self.unsubscribed and self.tick_count >= 12) {
            self.session.unsubscribe(conn, self.tokens) catch |err| {
                self.callback_error = err;
                std.debug.print("unsubscribe failed: {s}\n", .{@errorName(err)});
                return;
            };
            self.unsubscribed = true;
            std.debug.print("unsubscribed all configured tokens\n", .{});
        }
    }

    fn onOrderUpdate(ctx: *anyopaque, order: kite.order_models.Order) void {
        _ = ctx;
        std.debug.print("order update: id={s} status={s}\n", .{ order.order_id, order.status });
    }

    fn onErrorMessage(ctx: *anyopaque, message: []const u8) void {
        _ = ctx;
        std.debug.print("ticker error frame: {s}\n", .{message});
    }

    fn onBrokerMessage(ctx: *anyopaque, message: []const u8) void {
        _ = ctx;
        std.debug.print("broker message: {s}\n", .{message});
    }

    fn onTextMessage(ctx: *anyopaque, payload: []const u8) void {
        _ = ctx;
        std.debug.print("text frame ({d} bytes)\n", .{payload.len});
    }

    fn onRuntimeError(ctx: *anyopaque, err: anyerror) void {
        _ = ctx;
        std.debug.print("runtime error: {s}\n", .{@errorName(err)});
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        if (leaked != .ok) std.debug.print("warning: leaked allocations detected\n", .{});
    }
    const allocator = gpa.allocator();

    const config = try loadConfig(allocator);
    defer config.deinit(allocator);

    var session = kite.ticker_session.Session.init(allocator, .{
        .root_url = config.root_url,
        .api_key = config.api_key,
        .access_token = config.access_token,
        .auto_reconnect = false,
    });
    defer session.deinit();

    var ws_transport = kite.ticker_websocket.WebSocketClientTransport{
        .allocator = allocator,
    };

    const url = try session.connectUrl();
    defer allocator.free(url);

    var connection = try ws_transport.transport().connect(allocator, url);
    defer connection.close();

    var state = CallbackState{
        .allocator = allocator,
        .session = &session,
        .tokens = config.tokens,
        .connection = connection,
    };

    const handler = kite.ticker_session.EventHandler{
        .context = &state,
        .onConnect = CallbackState.onConnect,
        .onDisconnect = CallbackState.onDisconnect,
        .onTick = CallbackState.onTick,
        .onOrderUpdate = CallbackState.onOrderUpdate,
        .onErrorMessage = CallbackState.onErrorMessage,
        .onBrokerMessage = CallbackState.onBrokerMessage,
        .onTextMessage = CallbackState.onTextMessage,
        .onRuntimeError = CallbackState.onRuntimeError,
    };

    if (handler.onConnect) |cb| cb(handler.context);

    try session.subscribe(connection, config.tokens);
    try session.setMode(connection, config.initial_mode, config.tokens);

    while (true) {
        const frame = connection.readFrame(allocator) catch |err| {
            if (err == error.WouldBlock) {
                std.Thread.sleep(10 * std.time.ns_per_ms);
                continue;
            }
            if (handler.onRuntimeError) |cb| cb(handler.context, err);
            break;
        };
        defer frame.deinit(allocator);

        const action = session.processFrame(frame, handler) catch |err| {
            if (handler.onRuntimeError) |cb| cb(handler.context, err);
            continue;
        };

        if (state.callback_error) |err| return err;

        switch (action) {
            .continue_reading => {},
            .closed => break,
            .reconnect => break,
        }
    }

    if (handler.onDisconnect) |cb| cb(handler.context);
}

fn loadConfig(allocator: std.mem.Allocator) !AppConfig {
    const api_key = try std.process.getEnvVarOwned(allocator, "KITE_API_KEY");
    errdefer allocator.free(api_key);

    const access_token = try std.process.getEnvVarOwned(allocator, "KITE_ACCESS_TOKEN");
    errdefer allocator.free(access_token);

    const root_url = std.process.getEnvVarOwned(allocator, "KITE_TICKER_ROOT_URL") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try allocator.dupe(u8, "wss://ws.kite.trade"),
        else => return err,
    };
    errdefer allocator.free(root_url);

    const tokens_csv = std.process.getEnvVarOwned(allocator, "KITE_TICKER_TOKENS") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try allocator.dupe(u8, "256265,408065"),
        else => return err,
    };
    defer allocator.free(tokens_csv);

    const mode_raw = std.process.getEnvVarOwned(allocator, "KITE_TICKER_MODE") catch |err| switch (err) {
        error.EnvironmentVariableNotFound => try allocator.dupe(u8, "full"),
        else => return err,
    };
    defer allocator.free(mode_raw);

    const tokens = try parseTokensCsv(allocator, tokens_csv);
    errdefer allocator.free(tokens);

    const initial_mode = try parseMode(mode_raw);

    return .{
        .api_key = api_key,
        .access_token = access_token,
        .root_url = root_url,
        .tokens = tokens,
        .initial_mode = initial_mode,
    };
}

fn parseTokensCsv(allocator: std.mem.Allocator, csv: []const u8) ![]u32 {
    var list = std.ArrayList(u32).empty;
    defer list.deinit(allocator);

    var it = std.mem.tokenizeScalar(u8, csv, ',');
    while (it.next()) |token_raw| {
        const trimmed = std.mem.trim(u8, token_raw, " \t\n\r");
        if (trimmed.len == 0) continue;
        try list.append(allocator, try std.fmt.parseInt(u32, trimmed, 10));
    }

    if (list.items.len == 0) return error.EmptyTokenList;
    return list.toOwnedSlice(allocator);
}

fn parseMode(raw: []const u8) !kite.ticker_session.Mode {
    if (std.ascii.eqlIgnoreCase(raw, "ltp")) return .ltp;
    if (std.ascii.eqlIgnoreCase(raw, "quote")) return .quote;
    if (std.ascii.eqlIgnoreCase(raw, "full")) return .full;
    return error.InvalidMode;
}
