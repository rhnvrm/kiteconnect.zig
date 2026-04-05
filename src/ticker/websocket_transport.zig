//! Concrete websocket client backend for the ticker session runtime.
//!
//! This module adapts `karlseguin/websocket.zig` to the transport-agnostic
//! contracts in `session.zig`, so the parser/session/runtime layer can run over
//! a real websocket connection without coupling the core ticker code to a
//! specific backend.

const std = @import("std");
const websocket = @import("websocket");
const session = @import("session.zig");

/// Concrete transport backed by `websocket.Client`.
pub const WebSocketClientTransport = struct {
    allocator: std.mem.Allocator,
    handshake_timeout_ms: u32 = 10_000,
    buffer_size: usize = 4096,
    max_message_size: usize = 65_536,
    ca_bundle: ?*const std.crypto.Certificate.Bundle = null,

    /// Returns the transport-agnostic session transport view.
    pub fn transport(self: *WebSocketClientTransport) session.Transport {
        return .{
            .context = self,
            .vtable = &.{
                .connect = connect,
                .sleepMs = sleepMs,
            },
        };
    }

    fn connect(context: *anyopaque, allocator: std.mem.Allocator, url: []const u8) anyerror!session.Connection {
        const self: *@This() = @ptrCast(@alignCast(context));
        var parsed = try ParsedUrl.parse(allocator, url);
        defer parsed.deinit(allocator);

        const owned = try allocator.create(OwnedClient);
        errdefer allocator.destroy(owned);
        owned.* = try OwnedClient.init(allocator, parsed, self.*);
        return owned.connection();
    }

    fn sleepMs(context: *anyopaque, delay_ms: u64) void {
        _ = context;
        std.Thread.sleep(delay_ms * std.time.ns_per_ms);
    }
};

const ParsedUrl = struct {
    tls: bool,
    host: []const u8,
    port: u16,
    path_with_query: []u8,

    fn parse(allocator: std.mem.Allocator, url: []const u8) !ParsedUrl {
        const uri = try std.Uri.parse(url);
        const tls = if (std.ascii.eqlIgnoreCase(uri.scheme, "wss"))
            true
        else if (std.ascii.eqlIgnoreCase(uri.scheme, "ws"))
            false
        else
            return error.UnsupportedScheme;

        const host = try uri.getHostAlloc(allocator);
        errdefer allocator.free(host);

        const port: u16 = uri.port orelse if (tls) 443 else 80;
        const path_with_query = try extractPathWithQuery(allocator, url);
        errdefer allocator.free(path_with_query);

        return .{
            .tls = tls,
            .host = host,
            .port = port,
            .path_with_query = path_with_query,
        };
    }

    fn deinit(self: ParsedUrl, allocator: std.mem.Allocator) void {
        allocator.free(self.host);
        allocator.free(self.path_with_query);
    }
};

const OwnedClient = struct {
    allocator: std.mem.Allocator,
    client: websocket.Client,

    fn init(allocator: std.mem.Allocator, parsed: ParsedUrl, config: WebSocketClientTransport) !OwnedClient {
        var client = try websocket.Client.init(allocator, .{
            .host = parsed.host,
            .port = parsed.port,
            .tls = parsed.tls,
            .buffer_size = config.buffer_size,
            .max_size = config.max_message_size,
            .ca_bundle = if (config.ca_bundle) |bundle| bundle.* else null,
        });
        errdefer client.deinit();

        const headers = try buildHandshakeHeaders(allocator, parsed.host, parsed.port, parsed.tls);
        defer allocator.free(headers);

        try client.handshake(parsed.path_with_query, .{
            .timeout_ms = config.handshake_timeout_ms,
            .headers = headers,
        });

        return .{
            .allocator = allocator,
            .client = client,
        };
    }

    fn connection(self: *OwnedClient) session.Connection {
        return .{
            .context = self,
            .vtable = &.{
                .readFrame = readFrame,
                .writeText = writeText,
                .close = close,
            },
        };
    }

    fn readFrame(context: *anyopaque, allocator: std.mem.Allocator) anyerror!session.OwnedFrame {
        const self: *@This() = @ptrCast(@alignCast(context));
        const message = (try self.client.read()) orelse return error.WouldBlock;
        defer self.client.done(message);

        return .{
            .opcode = switch (message.type) {
                .text => .text,
                .binary => .binary,
                .close => .close,
                .ping => .ping,
                .pong => .pong,
            },
            .payload = try allocator.dupe(u8, message.data),
        };
    }

    fn writeText(context: *anyopaque, payload: []const u8) anyerror!void {
        const self: *@This() = @ptrCast(@alignCast(context));
        const owned = try self.allocator.dupe(u8, payload);
        defer self.allocator.free(owned);
        try self.client.writeText(owned);
    }

    fn close(context: *anyopaque) void {
        const self: *@This() = @ptrCast(@alignCast(context));
        self.client.close(.{}) catch {};
        self.client.deinit();
        self.allocator.destroy(self);
    }
};

fn buildHandshakeHeaders(allocator: std.mem.Allocator, host: []const u8, port: u16, tls: bool) ![]u8 {
    const default_port: u16 = if (tls) 443 else 80;
    if (port == default_port) {
        return std.fmt.allocPrint(allocator, "host: {s}\r\n", .{host});
    }
    return std.fmt.allocPrint(allocator, "host: {s}:{d}\r\n", .{ host, port });
}

fn extractPathWithQuery(allocator: std.mem.Allocator, url: []const u8) ![]u8 {
    const scheme_end = std.mem.indexOf(u8, url, "://") orelse return error.InvalidUrl;
    const after_authority = url[scheme_end + 3 ..];
    const authority_end_rel = std.mem.indexOfAny(u8, after_authority, "/?#") orelse after_authority.len;
    const authority_end_abs = scheme_end + 3 + authority_end_rel;

    if (authority_end_abs >= url.len) return allocator.dupe(u8, "/");

    var remainder = url[authority_end_abs..];
    if (std.mem.indexOfScalar(u8, remainder, '#')) |fragment_start| {
        remainder = remainder[0..fragment_start];
    }

    if (remainder.len == 0) return allocator.dupe(u8, "/");
    if (remainder[0] == '?') return std.fmt.allocPrint(allocator, "/{s}", .{remainder});
    if (remainder[0] == '#') return allocator.dupe(u8, "/");
    return allocator.dupe(u8, remainder);
}

test "extractPathWithQuery preserves path and query" {
    const cases = [_]struct {
        url: []const u8,
        expected: []const u8,
    }{
        .{ .url = "wss://ws.kite.trade", .expected = "/" },
        .{ .url = "wss://ws.kite.trade?api_key=a&access_token=b", .expected = "/?api_key=a&access_token=b" },
        .{ .url = "wss://ws.kite.trade/ticker?api_key=a&access_token=b", .expected = "/ticker?api_key=a&access_token=b" },
    };

    for (cases) |case| {
        const actual = try extractPathWithQuery(std.testing.allocator, case.url);
        defer std.testing.allocator.free(actual);
        try std.testing.expectEqualStrings(case.expected, actual);
    }
}

test "buildHandshakeHeaders omits default ports" {
    const tls_headers = try buildHandshakeHeaders(std.testing.allocator, "ws.kite.trade", 443, true);
    defer std.testing.allocator.free(tls_headers);
    try std.testing.expectEqualStrings("host: ws.kite.trade\r\n", tls_headers);

    const non_default = try buildHandshakeHeaders(std.testing.allocator, "localhost", 9000, false);
    defer std.testing.allocator.free(non_default);
    try std.testing.expectEqualStrings("host: localhost:9000\r\n", non_default);
}
