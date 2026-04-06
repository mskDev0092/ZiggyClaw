# ZiggyClaw 🦞⚡

A Zig-native AI agent framework - fast, safe, and claws deep into AI tooling.

![ZiggyClaw](https://github.com/mskDev0092/ZiggyClaw/blob/main/assets/2vQny.jpg)

## Features

- **Agent System** - ReAct-style agent with tool calling and reasoning
- **LLM Integration** - OpenAI, Ollama, LM Studio support
- **Tool System** - 12 tools fully integrated + 2 manual tools (sessions, secrets)
- **Gateway API** - OpenAI-compatible REST endpoint (port 18789)
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
| `gateway start` | Start HTTP server |

## Tools (14 available)

| Tool | Description | Status |
|------|-------------|--------|
| `shell` | Run safe shell commands (ls, echo, pwd, cat, wc, grep) | ✅ Works |
| `file_read` | Read file contents (relative paths, max 64KB) | ✅ Works |
| `write_file` | Create or overwrite files (max 64KB) | ✅ Works |
| `edit_file` | Search and replace in files | ✅ Works |
| `list_directory` | List directory contents | ✅ Works |
| `search_files` | Search files for content (grep-like) | ✅ Works |
| `find_files` | Find files by pattern (*, ? wildcards) | ✅ Works |
| `web_get` | Make HTTP GET requests | ✅ Works |
| `web_fetch` | Fetch URL and extract readable text | ✅ Works |
| `search` | Search the web using DuckDuckGo | ✅ Works |
| `execute_command` | Run shell commands with timeout | ✅ Works |
| `process` | Manage background processes | ✅ Works |
| `sessions` | Manage agent sessions (list, send, spawn) | ⚠️ Manual only |
| `secrets` | Manage secrets vault (list, get, store) | ⚠️ Manual only |

## Stress Test Results

| Test | Iterations | Status |
|------|------------|--------|
| Rapid Agent Commands | 30x | ✅ PASS |
| File Churn (write/read) | 20x | ✅ PASS |
| Tool Rotation | 25x | ✅ PASS |
| Path Edge Cases | 10x | ✅ PASS |
| Shell Edge Cases | 20x | ✅ PASS |

**Total**: 40 passed, 0 failed, 5 skipped

## LLM Configuration

### Environment Variables

```bash
# LLM endpoint
export OPENAI_API_BASE="http://localhost:1234"  # LM Studio
export OPENAI_API_BASE="http://localhost:11434"  # Ollama

# API key (optional for local models)
export OPENAI_API_KEY="sk-..."

# Server port (for gateway)
export GATEWAY_PORT=18789
```

### Supported Providers

- **LM Studio** - `http://localhost:1234/v1/chat/completions`
- **Ollama** - `http://localhost:11434/api/chat`
- **OpenAI** - `https://api.openai.com/v1` (default)

## Usage Examples

### Agent Mode

```bash
# Ask agent to do something
zig build run -- agent "List files in current directory"
zig build run -- agent "Read the README.md file"
zig build run -- agent "Search for today's news"
zig build run -- agent "Fetch https://example.com"

# Direct tool usage (bypasses LLM)
zig build run -- agent "shell: ls -la"
zig build run -- agent "file_read: README.md"
zig build run -- agent "search: zig programming language"
```

### Interactive Pair Mode

```bash
zig build run -- pair

# Then type your messages:
# You> search latest AI news
# Agent> Search results for "latest AI news"...
# You> file_read: build.zig
# Agent> [file contents]
# You> exit
```

### Gateway API

```bash
# Start the server
zig build run -- gateway start

# Or run in background
nohup zig build run -- gateway start &

# Test with curl
curl -X POST http://127.0.0.1:18789/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "hello"}],
    "model": "assistant"
  }'

# Webhook endpoint
curl -X POST http://127.0.0.1:18789/webhook \
  -H "Content-Type: application/json" \
  -d '{"message": "your message here"}'

# WebSocket canvas
wscat -c ws://127.0.0.1:18789/canvas
```

## Configuration File

Create `ziggyclaw.json` in project root:

```json
{
  "model": "claude-3-sonnet",
  "max_iterations": 10,
  "timeout": 30000,
  "tools": {
    "shell": { "enabled": true },
    "file_read": { "enabled": true, "max_size": 65536 },
    "web_fetch": { "enabled": true, "max_length": 8000 }
  }
}
```

## Architecture

```
src/
├── cli/          # Commands: help, version, onboard, doctor, agent, pair, tool
├── core/         # Agent, Session, Gateway, LLM, Types
├── tools/        # 10 tools (file, shell, web, search)
├── security/     # Sandbox, path traversal protection
├── config/       # Config loading, JSON support
├── channels/     # Webhook, stdio IPC
├── canvas/       # WebSocket canvas state
├── plugins/      # Dynamic .so loading
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
- ✅ 10 tools implemented

## Contributing

Contributions welcome - pure Zig only.
