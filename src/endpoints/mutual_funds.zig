//! Mutual-funds endpoint contracts, runtime execution helpers, request builders, and envelope parsers.

const std = @import("std");
const client_mod = @import("../client.zig");
const envelope = @import("../models/envelope.zig");
const errors = @import("../errors.zig");
const http = @import("../http.zig");
const models = @import("../models/mutual_funds.zig");
const transport = @import("../transport.zig");

/// API path constants for mutual-fund endpoints.
pub const Paths = struct {
    pub const orders = "/mf/orders";
    pub const sips = "/mf/sips";
    pub const holdings = "/mf/holdings";
    pub const allotments = "/mf/allotments";
    pub const instruments = "/mf/instruments";
};

/// Form payload for placing MF orders.
pub const MfOrderForm = struct {
    tradingsymbol: []const u8,
    transaction_type: []const u8,
    amount: f64,
    quantity: ?f64 = null,
    tag: ?[]const u8 = null,
};

/// Form payload for creating MF SIPs.
pub const MfSipForm = struct {
    tradingsymbol: []const u8,
    amount: f64,
    instalments: u32,
    frequency: []const u8,
    initial_amount: ?f64 = null,
    instalment_day: ?u8 = null,
    trigger_price: ?f64 = null,
    step_up: ?[]const u8 = null,
    sip_type: ?[]const u8 = null,
    tag: ?[]const u8 = null,
};

/// Form payload for modifying MF SIPs.
pub const MfSipModifyForm = struct {
    amount: ?f64 = null,
    status: ?[]const u8 = null,
    instalments: ?u32 = null,
    frequency: ?[]const u8 = null,
    instalment_day: ?u8 = null,
    step_up: ?[]const u8 = null,
};

pub const PathError = error{
    InvalidOrderId,
    InvalidSipId,
    EmptyTradingsymbol,
    EmptyIsin,
    OutOfMemory,
};

pub const FormError = error{
    EmptyTradingsymbol,
    EmptyTransactionType,
    InvalidAmount,
    InvalidQuantity,
    InvalidInstalments,
    EmptyFrequency,
    EmptyStatus,
    EmptyStepUp,
    EmptySipType,
    EmptyPayload,
    OutOfMemory,
};

/// Parsed success payload for `GET /mf/orders` that retains response-body backing.
pub const MfOrdersSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.MfOrder));

/// Parsed success payload for `GET /mf/orders/{order_id}` that retains response-body backing.
pub const MfOrderSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.MfOrder));

/// Parsed success payload for MF order mutation APIs that retains response-body backing.
pub const MfOrderMutationSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.MfOrderMutationData));

/// Parsed success payload for `GET /mf/sips` that retains response-body backing.
pub const MfSipsSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.MfSip));

/// Parsed success payload for `GET /mf/sips/{sip_id}` that retains response-body backing.
pub const MfSipSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.MfSip));

/// Parsed success payload for MF SIP mutation APIs that retains response-body backing.
pub const MfSipMutationSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.MfSipMutationData));

/// Parsed success payload for `GET /mf/holdings` that retains response-body backing.
pub const MfHoldingsSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const models.MfHolding));

/// Parsed success payload for `GET /mf/holdings/{isin}` that retains response-body backing.
pub const MfHoldingInfoSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.MfHoldingBreakdown));

/// Parsed success payload for `GET /mf/allotments` that retains response-body backing.
pub const MfAllotmentsSuccess = http.OwnedParsed(envelope.SuccessEnvelope([]const []const u8));

/// Parsed success payload for `GET /mf/instruments/{tradingsymbol}` that retains response-body backing.
pub const MfInstrumentInfoSuccess = http.OwnedParsed(envelope.SuccessEnvelope(models.MfInstrumentInfo));

