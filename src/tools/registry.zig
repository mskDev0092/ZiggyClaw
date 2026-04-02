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

    pub fn list(self: *const ToolRegistry) []const Tool {
        var count: usize = 0;
        var it = self.tools.iterator();
        while (it.next()) |_| {
            count += 1;
        }
        var result = self.allocator.alloc(Tool, count) catch return &[_]Tool{};
        var i: usize = 0;
        var it2 = self.tools.iterator();
        while (it2.next()) |entry| {
            result[i] = entry.value_ptr.*;
            i += 1;
        }
        return result;
    }

    pub fn get(self: *const ToolRegistry, name: []const u8) ?Tool {
        return self.tools.get(name);
    }
};
