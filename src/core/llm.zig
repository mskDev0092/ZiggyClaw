const std = @import("std");
const types = @import("types.zig");
const tools_mod = @import("tools");

// LLM response types
pub const ToolCall = struct {
    id: []const u8,
    name: []const u8,
    arguments: []const u8, // JSON string
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
    api_base: []const u8, // "https://api.openai.com/v1" or similar

    pub fn init(
        allocator: std.mem.Allocator,
        api_key: []const u8,
        model: []const u8,
        api_base: []const u8,
    ) LLMClient {
        return .{
            .allocator = allocator,
            .api_key = api_key,
            .model = model,
            .api_base = api_base,
        };
    }

    /// Build OpenAI-style tool definitions from a registry
    pub fn buildToolDefinitions(
        self: LLMClient,
        registry: *const tools_mod.registry.ToolRegistry,
    ) ![]const u8 {
        var tools_list = std.ArrayList(u8).init(self.allocator);
        defer tools_list.deinit();

        try tools_list.appendSlice("[\n");

        var iter = registry.tools.iterator();
        var i: usize = 0;
        while (iter.next()) |entry| {
            if (i > 0) try tools_list.appendSlice(",\n");

            try tools_list.writer().print(
                \\  {{
                \\    "type": "function",
                \\    "function": {{
                \\      "name": "{s}",
                \\      "description": "{s}"
                \\    }}
                \\  }}
                , .{ entry.key_ptr.*, entry.value_ptr.description });

            i += 1;
        }

        try tools_list.appendSlice("\n]");
        return tools_list.items;
    }

    /// Call the LLM with a message and optional tools
    /// STUB: Returns a simple empty response
    /// Full implementation will be added in Phase 5 with proper HTTP client
    pub fn callLLM(
        self: LLMClient,
        messages: std.ArrayList(types.Message),
        tools: ?[]const u8,
    ) !LLMResponse {
        _ = messages;
        _ = tools;

        // For Phase 2, we return an empty response to allow the ReAct loop to fall back
        // to simple mode. Full OpenAI integration will be added in Phase 5.
        const tool_calls = std.ArrayList(ToolCall).init(self.allocator);

        return .{
            .content = "",
            .tool_calls = tool_calls,
            .stop_reason = "stub",
        };
    }
};
