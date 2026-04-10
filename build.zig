const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ziggyclaw",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Modules (this is what prevents import hallucinations)
    const core = b.addModule("core", .{ .root_source_file = b.path("src/core/mod.zig") });
    const tools = b.addModule("tools", .{ .root_source_file = b.path("src/tools/mod.zig") });
    tools.addImport("core", core);
    const security = b.addModule("security", .{ .root_source_file = b.path("src/security/mod.zig") });
    const memory = b.addModule("memory", .{ .root_source_file = b.path("src/memory/mod.zig") });
    core.addImport("tools", tools);
    core.addImport("security", security);
    const config = b.addModule("config", .{ .root_source_file = b.path("src/config/mod.zig") });
    tools.addImport("security", security);
    tools.addImport("memory", memory);
    const channels = b.addModule("channels", .{ .root_source_file = b.path("src/channels/mod.zig") });
    const canvas = b.addModule("canvas", .{ .root_source_file = b.path("src/canvas/mod.zig") });
    const plugins = b.addModule("plugins", .{ .root_source_file = b.path("src/plugins/mod.zig") });
    const cli = b.addModule("cli", .{ .root_source_file = b.path("src/cli/mod.zig") });
    cli.addImport("core", core);
    cli.addImport("config", config);
    cli.addImport("tools", tools);
    cli.addImport("memory", memory);
    const utils = b.addModule("utils", .{ .root_source_file = b.path("src/utils/mod.zig") });

    exe.root_module.addImport("core", core);
    exe.root_module.addImport("tools", tools);
    exe.root_module.addImport("security", security);
    exe.root_module.addImport("config", config);
    exe.root_module.addImport("channels", channels);
    exe.root_module.addImport("canvas", canvas);
    exe.root_module.addImport("plugins", plugins);
    exe.root_module.addImport("cli", cli);
    exe.root_module.addImport("utils", utils);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const run_step = b.step("run", "Run ZiggyClaw");
    run_step.dependOn(&run_cmd.step);

    // Add test step
    const test_step = b.step("test", "Run all tests");
    const test_all = b.addTest(.{
        .name = "test_all",
        .root_source_file = b.path("src/test_all.zig"),
        .target = target,
        .optimize = optimize,
    });
    test_all.root_module.addImport("core", core);
    test_all.root_module.addImport("tools", tools);
    test_all.root_module.addImport("security", security);
    test_all.root_module.addImport("config", config);
    test_all.root_module.addImport("memory", memory);
    test_all.root_module.addImport("channels", channels);
    test_all.root_module.addImport("canvas", canvas);
    test_all.root_module.addImport("plugins", plugins);
    test_all.root_module.addImport("cli", cli);
    test_all.root_module.addImport("utils", utils);

    const test_run = b.addRunArtifact(test_all);
    test_step.dependOn(&test_run.step);
}
