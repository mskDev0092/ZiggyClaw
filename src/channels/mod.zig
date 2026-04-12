const std = @import("std");
const agent_mod = @import("../core/agent.zig");
const session_mod = @import("../core/session.zig");
const tools = @import("../tools");
const types = @import("../core/types.zig");

pub const ChannelType = enum {
    http_webhook,
    stdio,
    discord,
    telegram,
    signal,
};

pub const ChannelMessage = struct {
    id: []const u8,
    channel_type: ChannelType,
    content: []const u8,
    metadata: std.StringHashMap([]const u8),
};

pub const ChannelHandler = struct {
    allocator: std.mem.Allocator,
    session_manager: *session_mod.SessionManager,
    tool_registry: *tools.registry.ToolRegistry,
    agent: *agent_mod.Agent,

    pub fn init(
        allocator: std.mem.Allocator,
        session_manager: *session_mod.SessionManager,
        tool_registry: *tools.registry.ToolRegistry,
        agent: *agent_mod.Agent,
    ) ChannelHandler {
        return .{
            .allocator = allocator,
            .session_manager = session_manager,
            .tool_registry = tool_registry,
            .agent = agent,
        };
    }

    pub fn handleMessage(self: *ChannelHandler, channel_type: ChannelType, content: []const u8) ![]const u8 {
        const session_id = switch (channel_type) {
            .http_webhook => "webhook-session",
            .stdio => "stdio-session",
        };

        const response = try self.agent.think(session_id, content);
        return response;
    }

    pub fn parseWebhookRequest(self: *ChannelHandler, body: []const u8) !ChannelMessage {
        var msg = ChannelMessage{
            .id = try std.fmt.allocPrint(self.allocator, "msg-{}", .{std.time.timestamp()}),
            .channel_type = .http_webhook,
            .content = undefined,
            .metadata = std.StringHashMap([]const u8).init(self.allocator),
        };
        errdefer msg.metadata.deinit();

        if (std.mem.indexOf(u8, body, "\"message\":")) |idx| {
            const start = idx + 10;
            if (start < body.len and body[start] == '"') {
                var end = start + 1;
                while (end < body.len and body[end] != '"') : (end += 1) {}
                msg.content = try self.allocator.dupe(u8, body[start + 1 .. end]);
            }
        } else if (std.mem.indexOf(u8, body, "\"text\":")) |idx| {
            const start = idx + 7;
            if (start < body.len and body[start] == '"') {
                var end = start + 1;
                while (end < body.len and body[end] != '"') : (end += 1) {}
                msg.content = try self.allocator.dupe(u8, body[start + 1 .. end]);
            }
        } else {
            msg.content = try self.allocator.dupe(u8, body);
        }

        return msg;
    }

    pub fn deinit(self: *ChannelHandler) void {
        self.session_manager.deinit();
    }
};

pub fn startWebhookServer(port: u16, handler: *ChannelHandler) !void {
    const address = try std.net.Address.parseIp4("127.0.0.1", port);
    var listener = try address.listen(.{
        .reuse_address = true,
        .reuse_port = true,
    });
    defer listener.deinit();

    std.debug.print("🌐 Webhook channel ready on http://127.0.0.1:{d}/webhook\n", .{port});

    while (true) {
        const connection = try listener.accept();
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch |err| {
            if (err == error.WouldBlock) continue;
            return err;
        };

        if (bytes_read == 0) continue;

        const request = buffer[0..bytes_read];

        if (std.mem.indexOf(u8, request, "POST /webhook") != null) {
            if (std.mem.indexOf(u8, request, "\r\n\r\n")) |body_start| {
                const body = request[body_start + 4 ..];

                const msg = handler.parseWebhookRequest(body) catch |err| {
                    std.debug.print("Failed to parse webhook: {}\n", .{err});
                    continue;
                };
                defer {
                    handler.allocator.free(msg.id);
                    handler.allocator.free(msg.content);
                    msg.metadata.deinit();
                }

                const response_text = handler.handleMessage(.http_webhook, msg.content) catch |err| {
                    std.debug.print("Failed to handle message: {}\n", .{err});
                    continue;
                };
                defer handler.allocator.free(response_text);

                const json_resp = try std.fmt.allocPrint(handler.allocator, "{{\"status\": \"ok\", \"response\": \"{s}\"}}", .{response_text});
                defer handler.allocator.free(json_resp);

                try connection.stream.writeAll("HTTP/1.1 200 OK\r\n");
                try connection.stream.writeAll("Content-Type: application/json\r\n");
                try connection.stream.writeAll("Content-Length: ");
                try connection.stream.writeAll(std.fmt.integerPrint(.{ .value = json_resp.len, .fill = 0 }));
                try connection.stream.writeAll("\r\n\r\n");
                try connection.stream.writeAll(json_resp);

                std.debug.print("🌐 Webhook message processed\n", .{});
            }
        } else {
            try connection.stream.writeAll("HTTP/1.1 404 Not Found\r\n\r\n");
        }
    }
}

