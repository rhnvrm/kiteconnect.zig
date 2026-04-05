//! Session/runtime helpers for the Kite ticker protocol.
//!
//! This module covers deterministic, testable pieces of the session layer:
//! URL construction, outbound command encoding, reconnect backoff policy,
//! subscription-state snapshots, and a transport-agnostic runtime loop that can
//! drive binary/text frame handling and resubscribe behavior.

const std = @import("std");
const order_models = @import("../models/orders.zig");
const parser = @import("parser.zig");
const ticker_models = @import("../models/ticker.zig");

pub const Mode = ticker_models.Mode;
pub const Tick = ticker_models.Tick;
pub const ParsedTextMessage = parser.ParsedTextMessage;

/// Reconnect behavior matching upstream exponential-backoff semantics.
pub const ReconnectPolicy = struct {
    max_retries: u32 = 300,
    min_delay_ms: u64 = 5_000,
    max_delay_ms: u64 = 60_000,

    pub fn delayForAttempt(self: ReconnectPolicy, attempt: u32) u64 {
        if (attempt == 0) return 0;

        var delay_ms: u64 = 1_000;
        var remaining = attempt;
        while (remaining > 0) : (remaining -= 1) {
            delay_ms = std.math.mul(u64, delay_ms, 2) catch std.math.maxInt(u64);
        }
        return @min(@max(delay_ms, self.min_delay_ms), self.max_delay_ms);
    }
};

/// Outbound command payloads supported by the Kite ticker websocket.
pub const SessionCommand = union(enum) {
    subscribe: []const u32,
    unsubscribe: []const u32,
    mode: struct {
        mode: Mode,
        tokens: []const u32,
    },
};

/// Session configuration needed to establish a ticker connection.
pub const Config = struct {
    root_url: []const u8,
    api_key: []const u8,
    access_token: []const u8,
    auto_reconnect: bool = true,
    reconnect_policy: ReconnectPolicy = .{},
};

/// Snapshot of tracked subscriptions, grouped for resubscribe replay.
pub const SubscriptionSnapshot = struct {
    subscribed: []u32,
    ltp: []u32,
    quote: []u32,
    full: []u32,

    pub fn deinit(self: SubscriptionSnapshot, allocator: std.mem.Allocator) void {
        allocator.free(self.subscribed);
        allocator.free(self.ltp);
        allocator.free(self.quote);
        allocator.free(self.full);
    }
};

/// Batch of outbound websocket text payloads.
pub const CommandBatch = struct {
    payloads: [][]u8,

    pub fn deinit(self: CommandBatch, allocator: std.mem.Allocator) void {
        for (self.payloads) |payload| allocator.free(payload);
        allocator.free(self.payloads);
    }
};

/// Mutable subscription bookkeeping used for later resubscribe replay.
pub const SubscriptionState = struct {
    allocator: std.mem.Allocator,
    tokens: std.AutoHashMap(u32, ?Mode),

    pub fn init(allocator: std.mem.Allocator) SubscriptionState {
        return .{
            .allocator = allocator,
            .tokens = std.AutoHashMap(u32, ?Mode).init(allocator),
        };
    }

    pub fn deinit(self: *SubscriptionState) void {
        self.tokens.deinit();
    }

    pub fn subscribe(self: *SubscriptionState, subscribed: []const u32) !void {
        for (subscribed) |token| {
            try self.tokens.put(token, null);
        }
    }

    pub fn unsubscribe(self: *SubscriptionState, unsubscribed: []const u32) void {
        for (unsubscribed) |token| {
            _ = self.tokens.remove(token);
        }
    }

    pub fn setMode(self: *SubscriptionState, mode: Mode, mode_tokens: []const u32) !void {
        for (mode_tokens) |token| {
            try self.tokens.put(token, mode);
        }
    }

    pub fn snapshot(self: *const SubscriptionState) !SubscriptionSnapshot {
        var subscribed = std.ArrayList(u32).empty;
        var ltp = std.ArrayList(u32).empty;
        var quote = std.ArrayList(u32).empty;
        var full = std.ArrayList(u32).empty;
        errdefer subscribed.deinit(self.allocator);
        errdefer ltp.deinit(self.allocator);
        errdefer quote.deinit(self.allocator);
        errdefer full.deinit(self.allocator);

        var iterator = self.tokens.iterator();
        while (iterator.next()) |entry| {
            try subscribed.append(self.allocator, entry.key_ptr.*);
            switch (entry.value_ptr.* orelse continue) {
                .ltp => try ltp.append(self.allocator, entry.key_ptr.*),
                .quote => try quote.append(self.allocator, entry.key_ptr.*),
                .full => try full.append(self.allocator, entry.key_ptr.*),
            }
        }

        std.mem.sort(u32, subscribed.items, {}, std.sort.asc(u32));
        std.mem.sort(u32, ltp.items, {}, std.sort.asc(u32));
        std.mem.sort(u32, quote.items, {}, std.sort.asc(u32));
        std.mem.sort(u32, full.items, {}, std.sort.asc(u32));

        return .{
            .subscribed = try subscribed.toOwnedSlice(self.allocator),
            .ltp = try ltp.toOwnedSlice(self.allocator),
            .quote = try quote.toOwnedSlice(self.allocator),
            .full = try full.toOwnedSlice(self.allocator),
        };
    }
};

