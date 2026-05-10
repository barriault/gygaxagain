# Phase 2c — Mythic Threads Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Phase 2b spec:** `docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md`.
**Slice of original Phase 2:** Mythic threads only. Mythic-event spotlight (random events targeting threads / factions / revelations) deferred to Phase 2d.

## Purpose

Add Mythic 2e–canonical thread tracking. Threads are the running list of unresolved questions a campaign accumulates as play unfolds — "the cult's plan", "Sariel's missing brother", "who is the knitting woman watching for?". The Mythic GME treats them as numbered, positional list items so random-event focus rolls ("Move Toward A Thread", "Move Away From A Thread") have a defined target. Phase 2c gives the engine that list and the open/close lifecycle that drives it. Phase 2d will then wire random-event focus rolls against thread positions.

## Definition of done

A successful Phase 2c build demonstrates all of:

- `dm/threads/active.md` exists with at least one seeded thread tied to session-003's loose-ends list (top candidate: the Mercer family of Brackenwood, three weeks absent from chapel service with an unreturned tinker's message).
- The mythic subagent gains `mcpServers: [dm-fs]` (currently empty) and three new query types (`open-thread`, `close-thread`, `list-threads`) layered on top of its existing oracle / event / chaos-factor responsibilities.
- New narrator routing rule 7 (Thread management) added to `CLAUDE.md` plus one new must-never bullet ("Never decide a thread is open or closed without invoking the mythic subagent").
- Smoke test (session-004) exercises the full lifecycle: at minimum, the narrator opens or closes a thread during real play, verified via the threads file, the session log, and the dm-fs access log.
- All 87 existing tests continue to pass; no Python code is added in this phase.
- Asymmetry boundary holds: narrator demonstrably never reads `dm/threads/` directly.

## Out of scope (deferred)

