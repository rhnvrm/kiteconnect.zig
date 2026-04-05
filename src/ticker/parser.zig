//! Binary and text-frame parser helpers for the Kite ticker protocol.

const std = @import("std");
const models = @import("../models/ticker.zig");
const order_models = @import("../models/orders.zig");

pub const Mode = models.Mode;
pub const Tick = models.Tick;
pub const Depth = models.Depth;
pub const DepthItem = models.DepthItem;
pub const Ohlc = models.Ohlc;
pub const TextEnvelope = models.TextEnvelope;
pub const OrderUpdateEnvelope = struct {
    type: []const u8,
    data: order_models.Order,
};
pub const ErrorTextEnvelope = struct {
    type: []const u8,
    data: []const u8,
};
pub const MessageTextEnvelope = struct {
    type: []const u8,
    data: []const u8,
};

pub const ParsedTextMessage = union(enum) {
    error_message: std.json.Parsed(ErrorTextEnvelope),
    order_update: std.json.Parsed(OrderUpdateEnvelope),
    broker_message: std.json.Parsed(MessageTextEnvelope),
    other: std.json.Parsed(TextEnvelope),

    pub fn deinit(self: *ParsedTextMessage) void {
        switch (self.*) {
            .error_message => |*parsed| parsed.deinit(),
            .order_update => |*parsed| parsed.deinit(),
            .broker_message => |*parsed| parsed.deinit(),
            .other => |*parsed| parsed.deinit(),
        }
    }
};

pub const Segment = enum(u8) {
    nse_cm = 1,
    nse_fo = 2,
    nse_cd = 3,
    bse_cm = 4,
    bse_fo = 5,
    bse_cd = 6,
    mcx_fo = 7,
    mcx_sx = 8,
    indices = 9,
};

pub const PacketView = struct {
    bytes: []const u8,
};

pub const PacketViews = struct {
    packets: []const PacketView,

    pub fn deinit(self: PacketViews, allocator: std.mem.Allocator) void {
        allocator.free(self.packets);
    }
};

pub const ParsePacketError = error{
    PacketTooShort,
    UnsupportedPacketLength,
};

pub const SplitPacketsError = error{
    TruncatedFrame,
};

pub const ParseBinaryError = SplitPacketsError || std.mem.Allocator.Error || ParsePacketError;

pub const PacketLength = struct {
    pub const ltp = 8;
    pub const quote_index = 28;
    pub const full_index = 32;
    pub const quote = 44;
    pub const full = 184;
};

pub fn splitPackets(allocator: std.mem.Allocator, payload: []const u8) (SplitPacketsError || std.mem.Allocator.Error)!PacketViews {
    if (payload.len < 2) return .{ .packets = &.{} };

    const packet_count = readU16(payload[0..2]);
    var packets = try allocator.alloc(PacketView, packet_count);
    errdefer allocator.free(packets);

    var cursor: usize = 2;
    var i: usize = 0;
    while (i < packet_count) : (i += 1) {
        if (cursor + 2 > payload.len) return error.TruncatedFrame;
        const packet_len = readU16(payload[cursor .. cursor + 2]);
        cursor += 2;
        if (cursor + packet_len > payload.len) return error.TruncatedFrame;
        packets[i] = .{ .bytes = payload[cursor .. cursor + packet_len] };
        cursor += packet_len;
    }

    return .{ .packets = packets };
}

pub fn parseBinary(allocator: std.mem.Allocator, payload: []const u8) ParseBinaryError![]Tick {
    const packet_views = try splitPackets(allocator, payload);
    defer packet_views.deinit(allocator);

    var ticks = try allocator.alloc(Tick, packet_views.packets.len);
    errdefer allocator.free(ticks);

    for (packet_views.packets, 0..) |packet, idx| {
        ticks[idx] = try parsePacket(packet.bytes);
    }

    return ticks;
}

