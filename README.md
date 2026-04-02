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
# Start the gateway server (runs in foreground)
zig build run -- gateway

# In another terminal, test it
curl http://127.0.0.1:18789/v1/chat/completions

# Stop the gateway server
# Press Ctrl+C in the terminal where the gateway is running
# OR kill the process:
pkill -f ziggyclaw
```

## Using with LM Studio

ZiggyClaw can connect to a local LM Studio server for LLM inference.

### Prerequisites

1. **Install LM Studio** from https://lmstudio.ai/
2. **Download and load a model** in LM Studio
3. **Start the LM Studio server** on port 1234 (default)
   - In LM Studio, go to the "Local Server" tab and click "Start Server"
   - The server will listen on `http://localhost:1234`

### Configuration

Set the `OPENAI_API_BASE` environment variable to point to your LM Studio server:

```bash
# Linux/macOS
export OPENAI_API_BASE="http://localhost:1234"

# Windows (cmd)
set OPENAI_API_BASE=http://localhost:1234

# Windows (PowerShell)
$env:OPENAI_API_BASE="http://localhost:1234"
```

### Running with LM Studio

```bash
# Start LM Studio server first (via LM Studio UI)

# Then run ZiggyClaw agent
OPENAI_API_BASE="http://localhost:1234" zig build run -- agent "What is Zig?"

# Or set the variable once and run multiple times
export OPENAI_API_BASE="http://localhost:1234"
zig build run -- agent "Hello from ZiggyClaw!"
```

### Stopping the Server

The gateway runs in the foreground. To stop it:

1. **Press `Ctrl+C`** in the terminal where the gateway is running
2. **Or kill the process:**
   ```bash
   pkill -f ziggyclaw
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
