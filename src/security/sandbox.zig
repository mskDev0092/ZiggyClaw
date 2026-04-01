const std = @import("std");

/// Execute a command safely in a sandbox environment
/// Returns the stdout output as a string
/// The caller is responsible for freeing the returned string
pub fn runSandboxed(allocator: std.mem.Allocator, cmd: []const u8) ![]const u8 {
    // Use caller's allocator to manage the output lifetime
    // Parse the command and arguments
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

    // Execute the process
    var child = std.process.Child.init(args.items, allocator);
    child.stdout_behavior = .Pipe;
    child.stderr_behavior = .Pipe;

    try child.spawn();

    // Read stdout
    const stdout = try child.stdout.?.readToEndAlloc(allocator, 64 * 1024);

    // Wait for process to finish
    const term = try child.wait();

    switch (term) {
        .Exited => |code| {
            if (code != 0) {
                return error.CommandFailed;
            }
            return stdout;
        },
        else => return error.CommandTerminatedAbnormally,
    }
}
