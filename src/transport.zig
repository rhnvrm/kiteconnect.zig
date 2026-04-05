//! Shared transport contracts and URL helpers.

const std = @import("std");

/// Supported HTTP methods used by the REST client.
pub const Method = enum {
    get,
    post,
    put,
    delete,
};

/// Expected response decoding strategy for a request.
pub const ResponseFormat = enum {
    json,
    csv,
    raw,
};

/// Supported request-body encodings for prepared requests.
pub const BodyKind = enum {
    none,
    form,
    json,
    raw,
};

/// Borrowed request-body payload.
pub const RequestBody = union(BodyKind) {
    none,
    form: []const u8,
    json: []const u8,
    raw: []const u8,
};

/// Error set used by URL-building helpers.
pub const UrlError = error{
    EmptyRootUrl,
    EmptyPath,
    OutOfMemory,
};

/// Common request metadata shared by endpoint implementations.
pub const RequestOptions = struct {
    method: Method,
    path: []const u8,
    requires_auth: bool = true,
};

/// Declarative request spec consumed by the shared client transport layer.
pub const RequestSpec = struct {
    options: RequestOptions,
    query: ?[]const u8 = null,
    body: RequestBody = .none,
    response_format: ResponseFormat = .json,

    /// Returns the request content type header, if the body implies one.
    pub fn contentType(self: RequestSpec) ?[]const u8 {
        return switch (self.body) {
            .none => null,
            .form => "application/x-www-form-urlencoded",
            .json => "application/json",
            .raw => null,
        };
    }
};

/// Prepared executable request assembled from a client plus a request spec.
pub const PreparedRequest = struct {
    method: Method,
    url: []u8,
    requires_auth: bool,
    authorization: ?[]u8,
    user_agent: []const u8,
    accept: []const u8,
    content_type: ?[]const u8,
    body: RequestBody,

    /// Frees owned URL and authorization-header allocations.
    pub fn deinit(self: PreparedRequest, allocator: std.mem.Allocator) void {
        allocator.free(self.url);
        if (self.authorization) |authorization| allocator.free(authorization);
    }
};

/// Returns the HTTP `Accept` header value for the expected response format.
pub fn acceptHeaderValue(format: ResponseFormat) []const u8 {
    return switch (format) {
        .json => "application/json",
        .csv => "text/csv",
        .raw => "*/*",
    };
}

/// Returns whether an HTTP status code is a success response.
pub fn isSuccessStatus(status: u16) bool {
    return status >= 200 and status < 300;
}

/// Builds an absolute URL from a root URL and API path.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildUrl(allocator: std.mem.Allocator, root_url: []const u8, path: []const u8) UrlError![]u8 {
    if (root_url.len == 0) return error.EmptyRootUrl;
    if (path.len == 0) return error.EmptyPath;

    const trimmed_root = std.mem.trimRight(u8, root_url, "/");
    const trimmed_path = std.mem.trimLeft(u8, path, "/");
    return std.fmt.allocPrint(allocator, "{s}/{s}", .{ trimmed_root, trimmed_path });
}

/// Builds an absolute URL from a root URL, API path, and already-encoded query string.
/// Caller owns the returned slice and must free it with the same allocator.
pub fn buildUrlWithQuery(
    allocator: std.mem.Allocator,
    root_url: []const u8,
    path: []const u8,
    query: ?[]const u8,
) UrlError![]u8 {
    const url = try buildUrl(allocator, root_url, path);
    errdefer allocator.free(url);

    if (query == null or query.?.len == 0) return url;
    defer allocator.free(url);
    return std.fmt.allocPrint(allocator, "{s}?{s}", .{ url, query.? });
}

test "buildUrl joins root and path cleanly" {
    const allocator = std.testing.allocator;
    const url = try buildUrl(allocator, "https://api.kite.trade/", "/orders");
    defer allocator.free(url);

    try std.testing.expectEqualStrings("https://api.kite.trade/orders", url);
}

test "buildUrlWithQuery appends encoded query" {
    const allocator = std.testing.allocator;
    const url = try buildUrlWithQuery(allocator, "https://api.kite.trade", "/quote", "i=NSE%3AINFY");
    defer allocator.free(url);

    try std.testing.expectEqualStrings("https://api.kite.trade/quote?i=NSE%3AINFY", url);
}

test "acceptHeaderValue matches response format" {
    try std.testing.expectEqualStrings("application/json", acceptHeaderValue(.json));
    try std.testing.expectEqualStrings("text/csv", acceptHeaderValue(.csv));
    try std.testing.expectEqualStrings("*/*", acceptHeaderValue(.raw));
}

test "isSuccessStatus classifies 2xx statuses" {
    try std.testing.expect(isSuccessStatus(200));
    try std.testing.expect(isSuccessStatus(204));
    try std.testing.expect(!isSuccessStatus(302));
    try std.testing.expect(!isSuccessStatus(400));
}
