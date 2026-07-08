# Bellamente Skills

> **This repo has moved.** Each skill now lives in its own repo. This one is archived and read-only.
>
> - Zo Computer: **[bellamente-zo-skill](https://github.com/The-Little-AI-Company/bellamente-zo-skill)**
> - Any other coding agent (Codex, Claude Code, Cursor, and similar): **[bellamente-agent-skill](https://github.com/The-Little-AI-Company/bellamente-agent-skill)**

Agent Skills that give an AI agent a local-first, auditable memory layer, backed by [Bellamente](https://github.com/The-Little-AI-Company/bellamente). Each skill wires Bellamente into one agent host so the agent recalls durable context at the start of a session and writes durable facts back for the next one.

Bellamente runs on your machine. No memory leaves it. Every recall is traceable, every fact is versioned, and nothing is silently overwritten.

## Skills

| Skill | Host | What it does |
|---|---|---|
| [Bellamente for Zo Computer](zo-computer/bellamente) | Zo Computer | Installs the Bellamente service on your Zo, recalls durable context at session start, writes durable facts back, and routes to your other skills based on what memory surfaces. |
| [Bellamente for coding agents](coding-agent/bellamente) | Codex, Claude Code, Cursor, and similar | Installs and self-manages the Bellamente server on your machine, recalls durable context at session start, writes durable facts back, and routes to your other skills based on what memory surfaces. |

Both skills share the same steady-state contract (session-start recall, write-back, cross-skill routing) and differ only in how they install and keep the service running. The coding-agent skill depends on nothing but a shell, so any agent that can run a command can use it. More hosts will land here as sibling folders.

## Install: Bellamente for Zo Computer

Copy the skill folder into your Zo workspace, then let it install itself.

1. Copy `zo-computer/bellamente/` into your Zo `Skills/` directory so the skill lives at `Skills/bellamente/`.
2. Start a session and invoke the skill. The `## Bootstrap` block in `SKILL.md` runs once. It downloads the Bellamente binary, verifies its sha256, registers it as a Zo process service so it survives restarts, and waits for `health` to return ok.
3. Once health is green, the skill edits its own `SKILL.md` and deletes the Bootstrap block. After that it only does session-start recall, write-back, and cross-skill routing. Install never runs again.

Base memory mode needs no API key, no config, and no external service. Proxy mode, where Zo's own inference routes through Bellamente so the model calls memory mid-turn, is opt-in and documented in [`zo-computer/bellamente/references/byok-proxy-setup.md`](zo-computer/bellamente/references/byok-proxy-setup.md).

## Install: Bellamente for coding agents

For Codex, Claude Code, Cursor, and any other agent that can run a shell command, the skill installs the Bellamente server and manages its lifecycle itself, since there is no host supervisor. It depends on no plugin system, no MCP server, and no specific runtime.

1. Copy `coding-agent/bellamente/` into wherever your agent loads skills or instruction files. Point the agent at the `SKILL.md` inside it (some agents read `SKILL.md` directly; for others, paste its contents into your agent's instruction file, such as `AGENTS.md`).
2. On first use, the `## Bootstrap` block in `SKILL.md` runs once. It checks your platform, downloads the Bellamente binary, verifies its sha256, installs the CLI to `~/.bellamente/bella.sh`, runs a feature check, and starts the local server.
3. Once health is green, the skill edits its own `SKILL.md` and deletes the Bootstrap block. After that it does session-start recall, write-back, and cross-skill routing. The session-start step runs `bella.sh start`, which recovers the server after a reboot.

Every steady-state command calls `~/.bellamente/bella.sh`, one agent-independent path, so nothing depends on where the skill folder lives. The current release ships a linux-x86_64 binary. On other platforms, run Bellamente in a linux-x86_64 container and point the skill at it. Proxy mode for OpenAI-compatible clients is opt-in and documented in [`coding-agent/bellamente/references/proxy-setup.md`](coding-agent/bellamente/references/proxy-setup.md).

## What Bellamente is

A single process. Embedded Postgres (PGlite) with pgvector for storage and search, a local embedding model for recall, versioned memory chains with supersede, reversible soft-forget, `asOf` time-travel to query what you knew at any past instant, and a trace for every recall you can inspect after the fact. Read the design at [the Bellamente paper](https://the-little-ai-company.github.io/bellamente/paper/).

## License

MIT. See [LICENSE](LICENSE).