/// Websocket opcode kinds consumed by the runtime loop.
pub const FrameOpcode = enum {
    text,
    binary,
    close,
    ping,
    pong,
};

/// Owned websocket frame used by the transport-agnostic runtime loop.
pub const OwnedFrame = struct {
    opcode: FrameOpcode,
    payload: []u8,

    pub fn deinit(self: OwnedFrame, allocator: std.mem.Allocator) void {
        allocator.free(self.payload);
    }
};

/// Connection-level websocket operations required by the runtime loop.
pub const Connection = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        readFrame: *const fn (context: *anyopaque, allocator: std.mem.Allocator) anyerror!OwnedFrame,
        writeText: *const fn (context: *anyopaque, payload: []const u8) anyerror!void,
        close: *const fn (context: *anyopaque) void,
    };

    pub fn readFrame(self: Connection, allocator: std.mem.Allocator) anyerror!OwnedFrame {
        return self.vtable.readFrame(self.context, allocator);
    }

    pub fn writeText(self: Connection, payload: []const u8) anyerror!void {
        return self.vtable.writeText(self.context, payload);
    }

    pub fn close(self: Connection) void {
        self.vtable.close(self.context);
    }
};

/// Transport-level connect/sleep hooks required by the runtime loop.
pub const Transport = struct {
    context: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        connect: *const fn (context: *anyopaque, allocator: std.mem.Allocator, url: []const u8) anyerror!Connection,
        sleepMs: ?*const fn (context: *anyopaque, delay_ms: u64) void = null,
    };

    pub fn connect(self: Transport, allocator: std.mem.Allocator, url: []const u8) anyerror!Connection {
        return self.vtable.connect(self.context, allocator, url);
    }

    pub fn sleepMs(self: Transport, delay_ms: u64) void {
        if (self.vtable.sleepMs) |sleep_fn| sleep_fn(self.context, delay_ms);
    }
};

/// Runtime callbacks. Borrowed slices are only valid for the callback duration.
pub const EventHandler = struct {
    context: *anyopaque,
    onConnect: ?*const fn (context: *anyopaque) void = null,
    onDisconnect: ?*const fn (context: *anyopaque) void = null,
    onReconnect: ?*const fn (context: *anyopaque, attempt: u32, delay_ms: u64) void = null,
    onNoReconnect: ?*const fn (context: *anyopaque, attempt: u32) void = null,
    onTick: ?*const fn (context: *anyopaque, tick: Tick) void = null,
    onOrderUpdate: ?*const fn (context: *anyopaque, order: order_models.Order) void = null,
    onErrorMessage: ?*const fn (context: *anyopaque, message: []const u8) void = null,
    onBrokerMessage: ?*const fn (context: *anyopaque, message: []const u8) void = null,
    onTextMessage: ?*const fn (context: *anyopaque, payload: []const u8) void = null,
    onRuntimeError: ?*const fn (context: *anyopaque, err: anyerror) void = null,
};

