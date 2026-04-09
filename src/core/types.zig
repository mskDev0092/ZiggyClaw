const std = @import("std");

pub const Message = struct {
    role: []const u8,
    content: []const u8,
    name: ?[]const u8 = null,
};

pub const MessageRole = enum {
    system,
    user,
    assistant,
    tool,
};

pub const ToolResult = struct {
    success: bool,
    data: []const u8,
    error_msg: ?[]const u8 = null,
    owned: bool = false,
};

pub const ToolContext = struct {
    allocator: std.mem.Allocator,
    session_id: []const u8,
};

pub const ToolDefinition = struct {
    name: []const u8,
    description: []const u8,
    parameters: ?[]const u8 = null,
};

pub const AgentConfig = struct {
    model: []const u8 = "gpt-4o",
    max_iterations: u8 = 10,
    temperature: f32 = 0.7,
    system_prompt: ?[]const u8 = null,
    max_context_messages: usize = 50,
    max_tokens: ?usize = null,
    track_token_usage: bool = false,
};

pub const ReasoningStep = struct {
    thought: []const u8,
    action: ?[]const u8,
    observation: ?[]const u8,
};

pub const ChainOfThought = struct {
    steps: std.ArrayList(ReasoningStep),

    pub fn init(allocator: std.mem.Allocator) ChainOfThought {
        return .{
            .steps = std.ArrayList(ReasoningStep).init(allocator),
        };
    }

    pub fn addStep(self: *ChainOfThought, thought: []const u8, action: ?[]const u8, observation: ?[]const u8) !void {
        try self.steps.append(.{
            .thought = thought,
            .action = action,
            .observation = observation,
        });
    }

    pub fn deinit(self: *ChainOfThought) void {
        self.steps.deinit();
    }
};

pub const Skill = struct {
    name: []const u8,
    description: []const u8,
    prompt: []const u8,
    tools: std.ArrayList([]const u8),

    pub fn init(allocator: std.mem.Allocator, name: []const u8, description: []const u8, prompt: []const u8) Skill {
        return .{
            .name = name,
            .description = description,
            .prompt = prompt,
            .tools = std.ArrayList([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *Skill) void {
        self.tools.deinit();
    }
};

pub const SkillRegistry = struct {
    allocator: std.mem.Allocator,
    skills: std.StringHashMap(Skill),

    pub fn init(allocator: std.mem.Allocator) SkillRegistry {
        return .{
            .allocator = allocator,
            .skills = std.StringHashMap(Skill).init(allocator),
        };
    }

    pub fn deinit(self: *SkillRegistry) void {
        var iter = self.skills.valueIterator();
        while (iter.next()) |skill| {
            skill.deinit(self.allocator);
        }
        self.skills.deinit();
    }

    pub fn register(self: *SkillRegistry, skill: Skill) !void {
        try self.skills.put(skill.name, skill);
    }

    pub fn get(self: *SkillRegistry, name: []const u8) ?*Skill {
        return self.skills.getPtr(name);
    }

    pub fn list(self: *SkillRegistry) []const []const u8 {
        return self.skills.keys();
    }
};

pub const ContextEntry = struct {
    key: []const u8,
    value: []const u8,
    timestamp: i64,
};

pub const AgentContext = struct {
    allocator: std.mem.Allocator,
    variables: std.StringHashMap([]const u8),
    history: std.ArrayList(ContextEntry),

    pub fn init(allocator: std.mem.Allocator) AgentContext {
        return .{
            .allocator = allocator,
            .variables = std.StringHashMap([]const u8).init(allocator),
            .history = std.ArrayList(ContextEntry).init(allocator),
        };
    }

    pub fn deinit(self: *AgentContext) void {
        var iter = self.variables.valueIterator();
        while (iter.next()) |v| {
            self.allocator.free(v.*);
        }
        self.variables.deinit();
        for (self.history.items) |entry| {
            self.allocator.free(entry.key);
            self.allocator.free(entry.value);
        }
        self.history.deinit();
    }

    pub fn set(self: *AgentContext, key: []const u8, value: []const u8) !void {
        const key_copy = try self.allocator.dupe(u8, key);
        const value_copy = try self.allocator.dupe(u8, value);

        if (self.variables.get(key)) |existing| {
            self.allocator.free(existing.*);
        }

        try self.variables.put(key_copy, value_copy);

        try self.history.append(.{
            .key = key_copy,
            .value = value_copy,
            .timestamp = std.time.timestamp(),
        });
    }

    pub fn get(self: *AgentContext, key: []const u8) ?[]const u8 {
        return self.variables.get(key);
    }
};
