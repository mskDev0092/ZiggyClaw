# ZiggyClaw Agent Roadmap

## Priority Tasks (Based on RustyClaw/OpenClaw Parity)

### P0 - Must Have (Core Parity)

#### Tools (File Operations) - DONE ✅
- [x] `file_read` - Read file contents
- [x] `write_file` - Create/overwrite files
- [x] `edit_file` - Search-and-replace edits
- [x] `list_directory` - List directory contents
- [x] `search_files` - Grep-like content search
- [x] `find_files` - Find files by name/glob

#### Tools (Web & Execution)
- [x] `web_fetch` - Fetch URL and extract readable text
- [x] `web_search` - Search the web
- [x] `execute_command` - Run shell commands with timeout
- [x] `process` - Background process management

#### Tools (Memory & Sessions)
- [ ] `memory_search` - Search over memory files
- [ ] `memory_get` - Retrieve memory snippets
- [ ] `sessions_list` - List active sessions
- [ ] `sessions_spawn` - Spawn sub-agent tasks
- [ ] `sessions_send` - Send messages to sessions

#### Tools (System)
- [ ] `secrets_list` - List secrets from vault
- [ ] `secrets_get` - Retrieve secret by key
- [ ] `secrets_store` - Store encrypted secret
- [ ] `gateway` - Config get/apply/patch, restart

---

### P1 - High Priority

#### Security Features
- [ ] PromptGuard - Detect prompt injection attacks
- [ ] LeakDetector - Block credential exfiltration
- [ ] SSRF Protection - Block private IP requests

#### Multi-Provider Support
- [ ] Anthropic provider (Claude)
- [ ] Google provider (Gemini)
- [ ] OpenRouter support
- [ ] xAI provider (Grok)

#### Context Management
- [ ] Context compaction (auto-summarize at 75%)
- [ ] Token usage tracking
- [ ] Model context window limits

---

### P2 - Medium Priority

#### TUI (Terminal UI)
- [ ] Interactive terminal UI with slash commands
- [ ] Tab completion
- [ ] Session pane navigation

#### Skills System
- [ ] YAML/TOML skill format support
- [ ] Skill dependency gating
- [ ] Skill enable/disable

#### Messenger Backends
- [ ] Discord integration
- [ ] Telegram integration
- [ ] Signal integration

---

### P3 - Nice to Have

#### Advanced Features
- [ ] Cron/scheduling system
- [ ] Heartbeat system for monitoring
- [ ] Canvas node visualization
- [ ] Browser automation (CDP)
- [ ] TTS (text-to-speech)
- [ ] Image analysis (vision models)

#### Multi-Agent
- [ ] Agent steering mid-execution
- [ ] Session history persistence

---

## Architecture Goals

```
ZiggyClaw/
├── src/
│   ├── cli/          # Commands: help, version, onboard, doctor, agent, pair, tool
│   ├── core/         # Agent, Session, Gateway, LLM, Types
│   ├── tools/        # 30+ tools (file, web, execution, memory, secrets, system)
│   ├── security/     # PromptGuard, LeakDetector, SSRF, Sandbox
│   ├── config/       # Config loading, migration
│   ├── channels/     # Webhook, Discord, Telegram, Signal
│   ├── memory/       # BM25 search, memory consolidation
│   ├── skills/       # Skill loading and execution
│   ├── canvas/       # Node canvas UI
│   └── plugins/      # Dynamic .so loading
```

---

## Target Parity Matrix

| Feature | RustyClaw | ZiggyClaw | Status |
|---------|-----------|-----------|--------|
| File tools (6) | ✅ | ✅ | 6/6 done |
| Web tools | ✅ | ⚠️ partial | web_get exists |
| Shell execution | ✅ | ✅ | done |
| Process management | ✅ | 🔲 | missing |
| Memory system | ✅ | 🔲 | missing |
| Multi-session/agent | ✅ | 🔲 | basic only |
| Secrets vault | ✅ | 🔲 | stub only |
| Gateway control | ✅ | ⚠️ basic | HTTP endpoint exists |
| TTS | ✅ | 🔲 | missing |
| Image analysis | ✅ | 🔲 | missing |
| Browser automation | ✅ | 🔲 | missing |
| Context compaction | ✅ | 🔲 | missing |
| Skills system | ✅ | 🔲 | types defined |
| Messengers | ✅ | ⚠️ partial | webhook only |

---

## Next Actions

1. **Add web_fetch tool** - Enhanced web content extraction
2. **Add process tool** - Background process management
3. **Add memory system** - BM25 search over memory files
4. **Add secrets vault** - Encrypted credential storage

## Alaways move done to /log.md

---

## Testing

```bash
# Run all tests
zig run scripts/test_all.zig

# Current: 38 passing
```

---

*Last Updated: 2026-04-03*
*Goals: Match RustyClaw 30+ tools, security features, multi-provider support*