/// High-level ticker session state and runtime behavior.
pub const Session = struct {
    allocator: std.mem.Allocator,
    config: Config,
    subscriptions: SubscriptionState,

    pub fn init(allocator: std.mem.Allocator, config: Config) Session {
        return .{
            .allocator = allocator,
            .config = config,
            .subscriptions = SubscriptionState.init(allocator),
        };
    }

    pub fn deinit(self: *Session) void {
        self.subscriptions.deinit();
    }

    pub fn connectUrl(self: *const Session) ![]u8 {
        return buildWebSocketUrl(
            self.allocator,
            self.config.root_url,
            self.config.api_key,
            self.config.access_token,
        );
    }

    pub fn subscribe(self: *Session, connection: ?Connection, tokens: []const u32) !void {
        if (tokens.len == 0) return;
        try self.subscriptions.subscribe(tokens);
        if (connection) |conn| {
            const payload = try buildSubscribeCommand(self.allocator, tokens);
            defer self.allocator.free(payload);
            try conn.writeText(payload);
        }
    }

    pub fn unsubscribe(self: *Session, connection: ?Connection, tokens: []const u32) !void {
        if (tokens.len == 0) return;
        self.subscriptions.unsubscribe(tokens);
        if (connection) |conn| {
            const payload = try buildUnsubscribeCommand(self.allocator, tokens);
            defer self.allocator.free(payload);
            try conn.writeText(payload);
        }
    }

    pub fn setMode(self: *Session, connection: ?Connection, mode: Mode, tokens: []const u32) !void {
        if (tokens.len == 0) return;
        try self.subscriptions.setMode(mode, tokens);
        if (connection) |conn| {
            const payload = try buildSetModeCommand(self.allocator, mode, tokens);
            defer self.allocator.free(payload);
            try conn.writeText(payload);
        }
    }

    pub fn replaySubscriptions(self: *Session, connection: Connection) !void {
        const snapshot = try self.subscriptions.snapshot();
        defer snapshot.deinit(self.allocator);

        const batch = try buildResubscribeCommands(self.allocator, snapshot);
        defer batch.deinit(self.allocator);

        for (batch.payloads) |payload| {
            try connection.writeText(payload);
        }
    }

    pub fn run(self: *Session, transport: Transport, handler: EventHandler) !void {
        var reconnect_attempt: u32 = 0;

        while (true) {
            if (reconnect_attempt > 0) {
                if (!self.config.auto_reconnect) return error.ConnectionClosed;
                if (reconnect_attempt > self.config.reconnect_policy.max_retries) {
                    if (handler.onNoReconnect) |cb| cb(handler.context, reconnect_attempt);
                    return error.MaxReconnectAttemptsExceeded;
                }

                const delay_ms = self.config.reconnect_policy.delayForAttempt(reconnect_attempt);
                if (handler.onReconnect) |cb| cb(handler.context, reconnect_attempt, delay_ms);
                transport.sleepMs(delay_ms);
            }

            const url = try self.connectUrl();
            defer self.allocator.free(url);

            var connection = transport.connect(self.allocator, url) catch |err| {
                if (handler.onRuntimeError) |cb| cb(handler.context, err);
                reconnect_attempt += 1;
                continue;
            };
            defer connection.close();

            if (handler.onConnect) |cb| cb(handler.context);
            if (reconnect_attempt > 0) try self.replaySubscriptions(connection);

            const loop_result = self.runReadLoop(connection, handler) catch |err| {
                if (handler.onRuntimeError) |cb| cb(handler.context, err);
                reconnect_attempt += 1;
                continue;
            };

            if (handler.onDisconnect) |cb| cb(handler.context);

            switch (loop_result) {
                .closed => return,
                .reconnect => reconnect_attempt += 1,
            }
        }
    }

    fn runReadLoop(self: *Session, connection: Connection, handler: EventHandler) anyerror!LoopResult {
        while (true) {
            var frame = try connection.readFrame(self.allocator);
            defer frame.deinit(self.allocator);

            const action = self.processFrame(frame, handler) catch |err| {
                if (handler.onRuntimeError) |cb| cb(handler.context, err);
                continue;
            };

            switch (action) {
                .continue_reading => {},
                .closed => return .closed,
                .reconnect => return .reconnect,
            }
        }
    }

    pub fn processFrame(self: *Session, frame: OwnedFrame, handler: EventHandler) !FrameAction {
        switch (frame.opcode) {
            .binary => {
                const ticks = try parser.parseBinary(self.allocator, frame.payload);
                defer self.allocator.free(ticks);
                if (handler.onTick) |cb| {
                    for (ticks) |tick| cb(handler.context, tick);
                }
                return .continue_reading;
            },
            .text => {
                if (handler.onTextMessage) |cb| cb(handler.context, frame.payload);

                var parsed = parser.parseTextMessage(self.allocator, frame.payload) catch |err| {
                    if (err == error.OutOfMemory) return err;
                    return .continue_reading;
                };
                defer parsed.deinit();

                switch (parsed) {
                    .error_message => |message| {
                        if (handler.onErrorMessage) |cb| cb(handler.context, message.value.data);
                    },
                    .order_update => |order| {
                        if (handler.onOrderUpdate) |cb| cb(handler.context, order.value.data);
                    },
                    .broker_message => |message| {
                        if (handler.onBrokerMessage) |cb| cb(handler.context, message.value.data);
                    },
                    .other => {},
                }
                return .continue_reading;
            },
            .close => return .closed,
            .ping, .pong => return .continue_reading,
        }
    }
};

