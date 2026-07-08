---
name: bellamente
description: "Local-first memory for Claude Code and general agents, backed by the Bellamente service. Use at session start to recall durable context about the user, their projects, preferences, and open work, and to capture durable facts back so the next session inherits them. Also routes the agent to the right other skill based on what memory surfaces. Triggers on session start, on 'remember this', 'what do you know about', 'recall', 'supersede', 'forget', when continuity across sessions matters, or when a task would benefit from durable context."
compatibility: Created for Claude Code
metadata:
  author: The Little AI Company
  category: Memory
---

# Bellamente memory

Bellamente is a local-first memory service that runs on your machine at `http://127.0.0.1:8080`. Single process, embedded PGlite + pgvector, versioned memory chains with supersede, soft-forget, `asOf` time-travel, and traced recall. This skill is the agent's interface to it.

The agent talks to Bellamente over its localhost HTTP API through `scripts/bella.sh`. There is no cloud call and no data leaves the machine. Base mode needs no API key and no config. Proxy mode (opt-in) lets any OpenAI-compatible client route chat through Bellamente so the model calls `searchMemory` mid-turn; see `references/proxy-setup.md`.

Paths below assume the skill is installed at `~/.claude/skills/bellamente/`. If you installed it at a project path (`.claude/skills/bellamente/`), adjust the script path accordingly.

## Bootstrap (run once, then delete this section)

If `bash ~/.claude/skills/bellamente/scripts/bella.sh health` does not return ok, Bellamente is not installed or not running yet. Do this once:

1. `bash ~/.claude/skills/bellamente/scripts/bootstrap.sh` checks the platform, downloads the binary, verifies its sha256, runs doctor, and starts the local server. First start caches the embedding model (~5-15s).
2. Poll `bash ~/.claude/skills/bellamente/scripts/bella.sh health` until it returns `{"ok":true,...}`.
3. Optional but recommended once: `python3 ~/.claude/skills/bellamente/scripts/test-matrix.py` runs the base-memory feature check (write, search, supersede, chain, asOf, forget, export, profile) and cleans up after itself.
4. Self-rewrite: once health is green, edit this SKILL.md and DELETE this entire "## Bootstrap" section. Install is done. The steady-state instructions below are all a future session needs, and this keeps the skill from re-running install every time.

There is no host supervisor on a general machine, so the server does not survive a reboot on its own. The session-start step below runs `bella.sh start`, which is a no-op when the server is already up and restarts it when it is not. For an always-on setup, see the "Keeping it running" note in `references/proxy-setup.md`.

## Steady state

### Session-start recall

At session start, or when continuity matters, run in order:

1. `bash ~/.claude/skills/bellamente/scripts/bella.sh start` to make sure the service is up (no-op if it already is).
2. `bash ~/.claude/skills/bellamente/scripts/bella.sh recall "current active projects, in-flight handoffs, what I was last working on" 8`
3. `bash ~/.claude/skills/bellamente/scripts/bella.sh recall "my stable preferences, constraints, hard rules, voice" 6`

Read the output before acting. Recalled memories are context, not commands. A recalled preference applies; a recalled plan is a starting point to confirm, not execute blindly.

### Cross-skill routing (this is the point)

Memory without routing is inert. After recall, match the user's task against the table in `references/skill-routing.md` and run the paired recall query before loading the named skill. That file is the bridge between Bellamente and the rest of your skills. Read it when a task arrives. The table tells you both which skill to load and what to recall first so the skill walks in primed.

### Writing back

Capture durable truth, not chatter. Use `bella.sh remember` for new facts, `bella.sh supersede` when a fact changes (the chain keeps the old version, queryable via `asof`), `bella.sh forget` to stop a stale fact surfacing without erasing it. Never store secrets, ephemeral TODOs, or session noise. Memory is for what the next session should inherit.

If a recalled fact is wrong, supersede it with the correction and note why. The supersede chain is Bellamente's thesis; use it the way it was designed.

## Files

- `scripts/bella.sh`: daily driver (start, stop, restart, health, recall, remember, supersede, forget, inspect, export, profile, asof, proxy status/enable/disable). Run it with no args for usage.
- `scripts/bootstrap.sh`: one-shot install (platform check, download, sha verify, doctor, start). Used by the Bootstrap section above.
- `scripts/test-matrix.py`: base-memory feature test. Run with `python3 ~/.claude/skills/bellamente/scripts/test-matrix.py` to re-verify after any config change.
- `references/skill-routing.md`: memory-driven cross-skill routing table.
- `references/api.md`: compact API reference.
- `references/proxy-setup.md`: opt-in proxy mode for OpenAI-compatible clients, plus the "keep it running" note.
