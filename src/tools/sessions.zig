const std = @import("std");
const core = @import("core");
const registry = @import("registry.zig");

var global_manager: ?*core.session.SessionManager = null;
var global_allocator: ?std.mem.Allocator = null;

pub fn setGlobalManager(manager: *core.session.SessionManager, allocator: std.mem.Allocator) void {
    global_manager = manager;
    global_allocator = allocator;
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    const trimmed = std.mem.trim(u8, params, " \n\r");
    if (trimmed.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: sessions <list|send|spawn> [args]" };
    }

    var parts = std.mem.splitScalar(u8, trimmed, ' ');
    const action = parts.first();

    if (std.mem.eql(u8, action, "list")) {
        if (global_manager == null) {
            return .{ .success = false, .data = "", .error_msg = "Session manager not initialized" };
        }
        const manager = global_manager.?;
        var result = std.ArrayList(u8).init(ctx.allocator);
        defer result.deinit();
        result.appendSlice("Active Sessions:\n") catch {};
        var count: usize = 0;
        var it = manager.sessions.iterator();
        while (it.next()) |entry| {
            count += 1;
            result.appendSlice("• ") catch {};
            result.appendSlice(entry.key_ptr.*) catch {};
            result.appendSlice(" (") catch {};
            const msg_count = entry.value_ptr.*.messages.items.len;
            result.appendSlice(std.fmt.allocPrint(ctx.allocator, "{d} messages", .{msg_count}) catch "") catch {};
            result.appendSlice(")\n") catch {};
        }
        if (count == 0) {
            result.appendSlice("  (none)\n") catch {};
        }
        const data = result.toOwnedSlice() catch "";
        return .{ .success = true, .data = data, .owned = true };
    }

    if (std.mem.eql(u8, action, "send")) {
        if (global_manager == null) {
            return .{ .success = false, .data = "", .error_msg = "Session manager not initialized" };
        }
        const session_id = parts.next() orelse {
            return .{ .success = false, .data = "", .error_msg = "Usage: sessions send <session_id> <message>" };
        };
        const message = parts.rest();
        if (message.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: sessions send <session_id> <message>" };
        }
        const manager = global_manager.?;
        const session = manager.getOrCreate(session_id) catch {
            return .{ .success = false, .data = "", .error_msg = "Failed to get or create session" };
        };
        session.addMessage("user", message) catch {
            return .{ .success = false, .data = "", .error_msg = "Failed to add message to session" };
        };
        return .{ .success = true, .data = "Message sent to session", .owned = false };
    }

    if (std.mem.eql(u8, action, "spawn")) {
        if (global_manager == null) {
            return .{ .success = false, .data = "", .error_msg = "Session manager not initialized" };
        }
        const name = parts.next() orelse {
            return .{ .success = false, .data = "", .error_msg = "Usage: sessions spawn <name>" };
        };
        const manager = global_manager.?;
        _ = manager.getOrCreate(name) catch {
            return .{ .success = false, .data = "", .error_msg = "Failed to spawn session" };
        };
        const msg = std.fmt.allocPrint(ctx.allocator, "Spawned session: {s}", .{name}) catch "Spawned session";
        return .{ .success = true, .data = msg, .owned = true };
    }

    return .{ .success = false, .data = "", .error_msg = "Unknown sessions command. Use: list, send, spawn" };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "sessions",
        .description = "Manage agent sessions: list, send, spawn",
        .execute = execute,
    };
}
