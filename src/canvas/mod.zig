const std = @import("std");
const types = @import("../core/types.zig");

pub const CanvasState = struct {
    allocator: std.mem.Allocator,
    objects: std.ArrayList(CanvasObject),
    history: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator) CanvasState {
        return .{
            .allocator = allocator,
            .objects = std.ArrayList(CanvasObject).init(allocator),
            .history = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *CanvasState) void {
        for (self.objects.items) |obj| {
            self.allocator.free(obj.id);
            self.allocator.free(obj.obj_type);
            if (obj.data) |d| self.allocator.free(d);
        }
        self.objects.deinit();
        for (self.history.items) |h| self.allocator.free(h);
        self.history.deinit();
    }
};

pub const CanvasObject = struct {
    id: []const u8,
    obj_type: []const u8,
    x: f64,
    y: f64,
    width: f64,
    height: f64,
    data: ?[]const u8,
};

pub const CanvasCommand = enum {
    push,
    eval,
    snapshot,
    clear,
};

pub const CanvasHandler = struct {
    allocator: std.mem.Allocator,
    state: CanvasState,

    pub fn init(allocator: std.mem.Allocator) CanvasHandler {
        return .{
            .allocator = allocator,
            .state = CanvasState.init(allocator),
        };
    }

    pub fn deinit(self: *CanvasHandler) void {
        self.state.deinit();
    }

    pub fn handlePush(self: *CanvasHandler, object_json: []const u8) ![]const u8 {
        var id: []const u8 = "";
        var obj_type: []const u8 = "rect";
        var x: f64 = 0;
        var y: f64 = 0;
        var width: f64 = 100;
        var height: f64 = 100;
        var data: ?[]const u8 = null;

        if (std.mem.indexOf(u8, object_json, "\"id\":")) |idx| {
            const start = idx + 6;
            if (start < object_json.len and object_json[start] == '"') {
                var end = start + 1;
                while (end < object_json.len and object_json[end] != '"') : (end += 1) {}
                id = try self.allocator.dupe(u8, object_json[start + 1 .. end]);
            }
        }
        if (id.len == 0) {
            id = try std.fmt.allocPrint(self.allocator, "obj-{}", .{self.state.objects.items.len});
        }

        if (std.mem.indexOf(u8, object_json, "\"type\":")) |idx| {
            const start = idx + 8;
            if (start < object_json.len and object_json[start] == '"') {
                var end = start + 1;
                while (end < object_json.len and object_json[end] != '"') : (end += 1) {}
                obj_type = try self.allocator.dupe(u8, object_json[start + 1 .. end]);
            }
        }

        if (std.mem.indexOf(u8, object_json, "\"x\":")) |idx| {
            const start = idx + 4;
            var end = start;
            while (end < object_json.len and object_json[end] >= '0' and object_json[end] <= '9') : (end += 1) {}
            if (end > start) {
                const slice = object_json[start..end];
                x = std.fmt.parseFloat(f64, slice) catch 0;
            }
        }
        if (std.mem.indexOf(u8, object_json, "\"y\":")) |idx| {
            const start = idx + 4;
            var end = start;
            while (end < object_json.len and object_json[end] >= '0' and object_json[end] <= '9') : (end += 1) {}
            if (end > start) {
                const slice = object_json[start..end];
                y = std.fmt.parseFloat(f64, slice) catch 0;
            }
        }

        try self.state.objects.append(.{
            .id = id,
            .obj_type = obj_type,
            .x = x,
            .y = y,
            .width = width,
            .height = height,
            .data = data,
        });

        return try std.fmt.allocPrint(self.allocator, "{{\"status\": \"pushed\", \"id\": \"{s}\"}}", .{id});
    }

    pub fn handleEval(self: *CanvasHandler, code: []const u8) ![]const u8 {
        _ = code;
        return try self.allocator.dupe(u8, "{\"status\": \"eval_not_implemented\"}");
    }

    pub fn handleSnapshot(self: *CanvasHandler) ![]const u8 {
        var json = std.ArrayList(u8).init(self.allocator);
        defer json.deinit();

        try json.appendSlice("{\"objects\":[");

        for (self.state.objects.items, 0..) |obj, i| {
            if (i > 0) try json.appendSlice(",");
            try json.appendSlice("{");
            try json.appendSlice(try std.fmt.allocPrint(self.allocator, "\"id\":\"{s}\",", .{obj.id}));
            try json.appendSlice(try std.fmt.allocPrint(self.allocator, "\"type\":\"{s}\",", .{obj.obj_type}));
            try json.appendSlice(try std.fmt.allocPrint(self.allocator, "\"x\":{},", .{obj.x}));
            try json.appendSlice(try std.fmt.allocPrint(self.allocator, "\"y\":{},", .{obj.y}));
            try json.appendSlice(try std.fmt.allocPrint(self.allocator, "\"w\":{},", .{obj.width}));
            try json.appendSlice(try std.fmt.allocPrint(self.allocator, "\"h\":{}", .{obj.height}));
            try json.appendSlice("}");
        }

        try json.appendSlice("],\"count\":");
        try json.appendSlice(try std.fmt.allocPrint(self.allocator, "{}", .{self.state.objects.items.len}));
        try json.appendSlice("}");

        return try json.toOwnedSlice();
    }

    pub fn handleClear(self: *CanvasHandler) ![]const u8 {
        for (self.state.objects.items) |obj| {
            self.allocator.free(obj.id);
            self.allocator.free(obj.obj_type);
            if (obj.data) |d| self.allocator.free(d);
        }
        self.state.objects.clearRetainingCapacity();
        return try self.allocator.dupe(u8, "{\"status\": \"cleared\"}");
    }

    pub fn processCommand(self: *CanvasHandler, cmd: []const u8, payload: []const u8) ![]const u8 {
        if (std.mem.eql(u8, cmd, "push")) {
            return try self.handlePush(payload);
        } else if (std.mem.eql(u8, cmd, "eval")) {
            return try self.handleEval(payload);
        } else if (std.mem.eql(u8, cmd, "snapshot")) {
            return try self.handleSnapshot();
        } else if (std.mem.eql(u8, cmd, "clear")) {
            return try self.handleClear();
        } else {
            return try std.fmt.allocPrint(self.allocator, "{{\"error\": \"unknown_command: {s}\"}}", .{cmd});
        }
    }
};

