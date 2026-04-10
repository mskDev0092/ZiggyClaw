const std = @import("std");
const core = @import("core");
const security = @import("security");
const registry = @import("registry.zig");

const allowed_commands = [_][]const u8{
    "ls",  "echo", "pwd",  "cat",  "wc",   "grep",  "find",   "head", "tail", "sort", "uniq",
    "cut", "tr",   "diff", "stat", "file", "which", "whoami", "date", "id",   "env",
};

fn isCommandAllowed(cmd: []const u8) bool {
    const first_space = std.mem.indexOf(u8, cmd, " ") orelse cmd.len;
    const command = cmd[0..first_space];

    for (allowed_commands) |allowed| {
        if (std.mem.eql(u8, command, allowed)) {
            return true;
        }
    }
    return false;
}

fn containsDangerousPatterns(params: []const u8) bool {
    const dangerous = [_][]const u8{ "&&", "||", ";", "|", ">", ">>", "<", "$", "`", "\\", "rm -rf", "mkfs", "dd if=" };

    for (dangerous) |pattern| {
        if (std.mem.indexOf(u8, params, pattern) != null) {
            return true;
        }
    }
    return false;
}

fn parseTimeout(params: []const u8) usize {
    const timeout_idx = std.mem.indexOf(u8, params, "\"timeout\":") orelse return 30;
    var cursor = timeout_idx + 10;
    while (cursor < params.len and (params[cursor] == ' ' or params[cursor] == '\t')) cursor += 1;
    var end = cursor;
    while (end < params.len and params[end] >= '0' and params[end] <= '9') end += 1;
    if (end > cursor) {
        return std.fmt.parseInt(usize, params[cursor..end], 10) catch 30;
    }
    return 30;
}

fn parseArgs(params: []const u8) ?[]const u8 {
    const cmd_start = std.mem.indexOf(u8, params, "\"cmd\":") orelse return null;
    var cursor = cmd_start + 6;
    while (cursor < params.len and (params[cursor] == ' ' or params[cursor] == '\t')) cursor += 1;
    if (cursor >= params.len or params[cursor] != '"') return null;
    cursor += 1;
    const value_start = cursor;
    while (cursor < params.len and params[cursor] != '"') cursor += 1;
    if (cursor >= params.len) return null;
    return params[value_start..cursor];
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    const clean_params = parseArgs(params) orelse {
        return .{ .success = false, .data = "", .error_msg = "Invalid arguments: expected {\"cmd\":\"...\"}" };
    };

    if (!isCommandAllowed(clean_params)) {
        return .{ .success = false, .data = "", .error_msg = "Command not allowed" };
    }

    if (containsDangerousPatterns(clean_params)) {
        return .{ .success = false, .data = "", .error_msg = "Command contains dangerous patterns" };
    }

    const timeout = parseTimeout(params);
    const capped_timeout = if (timeout > 60) 60 else timeout;

    const output = security.sandbox.runWithTimeout(ctx.allocator, clean_params, capped_timeout) catch |err| {
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };
    };

    return .{ .success = true, .data = output, .owned = true };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "execute_command",
        .description = "Run shell commands with timeout. Usage: execute_command {\"cmd\":\"<command>\", \"timeout\":30}. Allowed: ls, echo, pwd, cat, wc, grep, find, head, tail, sort, etc. Max 60s timeout.",
        .execute = execute,
    };
}
