const std = @import("std");
const types = @import("types.zig");
const tools = @import("tools");
const session_mod = @import("session.zig");

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

    pub fn think(self: *Agent, session_id: []const u8, user_message: []const u8) ![]const u8 {
        const sess = try self.session_manager.getOrCreate(session_id);
        try sess.addMessage("user", user_message);

        // Simple tool detection (expand later with real LLM parsing)

        // Check for file_read command first (look for patterns like "read file:" or "file_read")
        if (std.mem.indexOf(u8, user_message, "file_read") != null or std.mem.indexOf(u8, user_message, "read file") != null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("file_read")) |tool| {
                // Extract filename - default to build.zig
                var filename: []const u8 = "build.zig";

                // Try to extract filename from message
                if (std.mem.indexOf(u8, user_message, "build.zig")) |_| {
                    filename = "build.zig";
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

        if (std.mem.indexOf(u8, user_message, "shell") != null) {
            const ctx = types.ToolContext{
                .allocator = self.allocator,
                .session_id = session_id,
            };

            if (self.tool_registry.get("shell")) |tool| {
                const result = tool.execute(ctx, "ls"); // safe placeholder command
                if (result.success) {
                    try sess.addMessage("assistant", result.data);
                    return result.data;
                } else {
                    try sess.addMessage("assistant", result.error_msg orelse "tool failed");
                    return result.error_msg orelse "tool failed";
                }
            }
        }

        // Default response when no tool triggered
        const response = "ZiggyClaw agent ready (no tool triggered)";
        try sess.addMessage("assistant", response);
        return response;
    }
};
