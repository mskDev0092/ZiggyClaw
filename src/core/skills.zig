const std = @import("std");
const types = @import("types.zig");

pub const SkillLoader = struct {
    pub fn loadFromFile(allocator: std.mem.Allocator, path: []const u8) !types.Skill {
        const file = try std.fs.cwd().openFile(path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(allocator, 1024 * 64);
        defer allocator.free(content);

        var name: []const u8 = "";
        var description: []const u8 = "";
        var prompt: []const u8 = "";

        var lines = std.mem.split(u8, content, "\n");
        while (lines.next()) |line| {
            const trimmed = std.mem.trim(u8, line, " \t");
            if (trimmed.len == 0) continue;

            if (std.mem.startsWith(u8, trimmed, "name:") or std.mem.startsWith(u8, trimmed, "name ")) {
                const colon = std.mem.indexOf(u8, trimmed, ":");
                if (colon) |c| {
                    name = try allocator.dupe(u8, std.mem.trim(u8, trimmed[c + 1 ..], " \"\t"));
                }
            } else if (std.mem.startsWith(u8, trimmed, "description:") or std.mem.startsWith(u8, trimmed, "description ")) {
                const colon = std.mem.indexOf(u8, trimmed, ":");
                if (colon) |c| {
                    description = try allocator.dupe(u8, std.mem.trim(u8, trimmed[c + 1 ..], " \"\t"));
                }
            } else if (std.mem.startsWith(u8, trimmed, "prompt:") or std.mem.startsWith(u8, trimmed, "prompt ")) {
                const colon = std.mem.indexOf(u8, trimmed, ":");
                if (colon) |c| {
                    prompt = try allocator.dupe(u8, std.mem.trim(u8, trimmed[c + 1 ..], " \"\t"));
                }
            }
        }

        if (name.len == 0) {
            name = try allocator.dupe(u8, "unnamed-skill");
        }
        if (description.len == 0) {
            description = try allocator.dupe(u8, "No description");
        }
        if (prompt.len == 0) {
            prompt = try allocator.dupe(u8, "You are a helpful assistant.");
        }

        return types.Skill.init(allocator, name, description, prompt);
    }
};

pub const SkillManager = struct {
    allocator: std.mem.Allocator,
    registry: *types.SkillRegistry,

    pub fn init(allocator: std.mem.Allocator, registry: *types.SkillRegistry) SkillManager {
        return .{
            .allocator = allocator,
            .registry = registry,
        };
    }

    pub fn enableSkill(self: *SkillManager, name: []const u8) void {
        if (self.registry.get(name)) |skill| {
            skill.enabled = true;
        }
    }

    pub fn disableSkill(self: *SkillManager, name: []const u8) void {
        if (self.registry.get(name)) |skill| {
            skill.enabled = false;
        }
    }

    pub fn listEnabled(self: *SkillManager) []const []const u8 {
        var enabled = std.ArrayList([]const u8).init(self.allocator);
        var iter = self.registry.skills.iterator();
        while (iter.next()) {
            enabled.append(iter.key_ptr.*) catch {};
        }
        return enabled.items;
    }
};
