const std = @import("std");
const types = @import("types.zig");

pub const Session = struct {
    id: []const u8,
    messages: std.ArrayList(types.Message),
    allocator: std.mem.Allocator,
    token_count: usize = 0,
    summary: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) !Session {
        return Session{
            .id = try allocator.dupe(u8, id),
            .messages = std.ArrayList(types.Message).init(allocator),
            .allocator = allocator,
            .token_count = 0,
            .summary = null,
        };
    }

    pub fn deinit(self: *Session) void {
        self.allocator.free(self.id);
        for (self.messages.items) |*msg| {
            self.allocator.free(msg.role);
            self.allocator.free(msg.content);
        }
        self.messages.deinit();
        if (self.summary) |s| self.allocator.free(s);
    }

    pub fn save(self: *Session, dir: std.fs.Dir) !void {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();

        try json.appendSlice("{\n");
        try json.appendSlice("  \"id\": \"");
        try json.appendSlice(self.id);
        try json.appendSlice("\",\n");
        try json.appendSlice("  \"token_count\": ");
        try json.appendSlice(try std.fmt.allocPrint(self.allocator, "{}", .{self.token_count}));
        try json.appendSlice(",\n");
        try json.appendSlice("  \"summary\": ");
        if (self.summary) |s| {
            try json.appendSlice("\"");
            for (s) |c| {
                if (c == '"') try json.appendSlice("\\\"") else try json.append(c);
            }
            try json.appendSlice("\"");
        } else {
            try json.appendSlice("null");
        }
        try json.appendSlice(",\n");
        try json.appendSlice("  \"messages\": [\n");

        for (self.messages.items, 0..) |msg, i| {
            if (i > 0) try json.appendSlice(",\n");
            try json.appendSlice("    {\"role\": \"");
            for (msg.role) |c| {
                if (c == '"') try json.appendSlice("\\\"") else try json.append(c);
            }
            try json.appendSlice("\", \"content\": \"");
            for (msg.content) |c| {
                if (c == '"') try json.appendSlice("\\\"") else try json.append(c);
            }
            try json.appendSlice("\"}");
        }
        try json.appendSlice("\n  ]\n");
        try json.appendSlice("}\n");

        try dir.writeFile(self.id, json.items);
    }

    pub fn load(allocator: std.mem.Allocator, dir: std.fs.Dir, id: []const u8) !Session {
        const content = try dir.readFileAlloc(allocator, id, 1024 * 64);
        defer allocator.free(content);

        var session = try Session.init(allocator, id);

        if (std.mem.indexOf(u8, content, "\"messages\":")) |msg_start| {
            const after_messages = content[msg_start + 10 ..];
            var role_start: ?usize = null;
            var content_start: ?usize = null;

            var in_role = false;
            var in_content = false;
            var current_field: enum { none, role, content } = .none;

            for (after_messages, 0..) |c, i| {
                if (c == '"' and current_field == .none) {
                    const before = after_messages[0..i];
                    if (std.mem.endsWith(u8, before, "\"role\":")) {
                        in_role = true;
                        current_field = .role;
                    } else if (std.mem.endsWith(u8, before, "\"content\":")) {
                        in_content = true;
                        current_field = .content;
                    }
                }

                if (in_role and current_field == .role and c == '"') {
                    if (role_start == null) {
                        role_start = i + 1;
                    } else {
                        const role = after_messages[role_start..i];
                        const content_start_val = content_start orelse continue;
                        var content_end_idx = i;
                        while (content_end_idx > content_start_val and content_end_idx > 0) {
                            content_end_idx -= 1;
                            if (after_messages[content_end_idx] == '"') break;
                        }
                        const cont = after_messages[content_start_val..content_end_idx];
                        try session.addMessage(role, cont);
                        in_role = false;
                        in_content = false;
                        current_field = .none;
                        role_start = null;
                        content_start = null;
                    }
                }

                if (in_content and current_field == .content and c == '"') {
                    if (content_start == null) {
                        content_start = i + 1;
                    }
                }
            }
        }

        return session;
    }

    pub fn addMessage(self: *Session, role: []const u8, content: []const u8) !void {
        const r = try self.allocator.dupe(u8, role);
        const c = try self.allocator.dupe(u8, content);
        try self.messages.append(.{ .role = r, .content = c });
        self.token_count += self.estimateTokens(content);
    }

    pub fn estimateTokens(self: *Session, text: []const u8) usize {
        _ = self;
        return (text.len / 4) + 1;
    }

    pub fn getTokenCount(self: *Session) usize {
        return self.token_count;
    }

    pub fn needsCompaction(self: *Session, limit: usize, threshold_percent: u8) bool {
        const threshold = @divFloor(limit * threshold_percent, 100);
        return self.token_count >= threshold;
    }

    pub fn compact(self: *Session, allocator: std.mem.Allocator) !void {
        if (self.messages.items.len < 4) return;

        var summary_content = std.ArrayList(u8).init(allocator);
        errdefer summary_content.deinit();

        try summary_content.appendSlice("Previous conversation summary: ");

        var i: usize = 0;
        const keep_from = if (self.messages.items.len > 10) self.messages.items.len - 10 else 0;

        while (i < keep_from) : (i += 1) {
            const msg = self.messages.items[i];
            if (msg.content.len > 100) {
                try summary_content.appendSlice(msg.role);
                try summary_content.appendSlice(": ");
                try summary_content.appendSlice(msg.content[0..100]);
                try summary_content.appendSlice("... ");
            } else {
                try summary_content.appendSlice(msg.role);
                try summary_content.appendSlice(": ");
                try summary_content.appendSlice(msg.content);
                try summary_content.appendSlice(" ");
            }
        }

        if (self.summary) |old| allocator.free(old);
        self.summary = try summary_content.toOwnedSlice();

        const remove_count = keep_from;
        var j: usize = 0;
        while (j < remove_count) : (j += 1) {
            const msg = self.messages.items[0];
            allocator.free(msg.role);
            allocator.free(msg.content);
            _ = self.messages.orderedRemove(0);
        }

        self.token_count = 0;
        for (self.messages.items) |msg| {
            self.token_count += self.estimateTokens(msg.content);
        }

        const summary_msg = try self.allocator.dupe(u8, "system");
        const summary_content_copy = try self.allocator.dupe(u8, self.summary.?);
        try self.messages.insert(0, .{ .role = summary_msg, .content = summary_content_copy });
        self.token_count += self.estimateTokens(self.summary.?);
    }
};

