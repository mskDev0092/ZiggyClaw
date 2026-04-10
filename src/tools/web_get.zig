const std = @import("std");
const core = @import("core");

fn isUrlSafe(url: []const u8) bool {
    if (url.len == 0) return false;
    if (std.mem.indexOf(u8, url, "javascript:") != null) return false;
    if (std.mem.indexOf(u8, url, "data:") != null) return false;
    if (std.mem.indexOf(u8, url, "file:") != null) return false;
    return true;
}

fn isPrivateIp(host: []const u8) bool {
    if (std.mem.eql(u8, host, "localhost")) return true;
    if (std.mem.eql(u8, host, "localhost.localdomain")) return true;
    if (std.mem.startsWith(u8, host, "127.")) return true;
    if (std.mem.startsWith(u8, host, "0.0.0.0")) return true;
    if (std.mem.startsWith(u8, host, "10.")) return true;
    if (std.mem.startsWith(u8, host, "192.168.")) return true;
    if (std.mem.startsWith(u8, host, "172.")) {
        if (host.len >= 7) {
            const second = std.fmt.parseInt(u8, host[4..6], 10) catch 0;
            if (second >= 16 and second <= 31) return true;
        }
    }
    if (std.mem.startsWith(u8, host, "169.254.")) return true;
    if (std.mem.startsWith(u8, host, "::1")) return true;
    if (std.mem.startsWith(u8, host, "fc00:")) return true;
    if (std.mem.startsWith(u8, host, "fe80:")) return true;
    return false;
}

fn checkSSRF(url: []const u8) bool {
    if (std.mem.indexOf(u8, url, "://")) |scheme_end| {
        const rest = url[scheme_end + 3 ..];
        const slash_idx = std.mem.indexOfScalar(u8, rest, '/') orelse rest.len;
        const host_port = rest[0..slash_idx];
        const has_port = std.mem.indexOfScalar(u8, host_port, ':');
        const host = if (has_port) |colon| host_port[0..colon] else host_port;
        if (isPrivateIp(host)) return false;
    }
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

    if (!checkSSRF(url)) {
        return .{ .success = false, .data = "", .error_msg = "Request blocked: private IP addresses not allowed" };
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
