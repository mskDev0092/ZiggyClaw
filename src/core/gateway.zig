const std = @import("std");
const types = @import("types.zig");
const session_mod = @import("session.zig");
const agent_mod = @import("agent.zig");
const tools = @import("tools");

const HttpRequest = struct {
    method: []const u8,
    path: []const u8,
};

fn parseHttpRequest(allocator: std.mem.Allocator, buffer: []const u8) !?HttpRequest {
    if (buffer.len == 0) return null;

    // Find the end of the request line
    var line_end: usize = 0;
    while (line_end < buffer.len and buffer[line_end] != '\n') {
        line_end += 1;
    }
    if (line_end >= buffer.len) return null;

    const request_line = std.mem.trim(u8, buffer[0..line_end], "\r\n ");

    // Parse request line: METHOD PATH HTTP/VERSION
    var parts = std.mem.splitSequence(u8, request_line, " ");
    const method = parts.next() orelse return null;
    const path = parts.next() orelse return null;

    return HttpRequest{
        .method = try allocator.dupe(u8, method),
        .path = try allocator.dupe(u8, path),
    };
}

fn sendHttpResponse(stream: std.net.Stream, status: []const u8, content_type: []const u8, body: []const u8) !void {
    try stream.writeAll("HTTP/1.1 ");
    try stream.writeAll(status);
    try stream.writeAll("\r\n");
    try stream.writeAll("Content-Type: ");
    try stream.writeAll(content_type);
    try stream.writeAll("\r\n");
    try stream.writeAll("Content-Length: ");
    const len_str = try std.fmt.allocPrint(std.heap.page_allocator, "{d}", .{body.len});
    defer std.heap.page_allocator.free(len_str);
    try stream.writeAll(len_str);
    try stream.writeAll("\r\n\r\n");
    try stream.writeAll(body);
}

pub fn start(port: u16) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize agent components
    var session_manager = session_mod.SessionManager.init(allocator);
    defer session_manager.deinit();

    var registry = tools.registry.ToolRegistry.init(allocator);
    defer registry.deinit();

    // Register built-in tools
    try registry.register(tools.shell.getTool());
    try registry.register(tools.file_read.getTool());
    try registry.register(tools.write_file.getTool());
    try registry.register(tools.edit_file.getTool());
    try registry.register(tools.list_directory.getTool());
    try registry.register(tools.search_files.getTool());
    try registry.register(tools.find_files.getTool());
    try registry.register(tools.web_get.getTool());
    try registry.register(tools.web_fetch.getTool());
    try registry.register(tools.search.getTool());
    try registry.register(tools.execute_command.getTool());
    try registry.register(tools.process.getTool());

    const config = types.AgentConfig{
        .model = "gateway-agent",
    };

    var agent = agent_mod.Agent.init(allocator, config, &session_manager, &registry);

    const address = try std.net.Address.parseIp4("127.0.0.1", port);
    var listener = try address.listen(.{
        .reuse_address = true,
        .reuse_port = true,
    });
    defer listener.deinit();

    std.debug.print("✅ ZiggyClaw Gateway ready on http://127.0.0.1:{d}\n", .{port});
    std.debug.print("   OpenClaw / RustClaw compatible (port 18789)\n", .{});
    std.debug.print("   Try: curl http://127.0.0.1:{d}/v1/chat/completions\n\n", .{port});
    std.debug.print("   Press Ctrl+C to stop\n", .{});

    while (true) {
        const connection = try listener.accept();
        defer connection.stream.close();

        // Read request - use read() instead of readAll() since HTTP clients don't send EOF
        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch |err| {
            if (err == error.WouldBlock) continue;
            return err;
        };

        if (bytes_read == 0) continue;

        const request_buf = buffer[0..bytes_read];

        if (try parseHttpRequest(allocator, request_buf)) |req| {
            defer allocator.free(req.method);
            defer allocator.free(req.path);

            // Route requests
            if (std.mem.eql(u8, req.path, "/v1/chat/completions") or std.mem.eql(u8, req.path, "/v1/chat/completions/")) {
                // Extract user message from request body (simple JSON parsing)
                var user_message: []const u8 = "What is ZiggyClaw?"; // default message

                // Simple extraction: look for "content":"..." in the body
                if (std.mem.indexOf(u8, request_buf, "\"content\":\"")) |content_idx| {
                    const content_start = content_idx + 11; // length of "\"content\":\""
                    if (content_start < request_buf.len) {
                        if (std.mem.indexOf(u8, request_buf[content_start..], "\"")) |end_idx| {
                            const content_end = content_start + end_idx;
                            if (content_end > content_start) {
                                user_message = request_buf[content_start..content_end];
                            }
                        }
                    }
                }

                // Call agent
                const agent_response = try agent.think("http-session", user_message);

                // Format response as JSON
                const json_response = try std.fmt.allocPrint(allocator,
                    \\{{
                    \\  "id": "chatcmpl-ziggyclaw",
                    \\  "object": "chat.completion",
                    \\  "created": 1234567890,
                    \\  "model": "ziggyclaw-v1",
                    \\  "choices": [
                    \\    {{
                    \\      "index": 0,
                    \\      "message": {{
                    \\        "role": "assistant",
                    \\        "content": "{s}"
                    \\      }},
                    \\      "finish_reason": "stop"
                    \\    }}
                    \\  ],
                    \\  "usage": {{
                    \\    "prompt_tokens": 10,
                    \\    "completion_tokens": 10,
                    \\    "total_tokens": 20
                    \\  }}
                    \\}}
                , .{agent_response});
                defer allocator.free(json_response);

                try sendHttpResponse(connection.stream, "200 OK", "application/json", json_response);
                std.debug.print("📡 POST {s} -> 200 OK (via Agent)\n", .{req.path});
            } else {
                const response = "Unrecognized endpoint";
                try sendHttpResponse(connection.stream, "404 Not Found", "text/plain", response);
                std.debug.print("📡 {s} {s} -> 404\n", .{ req.method, req.path });
            }
        } else {
            const response = "Bad request";
            try sendHttpResponse(connection.stream, "400 Bad Request", "text/plain", response);
        }
    }
}
