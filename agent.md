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

#### Tools (Web & Execution) - DONE ✅
#### Tools (Memory & Sessions) - DONE ✅
- [x] `memory` - In-memory store (get, put, index, search)
- [x] `sessions_list` - List active sessions
- [x] `sessions_spawn` - Spawn sub-agent tasks
- [x] `sessions_send` - Send messages to sessions

#### Tools (System) - DONE ✅
- [x] `secrets_list` - List secrets from vault
- [x] `secrets_get` - Retrieve secret by key
- [x] `secrets_store` - Store encrypted secret
- [x] `gateway` - Config get/apply/patch, restart

---

### P1 - High Priority

#### Security Features
- [ ] PromptGuard - Detect prompt injection attacks
- [ ] LeakDetector - Block credential exfiltration
- [ ] SSRF Protection - Block private IP requests

#### Multi-Provider Support - DONE ✅
- [x] Anthropic provider (Claude)
- [x] Google provider (Gemini)
- [x] OpenRouter support
- [x] xAI provider (Grok)

#### Context Management - DONE ✅
- [x] Token usage tracking
- [ ] Context compaction (auto-summarize at 75%)
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

---

### Milestones & Plan

Objective: Align ZiggyClaw with parity goals and establish concrete milestones, ownership, and acceptance criteria before major coding efforts.

- Milestones
  - M0: Documentation alignment completed (this doc updated) — DONE
  - M1: Memory module skeleton added (src/memory/mod.zig) — DONE
  - M2: Memory store API skeleton (put/get) created — PENDING
  - M3: Integrate memory path into tests (test harness adjustments) — PENDING
  - M4: Implement BM25-style search skeleton and indexing — PENDING
  - M5: Achieve parity for all P0 features in Target Parity Matrix — PENDING

- Acceptance Criteria (per milestone)
  - AC1 (M1): Memory module exists and builds; no compile errors; exports a Memory type with init(allocator) signature.
  - AC2 (M2): Memory API skeleton present (put/get) and wired to allocate memory; basic usage in tests compiles.
  - AC3 (M3): Tests compile; Memory path covered in test harness; no leaks introduced.
  - AC4 (M4): BM25 skeleton exists; can index dummy docs; search returns results (not full ranking yet).
  - AC5 (M5): All P0 features demonstrated as working in a proof-of-concept (at least unit/integration tests).

- Ownership & Schedule
  - Owner: (AI-driven guidance)
  - Target dates: Milestones targeted over next 2-3 sprints; review weekly.

## Always move done to /log.md

---

## Testing

```bash
# Run all tests (moved to src/)
zig run src/test_all.zig

# Current: 39 passed, 4 skipped (LLM provider tests)
# Stress Tests: ✅ All 5 categories passing
# Phases 1-7: TESTED ✅
```

---

*Last Updated: 2026-04-04*
*Goals: Match RustyClaw 30+ tools, security features, multi-provider support*
