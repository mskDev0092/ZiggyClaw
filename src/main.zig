const std = @import("std");
const cli = @import("cli");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.debug.print("\n🦞⚡ ZiggyClaw (Zig-native OpenClaw clone)\n", .{});
    std.debug.print("Fast. Safe. Claws Deep.\n\n", .{});

    try cli.run(allocator);
}
