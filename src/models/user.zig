//! User-domain response models.

/// Metadata returned by `/user/profile`.
pub const UserMeta = struct {
    demat_consent: ?[]const u8 = null,
};

/// Metadata returned by `/user/profile/full`.
pub const FullUserMeta = struct {
    poa: ?[]const u8 = null,
    silo: ?[]const u8 = null,
    account_blocks: ?[][]const u8 = null,
};

/// Basic user profile returned by `/user/profile`.
pub const Profile = struct {
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
};

/// Bank account metadata included in `/user/profile/full`.
pub const BankAccount = struct {
    bank_name: ?[]const u8 = null,
    name: ?[]const u8 = null,
    branch: ?[]const u8 = null,
    account_type: ?[]const u8 = null,
    account: ?[]const u8 = null,
    ifsc: ?[]const u8 = null,
    primary: bool = false,
};

/// Full user profile returned by `/user/profile/full`.
pub const FullProfile = struct {
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
    phone: ?[]const u8 = null,
    twofa_type: ?[]const u8 = null,
    dp_ids: ?[][]const u8 = null,
    pan: ?[]const u8 = null,
    tags: ?[][]const u8 = null,
    password_timestamp: ?[]const u8 = null,
    twofa_timestamp: ?[]const u8 = null,
    demat_consent: ?bool = null,
    meta: ?FullUserMeta = null,
    bank_accounts: []BankAccount,
};
