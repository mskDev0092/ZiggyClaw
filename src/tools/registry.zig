const std = @import("std");
const core = @import("core");

pub const ToolRegistry = struct {
    tools: std.StringHashMap(Tool),
    allocator: std.mem.Allocator,

    pub const Tool = struct {
        name: []const u8,
        description: []const u8,
        execute: *const fn (ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult,
    };

    pub fn init(allocator: std.mem.Allocator) ToolRegistry {
        return .{ .tools = std.StringHashMap(Tool).init(allocator), .allocator = allocator };
    }

    pub fn deinit(self: *ToolRegistry) void {
        self.tools.deinit();
    }

    pub fn register(self: *ToolRegistry, tool: Tool) !void {
        try self.tools.put(tool.name, tool);
    }

    pub fn list(self: *const ToolRegistry) void {
        std.debug.print("Available tools:\n", .{});
        var it = self.tools.iterator();
        while (it.next()) |entry| {
            std.debug.print("  • {s} - {s}\n", .{ entry.key_ptr.*, entry.value_ptr.description });
        }
    }

    pub fn get(self: *const ToolRegistry, name: []const u8) ?Tool {
        return self.tools.get(name);
    }
};
