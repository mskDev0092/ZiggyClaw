Phase 1 – Make the current skeleton actually usable

Integrate Agent into CLI
Add a new command ziggyclaw agent "your message here" that uses the Agent + Session + ToolRegistry.
Improve Tool System
Make shell tool actually execute commands safely (using the sandbox you already have) and add 2–3 more built-in tools (file_read, web_get, llm stub).
Connect Gateway to Agent
Make the /v1/chat/completions endpoint call the Agent and return real responses (using sessions).

Phase 2 – Core Agent Loop (OpenClaw parity)

Full Agent Loop with Tool Calling
Replace the simple think() with a proper ReAct-style loop that can call multiple tools in one turn.
Real LLM Integration
Add support for OpenAI / Anthropic / Ollama API calls inside the agent (streaming + tool definitions).
Memory & Context Management
Add message trimming / summarization when context gets too long.

Phase 3 – Channels & Canvas

Basic Channels
Add at least one real channel (e.g. Telegram or simple HTTP webhook) that routes messages to the Agent.
Canvas Server
Add a simple WebSocket canvas endpoint (/canvas) that accepts push/eval/snapshot commands.

Phase 4 – Security & Plugins

Finish Security Layer
Make the capability checker and sandbox actually block unsafe actions (per-session).
Plugin System
Add dynamic plugin loading (.so/.dylib) with a simple manifest.

Phase 5 – Polish & Release

Config + Hot-Reload
Load config from JSON + env, support hot-reload for gateway.
CLI Completion
Add remaining commands: pair, tool install, doctor (full), onboard.
Testing & Parity Check
Run side-by-side with OpenClaw and verify identical behavior on the same model + tools.
Build & Cross-Compile
Add release build scripts and make a single static binary for Linux/macOS/Windows.