pub fn parsePacket(packet: []const u8) ParsePacketError!Tick {
    if (packet.len < PacketLength.ltp) return error.PacketTooShort;

    const instrument_token = readU32(packet[0..4]);
    const seg = @as(u8, @truncate(instrument_token & 0xff));
    const is_index = seg == @intFromEnum(Segment.indices);
    const is_tradable = !is_index;

    if (packet.len == PacketLength.ltp) {
        return .{
            .mode = .ltp,
            .instrument_token = instrument_token,
            .is_tradable = is_tradable,
            .is_index = is_index,
            .last_price = convertPrice(seg, @floatFromInt(readU32(packet[4..8]))),
        };
    }

    if (packet.len == PacketLength.quote_index or packet.len == PacketLength.full_index) {
        const last_price = convertPrice(seg, @floatFromInt(readU32(packet[4..8])));
        const close_price = convertPrice(seg, @floatFromInt(readU32(packet[20..24])));

        var tick = Tick{
            .mode = .quote,
            .instrument_token = instrument_token,
            .is_tradable = is_tradable,
            .is_index = is_index,
            .last_price = last_price,
            .net_change = last_price - close_price,
            .ohlc = .{
                .open = convertPrice(seg, @floatFromInt(readU32(packet[16..20]))),
                .high = convertPrice(seg, @floatFromInt(readU32(packet[8..12]))),
                .low = convertPrice(seg, @floatFromInt(readU32(packet[12..16]))),
                .close = close_price,
            },
        };

        if (packet.len == PacketLength.full_index) {
            tick.mode = .full;
            tick.timestamp_unix = readUnixSeconds(packet[28..32]);
        }
        return tick;
    }

    if (packet.len != PacketLength.quote and packet.len != PacketLength.full) {
        return error.UnsupportedPacketLength;
    }

    const last_price = convertPrice(seg, @floatFromInt(readU32(packet[4..8])));
    const close_price = convertPrice(seg, @floatFromInt(readU32(packet[40..44])));

    var tick = Tick{
        .mode = .quote,
        .instrument_token = instrument_token,
        .is_tradable = is_tradable,
        .is_index = is_index,
        .last_price = last_price,
        .last_traded_quantity = readU32(packet[8..12]),
        .average_trade_price = convertPrice(seg, @floatFromInt(readU32(packet[12..16]))),
        .volume_traded = readU32(packet[16..20]),
        .total_buy_quantity = readU32(packet[20..24]),
        .total_sell_quantity = readU32(packet[24..28]),
        .ohlc = .{
            .open = convertPrice(seg, @floatFromInt(readU32(packet[28..32]))),
            .high = convertPrice(seg, @floatFromInt(readU32(packet[32..36]))),
            .low = convertPrice(seg, @floatFromInt(readU32(packet[36..40]))),
            .close = close_price,
        },
    };

    if (packet.len == PacketLength.full) {
        tick.mode = .full;
        tick.last_trade_time_unix = readUnixSeconds(packet[44..48]);
        tick.oi = readU32(packet[48..52]);
        tick.oi_day_high = readU32(packet[52..56]);
        tick.oi_day_low = readU32(packet[56..60]);
        tick.timestamp_unix = readUnixSeconds(packet[60..64]);
        tick.net_change = last_price - close_price;
        tick.depth = parseDepth(seg, packet[64..184]);
    }

    return tick;
}

pub fn parseTextEnvelope(allocator: std.mem.Allocator, payload: []const u8) !std.json.Parsed(TextEnvelope) {
    return std.json.parseFromSlice(TextEnvelope, allocator, payload, .{});
}

pub fn parseTextMessage(allocator: std.mem.Allocator, payload: []const u8) !ParsedTextMessage {
    var envelope = try parseTextEnvelope(allocator, payload);
    defer envelope.deinit();

    if (std.mem.eql(u8, envelope.value.type, "error")) {
        if (std.json.parseFromSlice(ErrorTextEnvelope, allocator, payload, .{})) |parsed| {
            return .{ .error_message = parsed };
        } else |_| {
            return .{ .other = try std.json.parseFromSlice(TextEnvelope, allocator, payload, .{}) };
        }
    }
    if (std.mem.eql(u8, envelope.value.type, "order")) {
        if (std.json.parseFromSlice(OrderUpdateEnvelope, allocator, payload, .{})) |parsed| {
            return .{ .order_update = parsed };
        } else |_| {
            return .{ .other = try std.json.parseFromSlice(TextEnvelope, allocator, payload, .{}) };
        }
    }
    if (std.mem.eql(u8, envelope.value.type, "message")) {
        if (std.json.parseFromSlice(MessageTextEnvelope, allocator, payload, .{})) |parsed| {
            return .{ .broker_message = parsed };
        } else |_| {
            return .{ .other = try std.json.parseFromSlice(TextEnvelope, allocator, payload, .{}) };
        }
    }

    return .{ .other = try std.json.parseFromSlice(TextEnvelope, allocator, payload, .{}) };
}

