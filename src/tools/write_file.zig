const std = @import("std");
const core = @import("core");

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    _ = ctx;
    // Format: "filename\n---SEP---\ncontent"
    const sep = "\n---\n";
    const sep_idx = std.mem.indexOf(u8, params, sep);

    if (sep_idx == null) {
        return .{ .success = false, .data = "", .error_msg = "Usage: write_file <filename>\n---\n<content>" };
    }

    const filename = std.mem.trim(u8, params[0..sep_idx.?], " \n\r");
    const content = params[sep_idx.? + sep.len ..];

    if (filename.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Filename cannot be empty" };
    }

    // Security: prevent path traversal
    if (std.mem.indexOf(u8, filename, "..") != null or std.mem.startsWith(u8, filename, "/")) {
        return .{ .success = false, .data = "", .error_msg = "Invalid filename: path traversal not allowed" };
    }

    // Limit content size to 64KB
    if (content.len > 65536) {
        return .{ .success = false, .data = "", .error_msg = "Content too large (max 64KB)" };
    }

    // Create or overwrite file
    const file = std.fs.cwd().createFile(filename, .{}) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer file.close();

    file.writeAll(content) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };

    return .{ .success = true, .data = "File written successfully", .owned = false };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "write_file",
        .description = "Create or overwrite a file with content (relative paths, max 64KB)",
        .execute = execute,
    };
}