- **Mythic-event spotlight integration** — random events whose focus is "Move Toward A Thread", "Move Away From A Thread", "Current Context", or any thread-targeting variant rolling against thread positions. Phase 2d covers this end-to-end (it composes threads × factions × revelations × event focus into a unified spotlight system).
- Random-event-driven thread closure. Phase 2c's close mechanism is narrator-driven only.
- Thread-driven cadence at `/session-start` — no auto-listing of open threads as part of the session-start brief. Mirrors Phase 2b's on-demand pattern.
- Cross-thread relationships, thread hierarchies, thread-to-faction or thread-to-revelation links. Threads stay flat in 2c; richer composition lands in 2d's spotlight work.
- `/status threads` player-facing command — Phase 5 progression.
- Thread-driven downtime advancement (mentioned in `SPEC.md`'s downtime section). Phase 7.

## Architecture

### Slice mapping

| Component                          | Phase 2c touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | New routing rule 7 in `CLAUDE.md`. One new must-never bullet.                    |
| World-state subagent               | Untouched.                                                                       |
| Revelation subagent                | Untouched.                                                                       |
| **Mythic subagent**                | **MODIFIED** — frontmatter gains `mcpServers: [dm-fs]` and `Write` tool; prompt gains three new query types after the existing oracle/event/chaos blocks. |
| Dice subagent                      | Untouched.                                                                       |
| `dm-fs` MCP                        | No new ops. Phase 2a's `read_dm_file` / `list_dm_dir` / `write_dm_file` cover everything. The MCP is now wired into a third subagent (mythic), but `.mcp.json` already registers the server project-wide; only the per-subagent frontmatter needs updating. |
| `.claude/settings.json`            | No deny-rule changes.                                                            |
| `/session-start` command           | Untouched. No auto-thread-list at session-start.                                 |
| Other slash commands               | Untouched.                                                                       |
| Repository layout                  | New: `dm/threads/active.md` (single file, hand-authored at implementation time). |

### Information-asymmetry preservation

Same Phase 2a/2b shape. The narrator has no filesystem path to `dm/`. The mythic subagent reads and writes `dm/threads/` only via the dm-fs MCP. Adding a third subagent to the MCP doesn't expand the narrator's access — narrator still has no MCP. The dm-fs access log captures every mythic-subagent thread call, so the smoke-test asymmetry audit (grep the access log for non-subagent reads of `dm/`) extends naturally.

The Phase 2b spec flagged a future consideration: world-state's broad `dm/` read access overlapped with `dm/revelations/`. With threads now in dm/, world-state will likewise be able to read `dm/threads/`. The same disposition applies — meta-information surfacing is acceptable so long as full thread descriptions don't leak verbatim into narration. The question of tightening world-state's read scope remains a Phase 2d/2e+ concern.

### Integration with Phase 2a (factions) and Phase 2b (revelations)

Threads are independent of factions and revelations in Phase 2c. A thread might *describe* a faction's activity ("the Ashen Vintners' Crossroads Cup target arriving soon") or a revelation's question ("who is the knitting woman watching for?"), but no schema-level cross-link is enforced. If a thread happens to be answered when a revelation is delivered or a faction is discovered, the narrator invokes `close-thread` independently — the systems don't auto-coordinate.

Phase 2d will introduce the composition: random-event focus targeting threads, threads optionally tagging their referent faction/revelation for spotlight bookkeeping. That work is held out of 2c.

## Component designs

### Threads file schema (`dm/threads/active.md`)

```markdown
---
last-updated: <YYYY-MM-DD>
---

# Mythic Threads — Active

<!-- Open threads are numbered. The number is the canonical reference
     for Mythic 2e random-event "Move Toward A Thread" / "Move Away From
     A Thread" focus rolls (Phase 2d uses these numbers). Threads are
     listed in the order they were opened; new threads append. When a
     thread closes, it moves to ## Closed Threads at the bottom. -->

1. <thread description — 1-2 sentences>  *(opened: session NNN)*
2. <description>  *(opened: session NNN)*
3. ...

# Closed Threads

<!-- Append-only. Most recently closed at the bottom. -->

- ~~<thread description>~~  *(opened: session NNN, closed: session MMM — <one-line resolution>)*
```

Schema notes:

- **Open threads are a numbered Markdown list.** Numbers are positional and reassigned on close (when thread 2 closes, thread 3 becomes the new 2). Mythic's random-event spotlight rolls against current position, so positions must always reflect the live ordering.
- **Closed threads keep their original `opened` session for audit** but appear unnumbered in the Closed section. Strikethrough format (`~~text~~`) makes the visual distinction clear when the file is grep'd or eyeballed.
- **Length limit per thread:** 1-2 sentences. Mythic threads are short prompts, not full descriptions. Backstory and full context live in narrator memory or the session logs that surfaced the thread; the threads file is just the Mythic-canonical list.
- **`last-updated` frontmatter** is convenience for fast freshness checks (a session-start audit can compare it to the last session date).

### Mythic subagent extensions (`.claude/agents/mythic.md`)

Frontmatter updates:

```yaml
---
name: mythic
description: Resolves Mythic GME 2e oracle questions, random events, chaos factor adjustments, and Mythic threads CRUD.
tools: Read, Write, Edit, Bash
mcpServers: [dm-fs]
model: haiku
---
```

Changes from Phase 1:

- `description` mentions threads.
- `tools` adds `Write` (parallel to revelation agent's pattern — needed for creating `dm/threads/active.md` if it doesn't exist yet, and for constructing the full updated file content for `write_dm_file`).
- `mcpServers: [dm-fs]` is added (was empty).

The existing oracle, random-event, and chaos-factor procedures remain unchanged. Three new query types are added after them:

#### Query type 4: open-thread

> "Open thread: `<description>`. Active session log: `<path>`."

The caller provides a 1-2 sentence description and the session log path.

Procedure:

1. Call `read_dm_file("threads/active.md")` via the dm-fs MCP.
   - If the file doesn't exist: construct the schema header (frontmatter + `# Mythic Threads — Active` + empty list area + `# Closed Threads` + empty section) and proceed.
2. Parse the open-list (numbered list under `# Mythic Threads — Active`). Determine the next number (max existing + 1, or 1 if empty).
3. Append the new thread to the open list:
   ```
   N. <description>  *(opened: session NNN)*
   ```
   where NNN is the session number derivable from the active session log path.
4. Update `last-updated` frontmatter to today's date.
5. Call `write_dm_file("threads/active.md", <full updated file content>)`.
6. Append to the active session log via the `Edit` tool:
   ```
   - MYTHIC THREAD: opened #N — <description>
   ```
7. Return `{thread_number: N, description}`.

#### Query type 5: close-thread

> "Close thread #N. Resolution: `<one-line summary>`. Active session log: `<path>`."

Procedure:

1. Call `read_dm_file("threads/active.md")`.
2. Find thread N in the open list. If not found, return `{error: "no open thread #N"}` and log the failure.
3. Construct the updated file:
   - Remove thread N from the open list.
   - Renumber remaining open threads so the list stays 1, 2, 3, ... contiguous.
   - Append the closed entry to `# Closed Threads`:
     ```
     - ~~<original description>~~  *(opened: session NNN, closed: session MMM — <resolution>)*
     ```
4. Update `last-updated`.
5. `write_dm_file("threads/active.md", <full updated file content>)`.
6. Append to the active session log:
   ```
   - MYTHIC THREAD: closed #N — <description> — <resolution>
   ```
7. Return `{closed_thread_number: N, description, resolution, renumbered: true|false}` where `renumbered` is true iff at least one open thread was renumbered.

#### Query type 6: list-threads

> "List threads. Active session log: `<path>`."

Procedure:

1. Call `read_dm_file("threads/active.md")`. If file doesn't exist, return `{open: [], closed_count: 0}`.
2. Parse open list and Closed section.
3. Return `{open: [{number, description, opened_session}, ...], closed_count: N}`.
4. Append to the active session log:
   ```
   - MYTHIC THREAD: list — <K> open, <N> closed
   ```

### Edge cases

- **`dm/threads/active.md` doesn't exist on first open-thread.** Create it with the schema header.
- **`dm/threads/active.md` doesn't exist on close-thread or list-threads.** Return error / empty result respectively. Don't create on read.
- **close-thread with N out of range.** Return `{error: "no open thread #N"}`.
- **close-thread when N is the only open thread.** Open list becomes empty; Closed section gains the entry. Renumbering trivially succeeds.
- **Thread description is too long (>2 sentences).** Phase 2c does not enforce a length limit at the agent level — authoring discipline. Future phases may lint.
- **Two threads opened in rapid succession with same description.** Allowed; numbered separately. Authoring concern, not a runtime fault.
- **Active session log path is empty or invalid.** The thread operation still succeeds (the file write is the source of truth), but the session-log line write fails. Log an error to the dm-fs access log; return success.
- **Agent's `Edit` tool used on `dm/`.** Same as Phase 2a/2b: forbidden. The mythic subagent's "what you don't do" list gains a bullet enforcing this.

### CLAUDE.md routing rule 7

Inserted after rule 6 (Revelation routing), before `## Session log conventions`:

> ### 7. Thread management
>
> When play surfaces a question, mystery, or unresolved situation worth tracking — at scene transitions, at session-end loose-end review, or mid-scene when something concrete leaves a hanging beat — invoke the mythic subagent with "Open thread: `<1-2 sentence description>`. Active session log: `<path>`." The subagent appends a numbered thread to `dm/threads/active.md` and returns its number.
>
> When play resolves a previously-opened thread — the question gets answered, the missing person turns up, the cult plot completes — invoke "Close thread #N. Resolution: `<one-line summary>`. Active session log: `<path>`."
>
> To recall what threads are open mid-scene, invoke "List threads. Active session log: `<path>`."
>
> You do not author thread content yourself or directly edit `dm/threads/`. Threads emerge from play and are persisted only via the mythic subagent.

Plus a new must-never bullet:

> - Never decide a thread is open or closed without invoking the mythic subagent — the audit trail in `dm/threads/active.md` is the source of truth.

### Repository layout (Phase 2c additions)

```
gygaxagain/
├── .claude/agents/
│   └── mythic.md                # MODIFIED: mcpServers + Write + three new query types
├── dm/threads/
│   └── active.md                # NEW — hand-authored at implementation time
└── CLAUDE.md                    # rule 7 added; one new must-never bullet
```

No `world/threads/` (threads are entirely DM-side; the player learns of them only via narrator weaving open thread descriptions into narration when contextually natural). No new dm-fs MCP tools. No new Python.

### Seeded threads (content authoring)

Implementation-time seeding from session-003's loose-ends list. Strong primary candidate:

- **The Mercer family of Brackenwood** — six souls (matriarch Hanna and her boys), three weeks absent from chapel service. A tinker's message went out and never returned. Concrete, named, surfaces during chapel scene in 003, plausibly investigable in future sessions.

Optional second seed (stretch goal during the same relaxed-denies window):

- **Whatever Ravenna is waiting for at the front door of the Stallion** — open since session 001's establishing scene; reinforced in session 002's tells.

The implementation will seed at minimum the Brackenwood thread; the second is added if it fits cleanly.

## Smoke test for Phase 2c

### Primary smoke test — session-004 end-to-end

Real-session-004 play exercises the full thread lifecycle:

1. With `dm/threads/active.md` populated by Task 3's seeding (at minimum the Brackenwood-Mercer thread at position #1), the user runs `/session-start`.
2. Phase 2a's offscreen-developments tick fires for the Ashen Vintners. Phase 2b's revelation system stays available for clue surfacing. The narrator can additionally invoke `list-threads` if it wants a refresher mid-scene.
3. During play, the narrator either:
   - **Closes the seeded thread** if play resolves it (Dagnal investigates Brackenwood, finds the Mercer family alive or dead — either way the question is answered).
   - **Opens a new thread** if play surfaces something genuinely worth tracking (e.g., Dagnal commits to going south to find the Mercers; a new mystery emerges from Aldous's roads question).
4. Either operation routes through the mythic subagent. The subagent appends to the session log and updates `dm/threads/active.md` via the dm-fs MCP.
5. `/session-end` commits.

**Pass criteria:**
- `dm/threads/active.md` shows at least one mutation across the session — either an opened thread, a closed thread, or both.
- Session-004 log contains `- MYTHIC THREAD: ...` lines for each operation.
- The dm-fs access log shows the mythic subagent's new MCP calls (`read_dm_file threads/active.md`, `write_dm_file threads/active.md`).
- Asymmetry held: no narrator tool-use directly accessed `dm/threads/`.
- Phase 2a's offscreen tick still fires correctly (no regression). Phase 2b's revelation querying still works if the scene calls for it.

### Secondary smoke test — scaffolded (optional)

If real-session-004 doesn't naturally produce a thread lifecycle event (e.g., the player wanders into entirely new territory), a scaffolded fallback: the narrator invokes `open-thread` and `close-thread` directly with synthetic descriptions, verifies the file mutations and log lines, then immediately reverses (closes the synthetic thread) so the file state stays clean for future play.

### Asymmetry audit

Same as prior phases: grep session-004's tool-use trace and the dm-fs access log for any narrator-issued tool call touching `dm/`. There must be none. Mythic, world-state, and revelation subagents are the sole `dm/` accessors after Phase 2c lands.

## Failure modes Phase 2c must handle

- **`dm/threads/active.md` malformed.** Mythic subagent's parse fails on open or close. Return an error, log it, do not partially mutate. The file's previous state remains canonical.
- **Concurrent thread operations within a single session.** Sequential by design — each subagent invocation completes before the next begins.
- **Thread number drift between narrator memory and file state.** If the narrator says "close thread #3" referring to its older mental model but #3 has since shifted (e.g., #2 closed earlier in the same session, renumbering), close-thread targets the current #3 — which may be the wrong one. Mitigation: rule 7 instructs the narrator to invoke `list-threads` to refresh before close operations when uncertain. Phase 4 bookkeeper will harden this.
- **Description with embedded punctuation that breaks markdown numbered list parsing.** The agent constructs the file content; it should escape or accept the description as-is. If a description contains literal markdown (e.g., a numeric prefix), it goes verbatim — discipline gap rather than runtime fault.
- **Renumbering preserves opened-session metadata.** When thread 3 becomes thread 2, its `*(opened: session NNN)*` stays attached. Confirmed in close-thread procedure.

## Open questions resolved during brainstorming

- **Slicing of original Phase 2:** Phase 2c covers Mythic threads CRUD + lifecycle only. Spotlight integration → Phase 2d.
- **Storage shape:** Single file `dm/threads/active.md` (decision A) — matches Mythic 2e canon and the original SPEC; threads are list-shaped, not document-shaped.
- **Subagent design:** Extend the existing mythic subagent (no new agent). Mythic owns oracle/event/chaos already; threads are part of the same Mythic procedure family.
- **Lifecycle:** Open / closed binary. No "withdraw," no "promote," no "merge."
- **Authoring at runtime:** Narrator-driven open/close mid-play. No auto-opens from random events (deferred to 2d).
- **Auto-list at `/session-start`:** No. On-demand only, mirroring Phase 2b's revelation pattern.
- **Renumbering on close:** Yes. Open list always reads 1, 2, 3, ... contiguous. Required for Phase 2d's spotlight rolls to have a defined target distribution.
- **MCP tool changes:** None needed. Phase 2a's read/list/write/append cover Phase 2c.
- **Closed thread retention:** Append-only with strikethrough. No deletion.
- **Cross-cutting integration with factions and revelations:** Threads are independent in 2c. Cross-references emerge in narrator-authored thread descriptions but no schema-level link.

## Phase 2c → Phase 2d handoff

Phase 2c's exit unlocks Phase 2d (Mythic-event spotlight integration), which composes:

- The mythic CLI's existing random-event detection (a roll on the Chaos range during fate-chart resolution surfaces a `{focus, action, subject}` triple).
- The Phase 2c thread list — when focus is "Move Toward A Thread", "Move Away From A Thread", or "PC Thread", the agent rolls against the current open thread positions to pick a target.
- The Phase 2a faction list — when focus is "NPC Action", "PC Negative", or appropriate variants, the agent may target a faction's clock for an extra tick.
- The Phase 2b revelation list — when focus is "Discover" or "Investigate", the agent may surface a clue from the revelation list as if the narrator queried could-land.

Phase 2d will likely introduce a new mythic CLI subcommand or integrate spotlight resolution into the existing `oracle` command's response. The threads file structure from 2c is the substrate it builds on.

## Roadmap context

Phase 2c sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete)*
4. **Phase 2c — Mythic threads.** *(this design)*
5. **Phase 2d — Mythic-event spotlight integration.**
6. **Phase 3 — Source ingestion.** `/intake`, librarian, secret-quarantine logic.
7. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals, content authoring formalization.
8. **Phase 5 — Progression.** Milestones, `/level-up`, `/status` family including threads.
9. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
10. **Phase 7 — Downtime, banking, bastions.**

Phase 2c's scope is what's locked here.
