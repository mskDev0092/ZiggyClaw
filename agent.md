# ZiggyClaw Agent Roadmap

## Phase 1 – Core Infrastructure (COMPLETED ✅)
- [x] Agent CLI integration (`ziggyclaw agent`)
- [x] Tool system (shell, file_read, web_get, search)
- [x] Session management
- [x] Gateway HTTP endpoint (/v1/chat/completions)
- [x] Security layer (sandbox, path traversal protection, shell injection protection)
- [x] Memory safety (GPA leak detection)

## Phase 2 – LLM Integration (COMPLETED ✅)
- [x] LLM client (OpenAI, Ollama, LM Studio)
- [x] Tool definitions for LLM
- [x] ReAct loop
- [x] HTTP request/response parsing
- [x] Tool call parsing

## Phase 3 – Advanced Agent Features (COMPLETED ✅)
- [x] Chain-of-thought reasoning types
- [x] Multi-step tool calling in one turn
- [x] Context management (system prompt, memory)
- [x] Skills system (reusable skill definitions in types.zig)
- [x] Agent context variables

## Phase 4 – Channels & Integration (COMPLETED ✅)
- [x] Webhook channel (HTTP POST /webhook)
- [x] WebSocket canvas endpoint (/canvas)
- [ ] Telegram channel integration
- [ ] Discord channel integration

## Phase 5 – Configuration & Polish (COMPLETED ✅)
- [x] JSON config file support
- [x] Environment variable overrides
- [x] Hot-reload for gateway config
- [ ] Release build scripts
- [ ] Cross-compilation (Linux/macOS/Windows)

## Phase 6 – Plugin System (COMPLETED ✅)
- [x] Dynamic plugin loading (.so/.dylib)
- [x] Plugin manifest parsing
- [x] Plugin tool registration

## Phase 7 – CLI Commands (COMPLETED ✅)
- [x] help
- [x] version
- [x] onboard (interactive)
- [x] doctor (diagnostics)
- [x] tool list
- [x] agent <message>
- [x] gateway start
- [x] pair (interactive mode)

---

## Current Status
- **All 38 tests passing**
- **Build: stable**
- **CLI: fully functional**
- **Gateway: operational on port 18789**
- **LLM: works with OpenAI/Ollama/LM Studio endpoints**
- **4 tools: shell, file_read, web_get, search**

## Tools Available
| Tool | Description |
|------|-------------|
| shell | Run safe shell commands (ls, echo, pwd, cat, wc, grep) |
| file_read | Read file contents (relative paths, max 64KB) |
| web_get | Make HTTP GET requests |
| search | Search the web (stub - use web_get) |

## Getting Started
```bash
# Onboarding
ziggyclaw onboard

# Interactive mode
ziggyclaw pair

# Run agent
ziggyclaw agent "shell: echo hello"

# Start gateway
ziggyclaw gateway start

# Check system
ziggyclaw doctor
```

## Environment Variables
| Variable | Description | Default |
|----------|-------------|---------|
| OPENAI_API_KEY | OpenAI API key | - |
| OPENAI_API_BASE | LLM endpoint URL | https://api.openai.com/v1 |
| GATEWAY_PORT | Server port | 18789 |
| AGENT_MODEL | Model name | gpt-4o |
| LOG_LEVEL | Logging level | info |