pub const SessionManager = struct {
    sessions: std.StringHashMap(Session),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) SessionManager {
        return .{
            .sessions = std.StringHashMap(Session).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SessionManager) void {
        var it = self.sessions.iterator();
        while (it.next()) |entry| {
            var s = entry.value_ptr.*;
            s.deinit();
        }
        self.sessions.deinit();
    }

    pub fn getOrCreate(self: *SessionManager, id: []const u8) !*Session {
        if (self.sessions.getPtr(id)) |s| return s;

        const new_session = try Session.init(self.allocator, id);
        try self.sessions.put(id, new_session);
        return self.sessions.getPtr(id).?;
    }

    pub fn saveAll(self: *SessionManager, dir_path: []const u8) !void {
        const dir = try std.fs.cwd().makeOpenPath(dir_path, .{});
        defer dir.close();

        var iter = self.sessions.iterator();
        while (iter.next()) |entry| {
            try entry.value_ptr.save(dir);
        }
    }

    pub fn loadFromDir(self: *SessionManager, dir_path: []const u8) !void {
        const dir = try std.fs.cwd().openDir(dir_path, .{});
        defer dir.close();

        var iter = dir.iterate();
        while (try iter.next()) |entry| {
            if (entry.kind == .file) {
                const name = entry.name;
                if (std.mem.endsWith(u8, name, ".json") or std.mem.indexOf(u8, name, ".") == null) {
                    const session_name = if (std.mem.indexOf(u8, name, ".")) |dot| name[0..dot] else name;
                    const session = try Session.load(self.allocator, dir, session_name);
                    try self.sessions.put(session_name, session);
                }
            }
        }
    }
};
