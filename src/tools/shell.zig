const std = @import("std");
const core = @import("core");
const security = @import("security");
const registry = @import("registry.zig");

fn isCommandAllowed(cmd: []const u8) bool {
    const allowed_cmds = [_][]const u8{ "ls", "echo", "pwd", "cat", "wc", "grep" };

    for (allowed_cmds) |allowed| {
        if (std.mem.startsWith(u8, cmd, allowed)) {
            // Check that the next character is a space or end of string (to avoid matching "lsx")
            if (cmd.len == allowed.len or cmd[allowed.len] == ' ') {
                return true;
            }
        }
    }
    return false;
}

fn containsDangerousPatterns(params: []const u8) bool {
    // Block command injection patterns
    const dangerous = [_][]const u8{ "&&", "||", ";", "|", ">", "<", "$", "`", "\\", "*", "?" };

    for (dangerous) |pattern| {
        if (std.mem.indexOf(u8, params, pattern) != null) {
            return true;
        }
    }
    return false;
}

fn execute(ctx: core.types.ToolContext, params: []const u8) core.types.ToolResult {

    // Safety check 1: Only allow whitelisted commands
    if (!isCommandAllowed(params)) {
        return .{ .success = false, .data = "", .error_msg = "Command not allowed. Allowed: ls, echo, pwd, cat, wc, grep" };
    }

    // Safety check 2: Reject dangerous shell patterns
    if (containsDangerousPatterns(params)) {
        return .{ .success = false, .data = "", .error_msg = "Command contains dangerous characters" };
    }

    const output = security.sandbox.runSandboxed(ctx.allocator, params) catch |err|
        return .{ .success = false, .data = "", .error_msg = @errorName(err) };

    // Note: caller is responsible for freeing the output
    return .{ .success = true, .data = output };
}

pub fn getTool() registry.ToolRegistry.Tool {
    return .{
        .name = "shell",
        .description = "Run safe shell commands (ls, echo, pwd, cat, wc, grep only)",
        .execute = execute,
    };
}
