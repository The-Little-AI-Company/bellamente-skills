# Bellamente Skills

Agent Skills that give an AI agent a local-first, auditable memory layer, backed by [Bellamente](https://github.com/The-Little-AI-Company/bellamente). Each skill wires Bellamente into one agent host so the agent recalls durable context at the start of a session and writes durable facts back for the next one.

Bellamente runs on your machine. No memory leaves it. Every recall is traceable, every fact is versioned, and nothing is silently overwritten.

## Skills

| Skill | Host | What it does |
|---|---|---|
| [Bellamente for Zo Computer](zo-computer/bellamente) | Zo Computer | Installs the Bellamente service on your Zo, recalls durable context at session start, writes durable facts back, and routes to your other skills based on what memory surfaces. |

More hosts will land here as sibling folders. Zo Computer is first.

## Install: Bellamente for Zo Computer

Copy the skill folder into your Zo workspace, then let it install itself.

1. Copy `zo-computer/bellamente/` into your Zo `Skills/` directory so the skill lives at `Skills/bellamente/`.
2. Start a session and invoke the skill. The `## Bootstrap` block in `SKILL.md` runs once. It downloads the Bellamente binary, verifies its sha256, registers it as a Zo process service so it survives restarts, and waits for `health` to return ok.
3. Once health is green, the skill edits its own `SKILL.md` and deletes the Bootstrap block. After that it only does session-start recall, write-back, and cross-skill routing. Install never runs again.

Base memory mode needs no API key, no config, and no external service. Proxy mode, where Zo's own inference routes through Bellamente so the model calls memory mid-turn, is opt-in and documented in [`zo-computer/bellamente/references/byok-proxy-setup.md`](zo-computer/bellamente/references/byok-proxy-setup.md).

## What Bellamente is

A single process. Embedded Postgres (PGlite) with pgvector for storage and search, a local embedding model for recall, versioned memory chains with supersede, reversible soft-forget, `asOf` time-travel to query what you knew at any past instant, and a trace for every recall you can inspect after the fact. Read the design at [the Bellamente paper](https://the-little-ai-company.github.io/bellamente/paper/).

## License

MIT. See [LICENSE](LICENSE).
