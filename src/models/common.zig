//! Shared wire and diagnostic models.

/// Minimal client state used for smoke tests and diagnostics.
pub const ClientState = struct {
    api_key: []const u8,
    has_access_token: bool,
    root_url: []const u8,
    user_agent: []const u8,
};
