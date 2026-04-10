const std = @import("std");
const core = @import("core");

fn toLower(input: []const u8, allocator: std.mem.Allocator) []const u8 {
    var result = allocator.alloc(u8, input.len) catch return input;
    for (input, 0..) |c, i| {
        if (c >= 'A' and c <= 'Z') {
            result[i] = c + 32;
        } else {
            result[i] = c;
        }
    }
    return result;
}

fn execute(ctx: core.types.ToolContext, args: []const u8) core.types.ToolResult {
    const sep = "\n---\n";
    const sep_idx = std.mem.indexOf(u8, args, sep);

    var search_term: []const u8 = "";
    var search_path: []const u8 = ".";

    if (sep_idx) |idx| {
        search_term = std.mem.trim(u8, args[0..idx], " \n\r");
        search_path = std.mem.trim(u8, args[idx + sep.len ..], " \n\r");
    } else {
        search_term = std.mem.trim(u8, args, " \n\r");
    }

    if (search_term.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: search_files <term>\n---\n<path>" };
    }

    if (std.mem.indexOf(u8, search_path, "..") != null and std.mem.startsWith(u8, search_path, "/")) {
        return .{ .success = false, .data = "", .error_msg = "Invalid path: path traversal not allowed" };
    }

    const search_term_lower = toLower(search_term, ctx.allocator);
    defer ctx.allocator.free(search_term_lower);

    var dir = std.fs.cwd().openDir(if (search_path.len == 0) "." else search_path, .{}) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer dir.close();

    var buf: [32768]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&buf);
    const alloc = fba.allocator();

    var results = std.ArrayList(u8).init(alloc);
    var count: usize = 0;

    var walker = dir.walk(alloc) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer walker.deinit();

    while (walker.next() catch null) |entry| {
        if (entry.kind != .file) continue;

        const file = dir.openFile(entry.path, .{}) catch continue;
        defer file.close();

        const content = file.readToEndAlloc(alloc, 32768) catch continue;

        const content_lower = toLower(content, alloc);
        defer alloc.free(content_lower);

        if (std.mem.indexOf(u8, content_lower, search_term_lower)) |_| {
            results.appendSlice(entry.path) catch break;
            results.append('\n') catch break;
            count += 1;

            if (count >= 50) break;
        }
    }

    if (count == 0) {
        return .{ .success = true, .data = "No matches found", .owned = false };
    }

    const output = alloc.dupe(u8, results.items) catch return .{ .success = false, .data = "", .error_msg = "buffer_full" };
    return .{ .success = true, .data = output, .owned = true };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "search_files",
        .description = "Search files for content (case-insensitive grep)",
        .execute = execute,
    };
}
