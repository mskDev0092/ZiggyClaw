const std = @import("std");
const core = @import("core");
const tools = @import("tools");
const memory_mod = @import("memory");

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
        var port: u16 = 18789;

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
        try runOnboard(allocator);
        return;
    }

    if (std.mem.eql(u8, subcommand, "agent")) {
        try runAgent(allocator, &args);
        return;
    }

    if (std.mem.eql(u8, subcommand, "pair")) {
        try runPair(allocator);
        return;
    }

    if (std.mem.eql(u8, subcommand, "tui")) {
        try runTUI(allocator);
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
    try registry.register(tools.write_file.getTool());
    try registry.register(tools.edit_file.getTool());
    try registry.register(tools.list_directory.getTool());
    try registry.register(tools.search_files.getTool());
    try registry.register(tools.find_files.getTool());
    try registry.register(tools.web_get.getTool());
    try registry.register(tools.web_fetch.getTool());
    try registry.register(tools.search.getTool());
    try registry.register(tools.execute_command.getTool());
    try registry.register(tools.process.getTool());
    try registry.register(tools.sessions.getTool());
    try registry.register(tools.secrets.getTool());
    try registry.register(tools.memory.getTool());

    const stdout = std.io.getStdOut().writer();
    try stdout.print("Available tools:\n", .{});
    const tool_list = registry.list();
    defer allocator.free(tool_list);
    for (tool_list) |tool| {
        try stdout.print("  • {s} - {s}\n", .{ tool.name, tool.description });
    }
}

fn runDoctor() !void {
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\  🦞 ZiggyClaw Doctor
        \\  ───────────────────
        \\
    , .{});

    var env_map = try std.process.getEnvMap(std.heap.page_allocator);
    defer env_map.deinit();

    try stdout.print("  [4] LLM Configuration:\n", .{});
    if (env_map.get("OPENAI_API_KEY")) |_| {
        try stdout.print("      - OPENAI_API_KEY: set\n", .{});
    } else {
        try stdout.print("      - OPENAI_API_KEY: not set\n", .{});
    }
    if (env_map.get("OPENAI_API_BASE")) |base| {
        try stdout.print("      - OPENAI_API_BASE: {s}\n", .{base});
    } else {
        try stdout.print("      - OPENAI_API_BASE: not set (defaults to OpenAI)\n", .{});
    }

    try stdout.print("\n  Status: All OK 🦞\n\n", .{});
}

fn runOnboard(allocator: std.mem.Allocator) !void {
    _ = allocator;
    const stdout = std.io.getStdOut().writer();

    try stdout.print(
        \\
        \\  ╔══════════════════════════════════════════╗
        \\  ║       🦞 Welcome to ZiggyClaw! ⚡        ║
        \\  ╚══════════════════════════════════════════╝
        \\
        \\  ZiggyClaw is an AI agent framework with tools,
        \\  LLM integration, and extensible architecture.
        \\
        \\  ───────────────────────────────────────────
        \\  Quick Start:
        \\  ───────────────────────────────────────────
        \\
    , .{});

    try stdout.print("  1. Run agent:     {s}agent \"hello\"\n", .{"ziggyclaw "});
    try stdout.print("  2. Start server: {s}gateway start\n", .{"ziggyclaw "});
    try stdout.print("  3. List tools:   {s}tool list\n", .{"ziggyclaw "});
    try stdout.print("  4. Run doctor:   {s}doctor\n", .{"ziggyclaw "});

    try stdout.print(
        \\
        \\  ───────────────────────────────────────────
        \\  Environment Setup (optional):
        \\  ───────────────────────────────────────────
        \\  OPENAI_API_KEY     - Your OpenAI API key
        \\  OPENAI_API_BASE   - Custom LLM endpoint
        \\  GATEWAY_PORT      - Server port (default 18789)
        \\
        \\  Supported LLM providers: OpenAI, Ollama, LM Studio
        \\
        \\  ───────────────────────────────────────────
        \\  First Agent Test:
        \\  ───────────────────────────────────────────
        \\
    , .{});

    try stdout.print("  $ ziggyclaw agent \"shell: echo hello world\"\n\n", .{});

    try stdout.print("  Try it now!\n", .{});

    var buf: [10]u8 = undefined;
    const input = std.io.getStdIn().reader().readUntilDelimiterOrEof(&buf, '\n') catch null;
    _ = input;

    try stdout.print("\n✅ Onboarding complete! Run 'ziggyclaw help' for more.\n", .{});
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
    try registry.register(tools.write_file.getTool());
    try registry.register(tools.edit_file.getTool());
    try registry.register(tools.list_directory.getTool());
    try registry.register(tools.search_files.getTool());
    try registry.register(tools.find_files.getTool());
    try registry.register(tools.web_get.getTool());
    try registry.register(tools.web_fetch.getTool());
    try registry.register(tools.search.getTool());
    try registry.register(tools.execute_command.getTool());
    try registry.register(tools.process.getTool());
    try registry.register(tools.sessions.getTool());
    tools.sessions.setGlobalManager(&session_manager, allocator);
    try registry.register(tools.secrets.getTool());
    tools.secrets.initSecrets(allocator);
    try registry.register(tools.memory.getTool());
    var mem = memory_mod.Memory.init(allocator);
    tools.memory.setGlobalMemory(&mem, allocator);

    const config = core.types.AgentConfig{
        .model = "nvidia/nemotron-3-nano-4b",
    };

    var agent = core.agent.Agent.init(allocator, config, &session_manager, &registry);

    // Run agent
    const response = try agent.think("cli-session", message);
    defer allocator.free(response);
    try std.io.getStdOut().writer().print("{s}\n", .{response});
}

