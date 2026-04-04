const std = @import("std");
const core = @import("core");

fn encodeQuery(query: []const u8, allocator: std.mem.Allocator) []const u8 {
    var result = std.ArrayList(u8).init(allocator);
    for (query) |c| {
        switch (c) {
            ' ' => result.append('+') catch {},
            '&', '#' => {
                result.append('%') catch {};
                result.appendSlice("2X") catch {};
            },
            else => {
                if (c >= 'A' and c <= 'Z' or c >= 'a' and c <= 'z' or c >= '0' and c <= '9' or c == '-' or c == '_' or c == '.') {
                    result.append(c) catch {};
                } else {
                    result.append('%') catch {};
                }
            },
        }
    }
    return result.items;
}

fn execute(ctx: core.types.ToolContext, args: []const u8) core.types.ToolResult {
    const query = std.mem.trim(u8, args, " \n\r");

    if (query.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: search <query>" };
    }

    const encoded = encodeQuery(query, ctx.allocator);
    const search_url = std.fmt.allocPrint(ctx.allocator, "https://html.duckduckgo.com/html/?q={s}", .{encoded}) catch {
        return .{ .success = false, .data = "", .error_msg = "Failed to build search URL" };
    };
    defer ctx.allocator.free(search_url);

    const uri = std.Uri.parse(search_url) catch {
        return .{ .success = false, .data = "", .error_msg = "Invalid URL format" };
    };

    var client: std.http.Client = .{ .allocator = ctx.allocator };
    defer client.deinit();

    var header_buf: [4096]u8 = undefined;

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

    var results = std.ArrayList(u8).init(ctx.allocator);
    var idx: usize = 0;
    var count: usize = 0;

    while (count < 8 and idx < html.len) {
        const link_start = std.mem.indexOf(u8, html[idx..], "<a class=\"result__a\" href=\"");
        if (link_start == null) break;
        const url_start = idx + link_start.? + 27;

        const url_end = std.mem.indexOf(u8, html[url_start..], "\"") orelse break;
        const full_url = html[url_start .. url_start + url_end];

        const title_start = std.mem.indexOf(u8, html[url_start + url_end ..], ">") orelse break;
        const title_s = url_start + url_end + title_start + 1;
        const title_end = std.mem.indexOf(u8, html[title_s..], "<") orelse break;
        const title = std.mem.trim(u8, html[title_s .. title_s + title_end], " \t\n\r");

        if (title.len > 0) {
            results.appendSlice("• ") catch {};
            results.appendSlice(title) catch {};
            results.appendSlice("\n  ") catch {};
            results.appendSlice(full_url) catch {};
            results.appendSlice("\n\n") catch {};
            count += 1;
        }

        idx = url_start + url_end;
    }

    if (count == 0) {
        return .{ .success = true, .data = "No search results found. Try refining your query or use web_fetch to visit specific URLs directly.", .owned = false };
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
        .description = "Search the web using DuckDuckGo",
        .execute = execute,
    };
}
