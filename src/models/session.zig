//! Session/auth-domain wire models.

/// User metadata nested in session and profile responses.
pub const UserMeta = struct {
    demat_consent: ?[]const u8 = null,
};

/// Session payload returned by `POST /session/token`.
pub const UserSession = struct {
    user_id: []const u8,
    user_name: []const u8,
    user_shortname: []const u8,
    email: []const u8,
    user_type: []const u8,
    broker: []const u8,
    exchanges: [][]const u8,
    products: [][]const u8,
    order_types: [][]const u8,
    avatar_url: ?[]const u8 = null,
    meta: ?UserMeta = null,

    api_key: []const u8,
    public_token: []const u8,
    access_token: []const u8,
    refresh_token: []const u8,
    login_time: []const u8,
};

/// Token payload returned by `POST /session/refresh_token`.
pub const UserSessionTokens = struct {
    user_id: []const u8,
    access_token: []const u8,
    refresh_token: []const u8,
};
