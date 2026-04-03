const std = @import("std");
const core = @import("core");

fn execute(ctx: core.types.ToolContext, args: []const u8) core.types.ToolResult {
    _ = ctx;
    const path = std.mem.trim(u8, args, " \n\r");

    const dir_path = if (path.len == 0) "." else path;

    if (std.mem.indexOf(u8, dir_path, "..") != null and std.mem.startsWith(u8, dir_path, "/")) {
        return .{ .success = false, .data = "", .error_msg = "Invalid path: path traversal not allowed" };
    }

    var dir = std.fs.cwd().openDir(dir_path, .{}) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer dir.close();

    var buf: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var result = std.ArrayList(u8).init(alloc);

    var iter = dir.iterate();
    var count: usize = 0;

    while (iter.next() catch null) |entry| {
        const prefix: []const u8 = switch (entry.kind) {
            .file => "file: ",
            .directory => "dir:  ",
            .sym_link => "link: ",
            else => "other:",
        };

        result.appendSlice(prefix) catch break;
        result.appendSlice(entry.name) catch break;
        result.append('\n') catch break;
        count += 1;

        if (count >= 100) break;
    }

    if (count == 0) {
        return .{ .success = true, .data = "(empty directory)", .owned = false };
    }

    const output = alloc.dupe(u8, result.items) catch return .{ .success = false, .data = "", .error_msg = "buffer_full" };
    return .{ .success = true, .data = output, .owned = true };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "list_directory",
        .description = "List directory contents (files, dirs, symlinks)",
        .execute = execute,
    };
}
