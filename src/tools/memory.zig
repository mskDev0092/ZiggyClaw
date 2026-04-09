const std = @import("std");
const core = @import("core");
const registry = @import("registry.zig");
const memory_mod = @import("memory");

var global_memory: ?*memory_mod.Memory = null;
var global_allocator: ?std.mem.Allocator = null;

pub fn setGlobalMemory(mem: *memory_mod.Memory, allocator: std.mem.Allocator) void {
    global_memory = mem;
    global_allocator = allocator;
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    const trimmed = std.mem.trim(u8, params, " \n\r");
    if (trimmed.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: memory <get|put|index|search> [args]" };
    }

    var parts = std.mem.splitScalar(u8, trimmed, ' ');
    const action = parts.first();

    if (std.mem.eql(u8, action, "get")) {
        const key = parts.next() orelse {
            return .{ .success = false, .data = "", .error_msg = "Usage: memory get <key>" };
        };
        if (global_memory) |mem| {
            if (mem.get(key)) |value| {
                return .{ .success = true, .data = value, .owned = false };
            }
            return .{ .success = false, .data = "", .error_msg = "Key not found" };
        }
        return .{ .success = false, .data = "", .error_msg = "Memory not initialized" };
    }

    if (std.mem.eql(u8, action, "put")) {
        const key = parts.next() orelse {
            return .{ .success = false, .data = "", .error_msg = "Usage: memory put <key> <value>" };
        };
        const value = parts.rest();
        if (value.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: memory put <key> <value>" };
        }
        if (global_memory) |mem| {
            mem.put(key, value);
            return .{ .success = true, .data = "Stored", .owned = false };
        }
        return .{ .success = false, .data = "", .error_msg = "Memory not initialized" };
    }

    if (std.mem.eql(u8, action, "index")) {
        const id = parts.next() orelse {
            return .{ .success = false, .data = "", .error_msg = "Usage: memory index <doc_id> <content>" };
        };
        const content = parts.rest();
        if (content.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: memory index <doc_id> <content>" };
        }
        if (global_memory) |mem| {
            mem.indexDocument(id, content);
            return .{ .success = true, .data = "Indexed", .owned = false };
        }
        return .{ .success = false, .data = "", .error_msg = "Memory not initialized" };
    }

    if (std.mem.eql(u8, action, "search")) {
        const query = parts.rest();
        if (query.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: memory search <query>" };
        }
        if (global_memory) |mem| {
            const results = mem.search(query, 5);
            var result_str = std.ArrayList(u8).init(ctx.allocator);
            defer result_str.deinit();
            result_str.appendSlice("Search results:\n") catch {};
            for (results) |doc| {
                result_str.appendSlice("• ") catch {};
                result_str.appendSlice(doc.id) catch {};
                result_str.appendSlice(": ") catch {};
                const preview = if (doc.content.len > 100) doc.content[0..100] else doc.content;
                result_str.appendSlice(preview) catch {};
                result_str.appendSlice("\n") catch {};
            }
            if (results.len == 0) {
                result_str.appendSlice("  (no results)\n") catch {};
            }
            return .{ .success = true, .data = result_str.toOwnedSlice() catch "", .owned = true };
        }
        return .{ .success = false, .data = "", .error_msg = "Memory not initialized" };
    }

    return .{ .success = false, .data = "", .error_msg = "Use: get, put, index, search" };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "memory",
        .description = "In-memory store: get, put, index, search",
        .execute = execute,
    };
}
