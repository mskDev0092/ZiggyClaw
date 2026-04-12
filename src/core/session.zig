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
};
