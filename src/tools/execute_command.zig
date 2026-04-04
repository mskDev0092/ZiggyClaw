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
    const timeout_idx = std.mem.indexOf(u8, params, "--timeout ") orelse return 30;
    const timeout_str = params[timeout_idx + 11 ..];
    const end = std.mem.indexOf(u8, timeout_str, " ") orelse timeout_str.len;
    return std.fmt.parseInt(usize, timeout_str[0..end], 10) catch 30;
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {
    const clean_params = if (std.mem.indexOf(u8, params, "--timeout ") != null) blk: {
        var result = std.ArrayList(u8).init(ctx.allocator);
        var i: usize = 0;
        while (i < params.len) {
            if (std.mem.startsWith(u8, params[i..], "--timeout ")) {
                const next_space = std.mem.indexOf(u8, params[i..], " ") orelse params.len;
                i += next_space;
                while (i < params.len and params[i] == ' ') i += 1;
                while (i < params.len and params[i] != ' ') i += 1;
                continue;
            }
            result.append(params[i]) catch {};
            i += 1;
        }
        break :blk result.items;
    } else params;

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
        .description = "Run shell commands with timeout. Usage: execute_command <cmd> [--timeout seconds]. Allowed: ls, echo, pwd, cat, wc, grep, find, head, tail, sort, etc. Max 60s timeout.",
        .execute = execute,
    };
}
