# Proxy mode: routing chat through Bellamente

Two ways to use Bellamente. Default is **explicit-API mode**: the agent calls `/search` and `/memories` directly via `bella.sh`. This needs no config, no key, and is what this skill uses by default. Most users should stay here.

**Proxy mode** is the paper's full vision: an OpenAI-compatible client points its base URL at Bellamente's `/v1/chat/completions`, Bellamente injects the `searchMemory` tool, the model calls it mid-turn, and the whole recall path is traced. This is opt-in and needs an upstream model with function calling.

## Where proxy mode fits with Claude Code

Claude Code drives Anthropic models directly, so it does not route its own turns through an OpenAI-compatible proxy. In Claude Code, the memory round happens the explicit way: the skill calls `bella.sh recall` before acting and `bella.sh remember` after. That is the supported path and it loses nothing on recall.

Proxy mode is for the OpenAI-compatible clients and agents you run alongside Claude Code (your own app, an OpenAI SDK script, another agent runtime). Point any of them at `http://127.0.0.1:8080/v1` and they get the model-initiated `searchMemory` round and auto-capture for free.

## The topology (this matters)

Bellamente is a proxy, not a model. It forwards to its own upstream, so proxy mode needs a real external upstream that supports function calling.

**A known-working upstream is DeepSeek V4 Flash.**
- `BELLA_UPSTREAM_BASE_URL=https://api.deepseek.com/v1`
- `BELLA_UPSTREAM_API_KEY` loaded from `~/.bellamente/.upstream-key` (chmod 600), staged by `bella.sh proxy enable deepseek` from a `DEEPSEEK_API_KEY` env var. The server reads it at start, so the key never sits in a shell command or process listing you might paste into a log.
- Model: `deepseek-v4-flash` (supports function calling, so it calls `searchMemory` correctly). `deepseek-chat` and `deepseek-reasoner` are deprecated.
- Cost: roughly 580 tokens per memory-grounded turn, about $0.0001/turn. Negligible.

Any OpenAI-compatible provider with function-calling support works the same way (OpenRouter, OpenAI, Groq). Use `bella.sh proxy enable custom` with `BELLA_UPSTREAM_BASE_URL`, `BELLA_UPSTREAM_API_KEY`, and `BELLA_UPSTREAM_MODEL` set.

Then the flow is: your OpenAI-compatible client -> Bellamente (127.0.0.1:8080/v1) -> upstream provider -> model. Bellamente injects the tool, the model calls it, Bellamente runs recall, the answer is traced.

## Enabling it

1. Put the provider key in your environment (`export DEEPSEEK_API_KEY=...`).
2. `bash ~/.claude/skills/bellamente/scripts/bella.sh proxy enable deepseek`
3. `bash ~/.claude/skills/bellamente/scripts/bella.sh restart` so the server reads the staged upstream.
4. `bash ~/.claude/skills/bellamente/scripts/bella.sh proxy status` should report `MODE: proxy`.
5. Point your OpenAI-compatible client at the values below and send a memory-grounded question.

Client config to paste:
- Base URL: `http://127.0.0.1:8080/v1`
- API Key: any non-empty dummy string (e.g. `bella-loopback`). Bellamente ignores Authorization on loopback.
- Model: `deepseek-v4-flash` (or whichever upstream model you configured).

To turn it off: `bella.sh proxy disable` then `bella.sh restart`. Base memory mode returns.

## Container rule (do not skip)

The proxy and auto-capture both use the `default` container. There is no config to repoint it. Seed and write all memories with `containerTag: "default"`. The skill's `BELLA_TAG` default is `default`. Writing under a custom tag creates an invisible partition the proxy cannot see.

## What a proxy turn looks like

Ask a memory-grounded question through the proxy and the model answers from your seeded facts, with the recall path attached. Response headers report how many memories matched (`x-bella-search-results`) and provenance is fully inspectable: `GET /inspect/:traceId` shows the queries the model sent, every retrieved memory with similarity scores, injection count, and latency.

## The key-staging tradeoff (own this before enabling)

`bella.sh proxy enable` copies the provider key from an env var into a 600-perm file at `~/.bellamente/.upstream-key` so the server can read it at start without you retyping it. That duplicates the key. If you rotate the source secret, the staged file goes stale and proxy auth fails until you re-run `bella.sh proxy enable`. That is the cost of a persistent proxy on a host with no platform secret injection. Base memory mode needs no key, no file, no upstream, which is why it is the default.

## Keeping it running

There is no host supervisor on a general dev machine, so the server does not survive a reboot on its own. The skill's session-start step runs `bella.sh start`, which recovers it whenever a session begins. If you want it always on, add one of these:

- systemd user service: `systemd-run --user --unit=bellamente ~/.bellamente/bella-linux-x64`, or write a unit that runs the binary and `WantedBy=default.target`.
- cron at reboot: `@reboot ~/.claude/skills/bellamente/scripts/bella.sh start` in `crontab -e`.
- macOS launchd: a LaunchAgent plist that runs the binary at login.

None of these are required. Session-start recovery is enough for interactive use.