const LoopResult = enum {
    closed,
    reconnect,
};

const FrameAction = enum {
    continue_reading,
    closed,
    reconnect,
};

pub fn buildWebSocketUrl(
    allocator: std.mem.Allocator,
    root_url: []const u8,
    api_key: []const u8,
    access_token: []const u8,
) ![]u8 {
    if (root_url.len == 0) return error.EmptyRootUrl;
    if (api_key.len == 0) return error.EmptyApiKey;
    if (access_token.len == 0) return error.EmptyAccessToken;

    const separator: []const u8 = if (std.mem.indexOfScalar(u8, root_url, '?') == null) "?" else "&";
    return std.fmt.allocPrint(
        allocator,
        "{s}{s}api_key={s}&access_token={s}",
        .{ root_url, separator, api_key, access_token },
    );
}

pub fn buildSubscribeCommand(allocator: std.mem.Allocator, tokens: []const u32) ![]u8 {
    if (tokens.len == 0) return allocator.dupe(u8, "");
    return buildCommand(allocator, .{ .subscribe = tokens });
}

pub fn buildUnsubscribeCommand(allocator: std.mem.Allocator, tokens: []const u32) ![]u8 {
    if (tokens.len == 0) return allocator.dupe(u8, "");
    return buildCommand(allocator, .{ .unsubscribe = tokens });
}

pub fn buildSetModeCommand(allocator: std.mem.Allocator, mode: Mode, tokens: []const u32) ![]u8 {
    if (tokens.len == 0) return allocator.dupe(u8, "");
    return buildCommand(allocator, .{ .mode = .{ .mode = mode, .tokens = tokens } });
}

pub fn buildResubscribeCommands(allocator: std.mem.Allocator, snapshot: SubscriptionSnapshot) !CommandBatch {
    var payloads = std.ArrayList([]u8).empty;
    defer payloads.deinit(allocator);

    if (snapshot.subscribed.len > 0) {
        try payloads.append(allocator, try buildSubscribeCommand(allocator, snapshot.subscribed));
    }
    if (snapshot.full.len > 0) {
        try payloads.append(allocator, try buildSetModeCommand(allocator, .full, snapshot.full));
    }
    if (snapshot.quote.len > 0) {
        try payloads.append(allocator, try buildSetModeCommand(allocator, .quote, snapshot.quote));
    }
    if (snapshot.ltp.len > 0) {
        try payloads.append(allocator, try buildSetModeCommand(allocator, .ltp, snapshot.ltp));
    }

    return .{ .payloads = try payloads.toOwnedSlice(allocator) };
}

pub fn buildCommand(allocator: std.mem.Allocator, command: SessionCommand) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);

    switch (command) {
        .subscribe => |tokens| {
            try list.appendSlice(allocator, "{\"a\":\"subscribe\",\"v\":[");
            try appendTokenList(&list, allocator, tokens);
            try list.appendSlice(allocator, "]}");
        },
        .unsubscribe => |tokens| {
            try list.appendSlice(allocator, "{\"a\":\"unsubscribe\",\"v\":[");
            try appendTokenList(&list, allocator, tokens);
            try list.appendSlice(allocator, "]}");
        },
        .mode => |payload| {
            try list.appendSlice(allocator, "{\"a\":\"mode\",\"v\":[\"");
            try list.appendSlice(allocator, payload.mode.asString());
            try list.appendSlice(allocator, "\",[");
            try appendTokenList(&list, allocator, payload.tokens);
            try list.appendSlice(allocator, "]]}");
        },
    }

    return list.toOwnedSlice(allocator);
}

