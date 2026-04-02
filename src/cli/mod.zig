const std = @import("std");
const core = @import("core");
const tools = @import("tools");

pub fn run(allocator: std.mem.Allocator) !void {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();

    _ = args.skip(); // executable name

    const subcommand = args.next() orelse "help";

    if (std.mem.eql(u8, subcommand, "help") or std.mem.eql(u8, subcommand, "--help") or std.mem.eql(u8, subcommand, "-h")) {
        printHelp();
        return;
    }

    if (std.mem.eql(u8, subcommand, "version")) {
        try std.io.getStdOut().writer().print("ZiggyClaw v0.1.0\n", .{});
        return;
    }

    if (std.mem.eql(u8, subcommand, "gateway") or std.mem.eql(u8, subcommand, "start")) {
        // Default gateway port for local testing
        var port: u16 = 1234;

        // Allow overriding via environment variable GATEWAY_PORT
        var env_map = try std.process.getEnvMap(allocator);
        defer env_map.deinit();
        if (env_map.get("GATEWAY_PORT")) |p| {
            // parse decimal u16, fall back to default on parse error
            const parsed = std.fmt.parseInt(u16, p, 10) catch port;
            port = parsed;
        }

        try core.gateway.start(port);
        return;
    }

    if (std.mem.eql(u8, subcommand, "tool")) {
        if (args.next()) |tool_subcommand| {
            if (std.mem.eql(u8, tool_subcommand, "list")) {
                try listTools(allocator);
                return;
            }
        }
    }

    if (std.mem.eql(u8, subcommand, "doctor")) {
        try runDoctor();
        return;
    }

    if (std.mem.eql(u8, subcommand, "onboard")) {
        try std.io.getStdOut().writer().print("ZiggyClaw onboard complete. Ready to use.\n", .{});
        return;
    }

    if (std.mem.eql(u8, subcommand, "agent")) {
        try runAgent(allocator, &args);
        return;
    }

    // Unknown
    try std.io.getStdOut().writer().print("Unknown command: {s}\n\n", .{subcommand});
    printHelp();
}

fn printHelp() void {
    const stdout = std.io.getStdOut().writer();
    stdout.print(
        \\🦞 ZiggyClaw
        \\Usage:
        \\  ziggyclaw help
        \\  ziggyclaw version
        \\  ziggyclaw agent <message>
        \\  ziggyclaw gateway start
        \\  ziggyclaw tool list
        \\  ziggyclaw doctor
        \\  ziggyclaw onboard
        \\
    , .{}) catch {};
}

fn listTools(allocator: std.mem.Allocator) !void {
    var registry = tools.registry.ToolRegistry.init(allocator);
    defer registry.deinit();

    // Register built-in tools
    try registry.register(tools.shell.getTool());
    try registry.register(tools.file_read.getTool());

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Available tools:\n", .{});
    registry.list();
}

fn runDoctor() !void {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("ZiggyClaw doctor: All systems OK 🦞\n", .{});
}

fn runAgent(allocator: std.mem.Allocator, args: *std.process.ArgIterator) !void {
    // Collect remaining args as the message
    var message_parts = std.ArrayList([]const u8).init(allocator);
    defer message_parts.deinit();

    while (args.next()) |arg| {
        try message_parts.append(arg);
    }

    if (message_parts.items.len == 0) {
        try std.io.getStdOut().writer().print("Usage: ziggyclaw agent <message>\n", .{});
        return;
    }

    // Join message parts with spaces
    const message = try std.mem.join(allocator, " ", message_parts.items);
    defer allocator.free(message);

    // Initialize components
    var session_manager = core.session.SessionManager.init(allocator);
    defer session_manager.deinit();

    var registry = tools.registry.ToolRegistry.init(allocator);
    defer registry.deinit();

    // Register built-in tools
    try registry.register(tools.shell.getTool());
    try registry.register(tools.file_read.getTool());

    const config = core.types.AgentConfig{
        .model = "cli-agent",
    };

    var agent = core.agent.Agent.init(allocator, config, &session_manager, &registry);

    // Run agent
    const response = try agent.think("cli-session", message);
    try std.io.getStdOut().writer().print("{s}\n", .{response});
    // Note: response may be a string literal or allocated data, so we don't free it
}