pub const MfOrdersResult = union(enum) {
    success: MfOrdersSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfOrdersResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfOrderResult = union(enum) {
    success: MfOrderSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfOrderResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfOrderMutationResult = union(enum) {
    success: MfOrderMutationSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfOrderMutationResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfSipsResult = union(enum) {
    success: MfSipsSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfSipsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfSipResult = union(enum) {
    success: MfSipSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfSipResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfSipMutationResult = union(enum) {
    success: MfSipMutationSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfSipMutationResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfHoldingsResult = union(enum) {
    success: MfHoldingsSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfHoldingsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfHoldingInfoResult = union(enum) {
    success: MfHoldingInfoSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfHoldingInfoResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfAllotmentsResult = union(enum) {
    success: MfAllotmentsSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfAllotmentsResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

pub const MfInstrumentInfoResult = union(enum) {
    success: MfInstrumentInfoSuccess,
    api_error: errors.ApiError,

    pub fn deinit(self: MfInstrumentInfoResult, allocator: std.mem.Allocator) void {
        switch (self) {
            .success => |value| value.deinit(allocator),
            .api_error => |value| value.deinit(allocator),
        }
    }
};

/// Request metadata for `GET /mf/orders`.
pub fn listOrdersRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.orders };
}

/// Build a request spec for `GET /mf/orders`.
pub fn listOrdersRequestSpec() transport.RequestSpec {
    return .{ .options = listOrdersRequestOptions(), .response_format = .json };
}

/// Request metadata for `GET /mf/orders/{order_id}`.
pub fn getOrderRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.orders };
}

/// Build a request spec for `GET /mf/orders/{order_id}`.
pub fn getOrderRequestSpec(path: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .get, .path = path }, .response_format = .json };
}

/// Request metadata for `POST /mf/orders`.
pub fn placeOrderRequestOptions() transport.RequestOptions {
    return .{ .method = .post, .path = Paths.orders };
}

/// Build a request spec for `POST /mf/orders`.
pub fn placeOrderRequestSpec(form: []const u8) transport.RequestSpec {
    return .{ .options = placeOrderRequestOptions(), .body = .{ .form = form }, .response_format = .json };
}

/// Request metadata for `DELETE /mf/orders/{order_id}`.
pub fn cancelOrderRequestOptions() transport.RequestOptions {
    return .{ .method = .delete, .path = Paths.orders };
}

/// Build a request spec for `DELETE /mf/orders/{order_id}`.
pub fn cancelOrderRequestSpec(path: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .delete, .path = path }, .response_format = .json };
}

/// Request metadata for `GET /mf/sips`.
pub fn listSipsRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.sips };
}

/// Build a request spec for `GET /mf/sips`.
pub fn listSipsRequestSpec() transport.RequestSpec {
    return .{ .options = listSipsRequestOptions(), .response_format = .json };
}

/// Request metadata for `GET /mf/sips/{sip_id}`.
pub fn getSipRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.sips };
}

/// Build a request spec for `GET /mf/sips/{sip_id}`.
pub fn getSipRequestSpec(path: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .get, .path = path }, .response_format = .json };
}

/// Request metadata for `POST /mf/sips`.
pub fn createSipRequestOptions() transport.RequestOptions {
    return .{ .method = .post, .path = Paths.sips };
}

/// Build a request spec for `POST /mf/sips`.
pub fn createSipRequestSpec(form: []const u8) transport.RequestSpec {
    return .{ .options = createSipRequestOptions(), .body = .{ .form = form }, .response_format = .json };
}

/// Request metadata for `PUT /mf/sips/{sip_id}`.
pub fn modifySipRequestOptions() transport.RequestOptions {
    return .{ .method = .put, .path = Paths.sips };
}

/// Build a request spec for `PUT /mf/sips/{sip_id}`.
pub fn modifySipRequestSpec(path: []const u8, form: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .put, .path = path }, .body = .{ .form = form }, .response_format = .json };
}

/// Request metadata for `DELETE /mf/sips/{sip_id}`.
pub fn cancelSipRequestOptions() transport.RequestOptions {
    return .{ .method = .delete, .path = Paths.sips };
}

/// Build a request spec for `DELETE /mf/sips/{sip_id}`.
pub fn cancelSipRequestSpec(path: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .delete, .path = path }, .response_format = .json };
}

/// Request metadata for `GET /mf/holdings`.
pub fn holdingsRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.holdings };
}

