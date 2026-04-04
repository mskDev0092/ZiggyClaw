const std = @import("std");
const core = @import("core");
const registry = @import("registry.zig");

const ProcessManager = struct {
    processes: std.StringHashMap(ProcessInfo),

    const ProcessInfo = struct {
        pid: i32,
        command: []const u8,
        started: i64,
        status: []const u8,
    };

    fn init(allocator: std.mem.Allocator) ProcessManager {
        return .{ .processes = std.StringHashMap(ProcessInfo).init(allocator) };
    }

    fn add(self: *ProcessManager, name: []const u8, pid: i32, command: []const u8) !void {
        try self.processes.put(name, .{
            .pid = pid,
            .command = command,
            .started = std.time.timestamp(),
            .status = "running",
        });
    }

    fn listAll(self: *ProcessManager, allocator: std.mem.Allocator) ![]const ProcessInfo {
        var result = std.ArrayList(ProcessInfo).init(allocator);
        var it = self.processes.valueIterator();
        while (it.next()) |p| {
            try result.append(p.*);
        }
        return result.toOwnedSlice();
    }

    fn get(self: *ProcessManager, name: []const u8) ?ProcessInfo {
        return self.processes.get(name);
    }

    fn remove(self: *ProcessManager, name: []const u8) void {
        self.processes.remove(name);
    }
};

var manager: ?ProcessManager = null;
var manager_allocator: ?std.mem.Allocator = null;

fn ensureManager(allocator: std.mem.Allocator) void {
    if (manager == null) {
        manager = ProcessManager.init(allocator);
        manager_allocator = allocator;
    }
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    ensureManager(ctx.allocator);

    const trimmed = std.mem.trim(u8, params, " \n\r");
    if (trimmed.len == 0) {
        return .{ .success = false, .data = "", .error_msg = "Usage: process <start|list|stop|status> [args]" };
    }

    var parts = std.mem.splitScalar(u8, trimmed, ' ');
    const action = parts.first();

    if (std.mem.eql(u8, action, "list")) {
        const processes = manager.?.listAll(ctx.allocator) catch return .{ .success = false, .data = "", .error_msg = "Failed to list processes" };
        defer ctx.allocator.free(processes);

        if (processes.len == 0) {
            return .{ .success = true, .data = "No background processes running", .owned = false };
        }

        var result = std.ArrayList(u8).init(ctx.allocator);
        result.appendSlice("Background Processes:\n\n") catch {};
        for (processes) |p| {
            result.appendSlice("• ") catch {};
            result.appendSlice(p.command) catch {};
            result.appendSlice(" (PID: ") catch {};
            result.appendSlice(std.fmt.allocPrint(ctx.allocator, "{d}", .{p.pid}) catch unreachable) catch {};
            result.appendSlice(")\n") catch {};
        }
        return .{ .success = true, .data = result.items, .owned = true };
    }

    if (std.mem.eql(u8, action, "start")) {
        const cmd = parts.rest();
        if (cmd.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: process start <command>" };
        }

        var args = std.ArrayList([]const u8).init(ctx.allocator);
        var iter = std.mem.splitScalar(u8, cmd, ' ');
        while (iter.next()) |arg| {
            if (arg.len > 0) args.append(arg) catch {};
        }

        var child = std.process.Child.init(args.items, ctx.allocator);
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Pipe;

        child.spawn() catch |err| {
            return .{ .success = false, .data = "", .error_msg = @errorName(err) };
        };

        const name = std.fmt.allocPrint(ctx.allocator, "proc_{d}", .{child.id}) catch "proc_unknown";
        manager.?.add(name, child.id, cmd) catch {};

        const result = std.fmt.allocPrint(ctx.allocator, "Started process: {s} (PID: {d})", .{ cmd, child.id }) catch "";
        return .{ .success = true, .data = result, .owned = true };
    }

    if (std.mem.eql(u8, action, "stop")) {
        const target = parts.rest();
        if (target.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: process stop <name or pid>" };
        }

        return .{ .success = false, .data = "", .error_msg = "Process stop not yet implemented - use shell to kill processes" };
    }

    if (std.mem.eql(u8, action, "status")) {
        const target = parts.rest();
        if (target.len == 0) {
            return .{ .success = false, .data = "", .error_msg = "Usage: process status <name>" };
        }

        if (manager.?.get(target)) |p| {
            const result = std.fmt.allocPrint(ctx.allocator, "Process: {s}\n  PID: {d}\n  Command: {s}\n  Status: {s}", .{
                target, p.pid, p.command, p.status,
            }) catch "";
            return .{ .success = true, .data = result, .owned = true };
        }
        return .{ .success = false, .data = "", .error_msg = "Process not found" };
    }

    return .{ .success = false, .data = "", .error_msg = "Usage: process <start|list|stop|status>" };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "process",
        .description = "Manage background processes. Usage: process <start|list|stop|status> [args]. start <cmd>: launch background process. list: show running processes. status <name>: check process info.",
        .execute = execute,
    };
}