pub fn startStdioChannel(handler: *ChannelHandler) !void {
    const stdin = std.io.getStdIn();
    const stdout = std.io.getStdOut();

    std.debug.print("📡 Stdio channel ready (Ctrl+C to exit)\n", .{});

    var buffer: [4096]u8 = undefined;
    while (true) {
        const bytes_read = stdin.read(&buffer) catch break;
        if (bytes_read == 0) break;

        const input = std.mem.trim(u8, buffer[0..bytes_read], "\n\r ");
        if (input.len == 0) continue;

        const response = handler.handleMessage(.stdio, input) catch {
            continue;
        };
        defer handler.allocator.free(response);

        try stdout.writer().print("{s}\n", .{response});
    }
}

pub const DiscordConfig = struct {
    bot_token: []const u8,
    channel_id: []const u8,
};

pub fn startDiscordChannel(config: DiscordConfig, handler: *ChannelHandler) !void {
    _ = config;
    _ = handler;
    std.debug.print("📱 Discord channel ready (bot mode)\n", .{});
    std.debug.print("   Note: Discord integration requires gateway mode\n", .{});
}

pub const TelegramConfig = struct {
    bot_token: []const u8,
    allowed_users: []const []const u8,
};

pub fn startTelegramChannel(config: TelegramConfig, handler: *ChannelHandler) !void {
    _ = config;
    _ = handler;
    std.debug.print("📱 Telegram channel ready (bot mode)\n", .{});
    std.debug.print("   Note: Telegram integration requires gateway mode\n", .{});
}

pub const SignalConfig = struct {
    phone_number: []const u8,
    signal_cli_path: []const u8,
};

pub fn startSignalChannel(config: SignalConfig, handler: *ChannelHandler) !void {
    _ = config;
    _ = handler;
    std.debug.print("📱 Signal channel ready (cli mode)\n", .{});
    std.debug.print("   Note: Signal integration requires gateway mode and signal-cli\n", .{});
}

pub const HeartbeatConfig = struct {
    interval_seconds: u32 = 60,
    endpoint: ?[]const u8 = null,
};

pub const HeartbeatStatus = struct {
    healthy: bool,
    last_check: i64,
    checks_passed: u32,
    checks_failed: u32,
};

pub const Heartbeat = struct {
    allocator: std.mem.Allocator,
    interval_seconds: u32,
    status: HeartbeatStatus,
    running: bool,

    pub fn init(allocator: std.mem.Allocator, interval_seconds: u32) Heartbeat {
        return .{
            .allocator = allocator,
            .interval_seconds = interval_seconds,
            .status = .{
                .healthy = true,
                .last_check = std.time.timestamp(),
                .checks_passed = 0,
                .checks_failed = 0,
            },
            .running = false,
        };
    }

    pub fn start(self: *Heartbeat) void {
        self.running = true;
        std.debug.print("💓 Heartbeat started (interval: {}s)\n", .{self.interval_seconds});
    }

    pub fn stop(self: *Heartbeat) void {
        self.running = false;
    }

    pub fn check(self: *Heartbeat) void {
        self.status.last_check = std.time.timestamp();
        if (self.status.healthy) {
            self.status.checks_passed += 1;
        } else {
            self.status.checks_failed += 1;
        }
    }

    pub fn getStatus(self: *Heartbeat) HeartbeatStatus {
        return self.status;
    }
};

pub const CronTask = struct {
    id: []const u8,
    command: []const u8,
    interval_seconds: u32,
    enabled: bool,
};

pub const CronScheduler = struct {
    allocator: std.mem.Allocator,
    tasks: std.ArrayList(CronTask),
    running: bool,

    pub fn init(allocator: std.mem.Allocator) CronScheduler {
        return .{
            .allocator = allocator,
            .tasks = std.ArrayList(CronTask).init(allocator),
            .running = false,
        };
    }

    pub fn addTask(self: *CronScheduler, id: []const u8, command: []const u8, interval_seconds: u32) !void {
        try self.tasks.append(.{
            .id = try self.allocator.dupe(u8, id),
            .command = try self.allocator.dupe(u8, command),
            .interval_seconds = interval_seconds,
            .enabled = true,
        });
    }

    pub fn removeTask(self: *CronScheduler, id: []const u8) void {
        var i: usize = 0;
        while (i < self.tasks.items.len) {
            if (std.mem.eql(u8, self.tasks.items[i].id, id)) {
                _ = self.tasks.orderedRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn start(self: *CronScheduler) void {
        self.running = true;
        std.debug.print("⏰ Cron scheduler started ({} tasks)\n", .{self.tasks.items.len});
    }

    pub fn stop(self: *CronScheduler) void {
        self.running = false;
    }

    pub fn listTasks(self: *CronScheduler) []const CronTask {
        return self.tasks.items;
    }
};
