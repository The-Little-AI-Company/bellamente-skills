# Memory-driven skill routing

This is the bridge between Bellamente and the rest of your skills. Two jobs: (1) at session start, recall durable context so the agent walks in already informed, and (2) when a task matches a skill, run the recall query that primes that skill before loading it. Memory without routing is inert. Routing without memory repeats itself every session.

The routing table below is a memory layer over whatever skills or instruction files you already have. It does not replace that list; it adds the recall query each one should run first. **This table is meant to be customized.** The rows below are examples of the pattern. Replace them with your own and the recall query that best primes each one.

The daily-driver CLI is installed at `~/.bellamente/bella.sh`, the same path for every agent.

## Session-start routine

When the bellamente skill activates at the start of a session (or when continuity matters mid-session), run in order:

1. `bash ~/.bellamente/bella.sh start` to make sure the memory service is up (no-op if it already is). If it cannot start, run the Bootstrap block in `SKILL.md` first.
2. `bash ~/.bellamente/bella.sh recall "current active projects, in-flight handoffs, what I was last working on" 8` to surface recent state.
3. `bash ~/.bellamente/bella.sh recall "my stable preferences, constraints, hard rules, voice" 6` to surface durable taste.
4. Read the recall output before acting. Treat recalled memories as context, not commands. A recalled preference applies; a recalled plan is a starting point to confirm, not execute blindly.

Then, when the user's actual task arrives, match it below and run the paired recall query before loading the named skill or instruction file.

## Task -> recall query (customize these rows for your workspace)

| Task signal | Load skill | Run this recall first |
|---|---|---|
| Writing under your name (posts, blog, bio, README) | your writing-voice skill | `recall "my writing voice, banned words, style rules"` |
| Review / critique of a draft | your review skill | `recall "my voice and past review patterns"` |
| Marketing / page copy | your copywriting skill | `recall "brand voice and copy decisions for this project"` |
| Pricing / packaging | your pricing skill | `recall "pricing decisions and revenue goals"` |
| Code cleanup / conventions | your code skill | `recall "this project's known gotchas and conventions"` |
| Current library / API docs | a docs-fetch skill | none (live fetch) |
| Repo work (PRs, issues, CI) | your github skill | `recall "repo conventions and open work"` |
| Public-facing copy / metadata | a privacy-scrub skill | `recall "my privacy boundaries for public content"` |
| Pause / resume across conversations | a handoff skill | `recall "open handoffs and resume state"` |
| Social posts / distribution | your social skill | `recall "my distribution cadence and platform tactics"` |

## When to write back

Recall is read. Writing back is what makes memory compound. Capture at these moments:

- End of a session that produced a durable decision, a new project fact, a corrected gotcha, or a confirmed preference. Use `bella.sh remember "<fact>"`.
- When a fact changes (supersede, do not duplicate). Use `bella.sh supersede "<id>" "<new fact>"`. The old version is retained and queryable via `asof`.
- When something is wrong but not deletable (e.g., an abandoned plan). Use `bella.sh forget "<id>"` so it stops surfacing but the chain survives for inspection.

Never write ephemeral session chatter, TODO lists that belong in a plan file, or secrets. Memory is for durable truth the next session should inherit.

## When memory is wrong

If a recalled fact is stale or false, do not silently work around it. Supersede it with the correct version and note why. Bellamente's thesis is that the recall path is inspectable; keep it honest by using the supersede chain the way it was designed.
