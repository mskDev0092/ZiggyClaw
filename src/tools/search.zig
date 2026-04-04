const std = @import("std");
const core = @import("core");

fn extractActualUrl(redirect_url: []const u8) ?[]const u8 {
    const uddg_pos = std.mem.indexOf(u8, redirect_url, "uddg=") orelse return null;
    const encoded_start = redirect_url[uddg_pos + 5 ..];
    const amp_pos = std.mem.indexOf(u8, encoded_start, "&") orelse encoded_start.len;

    var decoded = std.ArrayList(u8).init(std.heap.page_allocator);
    var i: usize = 0;
    while (i < amp_pos) {
        if (encoded_start[i] == '%' and i + 2 < amp_pos) {
            const hex = encoded_start[i + 1 .. i + 3];
            const byte = std.fmt.parseInt(u8, hex, 16) catch null;
            if (byte) |b| {
                decoded.append(b) catch {};
                i += 3;
                continue;
            }
        }
        decoded.append(encoded_start[i]) catch {};
        i += 1;
    }
    return decoded.items;
}

fn execute(ctx: core.types.ToolContext, args: []const u8) core.types.ToolResult {
    const query = std.mem.trim(u8, args, " \n\r");

    if (query.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: search <query>" };
    }

    var encoded_query = std.ArrayList(u8).init(ctx.allocator);
    defer encoded_query.deinit();
    for (query) |c| {
        if (c == ' ') {
            encoded_query.append('+') catch {};
        } else if (c >= 'A' and c <= 'Z' or c >= 'a' and c <= 'z' or c >= '0' and c <= '9' or c == '-' or c == '_' or c == '.') {
            encoded_query.append(c) catch {};
        } else {
            encoded_query.append('_') catch {};
        }
    }

    const search_url = std.fmt.allocPrint(ctx.allocator, "https://html.duckduckgo.com/html/?q={s}", .{encoded_query.items}) catch {
        return .{ .success = false, .data = "", .error_msg = "Failed to build search URL" };
    };
    defer ctx.allocator.free(search_url);

    const uri = std.Uri.parse(search_url) catch {
        return .{ .success = false, .data = "", .error_msg = "Invalid URL format" };
    };

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

    const html = req.reader().readAllAlloc(ctx.allocator, 512 * 1024) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };
    defer ctx.allocator.free(html);

    if (std.mem.indexOf(u8, html, "anomaly-modal") != null) {
        return .{ .success = true, .data = "Search blocked by CAPTCHA. Use web_fetch with a specific URL instead.", .owned = false };
    }

    var results = std.ArrayList(u8).init(ctx.allocator);
    defer results.deinit();
    var count: usize = 0;
    var pos: usize = 0;

    while (count < 8) {
        const class_pos = std.mem.indexOf(u8, html[pos..], "class=\"result__a\"") orelse break;
        const class_idx = pos + class_pos;

        const href_pos = std.mem.indexOf(u8, html[class_idx..], "href=\"") orelse break;
        const url_start = class_idx + href_pos + 6;

        const url_end_quote = std.mem.indexOf(u8, html[url_start..], "\"") orelse break;
        const redirect_url = html[url_start .. url_start + url_end_quote];

        const actual_url = extractActualUrl(redirect_url);

        const gt_pos = std.mem.indexOf(u8, html[url_start + url_end_quote ..], ">") orelse break;
        const title_start2 = url_start + url_end_quote + gt_pos + 1;

        const lt_pos = std.mem.indexOf(u8, html[title_start2..], "<") orelse break;
        const title = std.mem.trim(u8, html[title_start2 .. title_start2 + lt_pos], " \t\n\r");

        if (title.len > 5) {
            results.appendSlice("• ") catch {};
            results.appendSlice(title) catch {};
            results.appendSlice("\n  ") catch {};
            if (actual_url) |url| {
                results.appendSlice(url) catch {};
            } else {
                results.appendSlice(redirect_url) catch {};
            }
            results.appendSlice("\n\n") catch {};
            count += 1;
        }

        pos = title_start2 + lt_pos;
    }

    if (count == 0) {
        return .{ .success = true, .data = "No search results found. Try using web_fetch with a specific URL.", .owned = false };
    }

    const header = std.fmt.allocPrint(ctx.allocator, "Search results for \"{s}\" (showing {d} results):\n\n", .{ query, count }) catch {
        return .{ .success = true, .data = results.items, .owned = true };
    };
    defer ctx.allocator.free(header);

    const output = std.mem.concat(ctx.allocator, u8, &.{ header, results.items }) catch {
        return .{ .success = true, .data = results.items, .owned = true };
    };
    return .{ .success = true, .data = output, .owned = true };
}

pub fn getTool() @import("registry.zig").ToolRegistry.Tool {
    return .{
        .name = "search",
        .description = "Search the web (DuckDuckGo). Usage: search <your query here>",
        .execute = execute,
    };
}
