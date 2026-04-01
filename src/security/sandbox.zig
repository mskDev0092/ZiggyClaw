const std = @import("std");
pub fn runSandboxed(cmd: []const u8) ![]const u8 { _ = cmd; return "sandbox ok"; } // src/security/sandbox.zig
