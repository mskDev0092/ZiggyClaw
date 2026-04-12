const std = @import("std");
const types = @import("types.zig");
const tools = @import("tools");
const session_mod = @import("session.zig");
const core_llm = @import("llm.zig");
const guard = @import("security").guard;

const DEFAULT_SYSTEM_PROMPT = "You are an autonomous agent. When user asks to do something (read file, list files, run commands, search, etc), use the available tools to complete the task. Think step by step. Keep using tools until the task is complete. Always respond with actual content, not empty.";

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
        const check = guard.PromptGuard.check(user_message);
        if (check.blocked) {
            return try self.allocator.dupe(u8, check.reason orelse "Message blocked by security check");
        }

        const leak = guard.LeakDetector.check(user_message);
        if (leak.blocked) {
            return try self.allocator.dupe(u8, leak.reason orelse "Message blocked by leak detection");
        }

        const sess = try self.session_manager.getOrCreate(session_id);
        try sess.addMessage("user", user_message);

        const limit = self.config.context_window_limit;
        const threshold = self.config.compact_threshold_percent;
        if (sess.needsCompaction(limit, threshold)) {
            try sess.compact(self.allocator);
            std.debug.print("[Agent] Context compacted\n", .{});
        }

        const max_iterations = self.config.max_iterations;
        var iteration: usize = 0;

        var use_llm = false;
        var api_key: []const u8 = "";
        var api_base: []const u8 = "https://api.openai.com/v1";

        var env_map = try std.process.getEnvMap(self.allocator);
        defer env_map.deinit();

        if (env_map.get("OPENAI_API_BASE")) |b| {
            api_base = b;
            use_llm = true;
            std.debug.print("[Agent] Using custom LLM base: {s}\n", .{api_base});
        }

        if (env_map.get("OPENAI_API_KEY")) |key| {
            api_key = key;
        }

        while (iteration < max_iterations) {
            iteration += 1;

            if (!use_llm) {
                return try self.thinkSimple(session_id, sess);
            }

            var llm = core_llm.LLMClient.init(
                self.allocator,
                api_key,
                self.config.model,
                api_base,
            );
            llm.system_prompt = self.config.system_prompt orelse DEFAULT_SYSTEM_PROMPT;

            const tool_defs = try llm.buildToolDefinitions(self.tool_registry);
            defer self.allocator.free(tool_defs);

            const llm_response = try llm.callLLM(sess.messages, tool_defs);
            std.debug.print("[Agent] Response - content: '{s}', reasoning: '{s}', tool_calls: {d}, stop_reason: '{s}'\n", .{ llm_response.content, llm_response.reasoning_content orelse "", llm_response.tool_calls.items.len, llm_response.stop_reason });
            defer {
                self.allocator.free(llm_response.content);
                self.allocator.free(llm_response.stop_reason);
                llm_response.tool_calls.deinit();
                if (llm_response.reasoning_content) |r| self.allocator.free(r);
            }

            if (llm_response.content.len > 0) {
                try sess.addMessage("assistant", llm_response.content);
            }

            // If no tool calls, check for meaningful content - otherwise continue looping
            const is_empty = std.mem.trim(u8, llm_response.content, " \n\r\t").len == 0;
            const has_reasoning = llm_response.reasoning_content != null and std.mem.trim(u8, llm_response.reasoning_content.?, " \n\r\t").len > 0;

            if (llm_response.tool_calls.items.len == 0) {
                if (!is_empty) {
                    return try self.allocator.dupe(u8, llm_response.content);
                } else if (has_reasoning) {
                    return try self.allocator.dupe(u8, llm_response.reasoning_content.?);
                } else {
                    // Empty response - continue looping to get meaningful result
                    continue;
                }
            }

            // Execute tool calls
            for (llm_response.tool_calls.items) |tool_call| {
                std.debug.print("[Agent] Executing tool: {s}\n", .{tool_call.name});
                if (self.tool_registry.get(tool_call.name)) |tool| {
                    const ctx = types.ToolContext{
                        .allocator = self.allocator,
                        .session_id = session_id,
                    };
                    const result = tool.execute(ctx, tool_call.arguments);

                    const result_msg = if (result.success) result.data else (result.error_msg orelse "tool failed");
                    try sess.addMessage("tool", result_msg);
                    if (result.owned) self.allocator.free(result.data);
                }
            }

            // After tool execution, loop continues to get final response
        }

        return try self.allocator.dupe(u8, "Agent reached maximum iterations");
    }

    /// Simple pattern-matching fallback when no LLM is configured
    /// Used for testing and when API keys aren't available
    fn thinkSimple(self: *Agent, session_id: []const u8, sess: *session_mod.Session) ![]const u8 {
        const user_message = sess.messages.items[sess.messages.items.len - 1].content;

        if (std.mem.indexOf(u8, user_message, "file_read") != null or std.mem.indexOf(u8, user_message, "read file") != null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("file_read")) |tool| {
                var filename: []const u8 = "build.zig";

                if (std.mem.indexOf(u8, user_message, "read file:")) |idx| {
                    var start = idx + 10;
                    while (start < user_message.len and user_message[start] == ' ') : (start += 1) {}
                    var end = start;
                    while (end < user_message.len and user_message[end] != ' ' and user_message[end] != '\n') : (end += 1) {}
                    if (end > start) filename = user_message[start..end];
                } else if (std.mem.indexOf(u8, user_message, "file:")) |idx| {
                    var start = idx + 5;
                    while (start < user_message.len and user_message[start] == ' ') : (start += 1) {}
                    var end = start;
                    while (end < user_message.len and user_message[end] != ' ' and user_message[end] != '\n') : (end += 1) {}
                    if (end > start) filename = user_message[start..end];
                } else if (std.mem.indexOf(u8, user_message, "agent.md")) |_| {
                    filename = "agent.md";
                } else if (std.mem.indexOf(u8, user_message, "README")) |_| {
                    filename = "README.md";
                }

                const result = tool.execute(ctx, filename);
                defer if (result.owned) self.allocator.free(result.data);

                if (result.success) {
                    try sess.addMessage("assistant", result.data);
                    return try self.allocator.dupe(u8, result.data);
                } else {
                    const err_msg = result.error_msg orelse "tool failed";
                    try sess.addMessage("assistant", err_msg);
                    return try self.allocator.dupe(u8, err_msg);
                }
            }
        }

        if (std.mem.indexOf(u8, user_message, "shell") != null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("shell")) |tool| {
                var cmd: []const u8 = "ls";

                if (std.mem.indexOf(u8, user_message, "shell:")) |idx| {
                    var start = idx + 6;
                    while (start < user_message.len and user_message[start] == ' ') : (start += 1) {}
                    var end = start;
                    while (end < user_message.len and user_message[end] != '\n') : (end += 1) {}
                    if (end > start) cmd = user_message[start..end];
                }

                const result = tool.execute(ctx, cmd);
                defer if (result.owned) self.allocator.free(result.data);

                if (result.success) {
                    try sess.addMessage("assistant", result.data);
                    return try self.allocator.dupe(u8, result.data);
                } else {
                    const err_msg = result.error_msg orelse "tool failed";
                    try sess.addMessage("assistant", err_msg);
                    return try self.allocator.dupe(u8, err_msg);
                }
            }
        }

        if (std.mem.indexOf(u8, user_message, "web_get") != null or std.mem.indexOf(u8, user_message, "http") != null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("web_get")) |tool| {
                var url: []const u8 = "";

                if (std.mem.indexOf(u8, user_message, "web_get ")) |idx| {
                    var start = idx + 8;
                    while (start < user_message.len and user_message[start] == ' ') : (start += 1) {}
                    var end = start;
                    while (end < user_message.len and user_message[end] != ' ' and user_message[end] != '\n') : (end += 1) {}
                    if (end > start) url = user_message[start..end];
                }

                if (url.len > 0) {
                    const result = tool.execute(ctx, url);
                    defer if (result.owned) self.allocator.free(result.data);

                    if (result.success) {
                        try sess.addMessage("assistant", result.data);
                        return try self.allocator.dupe(u8, result.data);
                    } else {
                        const err_msg = result.error_msg orelse "tool failed";
                        try sess.addMessage("assistant", err_msg);
                        return try self.allocator.dupe(u8, err_msg);
                    }
                }
            }
        }

        if (std.mem.indexOf(u8, user_message, "search") != null and std.mem.indexOf(u8, user_message, "web_get") == null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("search")) |tool| {
                var query: []const u8 = "";

                if (std.mem.indexOf(u8, user_message, "search ")) |idx| {
                    var start = idx + 7;
                    while (start < user_message.len and user_message[start] == ' ') : (start += 1) {}
                    var end = start;
                    while (end < user_message.len and user_message[end] != ' ' and user_message[end] != '\n') : (end += 1) {}
                    if (end > start) query = user_message[start..end];
                }

                const result = tool.execute(ctx, query);
                defer if (result.owned) self.allocator.free(result.data);

                if (result.success) {
                    try sess.addMessage("assistant", result.data);
                    return try self.allocator.dupe(u8, result.data);
                } else {
                    const err_msg = result.error_msg orelse "tool failed";
                    try sess.addMessage("assistant", err_msg);
                    return try self.allocator.dupe(u8, err_msg);
                }
            }
        }

        const response = "ZiggyClaw agent ready (no tool triggered)";
        try sess.addMessage("assistant", response);
        return try self.allocator.dupe(u8, response);
    }
};
