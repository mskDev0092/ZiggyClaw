const std = @import("std");

pub const Message = struct {
    role: []const u8,
    content: []const u8,
};

pub const ToolResult = struct {
    success: bool,
    data: []const u8,
    error_msg: ?[]const u8 = null,
    owned: bool = false,
};

pub const ToolContext = struct {
    allocator: std.mem.Allocator,
    session_id: []const u8,
};

pub const ToolDefinition = struct {
    name: []const u8,
    description: []const u8,
};

pub const AgentConfig = struct {
    model: []const u8 = "gpt-4o",
};
