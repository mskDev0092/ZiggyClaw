# ZiggyClaw

A Zig-native OpenClaw clone - fast, safe, and claws deep into AI tooling.

## Quick Start

```bash
zig build run -- help
zig build run -- gateway
zig build run -- tool list
zig build run -- doctor
zig build run -- onboard
```

## Commands

| Command | Description |
|---------|-------------|
| `zig build run -- help` | Show help and usage information |
| `zig build run -- version` | Show version info |
| `zig build run -- gateway [start]` | Start the gateway server (port 18789) |
| `zig build run -- tool list` | List available tools |
| `zig build run -- doctor` | Run system diagnostics |
| `zig build run -- onboard` | Run onboarding process |
| `zig build run -- agent <message>` | Run agent with a message |

## Gateway

The gateway provides an OpenClaw-compatible HTTP API on port 18789.

```bash
zig build run -- gateway
curl http://127.0.0.1:18789
```

## Building

```bash
zig build
zig build run -- <command>
zig build run    # Runs default command (help)
```

## Architecture

- **core** - Gateway, session, agent, types
- **tools** - Tool registry (shell, file_read)
- **security** - Sandboxed execution
- **config** - Configuration management
- **channels** - IPC channels
- **canvas** - Canvas state management
- **plugins** - Plugin system
- **cli** - Command-line interface
- **utils** - Utilities

## Requirements

- Zig 0.14.0+
