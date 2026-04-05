//! High-level Kite Connect client.

const std = @import("std");
const auth = @import("auth.zig");
const common = @import("models/common.zig");
const http = @import("http.zig");
const transport = @import("transport.zig");

/// Environment-driven client configuration.
pub const Config = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    access_token: ?[]const u8 = null,
    root_url: []const u8 = "https://api.kite.trade",
    user_agent: []const u8 = "kiteconnect.zig/0.1.0",
};

/// Errors that can arise while preparing an executable request.
pub const PrepareRequestError = transport.UrlError || auth.AuthError;

/// Errors that can arise while classifying an executed response.
pub const ClassifyResponseError = http.ClassifyResponseError;

/// Errors that can arise while executing a prepared request.
pub const ExecutePreparedError = http.ExecuteError;

/// Errors that can arise while preparing, executing, and classifying a request.
pub const ExecuteRequestError = PrepareRequestError || http.ExecuteError || http.ClassifyResponseError;

/// Main REST client state.
pub const Client = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    access_token: ?[]const u8,
    owned_access_token: ?[]u8,
    root_url: []const u8,
    user_agent: []const u8,

    /// Initialize a client using caller-owned string slices.
    pub fn init(config: Config) Client {
        return .{
            .allocator = config.allocator,
            .api_key = config.api_key,
            .access_token = config.access_token,
            .owned_access_token = null,
            .root_url = config.root_url,
            .user_agent = config.user_agent,
        };
    }

    /// Deinitialize client resources.
    pub fn deinit(self: *Client) void {
        self.clearOwnedAccessToken();
        self.* = undefined;
    }

    /// Update the bearer token used for authenticated requests.
    /// Any previously owned token is released before storing the new borrowed slice.
    pub fn setAccessToken(self: *Client, access_token: ?[]const u8) void {
        self.clearOwnedAccessToken();
        self.access_token = access_token;
    }

    /// Copy and store a bearer token so it remains valid independently of caller-managed buffers.
    pub fn setAccessTokenOwned(self: *Client, access_token: []const u8) std.mem.Allocator.Error!void {
        self.clearOwnedAccessToken();
        const duped = try self.allocator.dupe(u8, access_token);
        self.owned_access_token = duped;
        self.access_token = duped;
    }

    /// Builds the documented authorization header for authenticated requests.
    /// Caller owns the returned slice and must free it with the same allocator.
    pub fn authorizationHeader(self: Client) auth.AuthError![]u8 {
        return auth.authorizationHeader(self.allocator, self.api_key, self.access_token orelse return error.MissingAccessToken);
    }

    /// Builds an absolute API URL from the configured root URL and a relative path.
    /// Caller owns the returned slice and must free it with the same allocator.
    pub fn buildUrl(self: Client, path: []const u8) transport.UrlError![]u8 {
        return transport.buildUrl(self.allocator, self.root_url, path);
    }

    /// Prepares an executable request from shared request metadata plus client defaults.
    /// The returned request owns its URL and optional authorization header allocations.
    /// Body slices remain borrowed from the provided request spec.
    pub fn prepareRequest(self: Client, spec: transport.RequestSpec) PrepareRequestError!transport.PreparedRequest {
        const url = try transport.buildUrlWithQuery(self.allocator, self.root_url, spec.options.path, spec.query);
        errdefer self.allocator.free(url);

        const authorization = if (spec.options.requires_auth)
            try self.authorizationHeader()
        else
            null;
        errdefer if (authorization) |value| self.allocator.free(value);

        return .{
            .method = spec.options.method,
            .url = url,
            .requires_auth = spec.options.requires_auth,
            .authorization = authorization,
            .user_agent = self.user_agent,
            .accept = transport.acceptHeaderValue(spec.response_format),
            .content_type = spec.contentType(),
            .body = spec.body,
        };
    }

    /// Classifies an executed response using the request spec's declared response format.
    pub fn classifyResponse(
        self: Client,
        spec: transport.RequestSpec,
        response: http.ResponseView,
    ) ClassifyResponseError!http.ClassifiedResponse {
        return http.classifyResponse(self.allocator, spec.response_format, response);
    }

    /// Executes a previously prepared request using the provided stdlib runtime client.
    pub fn executePrepared(
        self: Client,
        runtime_client: *std.http.Client,
        request: transport.PreparedRequest,
    ) ExecutePreparedError!http.OwnedResponse {
        return http.executePrepared(self.allocator, runtime_client, request);
    }

    /// Prepares, executes, and classifies a request in one step.
    pub fn execute(
        self: Client,
        runtime_client: *std.http.Client,
        spec: transport.RequestSpec,
    ) ExecuteRequestError!http.ExecutedResponse {
        const request = try self.prepareRequest(spec);
        defer request.deinit(self.allocator);

        return http.executeClassified(self.allocator, runtime_client, spec.response_format, request);
    }

    /// Return a compact snapshot of client state for tests and diagnostics.
    pub fn state(self: Client) common.ClientState {
        return .{
            .api_key = self.api_key,
            .has_access_token = self.access_token != null,
            .root_url = self.root_url,
            .user_agent = self.user_agent,
        };
    }

    fn clearOwnedAccessToken(self: *Client) void {
        if (self.owned_access_token) |token| {
            self.allocator.free(token);
            self.owned_access_token = null;
        }
    }
};

