const std = @import("std");
const core = @import("core");

fn execute(ctx: core.types.ToolContext, args: []const u8) core.types.ToolResult {
    _ = ctx;
    const sep = "\n---\n";
    const sep_idx = std.mem.indexOf(u8, args, sep);

    var pattern: []const u8 = "";
    var search_path: []const u8 = ".";

    if (sep_idx) |idx| {
        pattern = std.mem.trim(u8, args[0..idx], " \n\r");
        search_path = std.mem.trim(u8, args[idx + sep.len ..], " \n\r");
    } else {
        pattern = std.mem.trim(u8, args, " \n\r");
    }

    if (pattern.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: find_files <pattern>\n---\n<path>" };
    }

    if (std.mem.indexOf(u8, search_path, "..") != null and std.mem.startsWith(u8, search_path, "/")) {
        return .{ .success = false, .data = "", .error_msg = "Invalid path: path traversal not allowed" };
    }

    var dir = std.fs.cwd().openDir(if (search_path.len == 0) "." else search_path, .{}) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer dir.close();

    var buf: [8192]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var results = std.ArrayList(u8).init(alloc);
    var count: usize = 0;

    var walker = dir.walk(alloc) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        const basename = std.fs.path.basename(entry.path);
        if (matchesPattern(basename, pattern)) {
            results.appendSlice(entry.path) catch break;
            results.append('\n') catch break;
            count += 1;

            if (count >= 100) break;
        }
    }

    if (count == 0) {
        return .{ .success = true, .data = "No files match the pattern", .owned = false };
    }

    const output = alloc.dupe(u8, results.items) catch return .{ .success = false, .data = "", .error_msg = "buffer_full" };
    return .{ .success = true, .data = output, .owned = true };
}

fn matchesPattern(filename: []const u8, pattern: []const u8) bool {
    var i: usize = 0;
    var j: usize = 0;

    while (i < filename.len and j < pattern.len) {
        if (pattern[j] == '*') {
            if (j + 1 >= pattern.len) return true;
            j += 1;
            while (i < filename.len and filename[i] != pattern[j]) {
                i += 1;
            }
        } else if (pattern[j] == '?') {
            i += 1;
            j += 1;
        } else if (filename[i] == pattern[j]) {
            i += 1;
            j += 1;
        } else {
            return false;
        }
    }

    return j == pattern.len;
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "find_files",
        .description = "Find files by name pattern (* and ? wildcards)",
        .execute = execute,
    };
}
