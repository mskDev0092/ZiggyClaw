const std = @import("std");
const core = @import("core");

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    // Format: "filename\n---\n<search>\n---\n<replace>"
    var search_start: ?usize = null;
    var replace_start: ?usize = null;

    var i: usize = 0;
    var sep_count: usize = 0;

    while (i < params.len) {
        if (i + 4 <= params.len and std.mem.eql(u8, params[i .. i + 4], "\n---")) {
            sep_count += 1;
            if (sep_count == 1) {
                search_start = i + 4;
            } else if (sep_count == 2) {
                replace_start = i + 4;
            }
            i += 4;
            continue;
        }
        i += 1;
    }

    if (search_start == null or replace_start == null) {
        return .{ .success = false, .data = "", .error_msg = "Usage: edit_file <filename>\n---\n<search>\n---\n<replace>" };
    }

    const filename = std.mem.trim(u8, params[0 .. search_start.? - 4], " \n\r");
    const search_str = params[search_start.? .. replace_start.? - 4];
    const replace_str = params[replace_start.?..];

    if (filename.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Filename cannot be empty" };
    }

    if (std.mem.indexOf(u8, filename, "..") != null or std.mem.startsWith(u8, filename, "/")) {
        return .{ .success = false, .data = "", .error_msg = "Invalid filename: path traversal not allowed" };
    }

    const original = std.fs.cwd().readFileAlloc(ctx.allocator, filename, 65536) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer ctx.allocator.free(original);

    const replace_idx = std.mem.indexOf(u8, original, search_str);
    if (replace_idx == null) {
        return .{ .success = false, .data = "", .error_msg = "Search string not found in file" };
    }

    var new_content = std.ArrayList(u8).init(ctx.allocator);
    new_content.appendSlice(original[0..replace_idx.?]) catch return .{ .success = false, .data = "", .error_msg = "alloc" };
    new_content.appendSlice(replace_str) catch return .{ .success = false, .data = "", .error_msg = "alloc" };
    new_content.appendSlice(original[replace_idx.? + search_str.len ..]) catch return .{ .success = false, .data = "", .error_msg = "alloc" };

    const file = std.fs.cwd().createFile(filename, .{}) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer file.close();

    file.writeAll(new_content.items) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };

    return .{ .success = true, .data = "File edited successfully", .owned = false };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "edit_file",
        .description = "Search and replace text in a file (first match only)",
        .execute = execute,
    };
}
