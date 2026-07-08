# Bellamente API (compact reference for agents)

Base: `http://127.0.0.1:8080`. JSON in, JSON out. No auth on localhost. The `bella.sh` script in `scripts/` wraps all of these; prefer it over raw curl.

## Memories
- `POST /memories` `{containerTag, memories:[{content, isStatic?, metadata?}], dedupe?}`: write 1 to 100. Result per item: `created` / `unchanged` (exact dup) / superseded (near-dup becomes a new version, old kept).
- `GET /memories?containerTag=`: latest, non-forgotten.
- `GET /memories/:id`: one memory plus its full version chain (forgotten versions included). Every version row carries `validFrom` / `validTo` (ISO or null = open-ended).
- `PATCH /memories/:id` `{content}`: content change creates a new version. Returns 409 + `latestId` if the target is not the chain's latest.
- `POST /memories/:id/forget` `{undo?}`: soft-forget the chain; `{undo:true}` reverses.
- `DELETE /memories/:id`: hard-delete the chain plus provenance. The only true eraser.

## Documents
- `POST /documents` `{title?, content, containerTag?}`: structure-aware markdown chunking, embedded, searchable.
- `GET /documents` / `GET /documents/:id` / `DELETE /documents/:id`.

## Search
- `POST /search` `{q, searchMode, limit?, recency?, diversify?, asOf?}`
  - `searchMode`: `memories` | `documents` | `hybrid`
  - `recency: false` turns off time-decay. Memory results get an MMR diversity pass (default on when limit >= 5; `diversify: false` off, `diversify: true` force on).
  - Results carry `similarity` (raw cosine evidence; 0 for keyword-only) and `score` (fused rank). Returned order is the ranking authority. Every search returns a `traceId`.
  - `asOf`: ISO 8601 with explicit timezone, or plain date (UTC midnight). Returns versions whose validity window covers that instant, including superseded ones. Timezone-less datetimes are a 400. Forgotten/expiry still apply at query time.

## Profile
- `GET /profile` / `PUT /profile`: static plus dynamic facts injected as context on proxied chats.

## Export / import
- `GET /export?containerTag=`: one versioned JSON doc. No embeddings (stays small, portable across embedder tiers).
- `POST /import`: restores a file. Fresh ids (old remapped, chain relations preserved), embeddings regenerated locally, never trusted from the file. Re-import is a no-op.

## Inspect (receipts)
- `GET /inspect`: recent traces. `GET /inspect/:id`: one trace showing what was searched, retrieved, injected, scores, latency, status. Traces are device-local and never exported.

## Chat proxy (OpenAI-compatible)
- `POST /v1/chat/completions`: forwards to upstream (`BELLA_UPSTREAM_BASE_URL`), injects the `searchMemory` tool plus profile, runs the memory round, traces everything. Diagnostic headers: `x-bella-trace-id`, `x-bella-memory-round`, `x-bella-context-modified`, `x-bella-search-results`, `x-bella-streaming`.

## Health
- `GET /health`: `{"ok":true,"service":"bellamente","auth":"none"|"required"}`. Never requires auth.
