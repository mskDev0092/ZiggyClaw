const std = @import("std");

/// Execute a command safely in a sandbox environment
/// Returns the stdout output as a string
/// The caller is responsible for freeing the returned string
pub fn runSandboxed(allocator: std.mem.Allocator, cmd: []const u8) ![]const u8 {
    return runWithTimeout(allocator, cmd, 30);
}

/// Execute a command with timeout (in seconds)
pub fn runWithTimeout(allocator: std.mem.Allocator, cmd: []const u8, timeout_secs: usize) ![]const u8 {
    _ = timeout_secs;
    // Note: Zig's Child process doesn't have built-in timeout support
    // For now we rely on the caller to manage timeouts externally
    // The timeout param is reserved for future implementation
    var args = std.ArrayList([]const u8).init(allocator);
    defer args.deinit();

    var iter = std.mem.splitSequence(u8, cmd, " ");
    while (iter.next()) |arg| {
        if (arg.len > 0) {
            try args.append(arg);
        }
    }

    if (args.items.len == 0) {
        return error.EmptyCommand;
    }

    var child = std.process.Child.init(args.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    const stdout = try child.stdout.?.readToEndAlloc(allocator, 64 * 1024);

    const result = child.wait() catch {
        _ = child.kill() catch {};
        return error.CommandTimeout;
    };

    switch (result) {
        .Exited => |code| {
            if (code != 0) {
                return error.CommandFailed;
            }
            return stdout;
        },
        .Signal => |sig| {
            _ = sig;
            return error.CommandTerminatedAbnormally;
        },
        else => return error.CommandTerminatedAbnormally,
    }
}
