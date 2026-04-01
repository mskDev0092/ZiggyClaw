const std = @import("std");

pub fn load() void {
    std.debug.print("Config loaded (port 18789)\n", .{});
}
