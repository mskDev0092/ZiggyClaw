const std = @import("std");

pub const SecurityResult = struct {
    blocked: bool,
    reason: ?[]const u8 = null,
    sanitized: ?[]const u8 = null,
};

fn toLower(input: []const u8) []const u8 {
    var result = std.ArrayList(u8).init(std.heap.page_allocator);
    for (input) |c| {
        if (c >= 'A' and c <= 'Z') {
            result.append(c + 32) catch return input;
        } else {
            result.append(c) catch return input;
        }
    }
    return result.items;
}

pub const PromptGuard = struct {
    const injection_patterns = [_][]const u8{
        "ignore previous instructions",
        "ignore all previous instructions",
        "disregard previous instructions",
        "system prompt",
        "you are now",
        "you are a",
        "act as",
        "act like",
        "pretend to be",
        "roleplay as",
        "new instructions:",
        "override instructions",
        "bypass restrictions",
        "override system",
        "replace instructions",
        "forget everything",
        "new system prompt",
        "instructions instead",
    };

    const dangerous_commands = [_][]const u8{
        "sudo",
        "rm -rf",
        "rm -r",
        "mkfs",
        "dd if=",
        ":(){ :|:& };:",
        "chmod 777",
        "chown -r",
        "wget",
        "curl",
        "nc -e",
        "bash -i",
        "/dev/tcp",
    };

    pub fn check(input: []const u8) SecurityResult {
        const lower = toLower(input);

        for (injection_patterns) |pattern| {
            if (std.mem.indexOf(u8, lower, pattern)) |_| {
                return .{
                    .blocked = true,
                    .reason = "Potential prompt injection detected",
                };
            }
        }

        for (dangerous_commands) |cmd| {
            if (std.mem.indexOf(u8, lower, cmd)) |_| {
                return .{
                    .blocked = true,
                    .reason = "Potentially dangerous command pattern",
                };
            }
        }

        return .{ .blocked = false };
    }

    pub fn sanitize(input: []const u8) []const u8 {
        const lower = toLower(input);
        for (injection_patterns) |pattern| {
            if (std.mem.indexOf(u8, lower, pattern)) |_| {
                return "[FILTERED]";
            }
        }
        return input;
    }

    pub fn deinit() void {}
};

pub const LeakDetector = struct {
    const credential_patterns = [_][]const u8{
        "api_key",
        "apikey",
        "api-key",
        "secret_key",
        "secretkey",
        "password",
        "passwd",
        "bearer ",
        "token=",
        "auth_token",
        "access_token",
        "private_key",
        "ssh-rsa",
        "-----begin rsa",
        "-----begin private",
    };

    const sensitive_domains = [_][]const u8{
        "amazonaws.com",
        "heroku.com",
        "digitalocean.com",
        "github.com",
        "gitlab.com",
        "bitbucket.org",
        "azure.com",
        "cloudflare.com",
    };

    pub fn check(input: []const u8) SecurityResult {
        const lower = toLower(input);

        for (credential_patterns) |pattern| {
            if (std.mem.indexOf(u8, lower, pattern)) |_| {
                if (std.mem.indexOf(u8, input, "=")) |suspicious| {
                    if (suspicious < input.len - 5) {
                        return .{
                            .blocked = true,
                            .reason = "Potential credential exfiltration detected",
                        };
                    }
                }
            }
        }

        for (sensitive_domains) |domain| {
            if (std.mem.indexOf(u8, lower, domain)) |_| {
                if (std.mem.indexOf(u8, lower, "key") != null or
                    std.mem.indexOf(u8, lower, "secret") != null or
                    std.mem.indexOf(u8, lower, "token") != null)
                {
                    return .{
                        .blocked = true,
                        .reason = "Potential sensitive domain with credentials",
                    };
                }
            }
        }

        return .{ .blocked = false };
    }

    pub fn redact(input: []const u8) []const u8 {
        const lower = toLower(input);
        for (credential_patterns) |pattern| {
            if (std.mem.indexOf(u8, lower, pattern)) |_| {
                if (std.mem.indexOf(u8, input, "=")) |eq_pos| {
                    return std.fmt.allocPrint(std.heap.page_allocator, "{s}=[REDACTED]", .{input[0..eq_pos]}) catch input;
                }
            }
        }
        return input;
    }

    pub fn deinit() void {}
};
