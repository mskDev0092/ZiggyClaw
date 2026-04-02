const std = @import("std");
const types = @import("types.zig");
const tools = @import("tools");
const session_mod = @import("session.zig");
const core_llm = @import("llm.zig");

pub const Agent = struct {
    config: types.AgentConfig,
    session_manager: *session_mod.SessionManager,
    tool_registry: *tools.registry.ToolRegistry,
    allocator: std.mem.Allocator,

    pub fn init(
        allocator: std.mem.Allocator,
        config: types.AgentConfig,
        session_manager: *session_mod.SessionManager,
        tool_registry: *tools.registry.ToolRegistry,
    ) Agent {
        return .{
            .config = config,
            .session_manager = session_manager,
            .tool_registry = tool_registry,
            .allocator = allocator,
        };
    }

    /// Main ReAct loop for agent reasoning
    /// 1. Add user message to session
    /// 2. Call LLM with tools
    /// 3. If tool calls present, execute and loop
    /// 4. Return final response when LLM stops requesting tools
    pub fn think(self: *Agent, session_id: []const u8, user_message: []const u8) ![]const u8 {
        const sess = try self.session_manager.getOrCreate(session_id);
        try sess.addMessage("user", user_message);

        // Maximum iterations to prevent infinite loops
        const max_iterations = 10;
        var iteration: usize = 0;

        // For now, fallback to simple response if no LLM API is configured
        // Support reading LLM base URL from environment so local LLMs can be used
        var use_llm = false;
        var api_key: []const u8 = "";
        var api_base: []const u8 = "https://api.openai.com/v1";

        // Read environment variables for API key / base
        var env_map = try std.process.getEnvMap(self.allocator);
        defer env_map.deinit();

        // OPENAI_API_BASE enables LLM mode (will be used for local lm-studio/ollama)
        if (env_map.get("OPENAI_API_BASE")) |b| {
            api_base = b;
            use_llm = true;
            std.debug.print("[Agent] Using custom LLM base: {s}\n", .{api_base});
        }

        // OPENAI_API_KEY is optional (not needed for local lm-studio)
        if (env_map.get("OPENAI_API_KEY")) |key| {
            api_key = key;
        }

        // ReAct loop
        while (iteration < max_iterations) {
            iteration += 1;

            if (!use_llm) {
                // Fallback: use simple pattern matching for now
                // This lets our tool system work without API key
                return try self.thinkSimple(session_id, sess);
            }

            // Build LLM client
            const llm = core_llm.LLMClient.init(
                self.allocator,
                api_key,
                self.config.model,
                api_base,
            );

            // Get tool definitions and call LLM
            const tool_defs = try llm.buildToolDefinitions(self.tool_registry);
            defer self.allocator.free(tool_defs);

            // Call LLM with current session history
            const llm_response = try llm.callLLM(sess.messages, tool_defs);
            defer {
                self.allocator.free(llm_response.content);
                self.allocator.free(llm_response.stop_reason);
            }

            // Add LLM response to session
            if (llm_response.content.len > 0) {
                try sess.addMessage("assistant", llm_response.content);
            }

            // If no tool calls, we're done
            if (llm_response.tool_calls.items.len == 0) {
                llm_response.tool_calls.deinit();
                if (llm_response.content.len > 0) {
                    return try self.allocator.dupe(u8, llm_response.content);
                } else {
                    return "Agent completed reasoning";
                }
            }

            // Execute each tool call and collect results
            for (llm_response.tool_calls.items) |tool_call| {
                if (self.tool_registry.get(tool_call.name)) |tool| {
                    const ctx = types.ToolContext{
                        .allocator = self.allocator,
                        .session_id = session_id,
                    };
                    const result = tool.execute(ctx, tool_call.arguments);

                    // Add tool result to session
                    const result_msg = if (result.success) result.data else (result.error_msg orelse "tool failed");
                    try sess.addMessage("tool", result_msg);
                }
            }

            llm_response.tool_calls.deinit();

            // If stop_reason is "end_turn", we're done
            if (std.mem.eql(u8, llm_response.stop_reason, "end_turn")) {
                if (llm_response.content.len > 0) {
                    return try self.allocator.dupe(u8, llm_response.content);
                } else {
                    return "Agent completed with tool calls";
                }
            }

            // Otherwise, loop and continue reasoning with tool results
        }

        return "Agent reached maximum iterations";
    }

    /// Simple pattern-matching fallback when no LLM is configured
    /// Used for testing and when API keys aren't available
    fn thinkSimple(self: *Agent, session_id: []const u8, sess: *session_mod.Session) ![]const u8 {
        const user_message = sess.messages.items[sess.messages.items.len - 1].content;

        // Check for file_read command
        if (std.mem.indexOf(u8, user_message, "file_read") != null or std.mem.indexOf(u8, user_message, "read file") != null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("file_read")) |tool| {
                // Extract filename - look for common patterns
                var filename: []const u8 = "build.zig";

                // Try to extract filename after keywords
                if (std.mem.indexOf(u8, user_message, "read file:")) |idx| {
                    var start = idx + 10;
                    // Skip whitespace after colon
                    while (start < user_message.len and user_message[start] == ' ') {
                        start += 1;
                    }
                    var end = start;
                    while (end < user_message.len and user_message[end] != ' ' and user_message[end] != '\n') {
                        end += 1;
                    }
                    if (end > start) {
                        filename = user_message[start..end];
                    }
                } else if (std.mem.indexOf(u8, user_message, "file:")) |idx| {
                    var start = idx + 5;
                    // Skip whitespace after colon
                    while (start < user_message.len and user_message[start] == ' ') {
                        start += 1;
                    }
                    var end = start;
                    while (end < user_message.len and user_message[end] != ' ' and user_message[end] != '\n') {
                        end += 1;
                    }
                    if (end > start) {
                        filename = user_message[start..end];
                    }
                } else if (std.mem.indexOf(u8, user_message, "agent.md")) |_| {
                    filename = "agent.md";
                } else if (std.mem.indexOf(u8, user_message, "README")) |_| {
                    filename = "README.md";
                }

                const result = tool.execute(ctx, filename);
                if (result.success) {
                    try sess.addMessage("assistant", result.data);
                    return result.data;
                } else {
                    try sess.addMessage("assistant", result.error_msg orelse "tool failed");
                    return result.error_msg orelse "tool failed";
                }
            }
        }

        // Check for shell command
        if (std.mem.indexOf(u8, user_message, "shell") != null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("shell")) |tool| {
                var cmd: []const u8 = "ls";

                // Try to extract command after keywords
                if (std.mem.indexOf(u8, user_message, "shell:")) |idx| {
                    var start = idx + 6;
                    // Skip whitespace after colon
                    while (start < user_message.len and user_message[start] == ' ') {
                        start += 1;
                    }
                    var end = start;
                    while (end < user_message.len and user_message[end] != '\n') {
                        end += 1;
                    }
                    if (end > start) {
                        cmd = user_message[start..end];
                    }
                }

                const result = tool.execute(ctx, cmd);
                if (result.success) {
                    try sess.addMessage("assistant", result.data);
                    return result.data;
                } else {
                    try sess.addMessage("assistant", result.error_msg orelse "tool failed");
                    return result.error_msg orelse "tool failed";
                }
            }
        }

        // Default response
        const response = "ZiggyClaw agent ready (no tool triggered)";
        try sess.addMessage("assistant", response);
        return response;
    }
};
