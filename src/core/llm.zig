const std = @import("std");
const types = @import("types.zig");
const tools_mod = @import("tools");

pub const ProviderType = enum {
    openai,
    ollama,
    lmstudio,
    anthropic,
    google,
    openrouter,
    xai,
};

pub const ToolCall = struct {
    id: []const u8,
    name: []const u8,
    arguments: []const u8,
};

pub const LLMResponse = struct {
    content: []const u8,
    tool_calls: std.ArrayList(ToolCall),
    stop_reason: []const u8,
    reasoning_content: ?[]const u8 = null,
    usage: ?TokenUsage = null,
};

pub const TokenUsage = struct {
    prompt_tokens: usize = 0,
    completion_tokens: usize = 0,
    total_tokens: usize = 0,
};

pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    model: []const u8,
    api_base: []const u8,
    provider: ProviderType,
    system_prompt: ?[]const u8 = null,

    pub fn init(
        allocator: std.mem.Allocator,
        api_key: []const u8,
        model: []const u8,
        api_base: []const u8,
    ) LLMClient {
        const provider = if (std.mem.indexOf(u8, api_base, "ollama") != null)
            ProviderType.ollama
        else if (std.mem.indexOf(u8, api_base, "lmstudio") != null or std.mem.indexOf(u8, api_base, "localhost:1234") != null)
            ProviderType.lmstudio
        else if (std.mem.indexOf(u8, api_base, "anthropic") != null or std.mem.indexOf(u8, api_base, "api.anthropic") != null)
            ProviderType.anthropic
        else if (std.mem.indexOf(u8, api_base, "google") != null or std.mem.indexOf(u8, api_base, "generativelanguage") != null)
            ProviderType.google
        else if (std.mem.indexOf(u8, api_base, "openrouter") != null or std.mem.indexOf(u8, api_base, "openrouter.ai") != null)
            ProviderType.openrouter
        else if (std.mem.indexOf(u8, api_base, "x.ai") != null or std.mem.indexOf(u8, api_base, "xai") != null)
            ProviderType.xai
        else
            ProviderType.openai;

        return .{
            .allocator = allocator,
            .api_key = api_key,
            .model = model,
            .api_base = api_base,
            .provider = provider,
            .system_prompt = null,
        };
    }

    pub fn buildToolDefinitions(
        self: LLMClient,
        registry: *const tools_mod.registry.ToolRegistry,
    ) ![]const u8 {
        var tools_json = std.ArrayList(u8).init(self.allocator);
        errdefer tools_json.deinit();

        try tools_json.append('[');

        const tools = registry.list();
        defer self.allocator.free(tools);

        for (tools, 0..) |tool, idx| {
            if (idx > 0) try tools_json.append(',');
            try tools_json.appendSlice("{\"type\":\"function\",\"function\":{\"name\":\"");
            try tools_json.appendSlice(tool.name);
            try tools_json.appendSlice("\",\"description\":\"");
            // Escape the description for valid JSON
            for (tool.description) |c| {
                switch (c) {
                    '"' => try tools_json.appendSlice("\\\""),
                    '\\' => try tools_json.appendSlice("\\\\"),
                    '\n' => try tools_json.appendSlice("\\n"),
                    '\r' => try tools_json.appendSlice("\\r"),
                    '\t' => try tools_json.appendSlice("\\t"),
                    else => try tools_json.append(c),
                }
            }
            try tools_json.appendSlice("\"}}");
        }

        try tools_json.append(']');
        return tools_json.toOwnedSlice();
    }

    fn escapeJsonString(self: *const LLMClient, input: []const u8) ![]const u8 {
        var escaped = std.ArrayList(u8).init(self.allocator);
        errdefer escaped.deinit();

        for (input) |c| {
            switch (c) {
                '"' => try escaped.appendSlice("\\\""),
                '\\' => try escaped.appendSlice("\\\\"),
                '\n' => try escaped.appendSlice("\\n"),
                '\r' => try escaped.appendSlice("\\r"),
                '\t' => try escaped.appendSlice("\\t"),
                else => try escaped.append(c),
            }
        }
        return escaped.toOwnedSlice();
    }

    fn buildMessagesJson(
        self: LLMClient,
        messages: std.ArrayList(types.Message),
        system_prompt: ?[]const u8,
    ) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        errdefer json.deinit();

        var first_message = true;
        try json.appendSlice("[");

        // Add system message first if provided
        if (system_prompt) |sp| {
            try json.appendSlice("{\"role\":\"system\",\"content\":\"");
            const escaped = try self.escapeJsonString(sp);
            defer self.allocator.free(escaped);
            try json.appendSlice(escaped);
            try json.appendSlice("\"}");
            first_message = false;
        }

        for (messages.items) |msg| {
            if (!first_message) try json.appendSlice(",");
            first_message = false;
            const escaped_content = try self.escapeJsonString(msg.content);
            defer self.allocator.free(escaped_content);
            try json.appendSlice("{\"role\":\"");
            try json.appendSlice(msg.role);
            try json.appendSlice("\",\"content\":\"");
            try json.appendSlice(escaped_content);
            try json.appendSlice("\"}");
        }
        try json.appendSlice("]");
        return json.toOwnedSlice();
    }

    fn httpRequest(self: LLMClient, url: []const u8, body: []const u8) ![]const u8 {
        var client: std.http.Client = .{ .allocator = self.allocator };
        defer client.deinit();

        var header_buf: [4096]u8 = undefined;

        // Build headers
        var headers = std.ArrayList(std.http.Header).init(self.allocator);
        defer headers.deinit();
        try headers.append(.{ .name = "Content-Type", .value = "application/json" });
        try headers.append(.{ .name = "Accept", .value = "application/json" });

        var auth_header_buf: [256]u8 = undefined;
        if (self.api_key.len > 0) {
            const auth = try std.fmt.bufPrint(&auth_header_buf, "Bearer {s}", .{self.api_key});
            try headers.append(.{ .name = "Authorization", .value = auth });
        }

        var req = try client.open(.POST, try std.Uri.parse(url), .{
            .server_header_buffer = &header_buf,
            .extra_headers = headers.items,
        });
        defer req.deinit();

        std.debug.print("[LLM] HTTP request: POST {s}, body len={d}\n", .{ url, body.len });

        req.transfer_encoding = .{ .content_length = body.len };
        try req.send();
        try req.writeAll(body);
        try req.finish();

        // Wait for response FIRST, then read body
        try req.wait();

        const status = req.response.status;
        std.debug.print("[LLM] HTTP response status: {}\n", .{status});

        const response_body = try req.reader().readAllAlloc(self.allocator, 1024 * 1024);
        return response_body;
    }

    pub fn callLLM(
        self: LLMClient,
        messages: std.ArrayList(types.Message),
        tools: ?[]const u8,
    ) !LLMResponse {
        const messages_json = try self.buildMessagesJson(messages, self.system_prompt);
        defer self.allocator.free(messages_json);

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.appendSlice("{\"model\":\"");
        try body.appendSlice(self.model);
        try body.appendSlice("\",\"messages\":");
        try body.appendSlice(messages_json);

        if (tools) |t| {
            try body.appendSlice(",\"tools\":");
            try body.appendSlice(t);
        }

        try body.appendSlice("}");

        std.debug.print("[LLM] Sending request to {s}\n", .{self.api_base});
        std.debug.print("[LLM] Full request body: {s}\n", .{body.items});

        var base_url = self.api_base;
        // Strip trailing /v1 or /api if present - we'll add the endpoint ourselves
        if (std.mem.endsWith(u8, base_url, "/v1")) {
            base_url = base_url[0..(base_url.len - 3)];
        } else if (std.mem.endsWith(u8, base_url, "/api")) {
            base_url = base_url[0..(base_url.len - 4)];
        }

        const endpoint = switch (self.provider) {
            .ollama => "/api/chat",
            .lmstudio => "/v1/chat/completions",
            .openai => "/v1/chat/completions",
            .anthropic => "/v1/messages",
            .google => "/v1beta/models/{s}:generateContent",
            .openrouter => "/v1/chat/completions",
            .xai => "/v1/chat/completions",
        };

        // Special handling: if base_url already ends with /v1 and endpoint starts with /v1, don't double-add
        const full_url = if (std.mem.endsWith(u8, base_url, "/v1") and std.mem.startsWith(u8, endpoint, "/v1"))
            try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base_url, endpoint[3..] })
        else
            try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base_url, endpoint });
        defer self.allocator.free(full_url);
        std.debug.print("[LLM] Full URL: {s}\n", .{full_url});

        const response_text = try self.httpRequest(full_url, body.items);
        defer self.allocator.free(response_text);

        std.debug.print("[LLM] Response received: {d} bytes\n", .{response_text.len});
        std.debug.print("[LLM] Response body: {s}\n", .{response_text});

        return try self.parseResponse(response_text);
    }

    pub fn parseResponse(self: LLMClient, response: []const u8) !LLMResponse {
        var tool_calls = std.ArrayList(ToolCall).init(self.allocator);
        var content: []const u8 = "";
        var stop_reason: []const u8 = "";
        var reasoning_content: ?[]const u8 = null;

        // Allocate default strings that will be owned by the caller
        content = try self.allocator.dupe(u8, "");
        errdefer self.allocator.free(content);

        stop_reason = try self.allocator.dupe(u8, "stop");
        errdefer self.allocator.free(stop_reason);

        // First check for error response
        if (std.mem.indexOf(u8, response, "\"error\"") != null) {
            std.debug.print("[LLM] Error in response: {s}\n", .{response});
            return .{
                .content = content,
                .tool_calls = tool_calls,
                .stop_reason = stop_reason,
                .reasoning_content = null,
            };
        }

        // Parse content from message object within choices
        // Find choices array and parse the first message's content
        // Look for "content" that appears BEFORE "reasoning_content" to avoid confusion
        if (std.mem.indexOf(u8, response, "\"choices\":")) |choices_start| {
            const after_choices = response[choices_start + 9 ..];
            if (std.mem.indexOf(u8, after_choices, "\"message\":{")) |msg_start| {
                const after_msg = after_choices[msg_start + 9 ..];

                // Find position of reasoning_content first to know where content ends
                const reasoning_pos = std.mem.indexOf(u8, after_msg, "\"reasoning_content\":");
                const search_end = reasoning_pos orelse after_msg.len;
                const content_search_area = after_msg[0..search_end];

                const content_pat = "\"content\":";
                if (std.mem.indexOf(u8, content_search_area, content_pat)) |pos| {
                    const content_start = pos + content_pat.len;
                    var cursor = content_start;
                    while (cursor < content_search_area.len and (content_search_area[cursor] == ' ' or content_search_area[cursor] == '\t')) cursor += 1;
                    if (cursor < content_search_area.len and content_search_area[cursor] == '"') cursor += 1;
                    const value_start = cursor;
                    var value_end = cursor;
                    while (value_end < content_search_area.len and content_search_area[value_end] != '"') value_end += 1;
                    if (value_end < content_search_area.len) {
                        const parsed = content_search_area[value_start..value_end];
                        // Keep the content even if it seems empty - it might have newlines
                        if (parsed.len > 0) {
                            self.allocator.free(content);
                            content = try self.allocator.dupe(u8, parsed);
                        }
                    }
                }
            }
        }

        // Parse tool_calls - find them within the message in choices
        if (std.mem.indexOf(u8, response, "\"tool_calls\":")) |tool_calls_start| {
            const after_tool_calls = response[tool_calls_start + 12 ..];
            var search_idx: usize = 0;
            var found: usize = 0;
            while (search_idx < after_tool_calls.len and found < 5) {
                const name_pat = "\"name\":";
                if (std.mem.indexOf(u8, after_tool_calls[search_idx..], name_pat)) |pos| {
                    const name_start = search_idx + pos + name_pat.len;
                    var name_cursor = name_start;
                    while (name_cursor < after_tool_calls.len and (after_tool_calls[name_cursor] == ' ' or after_tool_calls[name_cursor] == '\t')) name_cursor += 1;
                    if (name_cursor < after_tool_calls.len and after_tool_calls[name_cursor] == '"') name_cursor += 1;
                    const name_value_start = name_cursor;
                    var name_end = name_cursor;
                    while (name_end < after_tool_calls.len and after_tool_calls[name_end] != '"') name_end += 1;
                    const tool_name = after_tool_calls[name_value_start..name_end];

                    const remaining = after_tool_calls[name_end..];
                    const args_pat = "\"arguments\":";
                    if (std.mem.indexOf(u8, remaining, args_pat)) |apos| {
                        const args_cursor = name_end + 2 + apos + args_pat.len;
                        var args_start = args_cursor;
                        while (args_start < after_tool_calls.len and (after_tool_calls[args_start] == ' ' or after_tool_calls[args_start] == '\t')) args_start += 1;
                        if (args_start < after_tool_calls.len and after_tool_calls[args_start] == '"') args_start += 1;
                        var args_end = args_start;
                        while (args_end < after_tool_calls.len and after_tool_calls[args_end] != '"') args_end += 1;
                        const tool_args = after_tool_calls[args_start..args_end];

                        if (tool_name.len > 0 and tool_args.len > 0) {
                            try tool_calls.append(.{
                                .id = try std.fmt.allocPrint(self.allocator, "call_{d}", .{found}),
                                .name = try self.allocator.dupe(u8, tool_name),
                                .arguments = try self.allocator.dupe(u8, tool_args),
                            });
                            found += 1;
                        }
                    }
                    search_idx = name_end + 1;
                } else {
                    break;
                }
            }
        }

        // Try to extract finish_reason
        var finish_search_idx: usize = 0;
        while (finish_search_idx < response.len) {
            const finish_pat = "\"finish_reason\":";
            if (std.mem.indexOf(u8, response[finish_search_idx..], finish_pat)) |pos| {
                const reason_start = finish_search_idx + pos + finish_pat.len;
                var reason_cursor = reason_start;
                while (reason_cursor < response.len and (response[reason_cursor] == ' ' or response[reason_cursor] == '\t')) reason_cursor += 1;
                if (reason_cursor < response.len and response[reason_cursor] == '"') reason_cursor += 1;
                var reason_end = reason_cursor;
                while (reason_end < response.len and response[reason_end] != '"') : (reason_end += 1) {}
                if (reason_end < response.len) {
                    self.allocator.free(stop_reason);
                    stop_reason = try self.allocator.dupe(u8, response[reason_cursor..reason_end]);
                    break;
                }
                finish_search_idx = reason_end + 1;
            } else {
                break;
            }
        }

        // Parse reasoning_content if present
        var reason_search_idx: usize = 0;
        while (reason_search_idx < response.len) {
            const reason_pat = "\"reasoning_content\":";
            if (std.mem.indexOf(u8, response[reason_search_idx..], reason_pat)) |pos| {
                const rstart = reason_search_idx + pos + reason_pat.len;
                var r_cursor = rstart;
                while (r_cursor < response.len and (response[r_cursor] == ' ' or response[r_cursor] == '\t')) r_cursor += 1;
                if (r_cursor < response.len and response[r_cursor] == '"') r_cursor += 1;
                var rend = r_cursor;
                while (rend < response.len and response[rend] != '"') : (rend += 1) {}
                if (rend < response.len) {
                    const parsed_reasoning = response[r_cursor..rend];
                    // Only use if non-empty (trimming whitespace)
                    if (parsed_reasoning.len > 0 and std.mem.trim(u8, parsed_reasoning, " \n\r\t").len > 0) {
                        reasoning_content = try self.allocator.dupe(u8, parsed_reasoning);
                        break;
                    }
                }
                reason_search_idx = rend + 1;
            } else {
                break;
            }
        }

        return .{
            .content = content,
            .tool_calls = tool_calls,
            .stop_reason = stop_reason,
            .reasoning_content = reasoning_content,
        };
    }
};
