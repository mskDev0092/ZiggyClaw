const std = @import("std");
const core = @import("core");

fn isUrlSafe(url: []const u8) bool {
    if (url.len == 0) return false;
    if (std.mem.indexOf(u8, url, "javascript:") != null) return false;
    if (std.mem.indexOf(u8, url, "data:") != null) return false;
    return true;
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    var url = std.mem.trim(u8, params, " \n\r");

    if (url.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: web_get <url>" };
    }

    if (!isUrlSafe(url)) {
        return .{ .success = false, .data = "", .error_msg = "URL not allowed" };
    }

    if (std.mem.indexOf(u8, url, "://") == null) {
        url = std.fmt.allocPrint(ctx.allocator, "https://{s}", .{url}) catch {
            return .{ .success = false, .data = "", .error_msg = "URL formatting failed" };
        };
    }

    var client: std.http.Client = .{ .allocator = ctx.allocator };
    defer client.deinit();

    var header_buf: [4096]u8 = undefined;

    const uri = std.Uri.parse(url) catch {
        return .{ .success = false, .data = "", .error_msg = "Invalid URL format" };
    };

    var req = client.open(.GET, uri, .{
        .server_header_buffer = &header_buf,
    }) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer req.deinit();

    req.send() catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };

    req.finish() catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };

    req.wait() catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };

    const body = req.reader().readAllAlloc(ctx.allocator, 1024 * 1024) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };

    return .{ .success = true, .data = body, .owned = true };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "web_get",
        .description = "Make HTTP GET requests to fetch raw web content. Usage: web_get <url>",
        .execute = execute,
    };
}
