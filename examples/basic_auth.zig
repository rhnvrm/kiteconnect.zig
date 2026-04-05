const std = @import("std");
const kite = @import("kiteconnect");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const api_key = try getRequiredEnv(allocator, "KITE_API_KEY");
    defer allocator.free(api_key);

    const root_url = try getOptionalEnv(allocator, "KITE_ROOT_URL");
    defer if (root_url) |value| allocator.free(value);

    const access_token = try getOptionalEnv(allocator, "KITE_ACCESS_TOKEN");
    defer if (access_token) |value| allocator.free(value);

    const api_secret = try getOptionalEnv(allocator, "KITE_API_SECRET");
    defer if (api_secret) |value| allocator.free(value);

    const request_token = try getOptionalEnv(allocator, "KITE_REQUEST_TOKEN");
    defer if (request_token) |value| allocator.free(value);

    var client = kite.Client.init(.{
        .allocator = allocator,
        .api_key = api_key,
        .access_token = access_token,
        .root_url = root_url orelse "https://api.kite.trade",
    });
    defer client.deinit();

    var runtime_client: std.http.Client = .{ .allocator = allocator };
    defer runtime_client.deinit();

    const login_url = try kite.http.loginUrl(allocator, api_key);
    defer allocator.free(login_url);

    std.debug.print("Kite login URL (open in browser):\n  {s}\n\n", .{login_url});

    if (client.state().has_access_token) {
        std.debug.print("Using KITE_ACCESS_TOKEN from environment.\n\n", .{});
    } else if (request_token) |token| {
        const secret = api_secret orelse {
            std.debug.print("KITE_API_SECRET is required when KITE_REQUEST_TOKEN is provided.\n", .{});
            printUsage();
            return;
        };

        const form = try kite.session.buildGenerateSessionForm(allocator, api_key, token, secret);
        defer allocator.free(form);

        var session_result = try kite.session.executeGenerateSessionAndSetAccessToken(&client, &runtime_client, form);
        defer session_result.deinit(allocator);

        switch (session_result) {
            .success => |ok| {
                std.debug.print(
                    "Generated session for user {s}; access token is now set on client.\n\n",
                    .{ok.parsed.value.data.user_id},
                );
            },
            .api_error => |api_err| {
                std.debug.print(
                    "Session generation failed: status={?d} type={s} message={s}\n",
                    .{ api_err.status, api_err.error_type orelse "GeneralException", api_err.message },
                );
                return;
            },
        }
    } else {
        std.debug.print(
            "No access token available. Set KITE_ACCESS_TOKEN, or provide KITE_REQUEST_TOKEN + KITE_API_SECRET.\n",
            .{},
        );
        printUsage();
        return;
    }

    var profile_result = try kite.user.executeProfile(client, &runtime_client);
    defer profile_result.deinit(allocator);

    switch (profile_result) {
        .success => |ok| {
            const profile = ok.parsed.value.data;
            std.debug.print(
                "Profile: {s} ({s}) | exchanges={d} products={d}\n",
                .{ profile.user_name, profile.user_id, profile.exchanges.len, profile.products.len },
            );
        },
        .api_error => |api_err| {
            std.debug.print(
                "Profile request failed: status={?d} type={s} message={s}\n",
                .{ api_err.status, api_err.error_type orelse "GeneralException", api_err.message },
            );
            return;
        },
    }

    var margins_result = try kite.user.executeUserMargins(client, &runtime_client);
    defer margins_result.deinit(allocator);

    switch (margins_result) {
        .success => |ok| {
            const margins = ok.parsed.value.data;
            if (margins.equity) |equity| {
                std.debug.print("Margins (equity): net={d:.2} available.cash={d:.2}\n", .{
                    equity.net,
                    equity.available.cash,
                });
            } else {
                std.debug.print("Margins (equity): not available for this account.\n", .{});
            }
        },
        .api_error => |api_err| {
            std.debug.print(
                "Margins request failed: status={?d} type={s} message={s}\n",
                .{ api_err.status, api_err.error_type orelse "GeneralException", api_err.message },
            );
            return;
        },
    }
}

fn getOptionalEnv(allocator: std.mem.Allocator, name: []const u8) !?[]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => null,
        else => err,
    };
}

fn getRequiredEnv(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    return std.process.getEnvVarOwned(allocator, name) catch |err| switch (err) {
        error.EnvironmentVariableNotFound => {
            std.debug.print("Missing required environment variable: {s}\n", .{name});
            printUsage();
            return err;
        },
        else => err,
    };
}

fn printUsage() void {
    std.debug.print(
        \\Usage:
        \\  KITE_API_KEY=<key> KITE_ACCESS_TOKEN=<token> zig build example-basic
        \\or:
        \\  KITE_API_KEY=<key> KITE_API_SECRET=<secret> KITE_REQUEST_TOKEN=<request_token> zig build example-basic
        \\Optional:
        \\  KITE_ROOT_URL=https://api.kite.trade
        \\Compile only:
        \\  zig build examples
        \\
    , .{});
}