pub fn convertPrice(segment: u8, raw_value: f64) f64 {
    return switch (segment) {
        @intFromEnum(Segment.nse_cd) => raw_value / 10000000.0,
        @intFromEnum(Segment.bse_cd) => raw_value / 10000.0,
        else => raw_value / 100.0,
    };
}

fn parseDepth(segment: u8, payload: []const u8) Depth {
    var depth = Depth{};
    var buy_cursor: usize = 0;
    var sell_cursor: usize = 60;

    for (0..5) |idx| {
        depth.buy[idx] = .{
            .quantity = readU32(payload[buy_cursor .. buy_cursor + 4]),
            .price = convertPrice(segment, @floatFromInt(readU32(payload[buy_cursor + 4 .. buy_cursor + 8]))),
            .orders = readU16(payload[buy_cursor + 8 .. buy_cursor + 10]),
        };
        depth.sell[idx] = .{
            .quantity = readU32(payload[sell_cursor .. sell_cursor + 4]),
            .price = convertPrice(segment, @floatFromInt(readU32(payload[sell_cursor + 4 .. sell_cursor + 8]))),
            .orders = readU16(payload[sell_cursor + 8 .. sell_cursor + 10]),
        };
        buy_cursor += 12;
        sell_cursor += 12;
    }

    return depth;
}

fn readUnixSeconds(bytes: []const u8) i64 {
    return @as(i64, @intCast(readU32(bytes)));
}

fn readU16(bytes: []const u8) u16 {
    return std.mem.readInt(u16, bytes[0..2], .big);
}

fn readU32(bytes: []const u8) u32 {
    return std.mem.readInt(u32, bytes[0..4], .big);
}

test "splitPackets splits concatenated binary dump" {
    const payload = [_]u8{
        0x00, 0x02,
        0x00, 0x08,
        0x00, 0x06,
        0x3a, 0x02,
        0x00, 0x01,
        0x86, 0xa0,
        0x00, 0x08,
        0x00, 0x06,
        0x3a, 0x03,
        0x00, 0x01,
        0x86, 0xa1,
    };

    const packets = try splitPackets(std.testing.allocator, &payload);
    defer packets.deinit(std.testing.allocator);

    try std.testing.expectEqual(@as(usize, 2), packets.packets.len);
    try std.testing.expectEqual(@as(usize, 8), packets.packets[0].bytes.len);
    try std.testing.expectEqual(@as(usize, 8), packets.packets[1].bytes.len);
}

test "parsePacket decodes ltp packet" {
    const packet = [_]u8{ 0x00, 0x06, 0x3a, 0x01, 0x00, 0x02, 0x58, 0x52 };
    const tick = try parsePacket(&packet);

    try std.testing.expectEqual(Mode.ltp, tick.mode);
    try std.testing.expectEqual(@as(u32, 408065), tick.instrument_token);
    try std.testing.expectApproxEqAbs(@as(f64, 1536.82), tick.last_price, 0.0001);
}

test "parsePacket decodes full index packet" {
    var packet = std.mem.zeroes([PacketLength.full_index]u8);
    std.mem.writeInt(u32, packet[0..4], 0x00000009, .big);
    std.mem.writeInt(u32, packet[4..8], 201234, .big);
    std.mem.writeInt(u32, packet[8..12], 202000, .big);
    std.mem.writeInt(u32, packet[12..16], 199000, .big);
    std.mem.writeInt(u32, packet[16..20], 200100, .big);
    std.mem.writeInt(u32, packet[20..24], 200000, .big);
    std.mem.writeInt(u32, packet[28..32], 1711962900, .big);

    const tick = try parsePacket(&packet);
    try std.testing.expectEqual(Mode.full, tick.mode);
    try std.testing.expect(tick.is_index);
    try std.testing.expectEqual(@as(?i64, 1711962900), tick.timestamp_unix);
    try std.testing.expectApproxEqAbs(@as(f64, 2012.34), tick.last_price, 0.0001);
}

