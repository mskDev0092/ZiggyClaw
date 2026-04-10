const std = @import("std");
const core = @import("core");
const registry = @import("registry.zig");

fn isPathSafe(path: []const u8) bool {
    if (std.mem.startsWith(u8, path, "/")) return false;
    if (std.mem.indexOf(u8, path, "..") != null) return false;
    return true;
}

fn resolveAndCheckSymlink(allocator: std.mem.Allocator, path: []const u8) ?[]const u8 {
    var cwd = std.fs.cwd();
    const real_path = cwd.realpathAlloc(allocator, path) catch return null;
    const abs_cwd = cwd.realpathAlloc(allocator, ".") catch {
        allocator.free(real_path);
        return null;
    };
    defer allocator.free(abs_cwd);
    if (!std.mem.startsWith(u8, real_path, abs_cwd)) {
        allocator.free(real_path);
        return null;
    }
    return real_path;
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    const path = std.mem.trim(u8, params, " \n\r");
    if (path.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: file_read <filename>" };
    }

    if (!isPathSafe(path)) {
        return .{ .success = false, .data = "", .error_msg = "Cannot read files outside workspace" };
    }

    const resolved = resolveAndCheckSymlink(ctx.allocator, path);
    defer if (resolved) |p| ctx.allocator.free(p);

    if (resolved == null) {
        return .{ .success = false, .data = "", .error_msg = "Symlink points outside workspace or path invalid" };
    }

    var file = std.fs.cwd().openFile(path, .{}) catch |err|
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    defer file.close();

    const file_size = file.getEndPos() catch 0;
    if (file_size > 65536) {
        return .{ .success = false, .data = "", .error_msg = "File too large (max 64KB)" };
    }

    const content = file.readToEndAlloc(ctx.allocator, 65536) catch |err|
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };

    return .{ .success = true, .data = content, .owned = true };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "file_read",
        .description = "Read file contents (relative paths only, max 64KB)",
        .execute = execute,
    };
}
