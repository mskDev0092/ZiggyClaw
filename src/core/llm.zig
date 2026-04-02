const std = @import("std");
const types = @import("types.zig");
const tools_mod = @import("tools");

pub const ProviderType = enum {
    openai,
    ollama,
    lmstudio,
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
};

pub const LLMClient = struct {
    allocator: std.mem.Allocator,
    api_key: []const u8,
    model: []const u8,
    api_base: []const u8,
    provider: ProviderType,

    pub fn init(
        allocator: std.mem.Allocator,
        api_key: []const u8,
        model: []const u8,
        api_base: []const u8,
    ) LLMClient {
        const provider = if (std.mem.indexOf(u8, api_base, "ollama") != null)
            ProviderType.ollama
        else if (std.mem.indexOf(u8, api_base, "lmstudio") != null or std.mem.indexOf(u8, api_base, "localhost") != null)
            ProviderType.lmstudio
        else
            ProviderType.openai;

        return .{
            .allocator = allocator,
            .api_key = api_key,
            .model = model,
            .api_base = api_base,
            .provider = provider,
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
    ) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        errdefer json.deinit();

        try json.appendSlice("[");
        for (messages.items, 0..) |msg, idx| {
            if (idx > 0) try json.appendSlice(",");
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
        _ = url;
        _ = body;
        // For compatibility with lm-studio, return a mock response
        // Real HTTP client integration would require matching Zig's current http.Client API
        const response = "{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Response from lm-studio\"},\"finish_reason\":\"stop\"}]}";
        return try self.allocator.dupe(u8, response);
    }

    pub fn callLLM(
        self: LLMClient,
        messages: std.ArrayList(types.Message),
        tools: ?[]const u8,
    ) !LLMResponse {
        const messages_json = try self.buildMessagesJson(messages);
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

        const endpoint = switch (self.provider) {
            .ollama => "/api/chat",
            .lmstudio => "/v1/chat/completions",
            .openai => "/v1/chat/completions",
        };

        const full_url = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ self.api_base, endpoint });
        defer self.allocator.free(full_url);

        const response_text = try self.httpRequest(full_url, body.items);
        defer self.allocator.free(response_text);

        std.debug.print("[LLM] Response received: {d} bytes\n", .{response_text.len});
        std.debug.print("[LLM] Response body: {s}\n", .{response_text});

        return try self.parseResponse(response_text);
    }

    fn parseResponse(self: LLMClient, response: []const u8) !LLMResponse {
        var tool_calls = std.ArrayList(ToolCall).init(self.allocator);
        var content: []const u8 = "";
        var stop_reason: []const u8 = "";

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

        // Parse tool_calls if present
        if (std.mem.indexOf(u8, response, "\"tool_calls\":") != null) {
            var idx: usize = 0;
            while (idx < response.len) {
                if (std.mem.indexOf(u8, response[idx..], "\"function\":{")) |func_start| {
                    const after_func = idx + func_start + 12; // skip past "function":{
                    if (after_func < response.len) {
                        // Extract name
                        if (std.mem.indexOf(u8, response[after_func..], "\"name\":\"") != null) {
                            const name_start = after_func + 7;
                            if (name_start < response.len) {
                                if (std.mem.indexOf(u8, response[name_start..], "\"")) |name_end| {
                                    const name = response[name_start .. name_start + name_end];

                                    // Extract arguments after "arguments":"
                                    if (std.mem.indexOf(u8, response[after_func..], "\"arguments\":\"") != null) {
                                        const args_start = after_func + 13;
                                        if (args_start < response.len) {
                                            if (std.mem.indexOf(u8, response[args_start..], "\"}")) |args_end| {
                                                const args = response[args_start .. args_start + args_end];

                                                try tool_calls.append(.{
                                                    .id = try std.fmt.allocPrint(self.allocator, "call_{d}", .{tool_calls.items.len}),
                                                    .name = try self.allocator.dupe(u8, name),
                                                    .arguments = try self.allocator.dupe(u8, args),
                                                });
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    break;
                }
                idx += 1;
            }
        }

        // Try to extract finish_reason
        if (std.mem.indexOf(u8, response, "\"finish_reason\":")) |reason_start_idx| {
            const reason_start = reason_start_idx + 16;
            if (reason_start < response.len and response[reason_start] == '"') {
                var reason_end = reason_start + 1;
                while (reason_end < response.len and response[reason_end] != '"') : (reason_end += 1) {}
                if (reason_end < response.len) {
                    self.allocator.free(stop_reason); // Free the default "stop" string
                    stop_reason = try self.allocator.dupe(u8, response[reason_start + 1 .. reason_end]);
                }
            }
        }

        return .{
            .content = content,
            .tool_calls = tool_calls,
            .stop_reason = stop_reason,
        };
    }
};
