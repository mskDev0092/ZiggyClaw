# ZiggyClaw Agent Guide

**Primary reference:** `ZiggyClaw_Complete_Instructions.md` (comprehensive docs)

## Quick Status

| Category | Status |
|----------|--------|
| Core Tools (file, web, shell, process) | ✅ Done |
| Memory/Sessions | ✅ Done |
| Secrets Vault | ✅ Done |
| Gateway | ✅ Done |
| Multi-Provider (Anthropic, Google, xAI, OpenRouter) | ✅ Done |
| Security (Sandbox, PromptGuard, LeakDetector) | ⚠️ Partial |
| Skills System | ⚠️ Types defined |
| Context Compaction | 🔲 Pending |
| TUI/Skills/Messengers | 🔲 Pending |

## Current Priorities

1. **Security** - PromptGuard, LeakDetector, SSRF protection
2. **Context** - Compaction at 75%, model window limits
3. **TUI** - Interactive terminal with slash commands
4. **Skills** - YAML/TOML format, dependency gating

## Build & Test

```bash
zig build run -c "agent <message>"   # CLI mode
zig build run -c "gateway start"      # Gateway mode
zig test                              # Run tests
```

## Workflow Rules

1. **After completing work**: Move completed items to `log.md`
2. **Track pending tasks**: Use `todo.md` (create if missing)
3. **Reference**: Comprehensive docs in `ZiggyClaw_Complete_Instructions.md`
4. **Keep log.md updated** - Always append completed features/fixes

## Architecture

```
src/
├── cli/          # Commands: help, version, onboard, doctor, agent, pair
├── core/         # Agent, Session, Gateway, LLM, Types
├── tools/        # File, Web, Execution, Memory, Secrets, System
├── security/     # PromptGuard, LeakDetector, SSRF, Sandbox
├── config/       # Config loading, migration
├── channels/     # Webhook, Discord, Telegram
├── memory/       # BM25 search, consolidation
└── skills/       # Skill loading/execution
```

## Next Actions (from todo.md)

- Add context compaction (auto-summarize at 75%)
- Add model context window limits
- Implement TUI with tab completion
- Add Discord/Telegram messenger backends
- Add cron/scheduling system

---

*Last Updated: 2026-04-10*