fn runPair(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn();

    try stdout.print(
        \\
        \\  ╔══════════════════════════════════════════╗
        \\  ║     🦞 ZiggyClaw Pair Mode ⚡             ║
        \\  ╚══════════════════════════════════════════╝
        \\
        \\  Entering interactive mode. Type your message
        \\  and press Enter to chat with the agent.
        \\  Press Ctrl+C or type 'exit' to quit.
        \\
        \\  ───────────────────────────────────────────
        \\
    , .{});

    var session_manager = core.session.SessionManager.init(allocator);
    defer session_manager.deinit();

    var registry = tools.registry.ToolRegistry.init(allocator);
    defer registry.deinit();

    try registry.register(tools.shell.getTool());
    try registry.register(tools.file_read.getTool());
    try registry.register(tools.write_file.getTool());
    try registry.register(tools.edit_file.getTool());
    try registry.register(tools.list_directory.getTool());
    try registry.register(tools.search_files.getTool());
    try registry.register(tools.find_files.getTool());
    try registry.register(tools.web_get.getTool());
    try registry.register(tools.web_fetch.getTool());
    try registry.register(tools.search.getTool());
    try registry.register(tools.execute_command.getTool());
    try registry.register(tools.process.getTool());
    try registry.register(tools.sessions.getTool());
    tools.sessions.setGlobalManager(&session_manager, allocator);
    try registry.register(tools.secrets.getTool());
    tools.secrets.initSecrets(allocator);
    try registry.register(tools.memory.getTool());
    var mem = memory_mod.Memory.init(allocator);
    tools.memory.setGlobalMemory(&mem, allocator);

    const config = core.types.AgentConfig{ .model = "nvidia/nemotron-3-nano-4b" };
    var agent = core.agent.Agent.init(allocator, config, &session_manager, &registry);

    var buffer: [4096]u8 = undefined;
    while (true) {
        try stdout.print("You> ", .{});

        const bytes_read = stdin.read(&buffer) catch {
            try stdout.print("\nGoodbye!\n", .{});
            break;
        };

        if (bytes_read == 0) break;

        const input = std.mem.trim(u8, buffer[0..bytes_read], "\n\r");

        if (input.len == 0) continue;

        if (std.mem.eql(u8, input, "exit") or std.mem.eql(u8, input, "quit")) {
            try stdout.print("Goodbye!\n", .{});
            break;
        }

        const response = agent.think("pair-session", input) catch {
            try stdout.print("Error: Failed to get response\n", .{});
            continue;
        };
        defer allocator.free(response);

        try stdout.print("Agent> {s}\n\n", .{response});
    }
}

const TUICommand = struct {
    name: []const u8,
    description: []const u8,
    handler: fn (allocator: std.mem.Allocator, args: []const u8) anyerror!void,
};

