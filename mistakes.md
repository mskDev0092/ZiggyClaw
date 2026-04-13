# ZiggyClaw Mistakes Log

> A living document cataloging mistakes in architecture, code, implementation, product decisions, and engineering practices. Learn from the past to avoid repeating it.

---

## Table of Contents

1. [Architecture Mistakes](#architecture-mistakes)
2. [Code Implementation Mistakes](#code-implementation-mistakes)
3. [Security Mistakes](#security-mistakes)
4. [Performance Mistakes](#performance-mistakes)
5. [API/Interface Design Mistakes](#apiinterface-design-mistakes)
6. [Testing Mistakes](#testing-mistakes)
7. [Product/Feature Mistakes](#productfeature-mistakes)
8. [Process Mistakes](#process-mistakes)
9. [Communication Mistakes](#communication-mistakes)

---

## Architecture Mistakes

### ❌ Premature Abstraction
**Problem:** Creating generic frameworks before understanding actual requirements.
**Example:** Building a plugin system for "any future tool" when only shell and file ops are needed.
**Fix:** Wait for the third use case before abstracting.

### ❌ Monolithic Core
**Problem:** Putting everything in one module until it becomes unmaintainable.
**Example:** `agent.zig` handling LLM calls, tool execution, state management, and output parsing.
**Fix:** Separate concerns early. Core should be thin, delegating to specialized modules.

### ❌ Magic by Default
**Problem:** Implicit behavior that makes debugging impossible.
**Example:** Auto-loading config from multiple locations with priority rules no one remembers.
**Fix:** Explicit is better. Make magic opt-in, documented, and traceable.

### ❌ Ignoring Failures
**Problem:** Designing APIs that return errors as optionals instead of proper error types.
**Example:** `fn doThing() ?Result` instead of `fn doThing() !Result`.
**Fix:** Make failure the default case. `!` unions force handling.

### ❌ Hardcoded Values Everywhere
**Problem:** Magic numbers, paths, ports scattered through code.
**Example:** `PORT = 18789` inline vs. centralized config.
**Fix:** Centralize constants. Environment variables for deployment-specific values.

### ❌ Circular Dependencies
**Problem:** Module A imports B, B imports C, C imports A.
**Fix:** Dependency injection. Keep core types in a shared `types.zig`.

### ❌ Over-Engineering for Scale
**Problem:** Designing for 10x load before validating the product has any users.
**Example:** Distributed actor system for a single-user CLI tool.
**Fix:** Build simple first. Add complexity when you have data showing it's needed.

### ❌ Microservices Envy
**Problem:** Splitting a simple tool into multiple processes/services unnecessarily.
**Fix:** Monolith first. Extract when there are clear boundaries and independent deploy needs.

### ❌ Not Planning for Rollback
**Problem:** No strategy for reverting bad deployments.
**Fix:** Design for atomic deployments. State migrations should be reversible.

### ❌ Ignoring Observability
**Problem:** No logging, tracing, or metrics until things break in production.
**Fix:** Add structured logging from day one. Know what's happening before debugging.

---

## Code Implementation Mistakes

### ❌ Ignoring Compiler Warnings
**Problem:** Ship code with warnings because "it compiles."
**Example:** Unused variables, implicit casts, deprecated function usage.
**Fix:** Treat warnings as errors. `zig build -f-error` or equivalent.

### ❌ Not Using const Where Possible
**Problem:** Mutable state proliferating when immutable would be safer.
**Fix:** Default to `const`. Only use `var` when mutation is required.

### ❌ Memory Leaks by Forgetting to Defer
**Problem:** Allocating resources without cleanup on early returns.
**Example:** Opening a file but returning before closing on error paths.
**Fix:** Use `defer` immediately after allocation. Never alloc without a plan.

### ❌ Silent Error Swallowing
**Problem:** Catching errors and continuing as if nothing happened.
```zig
_ = doSomething() catch {};
```
**Fix:** Propagate or handle meaningfully. At minimum, log.

### ❌ Copy-Paste Code
**Problem:** Duplicating logic with slight variations.
**Example:** Three similar file parsers that diverge over time.
**Fix:** Extract to functions. Use generics/comptime where appropriate in Zig.

### ❌ Not Handling Edge Cases
**Problem:** Code works for happy path, breaks on boundary conditions.
**Example:** Off-by-one errors, empty arrays, nil/null checks.
**Fix:** Define edge cases upfront. Test them explicitly.

### ❌ Using Strings Where Enums Make Sense
**Problem:** `"error"`, `"warning"`, `"info"` as string literals instead of typed enums.
**Fix:** Enums provide exhaustiveness checking. Use them.

### ❌ No Input Validation
**Problem:** Trusting external input without checking bounds, types, or format.
**Fix:** Validate early. Fail fast with clear errors.

### ❌ Global Mutable State
**Problem:** Shared global variables that make concurrency impossible.
**Fix:** Pass state explicitly. Use thread-local if truly needed.

### ❌ Premature Optimization
**Problem:** Micro-optimizing code before profiling, making it unreadable.
**Fix:** Write clear code first. Optimize based on real bottlenecks.

### ❌ Not Freeing Resources
**Problem:** Leaking file handles, memory, network connections.
**Fix:** Zig's defer helps. Use arena allocators for grouped deallocation.

### ❌ Inconsistent Naming
**Problem:** `getUser`, `fetch_user`, `retrieveUser` all in the same codebase.
**Fix:** Pick a convention (Zig uses `camelCase`). Enforce with linter.

### ❌ Magic Numbers Without Names
**Problem:** `buffer[4096]` with no explanation of why 4096.
**Fix:** Named constants. `const PAGE_SIZE = 4096;`

### ❌ Commented-Out Code
**Problem:** Old code commented "just in case" pollutes the codebase.
**Fix:** Use version control. Delete old code. History is preserved.

### ❌ Deep Nesting
**Problem:** 6+ levels of indentation making code unreadable.
**Fix:** Early returns. Extract to functions. Reduce nesting.

---

## Security Mistakes

### ❌ Trusting User Input
**Problem:** Using user data directly in shell commands, file paths, SQL.
**Example:** `shell: cat /logs/{user_input}` — path traversal vulnerability.
**Fix:** Validate, sanitize, and use parameterized operations.

### ❌ Storing Secrets in Code
**Problem:** API keys, passwords, tokens in source code.
**Fix:** Environment variables. Secrets manager. Never commit secrets.

### ❌ No Rate Limiting
**Problem:** APIs that can be hammered without limits.
**Fix:** Implement rate limiting. Use token buckets or leaky buckets.

### ❌ Insecure Defaults
**Problem:** Default passwords, open permissions, disabled auth.
**Fix:** Secure by default. Require explicit opt-out for security features.

### ❌ Not Validating SSL/TLS
**Problem:** Disabling certificate verification for "simplicity."
**Fix:** Always validate certificates. Use pinned certs for internal services.

### ❌ Log Leaking Sensitive Data
**Problem:** Printing passwords, tokens, PII to logs.
**Fix:** Scrub sensitive data. Use structured logging with field redaction.

### ❌ No Input Length Limits
**Problem:** Buffer overflow vulnerabilities from unbounded input.
**Fix:** Set reasonable limits. Reject oversized input early.

### ❌ SSRF (Server-Side Request Forgery)
**Problem:** Fetching URLs from user input without validation.
**Fix:** Allowlist permitted domains/IPs. Block private IP ranges.

### ❌ Race Conditions
**Problem:** TOCTOU (time-of-check-time-of-use) vulnerabilities.
**Fix:** Atomic operations. Proper locking. Avoid check-then-act patterns.

### ❌ Not Sandboxing Execution
**Problem:** Agent can read/write anywhere on the filesystem.
**Fix:** Isolate execution. Use containers, seccomp, or language-level sandboxes.

### ❌ Insufficient Authorization
**Problem:** Checking auth but not per-resource permissions.
**Fix:** Principle of least privilege. Verify permissions per operation.

### ❌ Not Planning for Key Rotation
**Problem:** No way to rotate API keys without downtime.
**Fix:** Support key aliases. Multiple keys active during rotation window.

---

## Performance Mistakes

### ❌ N+1 Queries/Operations
**Problem:** One operation per item instead of batch operations.
**Fix:** Batch where possible. Cache repeated lookups.

### ❌ Not Using Streaming
**Problem:** Buffering entire responses in memory before processing.
**Fix:** Stream for large data. Process incrementally.

### ❌ Inefficient Data Structures
**Problem:** ArrayList for frequent lookups. HashMap for ordered iteration.
**Fix:** Choose based on access patterns. Profile before changing.

### ❌ Not Releasing Resources Promptly
**Problem:** Holding file handles, connections longer than needed.
**Fix:** Close/release in defer. Use scoped lifetimes.

### ❌ Blocking the Event Loop
**Problem:** Long synchronous operations blocking all other work.
**Fix:** Async/await. Thread pools for CPU-bound work.

### ❌ Not Caching Expensive Operations
**Problem:** Repeating the same expensive computation.
**Fix:** Cache with TTL. Invalidate properly. Watch memory usage.

### ❌ Memory Bloat
**Problem:** Loading entire files into memory when streaming would work.
**Fix:** Stream processing. Use buffered readers. Set memory limits.

### ❌ Not Profiling Before Optimizing
**Problem:** Guessing where time is spent based on intuition.
**Fix:** Use profilers. Measure before and after changes.

### ❌ Sync I/O Everywhere
**Problem:** Blocking I/O in a single-threaded or synchronous design.
**Fix:** Async I/O. Zig's comptime and async features can help here.

---

## API/Interface Design Mistakes

### ❌ Breaking Backward Compatibility
**Problem:** Changing response format, removing fields, altering behavior without versioning.
**Fix:** Semantic versioning. Additive changes only. Deprecate gracefully.

### ❌ Inconsistent Response Formats
**Problem:** Sometimes `{"data": ...}`, sometimes `{"result": ...}`, sometimes raw.
**Fix:** One consistent envelope. Document it. Validate it.

### ❌ Not Providing Examples
**Problem:** API docs without curl examples, SDK snippets.
**Fix:** Every endpoint needs working examples. Test them in CI.

### ❌ Too Many Options
**Problem:** Endpoints with 20 optional parameters.
**Fix:** Few, orthogonal options. Composable primitives over swiss army knives.

### ❌ Not Designing for Errors First
**Problem:** Only considering happy path.
**Fix:** Document error codes. Provide error context. Consistent error shapes.

### ❌ Stateless API with Stateful Expectations
**Problem:** Client expects session state the server doesn't maintain.
**Fix:** Make state explicit. Stateless = stateless. Or acknowledge sessions.

### ❌ No Versioning Strategy
**Problem:** `/api/v1/...` that changes meaning without version bump.
**Fix:** Version in URL (`/v1/`, `/v2/`). Maintain old versions.

### ❌ Authentication as Afterthought
**Problem:** Adding auth to existing APIs instead of designing with it.
**Fix:** Auth is part of the API contract. Design it in.

---

## Testing Mistakes

### ❌ No Tests
**Problem:** "I'll write tests later" (never happens).
**Fix:** Test-driven development. Or at minimum, write tests alongside code.

### ❌ Testing Implementation, Not Behavior
**Problem:** Asserting internal state instead of external behavior.
**Fix:** Black-box testing. What does it do, not how does it do it.

### ❌ Brittle Tests
**Problem:** Tests that break on unrelated changes.
**Example:** Testing "5 items" when you should test "items exist."
**Fix:** Test behaviors, not exact outputs. Use matchers, not equality.

### ❌ Not Testing Edge Cases
**Problem:** Only testing the happy path.
**Fix:** Explicitly list edge cases. Test empty, null, max values.

### ❌ Manual Testing Only
**Problem:** "Works on my machine." No automated verification.
**Fix:** Automate everything possible. CI/CD pipeline with tests.

### ❌ Not Testing Error Paths
**Problem:** Only testing success cases.
**Fix:** Test what happens on failure. Ensure errors are proper.

### ❌ Tests That Depend on Each Other
**Problem:** Test B must run after Test A to pass.
**Fix:** Independent, isolated tests. Shared setup in beforeeach, not beforeall.

### ❌ No Integration Tests
**Problem:** Only unit tests. Gaps in how pieces fit together.
**Fix:** Integration tests that verify component interaction.

### ❌ Test Data Pollution
**Problem:** Tests leaving state that affects other tests.
**Fix:** Clean up in aftereach. Fresh state per test.

### ❌ Not Testing the Interface Users Actually Use
**Problem:** Testing internal methods instead of public API.
**Fix:** Treat public API as the contract. Test that contract.

---

## Product/Feature Mistakes

### ❌ Building Features No One Asked For
**Problem:** Engineering time on features that don't solve user problems.
**Fix:** User research first. Validate before building.

### ❌ Not Defining Success Metrics
**Problem:** Shipping features without knowing how to measure success.
**Fix:** Define metrics before building. What does "done" look like?

### ❌ Scope Creep
**Problem:** "While we're at it..." extending features indefinitely.
**Fix:** Clear scope. Separate additions into new features.

### ❌ Not Cutting Features
**Problem:** Holding onto features that don't work or aren't used.
**Fix:** Kill features that don't meet metrics. Remove dead weight.

### ❌ Ignoring User Feedback
**Problem:** Building what we think is right, ignoring what users say.
**Fix:** Feedback loops. A/B testing. User interviews.

### ❌ Perfect is the Enemy of Good
**Problem:** Over-engineering to avoid shipping.
**Fix:** MVP first. Iterate based on real usage.

### ❌ Not Prioritizing Technical Debt
**Problem:** Only building features. Never fixing foundational issues.
**Fix:** Allocate time for tech debt. Track it explicitly.

### ❌ Feature Flags Gone Wild
**Problem:** 50 feature flags making code unmaintainable.
**Fix:** Time-boxed flags. Remove when feature is stable.

### ❌ Not Planning for Support
**Problem:** Shipping without documentation, support processes.
**Fix:** Document as you build. Plan support load.

---

## Process Mistakes

### ❌ Not Writing Docs
**Problem:** "Code is self-documenting." (It's not.)
**Fix:** Write docs for users, developers, and future-you.

### ❌ Skipping Code Review
**Problem:** Pushing directly to main. No peer review.
**Fix:** Required reviews. Make them substantive, not rubber stamps.

### ❌ Long-Running Branches
**Problem:** Feature branches open for weeks. Merge hell.
**Fix:** Small, frequent PRs. Trunk-based development.

### ❌ Not Automating Repetitive Tasks
**Problem:** Doing the same manual work repeatedly.
**Fix:** Automate. Scripts, CI, tooling. Invest time to save time.

### ❌ Ignoring Postmortems
**Problem:** Incidents happen, lessons not learned.
**Fix:** Blameless postmortems. Document what, why, how to prevent.

### ❌ Hero Culture
**Problem:** One person holding all knowledge. Bus factor = 1.
**Fix:** Knowledge sharing. Code ownership is shared.

### ❌ Estimation Without Tracking
**Problem:** Estimates made, never compared to actuals.
**Fix:** Track estimates vs. actuals. Improve over time.

### ❌ Not Having Rollback Plan
**Problem:** Deployment goes bad, no way to revert quickly.
**Fix:** Automate rollback. Test it before you need it.

### ❌ Inconsistent Environments
**Problem:** Works on my machine. Fails in prod.
**Fix:** Docker/containerize. Same environment everywhere.

### ❌ Ignoring Deprecations
**Problem:** Using deprecated APIs. Breaking changes surprise.
**Fix:** Monitor deprecations. Plan migration paths.

---

## Communication Mistakes

### ❌ Vague Requirements
**Problem:** "Make it better." "Add more features."
**Fix:** Specific, measurable requirements. Written down.

### ❌ Not Explaining the Why
**Problem:** Just telling what to build, not why it matters.
**Fix:** Context helps decisions. Explain purpose.

### ❌ Hiding Problems
**Problem:** Issues swept under the rug until they're crises.
**Fix:** Early escalation. Transparency about blockers.

### ❌ Over-Communicating vs Under-Communicating
**Problem:** Too many meetings, not enough async. Or vice versa.
**Fix:** Right channel for the message. Document decisions.

### ❌ Not Saying No
**Problem:** Accepting every request. Spreading too thin.
**Fix:** Honest capacity. Respectful "no" with alternatives.

### ❌ Blame Culture
**Problem:** People hide mistakes instead of fixing them.
**Fix:** Blameless culture. Focus on systems, not individuals.

### ❌ Assuming
**Problem:** "They know what I mean." "They'll figure it out."
**Fix:** Verify understanding. Ask questions. Confirm alignment.

---

## Contributing to This Document

When you make a mistake (and you will):

1. **Don't hide it** — acknowledge it
2. **Document it** — add it here with context
3. **Fix it** — the mistake is the lesson, not the document
4. **Share it** — help others avoid the same trap

---

## Template for New Entries

```markdown
### ❌ [Short Title]
**Problem:** What went wrong.
**Example:** Specific instance of the mistake (if applicable).
**Impact:** What happened because of this mistake.
**Fix:** How to avoid/prevent it.
**Status:** [Occurred/Prevented/N/A]
```

---

*Last Updated: 2026-04-13*