/// Build a request spec for `GET /mf/holdings`.
pub fn holdingsRequestSpec() transport.RequestSpec {
    return .{ .options = holdingsRequestOptions(), .response_format = .json };
}

/// Request metadata for `GET /mf/holdings/{isin}`.
pub fn holdingInfoRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.holdings };
}

/// Build a request spec for `GET /mf/holdings/{isin}`.
pub fn holdingInfoRequestSpec(path: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .get, .path = path }, .response_format = .json };
}

/// Request metadata for `GET /mf/allotments`.
pub fn allotmentsRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.allotments };
}

/// Build a request spec for `GET /mf/allotments`.
pub fn allotmentsRequestSpec() transport.RequestSpec {
    return .{ .options = allotmentsRequestOptions(), .response_format = .json };
}

/// Request metadata for `GET /mf/instruments/{tradingsymbol}`.
pub fn instrumentInfoRequestOptions() transport.RequestOptions {
    return .{ .method = .get, .path = Paths.instruments };
}

/// Build a request spec for `GET /mf/instruments/{tradingsymbol}`.
pub fn instrumentInfoRequestSpec(path: []const u8) transport.RequestSpec {
    return .{ .options = .{ .method = .get, .path = path }, .response_format = .json };
}

/// Builds `/mf/orders/{order_id}` path.
/// Caller owns returned slice and must free it with the same allocator.
pub fn orderPath(allocator: std.mem.Allocator, order_id: []const u8) PathError![]u8 {
    if (order_id.len == 0) return error.InvalidOrderId;
    return std.fmt.allocPrint(allocator, "/mf/orders/{s}", .{order_id});
}

/// Builds `/mf/sips/{sip_id}` path.
/// Caller owns returned slice and must free it with the same allocator.
pub fn sipPath(allocator: std.mem.Allocator, sip_id: []const u8) PathError![]u8 {
    if (sip_id.len == 0) return error.InvalidSipId;
    return std.fmt.allocPrint(allocator, "/mf/sips/{s}", .{sip_id});
}

/// Builds `/mf/holdings/{isin}` path.
/// Caller owns returned slice and must free it with the same allocator.
pub fn holdingInfoPath(allocator: std.mem.Allocator, isin: []const u8) PathError![]u8 {
    if (std.mem.trim(u8, isin, " ").len == 0) return error.EmptyIsin;
    return std.fmt.allocPrint(allocator, "/mf/holdings/{s}", .{std.mem.trim(u8, isin, " ")});
}

/// Builds `/mf/instruments/{tradingsymbol}` path.
/// Caller owns returned slice and must free it with the same allocator.
pub fn instrumentInfoPath(allocator: std.mem.Allocator, tradingsymbol: []const u8) PathError![]u8 {
    if (std.mem.trim(u8, tradingsymbol, " ").len == 0) return error.EmptyTradingsymbol;
    return std.fmt.allocPrint(allocator, "/mf/instruments/{s}", .{std.mem.trim(u8, tradingsymbol, " ")});
}

