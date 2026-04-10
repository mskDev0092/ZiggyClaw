# ZiggyClaw Development Log

A historical record of completed features and milestones.

---

## Completed: Phase 1 – Core Infrastructure ✅

- [x] Agent CLI integration (`ziggyclaw agent`)
- [x] Tool system (shell, file_read, web_get, search)
- [x] Session management
- [x] Gateway HTTP endpoint (/v1/chat/completions)
- [x] Security layer (sandbox, path traversal protection, shell injection protection)
- [x] Memory safety (GPA leak detection)

## Completed: Phase 2 – LLM Integration ✅

- [x] LLM client (OpenAI, Ollama, LM Studio)
- [x] Tool definitions for LLM
- [x] ReAct loop
- [x] HTTP request/response parsing
- [x] Tool call parsing

## Completed: Phase 3 – Advanced Agent Features ✅

- [x] Chain-of-thought reasoning types
- [x] Multi-step tool calling in one turn
- [x] Context management (system prompt, memory)
- [x] Skills system (reusable skill definitions in types.zig)
- [x] Agent context variables

## Completed: Phase 4 – Channels & Integration ✅

- [x] Webhook channel (HTTP POST /webhook)
- [x] WebSocket canvas endpoint (/canvas)

## Completed: Phase 5 – Configuration & Polish ✅

- [x] JSON config file support
- [x] Environment variable overrides
- [x] Hot-reload for gateway config

## Completed: Phase 6 – Plugin System ✅

- [x] Dynamic plugin loading (.so/.dylib)
- [x] Plugin manifest parsing
- [x] Plugin tool registration

## Completed: Phase 7 – CLI Commands ✅

- [x] help
- [x] version
- [x] onboard (interactive)
- [x] doctor (diagnostics)
- [x] tool list
- [x] agent <message>
- [x] gateway start
- [x] pair (interactive mode)

---

## Tools Implemented

| Tool | Description |
|------|-------------|
| shell | Run safe shell commands (ls, echo, pwd, cat, wc, grep) |
| file_read | Read file contents (relative paths, max 64KB) |
| write_file | Create/overwrite files (max 64KB) |
| edit_file | Search and replace in files |
| list_directory | List directory contents |
| search_files | Search files for content (grep) |
| find_files | Find files by pattern (*, ?) |
| web_get | Make HTTP GET requests |
| web_fetch | Fetch URL and extract readable text (strip HTML, title, description) |
| search | Search the web using DuckDuckGo |
| execute_command | Run shell commands with timeout (ls, echo, pwd, cat, wc, grep, find, head, tail, sort, etc.) |
| process | Manage background processes (start, list, stop, status) |

---

## Test Results

- **39 tests passing**
- **4 skipped** (LLM provider-specific tests)
- **Build: stable**
- **CLI: fully functional**
- **Gateway: operational on port 18789**
- **LLM: works with OpenAI/Ollama/LM Studio endpoints**
- **10 tools implemented**

## Completed: Phase 8 – Testing & Stress Tests ✅

- [x] Replaced all stub tests with real assertions (LLM + Architecture)
- [x] Added stress tests (30x rapid commands, 20x file churn, 25x tool rotation)
- [x] Path edge cases (10x)
- [x] Shell edge cases (20x)
- [x] GPA leak detection verified
- [x] Updated README.md with stress test results
- [x] Updated agent.md with test status

---

## Critical Bug Fixes (2026-04-10)

- [x] Fixed `build.zig.zon` name from `.ziggyclaws` to `.ziggyclaw` with proper fingerprint
- [x] Fixed `SkillRegistry.deinit()` signature mismatch (was passing allocator to Skill.deinit which takes 0 args)
- [x] Fixed memory leak in `config/mod.zig` `loadFromEnv()` - wasn't freeing old values before replacing
- [x] Fixed memory leak in `config/mod.zig` `save()` - intermediate allocPrint strings were leaked (now deferred free)
- [x] Fixed memory leak in `memory/mod.zig` `put()` - wasn't freeing old value on key update
- [x] Fixed `max_iterations` hardcoded to 10 in agent.zig - now uses config value `self.config.max_iterations`
- [x] Fixed test step in `build.zig` - added proper test build step with all module dependencies
- [x] Fixed test imports in `test_all.zig` - changed to use module imports instead of file paths to avoid duplicate module errors
- [x] Added SSRF protection to `web_get.zig` - blocks private IP ranges (127.x, 10.x, 192.168.x, 172.16-31.x, 169.254.x, IPv6 loopback/link-local)
- [x] Added SSRF protection to `web_fetch.zig` - added complete SSRF protection matching web_get (includes 0.0.0.0, ::1, fc00:, fe80:, link-local)
- [x] Fixed `file_read.zig` symlink vulnerability - added `resolveAndCheckSymlink()` to resolve symlinks and verify they stay within workspace
- [x] Fixed `search_files.zig` case-sensitivity - added `toLower()` function to perform case-insensitive search
- [x] Fixed agent creating new LLMClient every iteration - now creates once and reuses, reducing allocations

---

*Last Updated: 2026-04-10*