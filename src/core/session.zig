const std = @import("std");
const types = @import("types.zig");

pub const Session = struct {
    id: []const u8,
    messages: std.ArrayList(types.Message),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: []const u8) !Session {
        return Session{
            .id = try allocator.dupe(u8, id),
            .messages = std.ArrayList(types.Message).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Session) void {
        self.allocator.free(self.id);
        for (self.messages.items) |*msg| {
            self.allocator.free(msg.role);
            self.allocator.free(msg.content);
        }
        self.messages.deinit();
    }

    pub fn addMessage(self: *Session, role: []const u8, content: []const u8) !void {
        const r = try self.allocator.dupe(u8, role);
        const c = try self.allocator.dupe(u8, content);
        try self.messages.append(.{ .role = r, .content = c });
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
