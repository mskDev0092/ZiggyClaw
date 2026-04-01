const std = @import("std");
const core = @import("core");
const registry = @import("registry.zig");

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    // params is expected to be a file path
    // For security, we should restrict to certain directories

    // Simple safety: don't allow absolute paths or ../ traversal
    if (std.mem.startsWith(u8, params, "/") or std.mem.indexOf(u8, params, "..") != null) {
        return .{ .success = false, .data = "", .error_msg = "Cannot read files outside workspace" };
    }

    // Read the file
    var file = std.fs.cwd().openFile(params, .{}) catch |err|
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    defer file.close();

    // Limit file size to 64KB for safety
    const file_size = file.getEndPos() catch 0;
    if (file_size > 65536) {
        return .{ .success = false, .data = "", .error_msg = "File too large (max 64KB)" };
    }

    const content = file.readToEndAlloc(ctx.allocator, 65536) catch |err|
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };

    return .{ .success = true, .data = content };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "file_read",
        .description = "Read file contents (relative paths only, max 64KB)",
        .execute = execute,
    };
}
