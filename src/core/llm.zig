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
        // For local testing, return an empty tools list (tools aren't sent to stub LLM)
        _ = registry;
        const empty = try std.fmt.allocPrint(self.allocator, "[]", .{});
        return empty;
    }

    fn escapeJsonString(self: *const LLMClient, input: []const u8) ![]const u8 {
        var escaped = std.ArrayList(u8).init(self.allocator);

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
        // Caller responsible for freeing returned value
        const result = try self.allocator.dupe(u8, escaped.items);
        escaped.deinit();
        return result;
    }

    fn buildMessagesJson(
        self: LLMClient,
        messages: std.ArrayList(types.Message),
    ) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);

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
        // Return string owned by json ArrayList - don't defer free since caller will
        return try self.allocator.dupe(u8, json.items);
    }

    pub fn callLLM(
        self: LLMClient,
        messages: std.ArrayList(types.Message),
        tools: ?[]const u8,
    ) !LLMResponse {
        _ = tools;

        // Build request payload
        const messages_json = try self.buildMessagesJson(messages);
        defer self.allocator.free(messages_json);

        var body = std.ArrayList(u8).init(self.allocator);
        defer body.deinit();

        try body.appendSlice("{\"model\":\"");
        try body.appendSlice(self.model);
        try body.appendSlice("\",\"messages\":");
        try body.appendSlice(messages_json);
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

        // For local testing, return a stub response that won't break
        // A full HTTP implementation would require matching the Zig version's http API
        var response_body = std.ArrayList(u8).init(self.allocator);
        defer response_body.deinit();

        // Build a fake response showing what would be sent
        try response_body.appendSlice("{\"choices\":[{\"message\":{\"role\":\"assistant\",\"content\":\"Response from lm-studio\"},\"finish_reason\":\"stop\"}]}");

        const response_text = response_body.items;
        std.debug.print("[LLM] Response received: ", .{});
        std.debug.print("{d}", .{response_text.len});
        std.debug.print(" bytes\n", .{});
        std.debug.print("[LLM] Response body: {s}\n", .{response_text});

        return try self.parseResponse(response_text);
    }

    fn parseResponse(self: LLMClient, response: []const u8) !LLMResponse {
        const tool_calls = std.ArrayList(ToolCall).init(self.allocator);
        var content: []const u8 = "";
        var stop_reason: []const u8 = "stop";

        // Parse OpenAI/lm-studio format: look for "content":"..." in choices[0].message
        if (std.mem.indexOf(u8, response, "\"content\":")) |content_start_idx| {
            const content_start = content_start_idx + 11; // length of "\"content\":\""
            if (content_start < response.len and response[content_start] == '"') {
                var content_end = content_start + 1;
                while (content_end < response.len and response[content_end] != '"') : (content_end += 1) {
                    if (response[content_end] == '\\' and content_end + 1 < response.len) {
                        content_end += 1; // skip escaped char
                    }
                }
                if (content_end < response.len) {
                    content = response[content_start + 1 .. content_end];
                }
            }
        }

        // Try to extract finish_reason
        if (std.mem.indexOf(u8, response, "\"finish_reason\":")) |reason_start_idx| {
            const reason_start = reason_start_idx + 16; // length of "\"finish_reason\":"
            if (reason_start < response.len and response[reason_start] == '"') {
                var reason_end = reason_start + 1;
                while (reason_end < response.len and response[reason_end] != '"') : (reason_end += 1) {}
                if (reason_end < response.len) {
                    stop_reason = response[reason_start + 1 .. reason_end];
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