pub fn startCanvasServer(port: u16) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var handler = CanvasHandler.init(allocator);
    defer handler.deinit();

    const address = try std.net.Address.parseIp4("127.0.0.1", port);
    var listener = try address.listen(.{
        .reuse_address = true,
        .reuse_port = true,
    });
    defer listener.deinit();

    std.debug.print("🎨 Canvas server ready on ws://127.0.0.1:{d}/canvas\n", .{port});

    while (true) {
        const connection = try listener.accept();
        defer connection.stream.close();

        var buffer: [4096]u8 = undefined;
        const bytes_read = connection.stream.read(&buffer) catch |err| {
            if (err == error.WouldBlock) continue;
            continue;
        };

        if (bytes_read == 0) continue;

        const request = buffer[0..bytes_read];

        if (std.mem.indexOf(u8, request, "GET /canvas")) |_| {
            try connection.stream.writeAll("HTTP/1.1 101 Switching Protocols\r\n");
            try connection.stream.writeAll("Upgrade: websocket\r\n");
            try connection.stream.writeAll("Connection: Upgrade\r\n");
            try connection.stream.writeAll("Sec-WebSocket-Accept: SAMPLE\r\n\r\n");

            std.debug.print("🎨 WebSocket connected\n", .{});

            var frame_buffer: [4096]u8 = undefined;
            while (true) {
                const frame_len = connection.stream.read(&frame_buffer) catch break;
                if (frame_len == 0) break;

                const frame = frame_buffer[0..frame_len];
                if (frame.len >= 2) {
                    const opcode = frame[0] & 0x0f;
                    if (opcode == 8) break;

                    if (opcode == 1 and frame.len > 2) {
                        const payload_len = frame[1] & 0x7f;
                        if (frame.len >= 2 + payload_len) {
                            const payload = frame[2..(2 + payload_len)];
                            const response = handler.processCommand("snapshot", "") catch continue;
                            defer allocator.free(response);

                            try connection.stream.writeAll(&frame_buffer[0..2]);
                            const len = response.len;
                            try connection.stream.writeAll(&[_]u8{@intCast(len & 0x7f)});
                            try connection.stream.writeAll(response);
                        }
                    }
                }
            }
        } else {
            try connection.stream.writeAll("HTTP/1.1 404 Not Found\r\n\r\n");
        }
    }
}