test "parsePacket decodes full tradable packet depth" {
    var packet = std.mem.zeroes([PacketLength.full]u8);
    std.mem.writeInt(u32, packet[0..4], 0x00063a01, .big);
    std.mem.writeInt(u32, packet[4..8], 154225, .big);
    std.mem.writeInt(u32, packet[8..12], 25, .big);
    std.mem.writeInt(u32, packet[12..16], 154100, .big);
    std.mem.writeInt(u32, packet[16..20], 12000, .big);
    std.mem.writeInt(u32, packet[20..24], 5000, .big);
    std.mem.writeInt(u32, packet[24..28], 4500, .big);
    std.mem.writeInt(u32, packet[28..32], 153000, .big);
    std.mem.writeInt(u32, packet[32..36], 155000, .big);
    std.mem.writeInt(u32, packet[36..40], 152500, .big);
    std.mem.writeInt(u32, packet[40..44], 151000, .big);
    std.mem.writeInt(u32, packet[44..48], 1711962000, .big);
    std.mem.writeInt(u32, packet[48..52], 3400, .big);
    std.mem.writeInt(u32, packet[52..56], 3500, .big);
    std.mem.writeInt(u32, packet[56..60], 3300, .big);
    std.mem.writeInt(u32, packet[60..64], 1711962900, .big);

    std.mem.writeInt(u32, packet[64..68], 100, .big);
    std.mem.writeInt(u32, packet[68..72], 154200, .big);
    std.mem.writeInt(u16, packet[72..74], 3, .big);
    std.mem.writeInt(u32, packet[124..128], 120, .big);
    std.mem.writeInt(u32, packet[128..132], 154300, .big);
    std.mem.writeInt(u16, packet[132..134], 4, .big);

    const tick = try parsePacket(&packet);
    try std.testing.expectEqual(Mode.full, tick.mode);
    try std.testing.expect(tick.depth != null);
    try std.testing.expectEqual(@as(?u32, 3400), tick.oi);
    try std.testing.expectApproxEqAbs(@as(f64, 1542.25), tick.last_price, 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 1543.00), tick.depth.?.sell[0].price, 0.0001);
    try std.testing.expectEqual(@as(u32, 100), tick.depth.?.buy[0].quantity);
}

test "parseTextEnvelope decodes order message envelope" {
    const parsed = try parseTextEnvelope(
        std.testing.allocator,
        "{\"type\":\"order\",\"data\":{\"order_id\":\"123\"}}",
    );
    defer parsed.deinit();

    try std.testing.expectEqualStrings("order", parsed.value.type);
    try std.testing.expect(parsed.value.data == .object);
}

test "parseTextMessage decodes typed order update" {
    var parsed = try parseTextMessage(
        std.testing.allocator,
        "{\"type\":\"order\",\"data\":{\"order_id\":\"123\",\"status\":\"COMPLETE\"}}",
    );
    defer parsed.deinit();

    switch (parsed) {
        .order_update => |order| {
            try std.testing.expectEqualStrings("123", order.value.data.order_id);
            try std.testing.expectEqualStrings("COMPLETE", order.value.data.status);
        },
        else => return error.UnexpectedTextMessageVariant,
    }
}

test "parseTextMessage decodes typed error message" {
    var parsed = try parseTextMessage(
        std.testing.allocator,
        "{\"type\":\"error\",\"data\":\"permission denied\"}",
    );
    defer parsed.deinit();

    switch (parsed) {
        .error_message => |message| try std.testing.expectEqualStrings("permission denied", message.value.data),
        else => return error.UnexpectedTextMessageVariant,
    }
}

test "parseTextMessage decodes typed broker message" {
    var parsed = try parseTextMessage(
        std.testing.allocator,
        "{\"type\":\"message\",\"data\":\"market closing soon\"}",
    );
    defer parsed.deinit();

    switch (parsed) {
        .broker_message => |message| try std.testing.expectEqualStrings("market closing soon", message.value.data),
        else => return error.UnexpectedTextMessageVariant,
    }
}

test "parseTextMessage falls back to generic envelope for malformed typed payload" {
    var parsed = try parseTextMessage(
        std.testing.allocator,
        "{\"type\":\"order\",\"data\":\"not-an-order-object\"}",
    );
    defer parsed.deinit();

    switch (parsed) {
        .other => |message| {
            try std.testing.expectEqualStrings("order", message.value.type);
            try std.testing.expect(message.value.data == .string);
        },
        else => return error.UnexpectedTextMessageVariant,
    }
}
