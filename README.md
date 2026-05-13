# gygaxagain

A solo D&D campaign engine built on Claude Code. The player drives one primary PC; Claude narrates the world. Mechanical outcomes route through a `dice` subagent. Genuinely uncertain yes/no questions route through a `mythic` subagent (Mythic GME 2e oracle). Hidden world state lives behind a `world-state` subagent backed by a path-scoped local MCP server (`dm-fs`) so the narrator cannot read campaign secrets directly — the asymmetry between what the player knows and what's actually in the world is the load-bearing invariant of the design.

In active development. Not packaged for general use.

## Repo layout

- `CLAUDE.md` — narrator instructions and routing rules. The authoritative spec for what the narrator may and may not do during play.
- `SPEC.md` — the original design spec for the engine.
- `dm/` — hidden world state. **Read-denied to the narrator** at the project level (`.claude/settings.json`). Subagents reach it via the `dm-fs` MCP only.
- `world/` — player-facing world state (gazetteer, NPCs the party has met, locations the party has visited).
- `party/primary/` — primary PC sheet.
- `sessions/play/YYYY/MM/session-NNN.md` — append-only session logs.
- `library/index.md` — enumeration of ingested module and lore sources.
- `library/lore/<source>/` — narrator-readable lore reference material (monster stat blocks, spell descriptions, gazetteer entries).
- `library/modules/<slug>/` — intentionally empty; module content is dm-quarantined under `dm/modules/<slug>/`.
- `references/` — raw source material (PDFs, etc.) staged for intake. PDFs and TXTs are gitignored; per-source structure may be tracked.
- `tools/dm-fs-mcp/` — Python MCP server exposing `dm/` as path-scoped reads and writes for authorized subagents.
- `docs/superpowers/specs/` — phase design specs.
- `docs/superpowers/plans/` — phase implementation plans.
- `docs/resume-on-new-machine.md` — bootstrap procedure for a fresh clone.
- `docs/known-limitations.md` — durable record of cross-cutting issues affecting the engine.
- `.claude/agents/` — subagent definitions (dice, mythic, world-state, librarian, revelation, bookkeeper).
- `.claude/commands/` — slash commands (`/session-start`, `/session-end`, `/roll`, `/intake`, etc.).
- `.mcp.json` — project-scoped MCP server registration.

## Setup on a new machine

See `docs/resume-on-new-machine.md` for the full bootstrap procedure. At a high level:

1. Create a Python 3.11+ venv at `.venv/` (system Python on macOS is typically too old).
2. `pip install -e tools/dm-fs-mcp`.
3. Confirm `.mcp.json` points at the venv's interpreter and the correct `DM_ROOT` for this machine. (The current `.mcp.json` hardcodes absolute paths; portability is a known cleanup.)
4. Relaunch Claude Code so it picks up the MCP server. Verify with `claude mcp list` — expect `dm-fs: ✓ Connected`.
5. Run the dm-fs test suite (`python -m pytest -q tools/dm-fs-mcp`) — expect 37 passed.

## Current state

The engine is being built incrementally. The authoritative shipped-phase list lives in the **Current phase scope** section of `CLAUDE.md`. Each phase's design and implementation plan lives under `docs/superpowers/specs/` and `docs/superpowers/plans/` respectively.

## Known limitations

See `docs/known-limitations.md`. The current entry of note is an upstream Claude Code regression (tracked at [anthropics/claude-code#25200](https://github.com/anthropics/claude-code/issues/25200)) that prevents custom subagents from reaching MCP servers. Every dm/-touching subagent is affected, which materially degrades Phase 2+ play sessions on Claude Code v2.1.46+. The asymmetry boundary itself is intact; the crossing mechanism is broken until upstream resolves.