/// Executes `GET /mf/orders` and decodes either success payload or owned API error.
pub fn executeListOrders(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfOrdersResult {
    return decodeMfOrdersExecuted(client.allocator, try client.execute(runtime_client, listOrdersRequestSpec()));
}

/// Executes `GET /mf/orders/{order_id}` and decodes either success payload or owned API error.
pub fn executeGetOrder(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfOrderResult {
    return decodeMfOrderExecuted(client.allocator, try client.execute(runtime_client, getOrderRequestSpec(path)));
}

/// Executes `POST /mf/orders` and decodes either success payload or owned API error.
pub fn executePlaceOrder(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfOrderMutationResult {
    return decodeMfOrderMutationExecuted(client.allocator, try client.execute(runtime_client, placeOrderRequestSpec(form)));
}

/// Executes `DELETE /mf/orders/{order_id}` and decodes either success payload or owned API error.
pub fn executeCancelOrder(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfOrderMutationResult {
    return decodeMfOrderMutationExecuted(client.allocator, try client.execute(runtime_client, cancelOrderRequestSpec(path)));
}

/// Executes `GET /mf/sips` and decodes either success payload or owned API error.
pub fn executeListSips(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfSipsResult {
    return decodeMfSipsExecuted(client.allocator, try client.execute(runtime_client, listSipsRequestSpec()));
}

/// Executes `GET /mf/sips/{sip_id}` and decodes either success payload or owned API error.
pub fn executeGetSip(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfSipResult {
    return decodeMfSipExecuted(client.allocator, try client.execute(runtime_client, getSipRequestSpec(path)));
}

/// Executes `POST /mf/sips` and decodes either success payload or owned API error.
pub fn executeCreateSip(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfSipMutationResult {
    return decodeMfSipMutationExecuted(client.allocator, try client.execute(runtime_client, createSipRequestSpec(form)));
}

/// Executes `PUT /mf/sips/{sip_id}` and decodes either success payload or owned API error.
pub fn executeModifySip(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
    form: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfSipMutationResult {
    return decodeMfSipMutationExecuted(client.allocator, try client.execute(runtime_client, modifySipRequestSpec(path, form)));
}

/// Executes `DELETE /mf/sips/{sip_id}` and decodes either success payload or owned API error.
pub fn executeCancelSip(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfSipMutationResult {
    return decodeMfSipMutationExecuted(client.allocator, try client.execute(runtime_client, cancelSipRequestSpec(path)));
}

/// Executes `GET /mf/holdings` and decodes either success payload or owned API error.
pub fn executeHoldings(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfHoldingsResult {
    return decodeMfHoldingsExecuted(client.allocator, try client.execute(runtime_client, holdingsRequestSpec()));
}

/// Executes `GET /mf/holdings/{isin}` and decodes either success payload or owned API error.
pub fn executeHoldingInfo(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfHoldingInfoResult {
    return decodeMfHoldingInfoExecuted(client.allocator, try client.execute(runtime_client, holdingInfoRequestSpec(path)));
}

/// Executes `GET /mf/allotments` and decodes either success payload or owned API error.
pub fn executeAllotments(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfAllotmentsResult {
    return decodeMfAllotmentsExecuted(client.allocator, try client.execute(runtime_client, allotmentsRequestSpec()));
}

/// Executes `GET /mf/instruments/{tradingsymbol}` and decodes either success payload or owned API error.
pub fn executeInstrumentInfo(
    client: client_mod.Client,
    runtime_client: *std.http.Client,
    path: []const u8,
) (client_mod.ExecuteRequestError || http.DecodeResponseError)!MfInstrumentInfoResult {
    return decodeMfInstrumentInfoExecuted(client.allocator, try client.execute(runtime_client, instrumentInfoRequestSpec(path)));
}

/// Builds form body for `POST /mf/orders`.
/// Caller owns returned slice and must free it with the same allocator.
pub fn buildOrderForm(allocator: std.mem.Allocator, form: MfOrderForm) FormError![]u8 {
    if (form.tradingsymbol.len == 0) return error.EmptyTradingsymbol;
    if (form.transaction_type.len == 0) return error.EmptyTransactionType;
    if (form.amount <= 0) return error.InvalidAmount;
    if (form.quantity) |quantity| {
        if (quantity <= 0) return error.InvalidQuantity;
    }

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendField(allocator, &buffer, "tradingsymbol", form.tradingsymbol, false);
    try appendField(allocator, &buffer, "transaction_type", form.transaction_type, true);

    const amount = try std.fmt.allocPrint(allocator, "{d}", .{form.amount});
    defer allocator.free(amount);
    try appendField(allocator, &buffer, "amount", amount, true);

    if (form.quantity) |quantity| {
        const quantity_str = try std.fmt.allocPrint(allocator, "{d}", .{quantity});
        defer allocator.free(quantity_str);
        try appendField(allocator, &buffer, "quantity", quantity_str, true);
    }

    if (form.tag) |tag| {
        try appendField(allocator, &buffer, "tag", tag, true);
    }

    return buffer.toOwnedSlice(allocator);
}

/// Builds form body for `POST /mf/sips`.
/// Caller owns returned slice and must free it with the same allocator.
pub fn buildSipForm(allocator: std.mem.Allocator, form: MfSipForm) FormError![]u8 {
    if (form.tradingsymbol.len == 0) return error.EmptyTradingsymbol;
    if (form.amount <= 0) return error.InvalidAmount;
    if (form.instalments == 0) return error.InvalidInstalments;
    if (form.frequency.len == 0) return error.EmptyFrequency;

    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    try appendField(allocator, &buffer, "tradingsymbol", form.tradingsymbol, false);

    const amount = try std.fmt.allocPrint(allocator, "{d}", .{form.amount});
    defer allocator.free(amount);
    try appendField(allocator, &buffer, "amount", amount, true);

    const instalments = try std.fmt.allocPrint(allocator, "{d}", .{form.instalments});
    defer allocator.free(instalments);
    try appendField(allocator, &buffer, "instalments", instalments, true);

    try appendField(allocator, &buffer, "frequency", form.frequency, true);

    if (form.initial_amount) |initial_amount| {
        const initial_amount_str = try std.fmt.allocPrint(allocator, "{d}", .{initial_amount});
        defer allocator.free(initial_amount_str);
        try appendField(allocator, &buffer, "initial_amount", initial_amount_str, true);
    }

    if (form.instalment_day) |instalment_day| {
        const instalment_day_str = try std.fmt.allocPrint(allocator, "{d}", .{instalment_day});
        defer allocator.free(instalment_day_str);
        try appendField(allocator, &buffer, "instalment_day", instalment_day_str, true);
    }

    if (form.trigger_price) |trigger_price| {
        const trigger_price_str = try std.fmt.allocPrint(allocator, "{d}", .{trigger_price});
        defer allocator.free(trigger_price_str);
        try appendField(allocator, &buffer, "trigger_price", trigger_price_str, true);
    }

    if (form.step_up) |step_up| {
        if (step_up.len == 0) return error.EmptyStepUp;
        try appendField(allocator, &buffer, "step_up", step_up, true);
    }

    if (form.sip_type) |sip_type| {
        if (sip_type.len == 0) return error.EmptySipType;
        try appendField(allocator, &buffer, "sip_type", sip_type, true);
    }

    if (form.tag) |tag| {
        try appendField(allocator, &buffer, "tag", tag, true);
    }

    return buffer.toOwnedSlice(allocator);
}

/// Builds form body for `PUT /mf/sips/{sip_id}`.
/// Caller owns returned slice and must free it with the same allocator.
pub fn buildSipModifyForm(allocator: std.mem.Allocator, form: MfSipModifyForm) FormError![]u8 {
    var buffer: std.ArrayList(u8) = .empty;
    defer buffer.deinit(allocator);

    var has_fields = false;

    if (form.amount) |amount| {
        if (amount <= 0) return error.InvalidAmount;
        const amount_str = try std.fmt.allocPrint(allocator, "{d}", .{amount});
        defer allocator.free(amount_str);
        try appendField(allocator, &buffer, "amount", amount_str, has_fields);
        has_fields = true;
    }

    if (form.status) |status| {
        if (status.len == 0) return error.EmptyStatus;
        try appendField(allocator, &buffer, "status", status, has_fields);
        has_fields = true;
    }

    if (form.instalments) |instalments| {
        if (instalments == 0) return error.InvalidInstalments;
        const instalments_str = try std.fmt.allocPrint(allocator, "{d}", .{instalments});
        defer allocator.free(instalments_str);
        try appendField(allocator, &buffer, "instalments", instalments_str, has_fields);
        has_fields = true;
    }

    if (form.frequency) |frequency| {
        if (frequency.len == 0) return error.EmptyFrequency;
        try appendField(allocator, &buffer, "frequency", frequency, has_fields);
        has_fields = true;
    }

    if (form.instalment_day) |instalment_day| {
        const instalment_day_str = try std.fmt.allocPrint(allocator, "{d}", .{instalment_day});
        defer allocator.free(instalment_day_str);
        try appendField(allocator, &buffer, "instalment_day", instalment_day_str, has_fields);
        has_fields = true;
    }

    if (form.step_up) |step_up| {
        if (step_up.len == 0) return error.EmptyStepUp;
        try appendField(allocator, &buffer, "step_up", step_up, has_fields);
        has_fields = true;
    }

    if (!has_fields) return error.EmptyPayload;
    return buffer.toOwnedSlice(allocator);
}

/// Parses `GET /mf/orders` success payload.
pub fn parseOrders(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.MfOrder)) {
    return envelope.parseSuccessEnvelope([]const models.MfOrder, allocator, payload);
}

/// Parses `GET /mf/orders/{order_id}` success payload.
pub fn parseOrder(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.MfOrder)) {
    return envelope.parseSuccessEnvelope(models.MfOrder, allocator, payload);
}

/// Parses order mutation success payload.
pub fn parseOrderMutation(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.MfOrderMutationData)) {
    return envelope.parseSuccessEnvelope(models.MfOrderMutationData, allocator, payload);
}

/// Parses `GET /mf/sips` success payload.
pub fn parseSips(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.MfSip)) {
    return envelope.parseSuccessEnvelope([]const models.MfSip, allocator, payload);
}

/// Parses `GET /mf/sips/{sip_id}` success payload.
pub fn parseSip(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.MfSip)) {
    return envelope.parseSuccessEnvelope(models.MfSip, allocator, payload);
}

/// Parses SIP mutation success payload.
pub fn parseSipMutation(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.MfSipMutationData)) {
    return envelope.parseSuccessEnvelope(models.MfSipMutationData, allocator, payload);
}

/// Parses `GET /mf/holdings` success payload.
pub fn parseHoldings(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const models.MfHolding)) {
    return envelope.parseSuccessEnvelope([]const models.MfHolding, allocator, payload);
}

/// Parses `GET /mf/holdings/{isin}` success payload.
pub fn parseHoldingInfo(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.MfHoldingBreakdown)) {
    return envelope.parseSuccessEnvelope(models.MfHoldingBreakdown, allocator, payload);
}

/// Parses `GET /mf/allotments` success payload.
pub fn parseAllotments(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope([]const []const u8)) {
    return envelope.parseSuccessEnvelope([]const []const u8, allocator, payload);
}

/// Parses `GET /mf/instruments/{tradingsymbol}` success payload.
pub fn parseInstrumentInfo(
    allocator: std.mem.Allocator,
    payload: []const u8,
) !std.json.Parsed(envelope.SuccessEnvelope(models.MfInstrumentInfo)) {
    return envelope.parseSuccessEnvelope(models.MfInstrumentInfo, allocator, payload);
}

fn decodeMfOrdersExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfOrdersResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.MfOrder, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfOrderExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfOrderResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.MfOrder, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfOrderMutationExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfOrderMutationResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.MfOrderMutationData, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfSipsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfSipsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.MfSip, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfSipExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfSipResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.MfSip, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfSipMutationExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfSipMutationResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.MfSipMutationData, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfHoldingsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfHoldingsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const models.MfHolding, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfHoldingInfoExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfHoldingInfoResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.MfHoldingBreakdown, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfAllotmentsExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfAllotmentsResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope([]const []const u8, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn decodeMfInstrumentInfoExecuted(
    allocator: std.mem.Allocator,
    executed: http.ExecutedResponse,
) http.DecodeResponseError!MfInstrumentInfoResult {
    return switch (executed) {
        .success => |response| .{ .success = try http.parseOwnedSuccessEnvelope(models.MfInstrumentInfo, allocator, response) },
        .api_error => |api_error| .{ .api_error = api_error },
    };
}

fn appendField(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), key: []const u8, value: []const u8, prefix_ampersand: bool) !void {
    if (prefix_ampersand) try buffer.append(allocator, '&');
    try percentEncodeInto(allocator, buffer, key);
    try buffer.append(allocator, '=');
    try percentEncodeInto(allocator, buffer, value);
}

fn percentEncodeInto(allocator: std.mem.Allocator, buffer: *std.ArrayList(u8), value: []const u8) !void {
    for (value) |ch| {
        if (isUnreserved(ch)) {
            try buffer.append(allocator, ch);
            continue;
        }

        var encoded: [3]u8 = undefined;
        encoded[0] = '%';
        encoded[1] = "0123456789ABCDEF"[ch >> 4];
        encoded[2] = "0123456789ABCDEF"[ch & 0x0f];
        try buffer.appendSlice(allocator, &encoded);
    }
}

fn isUnreserved(ch: u8) bool {
    return (ch >= 'a' and ch <= 'z') or
        (ch >= 'A' and ch <= 'Z') or
        (ch >= '0' and ch <= '9') or
        ch == '-' or ch == '.' or ch == '_' or ch == '~';
}

test "mf request metadata path and request specs" {
    const list_orders = listOrdersRequestOptions();
    try std.testing.expectEqual(transport.Method.get, list_orders.method);
    try std.testing.expectEqualStrings(Paths.orders, list_orders.path);
    const list_orders_spec = listOrdersRequestSpec();
    try std.testing.expectEqual(transport.ResponseFormat.json, list_orders_spec.response_format);

    const place_order_spec = placeOrderRequestSpec("tradingsymbol=INF090I01NY8");
    try std.testing.expectEqualStrings("application/x-www-form-urlencoded", place_order_spec.contentType().?);

    const create_sip = createSipRequestOptions();
    try std.testing.expectEqual(transport.Method.post, create_sip.method);
    try std.testing.expectEqualStrings(Paths.sips, create_sip.path);
    const modify_sip_spec = modifySipRequestSpec("/mf/sips/sip_100", "status=active");
    try std.testing.expectEqualStrings("/mf/sips/sip_100", modify_sip_spec.options.path);

    const holdings_spec = holdingsRequestSpec();
    try std.testing.expectEqual(transport.Method.get, holdings_spec.options.method);

    const holding_info_spec = holdingInfoRequestSpec("/mf/holdings/INF209K01UN8");
    try std.testing.expectEqualStrings("/mf/holdings/INF209K01UN8", holding_info_spec.options.path);

    const allotments_spec = allotmentsRequestSpec();
    try std.testing.expectEqualStrings(Paths.allotments, allotments_spec.options.path);

    const holding_path = try holdingInfoPath(std.testing.allocator, " INF209K01UN8 ");
    defer std.testing.allocator.free(holding_path);
    try std.testing.expectEqualStrings("/mf/holdings/INF209K01UN8", holding_path);

    const instrument_path = try instrumentInfoPath(std.testing.allocator, " INF090I01NY8 ");
    defer std.testing.allocator.free(instrument_path);
    try std.testing.expectEqualStrings("/mf/instruments/INF090I01NY8", instrument_path);
}

test "mf form builders encode required and optional fields" {
    const order_form = try buildOrderForm(std.testing.allocator, .{
        .tradingsymbol = "INF090I01NY8",
        .transaction_type = "BUY",
        .amount = 5000,
        .tag = "long term",
    });
    defer std.testing.allocator.free(order_form);
    try std.testing.expect(std.mem.indexOf(u8, order_form, "tradingsymbol=INF090I01NY8") != null);
    try std.testing.expect(std.mem.indexOf(u8, order_form, "tag=long%20term") != null);

    const sip_form = try buildSipForm(std.testing.allocator, .{
        .tradingsymbol = "INF090I01NY8",
        .amount = 2000,
        .instalments = 24,
        .frequency = "monthly",
        .instalment_day = 5,
        .trigger_price = 0,
        .step_up = "01-01:10",
        .sip_type = "sip",
    });
    defer std.testing.allocator.free(sip_form);
    try std.testing.expect(std.mem.indexOf(u8, sip_form, "instalments=24") != null);
    try std.testing.expect(std.mem.indexOf(u8, sip_form, "instalment_day=5") != null);
    try std.testing.expect(std.mem.indexOf(u8, sip_form, "trigger_price=0") != null);
    try std.testing.expect(std.mem.indexOf(u8, sip_form, "step_up=01-01%3A10") != null);
    try std.testing.expect(std.mem.indexOf(u8, sip_form, "sip_type=sip") != null);

    const modify_form = try buildSipModifyForm(std.testing.allocator, .{
        .status = "active",
        .amount = 2500,
        .step_up = "15-02:10",
    });
    defer std.testing.allocator.free(modify_form);
    try std.testing.expectEqualStrings("amount=2500&status=active&step_up=15-02%3A10", modify_form);
}

test "mf parsers decode orders sips and holdings envelopes" {
    const orders_payload =
        \\{"status":"success","data":[{"order_id":"2401010001","tradingsymbol":"INF090I01NY8","transaction_type":"BUY","status":"COMPLETE","amount":5000}]}
    ;

    const orders = try parseOrders(std.testing.allocator, orders_payload);
    defer orders.deinit();
    try std.testing.expectEqual(@as(usize, 1), orders.value.data.len);
    try std.testing.expectEqualStrings("2401010001", orders.value.data[0].order_id);

    const sips_payload =
        \\{"status":"success","data":[{"sip_id":"sip_100","tradingsymbol":"INF090I01NY8","status":"active","instalments":24,"amount":2000}]}
    ;

    const sips = try parseSips(std.testing.allocator, sips_payload);
    defer sips.deinit();
    try std.testing.expectEqual(@as(usize, 1), sips.value.data.len);
    try std.testing.expectEqualStrings("sip_100", sips.value.data[0].sip_id);

    const holdings_payload =
        \\{"status":"success","data":[{"tradingsymbol":"INF090I01NY8","folio":"12345","quantity":10.5,"average_price":47.5}]}
    ;

    const holdings = try parseHoldings(std.testing.allocator, holdings_payload);
    defer holdings.deinit();
    try std.testing.expectEqual(@as(usize, 1), holdings.value.data.len);
    try std.testing.expectEqualStrings("INF090I01NY8", holdings.value.data[0].tradingsymbol);

    const holding_info_payload =
        \\{"status":"success","data":[{"fund":"Sample Fund","tradingsymbol":"INF090I01NY8","average_price":10.5,"amount":1000,"folio":"12345","quantity":100}]}
    ;
    const holding_info = try parseHoldingInfo(std.testing.allocator, holding_info_payload);
    defer holding_info.deinit();
    try std.testing.expectEqual(@as(usize, 1), holding_info.value.data.len);
    try std.testing.expectEqualStrings("Sample Fund", holding_info.value.data[0].fund.?);
    try std.testing.expectEqualStrings("INF090I01NY8", holding_info.value.data[0].tradingsymbol.?);

    const allotments_payload =
        \\{"status":"success","data":["INF090I01NY8","INF179K01VY8"]}
    ;
    const allotments = try parseAllotments(std.testing.allocator, allotments_payload);
    defer allotments.deinit();
    try std.testing.expectEqual(@as(usize, 2), allotments.value.data.len);
}

test "decodeMfOrdersExecuted decodes owned success payload" {
    const body = try std.testing.allocator.dupe(
        u8,
        "{\"status\":\"success\",\"data\":[{\"order_id\":\"2401010001\",\"tradingsymbol\":\"INF090I01NY8\",\"transaction_type\":\"BUY\",\"status\":\"COMPLETE\",\"amount\":5000}]}",
    );
    const content_type = try std.testing.allocator.dupe(u8, "application/json");

    const result = try decodeMfOrdersExecuted(std.testing.allocator, .{
        .success = .{ .status = 200, .content_type = content_type, .body = body },
    });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .success);
    try std.testing.expectEqual(@as(usize, 1), result.success.parsed.value.data.len);
    try std.testing.expectEqualStrings("2401010001", result.success.parsed.value.data[0].order_id);
}

test "decodeMfSipMutationExecuted preserves owned api error" {
    const api_error = try errors.ApiError.fromEnvelope(std.testing.allocator, .{
        .status = "error",
        .message = "SIP not found",
        .error_type = "GeneralException",
    }, 404);

    const result = try decodeMfSipMutationExecuted(std.testing.allocator, .{ .api_error = api_error });
    defer result.deinit(std.testing.allocator);

    try std.testing.expect(result == .api_error);
    try std.testing.expectEqualStrings("SIP not found", result.api_error.message);
}
