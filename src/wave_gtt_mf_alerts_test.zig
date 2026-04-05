const std = @import("std");

comptime {
    _ = @import("endpoints/gtt.zig");
    _ = @import("endpoints/mutual_funds.zig");
    _ = @import("endpoints/alerts.zig");
}

test "wave gtt/mf/alerts module smoke" {
    try std.testing.expect(true);
}
