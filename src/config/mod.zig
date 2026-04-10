const std = @import("std");

pub const Config = struct {
    gateway: GatewayConfig,
    agent: AgentConfig,
    tools: ToolsConfig,
    logging: LoggingConfig,
};

pub const GatewayConfig = struct {
    port: u16 = 18789,
    host: []const u8 = "127.0.0.1",
    workers: u8 = 4,
    timeout_seconds: u32 = 30,
};

pub const AgentConfig = struct {
    model: []const u8 = "claude-3-sonnet",
    max_iterations: u8 = 10,
    temperature: f32 = 0.7,
    api_base: []const u8 = "",
    api_key: []const u8 = "",
};

pub const ToolsConfig = struct {
    shell_whitelist: []const []const u8 = &.{ "ls", "echo", "cat", "pwd", "git" },
    max_file_size: usize = 1024 * 1024,
    allow_path_traversal: bool = false,
    file_read_allowed_paths: []const []const u8 = &.{"."},
};

pub const LoggingConfig = struct {
    level: []const u8 = "info",
    format: []const u8 = "text",
};

var config_instance: ?Config = null;
var config_mutex: std.Thread.Mutex = undefined;

pub fn init() void {
    config_mutex = .{};
}

pub fn load(allocator: std.mem.Allocator, path: []const u8) !Config {
    const file = std.fs.cwd().openFile(path, .{}) catch |err| {
        if (err == error.FileNotFound) {
            return getDefaults(allocator);
        }
        return err;
    };
    defer file.close();

    const content = try file.readToEndAlloc(allocator, 1024 * 16);
    defer allocator.free(content);

    return try parseJson(allocator, content);
}

fn parseJson(allocator: std.mem.Allocator, content: []const u8) !Config {
    var config = try getDefaults(allocator);
    errdefer config.deinit(allocator);

    var parser = std.json.Parser.init(allocator, .{});
    defer parser.deinit();

    const parsed = try parser.parse(content);
    defer parsed.deinit();

    if (parsed.value != .object) return config;

    const obj = parsed.value.object;
    if (obj.get("gateway")) |gw| {
        if (gw == .object) {
            if (gw.object.get("port")) |v| {
                if (v == .integer) config.gateway.port = @intCast(v.integer);
            }
            if (gw.object.get("host")) |v| {
                if (v == .string) {
                    allocator.free(config.gateway.host);
                    config.gateway.host = try allocator.dupe(u8, v.string);
                }
            }
            if (gw.object.get("workers")) |v| {
                if (v == .integer) config.gateway.workers = @intCast(v.integer);
            }
            if (gw.object.get("timeout")) |v| {
                if (v == .integer) config.gateway.timeout_seconds = @intCast(v.integer);
            }
        }
    }

    if (obj.get("agent")) |ag| {
        if (ag == .object) {
            if (ag.object.get("model")) |v| {
                if (v == .string) {
                    allocator.free(config.agent.model);
                    config.agent.model = try allocator.dupe(u8, v.string);
                }
            }
            if (ag.object.get("max_iterations")) |v| {
                if (v == .integer) config.agent.max_iterations = @intCast(v.integer);
            }
            if (ag.object.get("temperature")) |v| {
                if (v == .float) config.agent.temperature = v.float;
            }
        }
    }

    if (obj.get("tools")) |tl| {
        if (tl == .object) {
            if (tl.object.get("shell_whitelist")) |_| {
                if (false) {
                    // Reserved for whitelist parsing
                }
            }
        }
    }

    return config;
}

pub fn loadFromEnv(allocator: std.mem.Allocator, config: *Config) !void {
    var env_map = try std.process.getEnvMap(allocator);
    defer env_map.deinit();

    if (env_map.get("GATEWAY_PORT")) |p| {
        config.gateway.port = std.fmt.parseInt(u16, p, 10) catch config.gateway.port;
    }
    if (env_map.get("GATEWAY_HOST")) |h| {
        allocator.free(config.gateway.host);
        config.gateway.host = try allocator.dupe(u8, h);
    }
    if (env_map.get("OPENAI_API_BASE")) |b| {
        allocator.free(config.agent.api_base);
        config.agent.api_base = try allocator.dupe(u8, b);
    }
    if (env_map.get("OPENAI_API_KEY")) |k| {
        allocator.free(config.agent.api_key);
        config.agent.api_key = try allocator.dupe(u8, k);
    }
    if (env_map.get("AGENT_MODEL")) |m| {
        allocator.free(config.agent.model);
        config.agent.model = try allocator.dupe(u8, m);
    }
    if (env_map.get("LOG_LEVEL")) |l| {
        allocator.free(config.logging.level);
        config.logging.level = try allocator.dupe(u8, l);
    }
}