test "client authorizationHeader uses configured credentials" {
    var client = Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
        .access_token = "access",
    });
    defer client.deinit();

    const header = try client.authorizationHeader();
    defer std.testing.allocator.free(header);

    try std.testing.expectEqualStrings("token kite_key:access", header);
}

test "client buildUrl uses configured root URL" {
    const client = Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
        .root_url = "https://api.kite.trade/",
    });

    const url = try client.buildUrl("/user/profile");
    defer std.testing.allocator.free(url);

    try std.testing.expectEqualStrings("https://api.kite.trade/user/profile", url);
}

test "client prepareRequest applies auth accept and content type" {
    const client = Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
        .access_token = "access",
        .root_url = "https://api.kite.trade",
    });

    const request = try client.prepareRequest(.{
        .options = .{ .method = .post, .path = "/orders" },
        .query = "foo=bar",
        .body = .{ .form = "variety=regular" },
        .response_format = .json,
    });
    defer request.deinit(std.testing.allocator);

    try std.testing.expectEqual(transport.Method.post, request.method);
    try std.testing.expectEqualStrings("https://api.kite.trade/orders?foo=bar", request.url);
    try std.testing.expectEqualStrings("token kite_key:access", request.authorization.?);
    try std.testing.expectEqualStrings("application/json", request.accept);
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", request.content_type.?);
    try std.testing.expectEqualStrings("variety=regular", request.body.form);
}

test "client prepareRequest skips auth when request does not require it" {
    const client = Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
    });

    const request = try client.prepareRequest(.{
        .options = .{ .method = .get, .path = "/instruments", .requires_auth = false },
        .response_format = .csv,
    });
    defer request.deinit(std.testing.allocator);

    try std.testing.expect(request.authorization == null);
    try std.testing.expectEqualStrings("text/csv", request.accept);
    try std.testing.expectEqualStrings("https://api.kite.trade/instruments", request.url);
}

test "client classifyResponse uses request response format for success" {
    const client = Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
    });

    const classified = try client.classifyResponse(.{
        .options = .{ .method = .get, .path = "/quote" },
        .response_format = .json,
    }, .{
        .status = 200,
        .content_type = "application/json",
        .body = "{\"status\":\"success\",\"data\":{}}",
    });
    defer classified.deinit(std.testing.allocator);

    try std.testing.expect(classified == .success);
}

test "client classifyResponse yields api_error for non-2xx responses" {
    const client = Client.init(.{
        .allocator = std.testing.allocator,
        .api_key = "kite_key",
    });

    const classified = try client.classifyResponse(.{
        .options = .{ .method = .get, .path = "/quote" },
        .response_format = .json,
    }, .{
        .status = 403,
        .content_type = "application/json",
        .body = "{\"status\":\"error\",\"message\":\"Token is invalid\"}",
    });
    defer classified.deinit(std.testing.allocator);

    try std.testing.expect(classified == .api_error);
    try std.testing.expectEqualStrings("Token is invalid", classified.api_error.message);
}