fn appendTokenList(list: *std.ArrayList(u8), allocator: std.mem.Allocator, tokens: []const u32) !void {
    for (tokens, 0..) |token, idx| {
        if (idx != 0) try list.append(allocator, ',');
        try list.writer(allocator).print("{d}", .{token});
    }
}

test "buildSubscribeCommand matches upstream payload shape" {
    const payload = try buildSubscribeCommand(std.testing.allocator, &.{ 408065, 738561 });
    defer std.testing.allocator.free(payload);

    try std.testing.expectEqualStrings("{\"a\":\"subscribe\",\"v\":[408065,738561]}", payload);
}

test "buildUnsubscribeCommand matches upstream payload shape" {
    const payload = try buildUnsubscribeCommand(std.testing.allocator, &.{408065});
    defer std.testing.allocator.free(payload);

    try std.testing.expectEqualStrings("{\"a\":\"unsubscribe\",\"v\":[408065]}", payload);
}

test "buildSetModeCommand matches upstream payload shape" {
    const payload = try buildSetModeCommand(std.testing.allocator, .full, &.{ 408065, 738561 });
    defer std.testing.allocator.free(payload);

    try std.testing.expectEqualStrings("{\"a\":\"mode\",\"v\":[\"full\",[408065,738561]]}", payload);
}

test "reconnect policy doubles delay and clamps at max" {
    const policy = ReconnectPolicy{};
    try std.testing.expectEqual(@as(u64, 0), policy.delayForAttempt(0));
    try std.testing.expectEqual(@as(u64, 5_000), policy.delayForAttempt(1));
    try std.testing.expectEqual(@as(u64, 8_000), policy.delayForAttempt(3));
    try std.testing.expectEqual(@as(u64, 60_000), policy.delayForAttempt(10));
}

test "buildResubscribeCommands emits subscribe then mode payloads" {
    const snapshot = SubscriptionSnapshot{
        .subscribed = try std.testing.allocator.dupe(u32, &.{ 408065, 738561 }),
        .ltp = try std.testing.allocator.dupe(u32, &.{738561}),
        .quote = try std.testing.allocator.dupe(u32, &.{}),
        .full = try std.testing.allocator.dupe(u32, &.{408065}),
    };
    defer snapshot.deinit(std.testing.allocator);

    const batch = try buildResubscribeCommands(std.testing.allocator, snapshot);
    defer batch.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 3), batch.payloads.len);
    try std.testing.expectEqualStrings("{\"a\":\"subscribe\",\"v\":[408065,738561]}", batch.payloads[0]);
    try std.testing.expectEqualStrings("{\"a\":\"mode\",\"v\":[\"full\",[408065]]}", batch.payloads[1]);
    try std.testing.expectEqualStrings("{\"a\":\"mode\",\"v\":[\"ltp\",[738561]]}", batch.payloads[2]);
}

test "subscription state tracks resubscribe snapshot" {
    var state = SubscriptionState.init(std.testing.allocator);
    defer state.deinit();

    try state.subscribe(&.{ 408065, 738561, 884737 });
    try state.setMode(.full, &.{408065});
    try state.setMode(.ltp, &.{738561});
    state.unsubscribe(&.{884737});

    const snapshot = try state.snapshot();
    defer snapshot.deinit(std.testing.allocator);

    try std.testing.expectEqualSlices(u32, &.{ 408065, 738561 }, snapshot.subscribed);
    try std.testing.expectEqualSlices(u32, &.{738561}, snapshot.ltp);
    try std.testing.expectEqualSlices(u32, &.{}, snapshot.quote);
    try std.testing.expectEqualSlices(u32, &.{408065}, snapshot.full);
}

