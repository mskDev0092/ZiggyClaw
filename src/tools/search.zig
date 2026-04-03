const std = @import("std");
const core = @import("core");

fn execute(ctx: core.types.ToolContext, args: []const u8) core.types.ToolResult {
    _ = ctx;
    const query = std.mem.trim(u8, args, " \n\r");

    if (query.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: search <query>" };
    }

    return .{ .success = false, .data = "", .error_msg = "Search tool: use web_get with search URL like https://duckduckgo.com/?q=your+query" };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "search",
        .description = "Search the web for information",
        .execute = execute,
    };
}
