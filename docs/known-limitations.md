# Known limitations

Cross-cutting issues that affect the engine but aren't tied to a single phase. Track upstream fixes here.

## Upstream: Claude Code custom-subagent MCP regression (2026-05-12)

**Status:** OPEN upstream. Tracked at [anthropics/claude-code#25200](https://github.com/anthropics/claude-code/issues/25200).

**Symptom.** Every dm-quarantined subagent that depends on the `dm-fs` MCP server reports `No such tool available: mcp__dm-fs__list_dm_dir` (or `mcp__dm-fs__read_dm_file`, etc.) at runtime, even when:

- The dm-fs MCP server is configured in `.mcp.json` at the project root.
- `claude mcp list` shows `dm-fs: ✓ Connected`.
- The main Claude Code session has the dm-fs tools as deferred and can materialize them via `ToolSearch`.
- The subagent's frontmatter declares `mcpServers: [dm-fs]` and (optionally) includes the qualified MCP tool names in the `tools:` allowlist.

**Root cause.** Custom subagents in `.claude/agents/` are hardcoded to a 6-tool inventory (Read, Write, Edit, Bash, Glob, Grep) via `CUSTOM_AGENT_DISALLOWED_TOOLS`. That disallow list excludes `ToolSearch`. Deferred MCP tools require `ToolSearch` to materialize. Without it, the MCP tool names are registered for the subagent but cannot be called. Frontmatter declarations are parsed but have zero effect on the runtime tool inventory. The regression was introduced between Claude Code v2.1.45 (last known working version) and v2.1.92, and persists through at least v2.1.139.

**Affected subagents and behaviors.** Every dm/-touching subagent is broken:

| Subagent | Affected behaviors |
|---|---|
| `world-state` | Phase 2a offscreen-developments tick at `/session-start`; all hidden-info queries during play; faction ticks; NPC behavior queries |
| `librarian` | Phase 3a `intake-module`; Phase 3b `consult-library`; Phase 3b `reveal-from-module`; Phase 3d `propose-revelations`; Phase 3e `propose-factions` |
| `revelation` | Phase 2b `could-land` queries; Phase 2b clue delivery confirmation against `dm/revelations/` |
| `bookkeeper` | Phase 4b checks 4–6 (faction tick rationale, clue delivery confirmation, thread state consistency) |
| `mythic` | Phase 2c thread CRUD against `dm/threads/active.md` — uses dm-fs MCP for thread state reads/writes |
| `dice` | Not affected. No `dm/` access. |

**What still works.** Subagents' direct-file work (the 6 built-in tools) still functions. Bookkeeper checks 1–3 (narrator-discipline trio) work because they only need Read/Glob/Bash. Dice rolls work. Mythic oracle questions work (no `dm/` reads). Narrator-side reads of `world/`, `party/`, `library/lore/`, `sessions/` work. The deny rules in `.claude/settings.json` still hold — the narrator still cannot read `dm/` directly. The asymmetry boundary is intact; it's the *crossing mechanism* that's broken.

**Operating impact.** Play sessions on Claude Code v2.1.46+ are materially degraded. Specifically:

- `/session-start` cannot run the offscreen-developments tick — world-state can't read `dm/factions/`.
- The narrator cannot get answers to hidden-info questions ("does the NPC trust me?", "what's behind this door?") routed through world-state.
- `/intake` cannot ingest new module material (librarian can't write to `dm/modules/`).
- Revelations cannot surface during play.
- Threads cannot be opened, listed, or closed.
- `/session-end` runs bookkeeper checks 1–3 only; checks 4–6 skip with warnings (documented graceful degradation).

Effectively, only Phase 1 (MVP session with dice + oracle + manual world state) works end-to-end on current Claude Code.

**Paths forward.** Four real options:

1. **Wait for upstream fix.** Issue #25200 has detailed RCA and a proposed fix (`CUSTOM_AGENT_DISALLOWED_TOOLS` adjustment). A v2.1.139 repro comment was added 2026-05-12.
2. **Downgrade Claude Code to v2.1.45.** The last known working version per the upstream RCA. Costs feature freeze; preserves engine functionality.
3. **Rework architecture to bypass the limitation.** Two sub-options:
   - Have subagents shell out to a `dm-fs` CLI via Bash. Subagents retain Bash; the dm-fs Python package would gain a CLI surface (`python -m dm_fs.cli list factions`, etc.) that mirrors the MCP tool surface. Subagents call the CLI instead of the MCP. Phase 4c-scale change touching the dm-fs package and every dm/-touching subagent.
   - Use `general-purpose` (built-in) subagent with inlined system prompts. Built-in agents have `ToolSearch` and reach MCP fine. Costs the reusable agent definition pattern; loses the per-subagent capability boundary enforced by frontmatter.
4. **Accept current degradation and shift roadmap.** Pause Phase 4c and beyond until upstream resolution. Continue with non-dm-touching work only (no Phase 2+ play).

The current plan is (1) + (4) in parallel: file/comment upstream (done), continue Phase 4c brainstorming with the regression as a first-class scope consideration, and don't pick up architecture rework until we know upstream's posture on the fix.

**Recovery procedure (when upstream fixes).** When a Claude Code release lands that restores subagent MCP access:

1. Upgrade Claude Code to the fixed version.
2. Restart any active session.
3. Re-run the Phase 4b post-resume validation: dispatch the bookkeeper against `sessions/play/2026/05/session-005.md` and verify checks 4–6 produce real findings (or clean `- (none)` results) instead of skip markers.
4. Commit the post-resume Phase 4b validation artifact.
5. Update this section to reflect the resolved state.