fn getDefaults(allocator: std.mem.Allocator) !Config {
    return .{
        .gateway = .{
            .port = 18789,
            .host = try allocator.dupe(u8, "127.0.0.1"),
            .workers = 4,
            .timeout_seconds = 30,
        },
        .agent = .{
            .model = try allocator.dupe(u8, "claude-3-sonnet"),
            .max_iterations = 10,
            .temperature = 0.7,
            .api_base = try allocator.dupe(u8, ""),
            .api_key = try allocator.dupe(u8, ""),
        },
        .tools = .{
            .shell_whitelist = &.{ try allocator.dupe(u8, "ls"), try allocator.dupe(u8, "echo"), try allocator.dupe(u8, "cat"), try allocator.dupe(u8, "pwd"), try allocator.dupe(u8, "git") },
            .max_file_size = 1024 * 1024,
            .allow_path_traversal = false,
            .file_read_allowed_paths = &.{try allocator.dupe(u8, ".")},
        },
        .logging = .{
            .level = try allocator.dupe(u8, "info"),
            .format = try allocator.dupe(u8, "text"),
        },
    };
}

pub fn set(config: Config) void {
    config_mutex.lock();
    defer config_mutex.unlock();
    config_instance = config;
}

pub fn get() ?Config {
    config_mutex.lock();
    defer config_mutex.unlock();
    return config_instance;
}

pub fn reload(allocator: std.mem.Allocator, path: []const u8) !void {
    const new_config = try load(allocator, path);
    set(new_config);
}

pub fn save(config: Config, allocator: std.mem.Allocator, path: []const u8) !void {
    const file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var json = std.ArrayList(u8).init(allocator);
    defer json.deinit();

    try json.appendSlice("{\n");
    try json.appendSlice("  \"gateway\": {\n");
    {
        const port_line = try std.fmt.allocPrint(allocator, "    \"port\": {d},\n", .{config.gateway.port});
        defer allocator.free(port_line);
        try json.appendSlice(port_line);
    }
    {
        const host_line = try std.fmt.allocPrint(allocator, "    \"host\": \"{s}\",\n", .{config.gateway.host});
        defer allocator.free(host_line);
        try json.appendSlice(host_line);
    }
    {
        const workers_line = try std.fmt.allocPrint(allocator, "    \"workers\": {d},\n", .{config.gateway.workers});
        defer allocator.free(workers_line);
        try json.appendSlice(workers_line);
    }
    {
        const timeout_line = try std.fmt.allocPrint(allocator, "    \"timeout\": {d}\n", .{config.gateway.timeout_seconds});
        defer allocator.free(timeout_line);
        try json.appendSlice(timeout_line);
    }
    try json.appendSlice("  },\n");
    try json.appendSlice("  \"agent\": {\n");
    {
        const model_line = try std.fmt.allocPrint(allocator, "    \"model\": \"{s}\",\n", .{config.agent.model});
        defer allocator.free(model_line);
        try json.appendSlice(model_line);
    }
    {
        const iter_line = try std.fmt.allocPrint(allocator, "    \"max_iterations\": {d},\n", .{config.agent.max_iterations});
        defer allocator.free(iter_line);
        try json.appendSlice(iter_line);
    }
    {
        const temp_line = try std.fmt.allocPrint(allocator, "    \"temperature\": {d:.2}\n", .{config.agent.temperature});
        defer allocator.free(temp_line);
        try json.appendSlice(temp_line);
    }
    try json.appendSlice("  },\n");
    try json.appendSlice("  \"tools\": {\n");
    try json.appendSlice("    \"shell_whitelist\": [");
    for (config.tools.shell_whitelist, 0..) |cmd, i| {
        if (i > 0) try json.appendSlice(", ");
        const cmd_line = try std.fmt.allocPrint(allocator, "\"{s}\"", .{cmd});
        defer allocator.free(cmd_line);
        try json.appendSlice(cmd_line);
    }
    try json.appendSlice("],\n");
    {
        const size_line = try std.fmt.allocPrint(allocator, "    \"max_file_size\": {d}\n", .{config.tools.max_file_size});
        defer allocator.free(size_line);
        try json.appendSlice(size_line);
    }
    try json.appendSlice("  },\n");
    try json.appendSlice("  \"logging\": {\n");
    {
        const level_line = try std.fmt.allocPrint(allocator, "    \"level\": \"{s}\",\n", .{config.logging.level});
        defer allocator.free(level_line);
        try json.appendSlice(level_line);
    }
    {
        const format_line = try std.fmt.allocPrint(allocator, "    \"format\": \"{s}\"\n", .{config.logging.format});
        defer allocator.free(format_line);
        try json.appendSlice(format_line);
    }
    try json.appendSlice("  }\n");
    try json.appendSlice("}\n");

    try file.writeAll(json.items);
}

pub fn deinit(config: *Config, allocator: std.mem.Allocator) void {
    allocator.free(config.gateway.host);
    allocator.free(config.agent.model);
    allocator.free(config.agent.api_base);
    allocator.free(config.agent.api_key);
    for (config.tools.shell_whitelist) |cmd| {
        allocator.free(cmd);
    }
    allocator.free(config.tools.shell_whitelist);
    for (config.tools.file_read_allowed_paths) |p| {
        allocator.free(p);
    }
    allocator.free(config.tools.file_read_allowed_paths);
    allocator.free(config.logging.level);
    allocator.free(config.logging.format);
}

pub fn loadAndApply(allocator: std.mem.Allocator, path: []const u8) !Config {
    var cfg = try load(allocator, path);
    try loadFromEnv(allocator, &cfg);
    set(cfg);
    return cfg;
}