test "session processFrame dispatches ticks and typed text messages" {
    const Recorder = struct {
        tick_count: usize = 0,
        order_count: usize = 0,
        error_count: usize = 0,
        broker_message_count: usize = 0,
        text_count: usize = 0,
        last_order_id: ?[]const u8 = null,
        last_error: ?[]const u8 = null,
        last_broker_message: ?[]const u8 = null,

        fn onTick(ctx: *anyopaque, tick: Tick) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.tick_count += 1;
            _ = tick;
        }

        fn onOrderUpdate(ctx: *anyopaque, order: order_models.Order) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.order_count += 1;
            self.last_order_id = order.order_id;
        }

        fn onErrorMessage(ctx: *anyopaque, message: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.error_count += 1;
            self.last_error = message;
        }

        fn onBrokerMessage(ctx: *anyopaque, message: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.broker_message_count += 1;
            self.last_broker_message = message;
        }

        fn onTextMessage(ctx: *anyopaque, payload: []const u8) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.text_count += 1;
            _ = payload;
        }
    };

    var recorder = Recorder{};
    const handler = EventHandler{
        .context = &recorder,
        .onTick = Recorder.onTick,
        .onOrderUpdate = Recorder.onOrderUpdate,
        .onErrorMessage = Recorder.onErrorMessage,
        .onBrokerMessage = Recorder.onBrokerMessage,
        .onTextMessage = Recorder.onTextMessage,
    };

    var session = Session.init(std.testing.allocator, .{
        .root_url = "wss://ws.kite.trade",
        .api_key = "kite",
        .access_token = "token",
    });
    defer session.deinit();

    const binary_frame = OwnedFrame{
        .opcode = .binary,
        .payload = try std.testing.allocator.dupe(u8, &.{
            0x00, 0x01,
            0x00, 0x08,
            0x00, 0x06,
            0x3a, 0x01,
            0x00, 0x02,
            0x58, 0x52,
        }),
    };
    defer binary_frame.deinit(std.testing.allocator);
    _ = try session.processFrame(binary_frame, handler);

    const order_frame = OwnedFrame{
        .opcode = .text,
        .payload = try std.testing.allocator.dupe(u8, "{\"type\":\"order\",\"data\":{\"order_id\":\"123\",\"status\":\"COMPLETE\"}}"),
    };
    defer order_frame.deinit(std.testing.allocator);
    _ = try session.processFrame(order_frame, handler);

    const error_frame = OwnedFrame{
        .opcode = .text,
        .payload = try std.testing.allocator.dupe(u8, "{\"type\":\"error\",\"data\":\"permission denied\"}"),
    };
    defer error_frame.deinit(std.testing.allocator);
    _ = try session.processFrame(error_frame, handler);

    const broker_message_frame = OwnedFrame{
        .opcode = .text,
        .payload = try std.testing.allocator.dupe(u8, "{\"type\":\"message\",\"data\":\"maintenance window\"}"),
    };
    defer broker_message_frame.deinit(std.testing.allocator);
    _ = try session.processFrame(broker_message_frame, handler);

    const malformed_text_frame = OwnedFrame{
        .opcode = .text,
        .payload = try std.testing.allocator.dupe(u8, "{\"type\":\"order\",\"data\":"),
    };
    defer malformed_text_frame.deinit(std.testing.allocator);
    _ = try session.processFrame(malformed_text_frame, handler);

    try std.testing.expectEqual(@as(usize, 1), recorder.tick_count);
    try std.testing.expectEqual(@as(usize, 1), recorder.order_count);
    try std.testing.expectEqual(@as(usize, 1), recorder.error_count);
    try std.testing.expectEqual(@as(usize, 1), recorder.broker_message_count);
    try std.testing.expectEqual(@as(usize, 4), recorder.text_count);
    try std.testing.expectEqualStrings("123", recorder.last_order_id.?);
    try std.testing.expectEqualStrings("permission denied", recorder.last_error.?);
    try std.testing.expectEqualStrings("maintenance window", recorder.last_broker_message.?);
}

