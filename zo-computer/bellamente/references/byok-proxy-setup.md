# Proxy mode: routing Zo inference through Bellamente (BYOK)

Two ways to use Bellamente inside Zo. Default is **explicit-API mode**: the agent calls `/search` and `/memories` directly via `bella.sh`. This needs no BYOK config and is what the skill uses by default.

**Proxy mode** is the paper's full vision: Zo's chat inference flows through Bellamente's `/v1/chat/completions`, Bellamente injects the `searchMemory` tool, the model calls it mid-turn, and the whole recall path is traced. This requires Zo's BYOK.

## Does Zo BYOK support this?

The mechanism exists and is documented. Zo's BYOK (`/?t=settings&s=ai&d=byok`, [docs](https://www.zo.computer/docs/byok)) takes a free-text **Base URL**, **API Key**, **Format** (OpenAI / Anthropic / Groq), and **Model ID**. Bellamente's `/v1` is OpenAI-compatible, so Format = OpenAI fits. Zo's own BYOK doc notes Zo uses streaming and tools, so the provider and model must support both. Bellamente's proxy injects tools, so tool support is exactly what's needed.

## Two things to check at the BYOK form

1. Does the Base URL field accept `http://127.0.0.1:8080/v1` (plain http, localhost)? The docs only show https examples. Most forms accept any URL string, but some validate https. If it rejects http/localhost, proxy mode is blocked and explicit-API mode is the path.
2. Does it accept an empty or dummy API key? Bellamente loopback needs no key. If the form requires a non-empty key, paste any dummy string. Bellamente ignores the Authorization header on localhost.

If both pass, proxy mode works. If either fails, fall back to explicit-API mode (no capability loss for recall; you lose auto-capture and the model-initiated tool round).

## The topology (this matters)

Bellamente is a proxy, not a model. It forwards to its own upstream. Inside Zo there is no local Ollama (the default upstream). So proxy mode needs a real external upstream.

**A known-working upstream is DeepSeek V4 Flash.**
- `BELLA_UPSTREAM_BASE_URL=https://api.deepseek.com/v1`
- `BELLA_UPSTREAM_API_KEY` loaded from `Projects/bellamente/.upstream-key` (chmod 600, populated from a Zo secret such as `DEEPSEEK_API_KEY`). Loaded by the `run.sh` wrapper at boot so the key never sits in service env_vars (which are echoed in tooling output).
- Model: `deepseek-v4-flash` (supports function calling, so it calls `searchMemory` correctly). `deepseek-chat` and `deepseek-reasoner` are deprecated.
- Cost: ~580 tokens per memory-grounded turn = roughly $0.0001/turn. Negligible.

Any OpenAI-compatible provider with function-calling support works the same way (OpenRouter, OpenAI, Groq). Point `run.sh` at its base URL, key, and model.

Then the flow is: external client (or Zo, if BYOK accepts localhost) -> Bellamente (localhost:8080/v1) -> upstream provider -> model. Bellamente injects the tool, the model calls it, Bellamente runs recall, the answer is traced.

## Container rule (do not skip)

The proxy and auto-capture both use the `default` container. There is no config to repoint it. Seed and write all memories with `containerTag: "default"`. The skill's `BELLA_TAG` default is `default`. Writing under a custom tag creates an invisible partition the proxy cannot see.

## What a proxy turn looks like

Ask a memory-grounded question through the proxy and the model answers from your seeded facts, with the recall path attached. Response headers report how many memories matched (`x-bella-search-results`) and provenance is fully inspectable: `GET /inspect/:traceId` shows the queries the model sent, every retrieved memory with similarity scores, injection count, and latency.

## Cost tradeoff (own this before enabling)

Routing a Zo chat through Bellamente -> your provider means the reasoning tokens are billed by that provider, not by Zo's included inference. Zo's included model is bypassed for any chat that uses the Bellamente-routed model. The smart pattern is a **dedicated** custom model entry used selectively for memory-heavy sessions, not replacing the default model for everything. Add it as one entry in the model picker, switch to it when you want the memory round, switch back for ordinary work.

## How proxy mode gets the key (read this before enabling)

Zo secrets live in Settings > Advanced and inject into the agent's own bash sessions, but they do NOT reach user-service processes. So a persistent Bellamente service in proxy mode cannot read the provider key from its environment. The service's `env_vars` (set via the Zo service tooling) get echoed back in tool output, so putting a real key there leaks it into chat and logs.

The least-bad path for a persistent proxy service: `bella.sh proxy enable <provider>` stages the key from the matching env var (`DEEPSEEK_API_KEY`, `OPENROUTER_API_KEY`) into a root-only 600-perm file at `Projects/bellamente/.upstream-key`, plus a `.upstream-url` and `.upstream-model` file. The `run.sh` wrapper reads them at boot and exports them as `BELLA_UPSTREAM_*`. The key never sits in service `env_vars` and never appears in tool output.

The tradeoff, owned: this duplicates the key. If you rotate the Zo secret, the staged file goes stale and proxy auth fails until you re-run `bella.sh proxy enable`. That is the cost of persistence without platform-level secret injection into services. Base memory mode needs no key, no file, no upstream. Most users should stay on base mode. Proxy mode is for the minority who want the model-initiated memory round on their own routed chats.

## Exact BYOK field values to paste (when you test the Zo form)

- Format: `OpenAI`
- Base URL: `http://127.0.0.1:8080/v1`
- API Key: any non-empty dummy string (e.g. `bella-loopback`). Bellamente ignores Authorization on loopback
- Model ID: `deepseek-v4-flash` (or whichever upstream model you configured)

If the BYOK form accepts the localhost URL, this is the only remaining step to route Zo's own chat turns through the memory layer.
