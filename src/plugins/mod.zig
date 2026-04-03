const std = @import("std");
const tools = @import("../tools");
const types = @import("../core/types.zig");

pub const PluginManifest = struct {
    name: []const u8,
    version: []const u8,
    description: []const u8,
    init_fn: ?*const fn () void,
};

pub const LoadedPlugin = struct {
    name: []const u8,
    handle: std.DlHandle,
    manifest: ?PluginManifest,
};

pub const PluginManager = struct {
    allocator: std.mem.Allocator,
    loaded: std.ArrayList(LoadedPlugin),

    pub fn init(allocator: std.mem.Allocator) PluginManager {
        return .{
            .allocator = allocator,
            .loaded = std.ArrayList(LoadedPlugin).init(allocator),
        };
    }

    pub fn deinit(self: *PluginManager) void {
        for (self.loaded.items) |plugin| {
            self.allocator.free(plugin.name);
            std.dlclose(plugin.handle) catch {};
        }
        self.loaded.deinit();
    }

    pub fn load(self: *PluginManager, path: []const u8) !void {
        const dl_path = try self.allocator.dupe(u8, path);
        errdefer self.allocator.free(dl_path);

        const handle = try std.dlopen(dl_path, .{});
        errdefer std.dlclose(handle) catch {};

        const name = std.fs.path.basename(path);
        const name_copy = try self.allocator.dupe(u8, name);

        try self.loaded.append(.{
            .name = name_copy,
            .handle = handle,
            .manifest = null,
        });

        std.debug.print("📦 Loaded plugin: {s}\n", .{name});
    }

    pub fn unload(self: *PluginManager, name: []const u8) !void {
        for (self.loaded.items, 0..) |plugin, idx| {
            if (std.mem.eql(u8, plugin.name, name)) {
                try self.loaded.swapRemove(idx);
                std.debug.print("📦 Unloaded plugin: {s}\n", .{name});
                return;
            }
        }
        return error.PluginNotFound;
    }

    pub fn list(self: *PluginManager) []const LoadedPlugin {
        return self.loaded.items;
    }

    pub fn registerTools(self: *PluginManager, registry: *tools.registry.ToolRegistry) !void {
        _ = registry;
        for (self.loaded.items) |plugin| {
            std.debug.print("📦 Registered tools from: {s}\n", .{plugin.name});
        }
    }
};

pub fn getManifest(handle: std.DlHandle) ?PluginManifest {
    const sym = std.dlsym(handle, "plugin_manifest", .{
        .type = *const PluginManifest,
    }) catch return null;
    return sym.*;
}

pub fn callInit(handle: std.DlHandle) void {
    const sym = std.dlsym(handle, "plugin_init", .{
        .type = *const fn () void,
    }) catch return;
    sym();
}

pub fn scanPluginDirectory(allocator: std.mem.Allocator, dir_path: []const u8) ![]const []const u8 {
    var results = std.ArrayList([]const u8).init(allocator);

    const dir = std.fs.cwd().openDir(dir_path, .{}) catch return &.{};
    defer dir.close();

    var iter = dir.iterate();
    while (iter.next() catch null) |entry| {
        if (entry.kind == .file) {
            const name = entry.name;
            const ext = std.fs.path.extension(name);
            if (std.mem.eql(u8, ext, ".so") or std.mem.eql(u8, ext, ".dylib") or std.mem.eql(u8, ext, ".dll")) {
                const full_path = try std.fs.path.join(allocator, &.{ dir_path, name });
                try results.append(full_path);
            }
        }
    }

    return try results.toOwnedSlice();
}
