const std = @import("std");
const core = @import("core");
const registry = @import("registry.zig");

const Secret = struct {
    key: []const u8,
    value: []const u8,
};

var secrets: std.StringHashMap([]const u8) = undefined;
var secrets_allocator: ?std.mem.Allocator = null;

pub fn initSecrets(allocator: std.mem.Allocator) void {
    secrets = std.StringHashMap([]const u8).init(allocator);
    secrets_allocator = allocator;
}

pub fn deinitSecrets() void {
    if (secrets_allocator) |alloc| {
        var it = secrets.iterator();
        while (it.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            alloc.free(entry.value_ptr.*);
        }
    }
    secrets.deinit();
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    const trimmed = std.mem.trim(u8, params, " \n\r");
    if (trimmed.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: secrets <list|get|store> [args]" };
    }

    var parts = std.mem.splitScalar(u8, trimmed, ' ');
    const action = parts.first();

    if (std.mem.eql(u8, action, "list")) {
        var result = std.ArrayList(u8).init(ctx.allocator);
        defer result.deinit();
        result.appendSlice("Stored secrets:\n") catch {};
        var count: usize = 0;
        var it = secrets.iterator();
        while (it.next()) |entry| {
            count += 1;
            result.appendSlice("• ") catch {};
            result.appendSlice(entry.key_ptr.*) catch {};
            result.appendSlice("\n") catch {};
        }
        if (count == 0) {
            result.appendSlice("  (none)\n") catch {};
        }
        const data = result.toOwnedSlice() catch "";
        return .{ .success = true, .data = data, .owned = true };
    }

    if (std.mem.eql(u8, action, "get")) {
        const key = parts.next() orelse {
            return .{ .success = false, .data = "", .error_msg = "Usage: secrets get <key>" };
        };
        if (secrets.get(key)) |value| {
            return .{ .success = true, .data = value, .owned = false };
        }
        return .{ .success = false, .data = "", .error_msg = "Secret not found" };
    }

    if (std.mem.eql(u8, action, "store")) {
        const key = parts.next() orelse {
            return .{ .success = false, .data = "", .error_msg = "Usage: secrets store <key> <value>" };
        };
        const value = parts.rest();
        if (value.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: secrets store <key> <value>" };
        }
        if (secrets_allocator == null) {
            return .{ .success = false, .data = "", .error_msg = "Secrets not initialized" };
        }
        const alloc = secrets_allocator.?;
        const key_copy = alloc.dupe(u8, key) catch {
            return .{ .success = false, .data = "", .error_msg = "Failed to store secret" };
        };
        const value_copy = alloc.dupe(u8, value) catch {
            alloc.free(key_copy);
            return .{ .success = false, .data = "", .error_msg = "Failed to store secret" };
        };
        secrets.put(key_copy, value_copy) catch {
            alloc.free(key_copy);
            alloc.free(value_copy);
            return .{ .success = false, .data = "", .error_msg = "Failed to store secret" };
        };
        return .{ .success = true, .data = "Secret stored", .owned = false };
    }

    return .{ .success = false, .data = "", .error_msg = "Unknown secrets command. Use: list, get, store" };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "secrets",
        .description = "Manage secrets vault: list, get, store",
        .execute = execute,
    };
}
