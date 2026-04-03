# ZiggyClaw 🦞⚡

A Zig-native AI agent framework - fast, safe, and claws deep into AI tooling.

![ZiggyClaw](https://github.com/mskDev0092/ZiggyClaw/blob/main/assets/2vQny.jpg)

## Features

- **Agent System** - ReAct-style agent with tool calling
- **LLM Integration** - OpenAI, Ollama, LM Studio support
- **Tool System** - Shell, file_read, web_get, search
- **Gateway API** - OpenAI-compatible REST endpoint
- **Security** - Sandboxed execution, path traversal protection
- **Plugin System** - Dynamic .so/.dylib loading
- **Interactive Mode** - Pair programming with agent
- **Channels** - HTTP webhooks, WebSocket canvas

## Quick Start

```bash
# Build
zig build

# Run commands
zig build run -- help
zig build run -- version
zig build run -- onboard
zig build run -- doctor
zig build run -- tool list
zig build run -- agent "shell: echo hello"
zig build run -- pair
zig build run -- gateway start
```

## Commands

| Command | Description |
|---------|-------------|
| `help` | Show help and usage |
| `version` | Show version info |
| `onboard` | Interactive onboarding |
| `doctor` | System diagnostics |
| `tool list` | List available tools |
| `agent <msg>` | Run agent with message |
| `pair` | Interactive chat mode |
| `gateway start` | Start HTTP server (port 18789) |

## Tools

| Tool | Description |
|------|-------------|
| `shell` | Run safe shell commands (ls, echo, pwd, cat, wc, grep) |
| `file_read` | Read file contents (relative paths, max 64KB) |
| `web_get` | Make HTTP GET requests to fetch web content |
| `search` | Search the web (use web_get with search URL) |

## LLM Configuration

### Environment Variables

```bash
# LLM endpoint (required for real LLM calls)
export OPENAI_API_BASE="http://localhost:1234"  # LM Studio
export OPENAI_API_BASE="http://localhost:11434"  # Ollama

# API key (optional for local models)
export OPENAI_API_KEY="your-key-here"

# Server port
export GATEWAY_PORT=18789
```

### Supported Providers

- **LM Studio** - `http://localhost:1234/v1/chat/completions`
- **Ollama** - `http://localhost:11434/api/chat`
- **OpenAI** - `https://api.openai.com/v1` (default)

### Example Usage

```bash
# With LM Studio
export OPENAI_API_BASE="http://localhost:1234"
zig build run -- agent "What is Zig programming?"

# With Ollama
export OPENAI_API_BASE="http://localhost:11434"
zig build run -- agent "List files in current directory"

# Without LLM (pattern matching fallback)
zig build run -- agent "shell: ls -la"
zig build run -- agent "web_get https://example.com"
```

## Gateway API

Start the gateway server:

```bash
zig build run -- gateway start
```

Test the endpoint:

```bash
curl -X POST http://127.0.0.1:18789/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"messages": [{"role": "user", "content": "hello"}]}'
```

## Interactive Pair Mode

```bash
# Start interactive chat
zig build run -- pair

# Then type messages:
# You> shell: echo hello
# Agent> hello
# You> exit
```

## Architecture

```
src/
├── cli/          # Command-line interface
├── core/         # Agent, session, gateway, LLM, types
├── tools/        # Tool registry (shell, file_read, web_get, search)
├── security/     # Sandbox, capability checking
├── config/       # Configuration management
├── channels/     # IPC channels (webhook, stdio)
├── canvas/       # WebSocket canvas state
├── plugins/      # Dynamic plugin loading
└── utils/        # Utilities
```

## Testing

```bash
# Run all tests
zig run scripts/test_all.zig

# Run specific test
zig build test
```

## Requirements

- Zig 0.14.0+

## Status

- ✅ 38 tests passing
- ✅ Build stable
- ✅ CLI functional
- ✅ Gateway operational (port 18789)
- ✅ LLM integration works

## Contributing

Contributions welcome - pure Zig only.