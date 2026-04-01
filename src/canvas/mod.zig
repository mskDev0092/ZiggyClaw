// All four files are identical minimal stubs:
const std = @import("std");
pub fn init() void {
    std.debug.print("{s} initialized (stub)\n", .{@typeName(@This())});
}
