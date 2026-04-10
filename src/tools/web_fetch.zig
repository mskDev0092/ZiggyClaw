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

fn stripHtmlTags(html: []const u8, allocator: std.mem.Allocator) ![]const u8 {
    var result = std.ArrayList(u8).init(allocator);
    var in_tag = false;
    var in_script = false;
    var in_style = false;

    for (html) |c| {
        if (c == '<') {
            in_tag = true;
            if (std.mem.endsWith(u8, html[0..@min(html.len, @as(usize, @intFromPtr(&c) - @intFromPtr(html.ptr)) + 1)], "<script")) {
                in_script = true;
            }
            if (std.mem.endsWith(u8, html[0..@min(html.len, @as(usize, @intFromPtr(&c) - @intFromPtr(html.ptr)) + 1)], "<style")) {
                in_style = true;
            }
            continue;
        }
        if (in_tag) {
            if (c == '>') {
                in_tag = false;
                if (in_script) in_script = false;
                if (in_style) in_style = false;
            }
            continue;
        }
        if (in_script or in_style) continue;
        if (c == '&') {
            try result.appendSlice("&");
        } else if (c == '\n' or c == '\r') {
            try result.append(' ');
        } else if (c != '\t') {
            try result.append(c);
        }
    }

    var cleaned = result.items;
    while (std.mem.indexOf(u8, cleaned, "  ")) |idx| {
        cleaned = std.mem.concat(allocator, u8, &.{ cleaned[0..idx], cleaned[idx + 2 ..] }) catch break;
    }
    return cleaned;
}

fn extractTitle(html: []const u8) ?[]const u8 {
    const title_start = std.mem.indexOf(u8, html, "<title>");
    const title_end = std.mem.indexOf(u8, html, "</title>");
    if (title_start != null and title_end != null) {
        const title = html[title_start.? + 7 .. title_end.?];
        return std.mem.trim(u8, title, " \n\r\t");
    }
    return null;
}

fn extractMetaDescription(html: []const u8) ?[]const u8 {
    const desc_start = std.mem.indexOf(u8, html, "name=\"description\" content=\"");
    const start_idx = if (desc_start != null) desc_start.? + 29 else blk: {
        const og_desc = std.mem.indexOf(u8, html, "property=\"og:description\" content=\"");
        if (og_desc == null) return null;
        break :blk og_desc.? + 29;
    };

    const end = std.mem.indexOf(u8, html[start_idx..], "\"") orelse html.len;
    return std.mem.trim(u8, html[start_idx .. start_idx + end], " \n\r\t");
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    var url = std.mem.trim(u8, params, " \n\r");

    if (url.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: web_fetch <url> [max_length]" };
    }

    var max_len: usize = 8000;
    var url_parts = std.mem.splitScalar(u8, url, ' ');
    url = url_parts.first();
    if (url_parts.next()) |len_str| {
        max_len = std.fmt.parseInt(usize, std.mem.trim(u8, len_str, " \n\r"), 10) catch max_len;
    }

    if (!isUrlSafe(url)) {
        return .{ .success = false, .data = "", .error_msg = "URL not allowed (unsafe scheme)" };
    }

    if (!checkSSRF(url)) {
        return .{ .success = false, .data = "", .error_msg = "Request blocked: private IP addresses not allowed" };
    }

    if (std.mem.indexOf(u8, url, "://") == null) {
        url = std.fmt.allocPrint(ctx.allocator, "https://{s}", .{url}) catch {
            return .{ .success = false, .data = "", .error_msg = "URL formatting failed" };
        };
    }

    const uri = std.Uri.parse(url) catch {
        return .{ .success = false, .data = "", .error_msg = "Invalid URL format" };
    };

    var host_str: []const u8 = "";
    if (std.mem.indexOf(u8, url, "://")) |start| {
        const after_scheme = url[start + 3 ..];
        if (std.mem.indexOf(u8, after_scheme, "/")) |end| {
            host_str = after_scheme[0..end];
        } else {
            host_str = after_scheme;
        }
    } else if (std.mem.indexOf(u8, url, "/")) |end| {
        host_str = url[0..end];
    } else {
        host_str = url;
    }
    if (host_str.len > 0 and isPrivateIp(host_str)) {
        return .{ .success = false, .data = "", .error_msg = "Private IP addresses not allowed" };
    }

    var client: std.http.Client = .{ .allocator = ctx.allocator };
    defer client.deinit();

    var header_buf: [8192]u8 = undefined;

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

    const html = req.reader().readAllAlloc(ctx.allocator, 1024 * 1024) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer ctx.allocator.free(html);

    const text = stripHtmlTags(html, ctx.allocator) catch {
        return .{ .success = true, .data = html[0..@min(html.len, max_len)], .owned = true };
    };
    defer ctx.allocator.free(text);

    var result = std.ArrayList(u8).init(ctx.allocator);

    if (extractTitle(html)) |title| {
        result.appendSlice("Title: ") catch {};
        result.appendSlice(title) catch {};
        result.appendSlice("\n\n") catch {};
    }

    if (extractMetaDescription(html)) |desc| {
        result.appendSlice("Description: ") catch {};
        result.appendSlice(desc) catch {};
        result.appendSlice("\n\n") catch {};
    }

    result.appendSlice("Content:\n") catch {};

    const trimmed = std.mem.trim(u8, text, " \n\r\t");
    const truncated = if (trimmed.len > max_len) trimmed[0..max_len] else trimmed;
    result.appendSlice(truncated) catch {};

    if (trimmed.len > max_len) {
        result.appendSlice("\n... (truncated)") catch {};
    }

    return .{ .success = true, .data = result.items, .owned = true };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "web_fetch",
        .description = "Fetch a URL and extract readable text. Strips HTML, extracts title/description. Usage: web_fetch <url> [max_length]",
        .execute = execute,
    };
}
