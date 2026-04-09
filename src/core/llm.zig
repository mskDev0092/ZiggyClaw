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
            try tools_json.appendSlice(tool.description);
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

        try json.appendSlice("[");

        // Add system message first if provided
        if (system_prompt) |sp| {
            try json.appendSlice("{\"role\":\"system\",\"content\":\"");
            const escaped = try self.escapeJsonString(sp);
            defer self.allocator.free(escaped);
            try json.appendSlice(escaped);
            try json.appendSlice("\"}");
        }

        for (messages.items) |msg| {
            if (system_prompt != null or json.items.len > 1) try json.appendSlice(",");
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
        var extra_headers = [_]std.http.Header{
            .{ .name = "Content-Type", .value = "application/json" },
        };

        var auth_header_buf: [256]u8 = undefined;
        var auth_header: ?std.http.Header = null;
        if (self.api_key.len > 0) {
            const auth = try std.fmt.bufPrint(&auth_header_buf, "Bearer {s}", .{self.api_key});
            auth_header = .{ .name = "Authorization", .value = auth };
        }

        var req = try client.open(.POST, try std.Uri.parse(url), .{
            .server_header_buffer = &header_buf,
            .extra_headers = if (auth_header) |h| &[_]std.http.Header{ extra_headers[0], h } else &extra_headers,
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = body.len };
        try req.send();
        try req.writeAll(body);
        try req.finish();
        try req.wait();

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
        std.debug.print("[LLM] Request body: {s}\n", .{body.items});

        var base_url = self.api_base;
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

        const full_url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ base_url, endpoint });
        defer self.allocator.free(full_url);

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

        // Parse OpenAI/lm-studio format: look for "content":"..." in choices[0].message
        if (std.mem.indexOf(u8, response, "\"content\":")) |content_start_idx| {
            const content_start = content_start_idx + 11; // length of "\"content\":\""
            if (content_start < response.len and response[content_start] == '"') {
                var content_end = content_start + 1;
                while (content_end < response.len and response[content_end] != '"') : (content_end += 1) {
                    if (response[content_end] == '\\' and content_end + 1 < response.len) {
                        content_end += 1;
                    }
                }
                if (content_end < response.len) {
                    self.allocator.free(content); // Free the default empty string
                    content = try self.allocator.dupe(u8, response[content_start + 1 .. content_end]);
                }
            }
        }

        // Parse tool_calls - with flexible whitespace handling
        if (std.mem.indexOf(u8, response, "\"function\":") != null and std.mem.indexOf(u8, response, "\"name\":") != null) {
            var idx: usize = 0;
            while (idx < response.len) {
                const func_start = std.mem.indexOf(u8, response[idx..], "\"name\":\"");
                if (func_start == null) break;
                const name_start = idx + func_start.? + 8;
                var name_end = name_start;
                while (name_end < response.len and response[name_end] != '"') name_end += 1;
                const tool_name = response[name_start..name_end];

                const after_name = response[name_end..];
                const args_start_pos = std.mem.indexOf(u8, after_name, "\"arguments\":");
                if (args_start_pos == null) break;
                const args_start = name_end + 2 + args_start_pos.? + 13;
                var args_end = args_start;
                while (args_end < response.len and response[args_end] != '"') args_end += 1;
                const tool_args = response[args_start..args_end];

                try tool_calls.append(.{
                    .id = try std.fmt.allocPrint(self.allocator, "call_{d}", .{tool_calls.items.len}),
                    .name = try self.allocator.dupe(u8, tool_name),
                    .arguments = try self.allocator.dupe(u8, tool_args),
                });

                idx = args_end + 1;
            }
            std.debug.print("[LLM] Total tool calls: {d}\n", .{tool_calls.items.len});
        }

        // Try to extract finish_reason
        const finish_pos = std.mem.indexOf(u8, response, "\"finish_reason\":\"");
        if (finish_pos != null) {
            const reason_start = finish_pos.? + 15;
            if (reason_start < response.len and response[reason_start] == '"') {
                var reason_end = reason_start + 1;
                while (reason_end < response.len and response[reason_end] != '"') : (reason_end += 1) {}
                if (reason_end < response.len) {
                    self.allocator.free(stop_reason);
                    stop_reason = try self.allocator.dupe(u8, response[reason_start + 1 .. reason_end]);
                }
            }
        }

        // Parse reasoning_content if present
        const reason_pos = std.mem.indexOf(u8, response, "\"reasoning_content\":\"");
        if (reason_pos != null) {
            const rstart = reason_pos.? + 20;
            if (rstart < response.len and response[rstart] == '"') {
                var rend = rstart + 1;
                while (rend < response.len and response[rend] != '"') : (rend += 1) {}
                if (rend < response.len) {
                    reasoning_content = try self.allocator.dupe(u8, response[rstart + 1 .. rend]);
                }
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
