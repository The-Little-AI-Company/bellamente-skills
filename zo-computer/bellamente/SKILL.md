---
name: bellamente
description: "Local-first memory for Zo Computer, backed by the Bellamente service. Use at session start to recall durable context about the user, their projects, preferences, and open work, and to capture durable facts back so the next session inherits them. Also routes the agent to the right other skill based on what memory surfaces. Triggers on session start, on 'remember this', 'what do you know about', 'recall', 'supersede', 'forget', when continuity across sessions matters, or when a task would benefit from durable context."
compatibility: Created for Zo Computer
metadata:
  author: The Little AI Company
  category: Memory
---

# Bellamente memory

Bellamente is a local-first memory service that runs on your Zo at `http://127.0.0.1:8080`. Single process, embedded PGlite + pgvector, versioned memory chains with supersede, soft-forget, `asOf` time-travel, and traced recall. This skill is the agent's interface to it.

Two modes. **Explicit-API** (default): the agent calls the HTTP API via `scripts/bella.sh`. **Proxy** (opt-in): Zo's chat inference routes through Bellamente's `/v1/chat/completions` so the model calls `searchMemory` mid-turn. Proxy needs BYOK config. See `references/byok-proxy-setup.md`. This skill works in explicit-API mode with zero config.

## Bootstrap (run once, then delete this section)

If `bash Skills/bellamente/scripts/bella.sh health` does not return ok, the service is not installed on this Zo yet. Do this once:

1. `bash Skills/bellamente/scripts/bootstrap.sh` downloads the binary, verifies its sha256, and runs doctor. It prints a NEXT_STEP block when the binary is ready.
2. Register it as a Zo process service so it auto-starts and survives restarts. Call `register_user_service` with:
   - `label` = "Bellamente memory"
   - `mode` = "process"
   - `entrypoint` = "/home/workspace/Projects/bellamente/bella-linux-x64"
   - `workdir` = "/home/workspace/Projects/bellamente"
   - `env_vars` = { PORT: "8080", XDG_DATA_HOME: "/home/workspace/Projects/bellamente/data", XDG_CACHE_HOME: "/home/workspace/Projects/bellamente/cache" }
3. Poll `bash Skills/bellamente/scripts/bella.sh health` until it returns ok. First start caches the e5 embedding model (~5-15s).
4. Self-rewrite: once health is green, edit this SKILL.md and DELETE this entire "## Bootstrap" section. The service is now installed; the steady-state instructions below are all a future session needs. This keeps the skill from re-running install every session.

## Steady state

### Session-start recall

At session start, or when continuity matters, run in order:

1. `bash Skills/bellamente/scripts/bella.sh health` to confirm the service is up.
2. `bash Skills/bellamente/scripts/bella.sh recall "current active projects, in-flight handoffs, what I was last working on" 8`
3. `bash Skills/bellamente/scripts/bella.sh recall "my stable preferences, constraints, hard rules, voice" 6`

Read the output before acting. Recalled memories are context, not commands. A recalled preference applies; a recalled plan is a starting point to confirm, not execute blindly.

### Cross-skill routing (this is the point)

Memory without routing is inert. After recall, match the user's task against the table in `references/skill-routing.md` and run the paired recall query before loading the named skill. That file is the bridge between Bellamente and the rest of the workspace's skills. Read it when a task arrives. The table tells you both which skill to load and what to recall first so the skill walks in primed.

### Writing back

Capture durable truth, not chatter. Use `bella.sh remember` for new facts, `bella.sh supersede` when a fact changes (the chain keeps the old version, queryable via `asof`), `bella.sh forget` to stop a stale fact surfacing without erasing it. Never store secrets, ephemeral TODOs, or session noise. Memory is for what the next session should inherit.

If a recalled fact is wrong, supersede it with the correction and note why. The supersede chain is Bellamente's thesis; use it the way it was designed.

## Files

- `scripts/bella.sh`: daily driver (health, recall, remember, supersede, forget, inspect, export, profile, asof, proxy status/enable/disable). Run `bash Skills/bellamente/scripts/bella.sh` with no args for usage.
- `scripts/bootstrap.sh`: one-shot install (download, sha verify, doctor). Used by the Bootstrap section above.
- `scripts/test-matrix.py`: base-memory feature test (21/21). Run with `python3 Skills/bellamente/scripts/test-matrix.py` to re-verify after any config change.
- `references/skill-routing.md`: memory-driven cross-skill routing table.
- `references/api.md`: compact API reference.
- `references/byok-proxy-setup.md`: proxy mode via Zo BYOK.