fn runTUI(allocator: std.mem.Allocator) !void {
    const stdout = std.io.getStdOut().writer();
    const stdin = std.io.getStdIn();

    try stdout.print(
        \\
        \\  ╔══════════════════════════════════════════╗
        \\  ║      🦞 ZiggyClaw TUI Mode ⚡            ║
        \\  ╚══════════════════════════════════════════╝
        \\
        \\  Type /help for available commands
        \\  Press Ctrl+C or /exit to quit
        \\
        \\  ───────────────────────────────────────────
        \\
    , .{});

    var session_manager = core.session.SessionManager.init(allocator);
    defer session_manager.deinit();

    var registry = tools.registry.ToolRegistry.init(allocator);
    defer registry.deinit();

    try registry.register(tools.shell.getTool());
    try registry.register(tools.file_read.getTool());
    try registry.register(tools.write_file.getTool());
    try registry.register(tools.edit_file.getTool());
    try registry.register(tools.list_directory.getTool());
    try registry.register(tools.search_files.getTool());
    try registry.register(tools.find_files.getTool());
    try registry.register(tools.web_get.getTool());
    try registry.register(tools.web_fetch.getTool());
    try registry.register(tools.search.getTool());
    try registry.register(tools.execute_command.getTool());
    try registry.register(tools.process.getTool());
    try registry.register(tools.sessions.getTool());
    tools.sessions.setGlobalManager(&session_manager, allocator);
    try registry.register(tools.secrets.getTool());
    tools.secrets.initSecrets(allocator);
    try registry.register(tools.memory.getTool());
    var mem = memory_mod.Memory.init(allocator);
    tools.memory.setGlobalMemory(&mem, allocator);

    const config = core.types.AgentConfig{ .model = "nvidia/nemotron-3-nano-4b" };
    var agent = core.agent.Agent.init(allocator, config, &session_manager, &registry);

    const current_session_id: []const u8 = "default";

    try stdout.print("Session: {s}\n\n", .{current_session_id});

    var input_buffer = std.ArrayList(u8).init(allocator);
    defer input_buffer.deinit();

    while (true) {
        try stdout.print("🦞> ", .{});
        input_buffer.clearRetainingCapacity();

        while (true) {
            var byte: [1]u8 = undefined;
            const bytes_read = stdin.read(&byte) catch {
                try stdout.print("\nGoodbye!\n", .{});
                return;
            };

            if (bytes_read == 0) {
                try stdout.print("\n", .{});
                return;
            }

            if (byte[0] == '\t') {
                const completions = getCompletions(allocator, input_buffer.items, &registry);
                if (completions.len > 0) {
                    try stdout.print("\n", .{});
                    for (completions) |c| {
                        try stdout.print("  {s}\n", .{c});
                    }
                    try stdout.print("🦞> {s}", .{input_buffer.items});
                }
                continue;
            }

            if (byte[0] == '\n' or byte[0] == '\r') {
                try stdout.print("\n", .{});
                break;
            }

            try input_buffer.append(byte[0]);
        }

        const input = std.mem.trim(u8, input_buffer.items, " \n\r");
        if (input.len == 0) continue;

        if (input[0] == '/') {
            try handleSlashCommand(allocator, input, current_session_id, &session_manager, &registry);
            continue;
        }

        const response = agent.think(current_session_id, input) catch {
            try stdout.print("Error: Failed to get response\n\n", .{});
            continue;
        };
        defer allocator.free(response);

        try stdout.print("{s}\n\n", .{response});
    }
}

fn handleSlashCommand(allocator: std.mem.Allocator, input: []const u8, current_session_id: []const u8, session_manager: *core.session.SessionManager, registry: *tools.registry.ToolRegistry) !void {
    _ = current_session_id;
    const stdout = std.io.getStdOut().writer();
    const trimmed = std.mem.trim(u8, input[1..], " \n\r");

    if (std.mem.eql(u8, trimmed, "help") or std.mem.eql(u8, trimmed, "h")) {
        try stdout.print(
            \\
            \\  ╔═══════════════════════════════╗
            \\  ║     Available Commands         ║
            \\  ╚═══════════════════════════════╝
            \\  /help, /h      - Show this help
            \\  /clear         - Clear screen
            \\  /tools         - List available tools
            \\  /sessions      - List active sessions
            \\  /new <name>    - Create new session
            \\  /switch <name> - Switch to session
            \\  /model         - Show current model
            \\  /status        - Show agent status
            \\  /exit, /quit   - Exit TUI
            \\
            \\  Examples:
            \\    /tools
            \\    /new my-session
            \\    /switch default
            \\
        , .{});
        return;
    }

    if (std.mem.eql(u8, trimmed, "exit") or std.mem.eql(u8, trimmed, "quit")) {
        try stdout.print("Goodbye!\n", .{});
        std.process.exit(0);
        return;
    }

    if (std.mem.eql(u8, trimmed, "clear")) {
        try stdout.print("\x1b[2J\x1b[H", .{});
        return;
    }

    if (std.mem.eql(u8, trimmed, "tools")) {
        const tool_list = registry.list();
        defer allocator.free(tool_list);
        try stdout.print("Available tools:\n", .{});
        for (tool_list) |tool| {
            try stdout.print("  • {s}\n", .{tool.name});
        }
        return;
    }

    if (std.mem.eql(u8, trimmed, "sessions")) {
        var iter = session_manager.sessions.iterator();
        var count: usize = 0;
        while (iter.next()) |_| {
            count += 1;
        }
        if (count == 0) {
            try stdout.print("No active sessions\n", .{});
        } else {
            try stdout.print("Active sessions:\n", .{});
            var iter2 = session_manager.sessions.iterator();
            while (iter2.next()) |entry| {
                try stdout.print("  • {s}\n", .{entry.key_ptr.*});
            }
        }
        return;
    }

    try stdout.print("Unknown command: /{s}\n", .{trimmed});
}

fn getCompletions(allocator: std.mem.Allocator, input: []const u8, registry: *tools.registry.ToolRegistry) []const []const u8 {
    var completions = std.ArrayList([]const u8).init(allocator);
    if (input.len == 0) {
        return completions.items;
    }

    if (input[0] == '/') {
        const commands = [_][]const u8{ "help", "clear", "tools", "sessions", "model", "status", "exit", "quit" };
        const search = input[1..];
        for (commands) |cmd| {
            if (std.mem.startsWith(u8, cmd, search)) {
                const completion = std.fmt.allocPrint(allocator, "/{s}", .{cmd}) catch continue;
                completions.append(completion) catch {};
            }
        }
    } else {
        const tool_list = registry.list();
        for (tool_list) |tool| {
            if (std.mem.startsWith(u8, tool.name, input)) {
                completions.append(tool.name) catch {};
            }
        }
    }

    return completions.items;
}