test "session run reconnects and replays subscriptions" {
    const FakeConnection = struct {
        allocator: std.mem.Allocator,
        frames: []const OwnedFrame,
        next_index: usize = 0,
        writes: std.ArrayList([]u8) = .empty,

        fn init(allocator: std.mem.Allocator, frames: []const OwnedFrame) @This() {
            return .{ .allocator = allocator, .frames = frames };
        }

        fn deinit(self: *@This()) void {
            for (self.writes.items) |payload| self.allocator.free(payload);
            self.writes.deinit(self.allocator);
        }

        fn asConnection(self: *@This()) Connection {
            return .{
                .context = self,
                .vtable = &.{
                    .readFrame = readFrame,
                    .writeText = writeText,
                    .close = close,
                },
            };
        }

        fn readFrame(ctx: *anyopaque, allocator: std.mem.Allocator) anyerror!OwnedFrame {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.next_index >= self.frames.len) return error.EndOfStream;
            const frame = self.frames[self.next_index];
            self.next_index += 1;
            return .{ .opcode = frame.opcode, .payload = try allocator.dupe(u8, frame.payload) };
        }

        fn writeText(ctx: *anyopaque, payload: []const u8) anyerror!void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            try self.writes.append(self.allocator, try self.allocator.dupe(u8, payload));
        }

        fn close(ctx: *anyopaque) void {
            _ = ctx;
        }
    };

    const FakeTransport = struct {
        allocator: std.mem.Allocator,
        connections: []Connection,
        connect_index: usize = 0,
        delays: std.ArrayList(u64) = .empty,

        fn init(allocator: std.mem.Allocator, connections: []Connection) @This() {
            return .{ .allocator = allocator, .connections = connections };
        }

        fn deinit(self: *@This()) void {
            self.delays.deinit(self.allocator);
        }

        fn asTransport(self: *@This()) Transport {
            return .{
                .context = self,
                .vtable = &.{
                    .connect = connect,
                    .sleepMs = sleepMs,
                },
            };
        }

        fn connect(ctx: *anyopaque, allocator: std.mem.Allocator, url: []const u8) anyerror!Connection {
            _ = allocator;
            _ = url;
            const self: *@This() = @ptrCast(@alignCast(ctx));
            if (self.connect_index >= self.connections.len) return error.NoMoreConnections;
            const connection = self.connections[self.connect_index];
            self.connect_index += 1;
            return connection;
        }

        fn sleepMs(ctx: *anyopaque, delay_ms: u64) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.delays.append(self.allocator, delay_ms) catch unreachable;
        }
    };

    const Recorder = struct {
        connect_count: usize = 0,
        disconnect_count: usize = 0,
        reconnect_count: usize = 0,
        runtime_errors: usize = 0,

        fn onConnect(ctx: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.connect_count += 1;
        }

        fn onDisconnect(ctx: *anyopaque) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.disconnect_count += 1;
        }

        fn onReconnect(ctx: *anyopaque, attempt: u32, delay_ms: u64) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.reconnect_count += 1;
            _ = attempt;
            _ = delay_ms;
        }

        fn onRuntimeError(ctx: *anyopaque, _: anyerror) void {
            const self: *@This() = @ptrCast(@alignCast(ctx));
            self.runtime_errors += 1;
        }
    };

    const first_frames = [_]OwnedFrame{};
    const second_frames = [_]OwnedFrame{
        .{ .opcode = .close, .payload = &.{} },
    };

    var first_connection = FakeConnection.init(std.testing.allocator, &first_frames);
    defer first_connection.deinit();
    var second_connection = FakeConnection.init(std.testing.allocator, &second_frames);
    defer second_connection.deinit();

    var connections = [_]Connection{ first_connection.asConnection(), second_connection.asConnection() };
    var transport = FakeTransport.init(std.testing.allocator, connections[0..]);
    defer transport.deinit();

    var recorder = Recorder{};
    const handler = EventHandler{
        .context = &recorder,
        .onConnect = Recorder.onConnect,
        .onDisconnect = Recorder.onDisconnect,
        .onReconnect = Recorder.onReconnect,
        .onRuntimeError = Recorder.onRuntimeError,
    };

    var session = Session.init(std.testing.allocator, .{
        .root_url = "wss://ws.kite.trade",
        .api_key = "kite",
        .access_token = "token",
    });
    defer session.deinit();

    try session.subscribe(null, &.{ 408065, 738561 });
    try session.setMode(null, .full, &.{408065});
    try session.setMode(null, .ltp, &.{738561});
    try session.run(transport.asTransport(), handler);

    try std.testing.expectEqual(@as(usize, 2), recorder.connect_count);
    try std.testing.expectEqual(@as(usize, 1), recorder.disconnect_count);
    try std.testing.expectEqual(@as(usize, 1), recorder.reconnect_count);
    try std.testing.expectEqual(@as(usize, 1), recorder.runtime_errors);
    try std.testing.expectEqual(@as(usize, 1), transport.delays.items.len);

    try std.testing.expectEqual(@as(usize, 3), second_connection.writes.items.len);
    try std.testing.expectEqualStrings("{\"a\":\"subscribe\",\"v\":[408065,738561]}", second_connection.writes.items[0]);
    try std.testing.expectEqualStrings("{\"a\":\"mode\",\"v\":[\"full\",[408065]]}", second_connection.writes.items[1]);
    try std.testing.expectEqualStrings("{\"a\":\"mode\",\"v\":[\"ltp\",[738561]]}", second_connection.writes.items[2]);
}
