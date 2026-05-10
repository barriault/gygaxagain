# Phase 2b — Revelations Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Slice of original Phase 2:** revelations only. Mythic threads deferred to Phase 2c. Mythic-event spotlight (factions × events × threads) deferred to Phase 2d.

## Purpose

Enable Alexander-style revelation tracking with the three-clue rule running mid-scene. After Phase 2b, when the narrator hits a moment in play that could plausibly surface a clue — entering a location, an NPC dialogue beat, an investigation move — they query the revelation subagent for plausibly-deliverable clues, weave one into narration if the scene fits, and confirm delivery once the player has engaged. Each pending revelation accumulates ≥3 distinct clue vectors so it has multiple chances to land regardless of which path the player takes.

Phase 2b is the parallel revelation system per the brainstorming decision: faction discovery (Phase 2a) is left untouched and continues to handle "the party learns the faction's existence by name." Revelations cover everything else — NPC secret allegiances, location hidden purposes, plot mysteries, situational facts — that don't naturally live on a faction sheet.

## Definition of done

A successful Phase 2b build demonstrates all of:

- One seeded revelation exists at `dm/revelations/<id>.md`, tied to existing campaign content (Ravenna, Amphail, the chapel, session-002's knitting woman, or the Brackenwood-folk thread) and **distinct** from the Ashen Vintners faction (so the parallel-system claim is exercised end-to-end).
- The seeded revelation has three or more clue vectors with genuinely different scopes (different locations, NPCs, or investigation moves).
- A new `revelation` subagent at `.claude/agents/revelation.md` answers three query types (could-land / confirm / has-been-delivered) per its system prompt.
- The narrator's `CLAUDE.md` gains a routing rule 6 instructing it to query the revelation subagent at scene moments matching a clue's scope and confirm delivery only when the player engages.
- A smoke test exercises the full flow: query → narrate hook → confirm → verify file updates.
- `dm-fs` MCP tools require **no changes** — Phase 2a's `read_dm_file`, `list_dm_dir`, `write_dm_file`, `append_dm_file` cover all 2b reads and writes.
- All 87 existing tests continue to pass; no Python code is added in this phase.
- Narrator demonstrably never reads `dm/revelations/` directly — verified via tool-use trace and the `dm-fs` access log.

## Out of scope (deferred to later phases)

- Mythic threads (Phase 2c).
- Mythic-event spotlight integration with factions and threads (Phase 2d).
- `/status revelations` player-facing summary command — deferred to Phase 5 (progression tracking) where it pairs with milestone-status surfacing.
- `/intake`-driven revelation authoring from module material (Phase 4).
- Bookkeeper verification of clue-delivery decisions (Phase 4).
- Cross-revelation dependencies — e.g., revelation B is gated on revelation A. Phase 2b treats each revelation as independent; if play needs gating, the user can add it as narrative discipline.
- Player-driven revelation insertion mid-campaign — revelations are author-time content, not runtime.
- Linking revelations to factions structurally. If a future revelation happens to mention a faction in its prose, that's fine, but no schema-level link is added.

## Architecture

### Slice mapping

| Component                          | Phase 2b touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | New routing rule 6 in `CLAUDE.md`. One new must-never bullet.                    |
| World-state subagent               | Untouched.                                                                       |
| Mythic subagent                    | Untouched (threads land in Phase 2c).                                            |
| Dice subagent                      | Untouched.                                                                       |
| **Revelation subagent**            | **NEW** — `.claude/agents/revelation.md`.                                        |
| `dm-fs` MCP                        | No changes. Read/list/write/append from Phase 2a are sufficient.                 |
| `.claude/settings.json`            | No deny-rule changes.                                                            |
| `/session-start` command           | Untouched. Revelation queries are mid-scene, not session-start.                  |
| Other slash commands               | Untouched.                                                                       |
| Repository layout                  | New: `dm/revelations/<id>.md` for the seeded revelation. `dm/revelations/` is empty until 2b lands. |

### Information-asymmetry preservation

Phase 2a's boundary holds without modification. Adding a new subagent that uses the existing `dm-fs` MCP doesn't expand the narrator's surface area — narrator still has zero filesystem path to `dm/`, and the new revelation subagent reads `dm/revelations/` only via the same MCP. The narrator queries the revelation subagent with structured prompts, gets back observable-only content (clue hook text the player can perceive), and weaves it into narration. The revelation list itself, the unrevealed clue vectors, and the delivered-tracking log never enter the narrator's context.

The dm-fs access log added in Phase 2a continues to capture every revelation-subagent call, so the smoke-test asymmetry audit (grep the access log for non-world-state, non-revelation accesses to `dm/`) extends naturally.

### Integration with Phase 2a

Faction discovery (Phase 2a's `## Discovery` block on faction files) remains the canonical mechanism for "the party learns this faction exists by name." Revelations cover everything else and do not need to know about factions. If a revelation's hook text happens to mention a faction by name, that's a content authoring choice — no schema-level cross-link.

There is one composability note worth flagging for future phases: the same session log could simultaneously trigger faction-discovery (in 2a's offscreen tick at session-start) and revelation-clue-delivery (in 2b's mid-scene routing). These are independent operations writing to different `dm/` files; no coordination is needed.

## Component designs

### Revelation file schema (`dm/revelations/<id>.md`)

```markdown
---
id: r-001
title: <revelation title — narrator-internal phrasing, never surfaced verbatim>
status: pending | delivered | retired
clue-count: 3
---

# <Title>

## Revelation

<The hidden fact players need to learn. 1-3 sentences. Narrator-internal phrasing — describes the answer, not how it's revealed.>

## Clue vectors

- **c-001a** — <scope tag>: <pre-authored hook text describing how this clue lands when surfaced>
- **c-001b** — <scope tag>: <hook text>
- **c-001c** — <scope tag>: <hook text>
- ... (three minimum, more allowed)

## Delivered

<!-- Append-only. The revelation subagent writes here when the narrator confirms a clue landed. Each entry: "- session NNN, YYYY-MM-DD: clue <id> — <one-line context>" -->
```

Schema notes:

- **ID convention.** Revelations are `r-001`, `r-002`, ... Clues are `c-001a`, `c-001b`, `c-001c`, ... — revelation-prefixed, no global counter. The user/author picks the next `r-NNN` at authoring time; clue letters are always `a`, `b`, `c`, ... in order.
- **`clue-count` frontmatter.** A redundant integer that lets the agent quickly check three-clue-rule discipline without parsing the body. Authors update it when adding/removing clue vectors. The agent warns (does not refuse) if `clue-count < 3`.
- **Scope tag.** Free-form short text (1-6 words) describing where/when/with-whom this clue would naturally surface. Examples: "the chapel," "any conversation with the Curate," "Ravenna's room," "investigating Brackenwood." The agent matches caller scopes against these tags using LLM judgment, the same way the world-state agent matches engagement triggers in 2a.
- **Hook text.** A 1-2 sentence prose fragment the narrator can use as a starting point when narrating the clue landing. Treated as a *seed* — the narrator paraphrases and contextualizes; the agent does not require verbatim copy.
- **`status: delivered`** flips the first time *any* clue for the revelation lands. Subsequent clues (if the narrator surfaces them later for thematic reinforcement) are still appended to `## Delivered`, but `status` doesn't transition further.
- **`status: retired`** is for revelations the campaign has moved past — neither delivered nor relevant. Phase 2b doesn't need it for the smoke test, but the schema supports it for forward compatibility.

### Revelation subagent (`.claude/agents/revelation.md`)

Frontmatter:

```yaml
---
name: revelation
description: Owns the revelation list and clue-delivery tracker per Alexander's three-clue rule. Always invoked when a scene moment could plausibly surface a clue or when the narrator confirms a clue landed in play.
tools: Read, Write, Edit
mcpServers: [dm-fs]
model: sonnet
---
```

The subagent's system prompt instructs:

#### Read access

- `world/`, `party/`, `sessions/` — readable.
- `dm/revelations/` — readable **only** through the `dm-fs` MCP. No direct filesystem reads of `dm/` are permitted.
- Other `dm/` paths — not in scope. The revelation subagent doesn't read faction files, NPC hidden sheets, or threads.

#### Contract

The revelation subagent is a **one-way valve** for the revelation list. It returns hook text the narrator can weave into prose; it never returns raw revelation phrasing or unrevealed clue vectors that don't match the queried scope. It records confirmed deliveries to `## Delivered` and updates frontmatter `status` accordingly.

#### Three query types

**Query 1 — could-land:**

> "What revelations could land in `<scope>`?"

Procedure:
1. `list_dm_dir("revelations")` to enumerate revelation files.
2. For each `r-NNN.md`, `read_dm_file("revelations/r-NNN.md")`. Skip if `status` is not `pending`.
3. Read `## Clue vectors`. Match each clue's scope tag against the caller-supplied scope using judgment — same LLM-interpretation pattern as world-state's NPC-behavior queries and engagement-trigger matching.
4. Collect all matching clues. For each, return `{revelation_id, clue_id, hook_text}`.
5. If the revelation has `clue-count < 3`, prepend a warning annotation: `[warning: revelation r-NNN has only N clue vectors — three-clue rule recommends ≥3]`.
6. Return the list (possibly empty).
7. Append a session-log line: `- REVELATION QUERY: could-land in <scope> — <K> clues from <M> revelations`.

**Query 2 — confirm:**

> "Confirm clue `<clue_id>` delivered. Context: `<one-line narrative summary>`."

Procedure:
1. Determine the parent revelation: `r-NNN` from the clue id `c-NNNa/b/c`.
2. `read_dm_file("revelations/r-NNN.md")` to fetch current state.
3. Construct the updated file: flip frontmatter `status: pending → delivered` (only if currently pending — idempotent), preserve all body sections.
4. `write_dm_file("revelations/r-NNN.md", <updated content>)` to persist the status change. Do **not** include the new `## Delivered` line in this payload.
5. `append_dm_file("revelations/r-NNN.md", "- session NNN, YYYY-MM-DD: clue <clue_id> — <context>\n")` to add the audit-trail line.
6. Return: `{revelation_id, clue_id, status_after_write, was_first_delivery: true|false}`.
7. Append a session-log line: `- REVELATION QUERY: confirm clue <clue_id> for r-NNN — <new status>`.

**Query 3 — has-been-delivered:**

> "Has revelation `<r_id>` been delivered?"

Procedure:
1. `read_dm_file("revelations/<r_id>.md")`.
2. Return `{status, delivered_via_clue_ids: [list], session_NNN_first_delivered}` from the `## Delivered` section.
3. Append a session-log line: `- REVELATION QUERY: status of <r_id> — <status>`.

#### Edge cases

- **No revelations exist.** Query 1 returns empty list; queries 2 and 3 return errors ("no such revelation").
- **Clue id doesn't match any revelation.** Query 2 returns an error; the narrator must surface a different clue or skip.
- **Clue id matches but is for an already-delivered revelation.** Query 2 still appends the line (a revelation can be reinforced multiple times); status stays `delivered`; `was_first_delivery` is false.
- **Revelation has fewer than 3 clue vectors.** Query 1 returns the matching clues with the warning annotation. The narrator passes the warning to the session log so the user can see the discipline gap.
- **Scope match is ambiguous.** Default to inclusive — return any clue whose scope plausibly fits. The narrator decides whether to use it.
- **`Edit` tool denied on `dm/`.** Mirroring world-state's contract: `dm/` mutations flow through `write_dm_file`/`append_dm_file` only.

#### What the revelation subagent doesn't do

- Doesn't author revelations or invent clue vectors at runtime — content is authored at design time.
- Doesn't decide whether a clue has actually been delivered — the narrator confirms based on player engagement.
- Doesn't write to faction files, NPC sheets, threads, or any `dm/` path outside `dm/revelations/`.
- Doesn't return raw revelation phrasing (the `## Revelation` body) verbatim. Hook text from `## Clue vectors` is the surface; the underlying answer stays hidden until the narrator weaves clue text into prose and the player puts the pieces together themselves.

### CLAUDE.md routing rule 6

Inserted after rule 5 (Offscreen developments), before `## Session log conventions`:

> ### 6. Revelation routing
>
> When a scene moment could plausibly surface a clue — entering a location, an NPC dialogue beat, an investigation move by the player — invoke the revelation subagent with "What revelations could land in `<scope>`?" providing a 1-6 word scope tag describing the moment. The agent returns matching clue options. Choose at most one to weave into narration; treat the hook text as a starting point, not verbatim copy. Do not surface multiple clues for the same revelation in the same scene unless the player has explicitly investigated multiple angles.
>
> When a clue lands in play (the player engaged with the surfaced detail in dialogue, action, or investigation), invoke "Confirm clue `<clue_id>` delivered. Context: `<one-line narrative summary>`." Do not confirm clues the player walked past without engaging.
>
> You do not author revelations or clue vectors at runtime. The revelation list is `dm/`-only content authored ahead of play. If a scene begs for a revelation that doesn't exist yet, note it under `## Notes for later phases` in the session log; the user or a later phase's authoring pipeline (Phase 4 librarian/intake) will add it.

Plus a new must-never bullet:

> - Never decide a revelation is delivered without confirming via the revelation subagent — the audit trail in `## Delivered` is the source of truth.

### Repository layout (Phase 2b additions)

```
gygaxagain/
├── .claude/agents/
│   └── revelation.md                 (NEW)
├── dm/revelations/
│   └── <seed-id>.md                  (NEW — hand-authored during implementation)
└── CLAUDE.md                         (rule 6 added; one new must-never bullet)
```

`dm/revelations/.gitkeep` is unnecessary because the seeded revelation file is created during implementation. No `world/revelations/` is created — revelations don't have a "discovery promotes a public stub" pattern; clue delivery in narration is itself the surface.

### Seeded revelation (content authoring)

Drafted at implementation time, with the lore choice made by the assistant from existing campaign cues. Constraints:

- **Distinct from the Ashen Vintners faction discovery.** This is the design-level claim that revelations and faction discovery are parallel systems; the seed must exercise it.
- **Tied to existing campaign content.** Candidates surfaced in session-002 narrative: the knitting woman who flickered attention to the High Road grumble; the Brackenwood-folk thread (party from Brackenwood haven't been to market in three weeks); the Curate of Amphail's chapel; the green-cloaked farmer.
- **Three genuinely different clue vectors.** Different scopes — different locations, different NPCs, different investigation moves. Discipline is demonstrated, not just claimed.
- **Plausibly investigable in 1-2 sessions of play.** Not campaign-defining; testbed-scale.

The lore is finalized during implementation; this design only commits to the structural constraints above.

## Smoke test for Phase 2b

### Primary smoke test — real session-003 end-to-end

1. With the seeded revelation in place at `dm/revelations/<id>.md` (status: pending), the user runs `/session-start`.
2. Phase 2a's offscreen-developments tick fires for the Ashen Vintners faction (now at clock 1/6 from session-002, so this run advances to 2/6 unless an engagement trigger matches). World-state surfaces the appropriate ladder rung.
3. The narrator narrates the opening scene. Mid-scene, the player engages with a beat that matches one of the seeded revelation's clue scopes (e.g., asks about the knitting woman, visits the chapel, asks about Brackenwood).
4. Narrator invokes the revelation subagent: `"What revelations could land in <matching scope>?"`
5. Revelation subagent returns `{revelation_id, clue_id, hook_text}` for the matching clue.
6. Narrator paraphrases the hook text into narration appropriate to the moment. Player engages.
7. Narrator invokes `"Confirm clue <clue_id> delivered. Context: <one-line narrative>."`
8. Revelation subagent updates `dm/revelations/<id>.md`: frontmatter `status: pending → delivered`, appends `- session 003, YYYY-MM-DD: clue <clue_id> — <context>` to `## Delivered`. Logs `REVELATION QUERY` lines to the active session log.
9. Free-form continuation; `/session-end` commits.

**Pass criteria:**
- The seeded revelation file's frontmatter `status` flipped from `pending` to `delivered`.
- The `## Delivered` section gained one line with the correct clue id and session number.
- The session log contains one `REVELATION QUERY: could-land` line and one `REVELATION QUERY: confirm` line.
- The dm-fs access log shows `list_dm_dir → read_dm_file → write_dm_file → append_dm_file` against `revelations/` paths.
- The narrator never directly accessed `dm/revelations/` — verifiable via tool-use trace.
- The Ashen Vintners faction state advanced normally per Phase 2a's offscreen tick (no regression).

### Secondary smoke test — scaffolded (optional)

If real-session play is impractical for any reason, a scaffolded variant: dispatch the revelation subagent directly with a synthetic could-land query against a stubbed scope, verify the response, then a synthetic confirm against the returned clue id, verify the file mutations and session-log lines. Less narrative, faster validation. Use only if the primary smoke test isn't feasible.

### Asymmetry audit

Same as Phase 2a: grep the session-003 tool-use trace and the `dm-fs` access log for any narrator-issued tool call touching `dm/`. There must be none. Revelation, world-state, and (Phase 2c+) mythic-thread queries are the sole `dm/` accessors.

## Failure modes Phase 2b must handle

- **Revelation file frontmatter malformed.** Subagent skips that revelation in could-land queries; logs a warning in the session log; continues with other revelations.
- **Clue id syntactically valid but doesn't match any revelation.** Confirm-delivery query returns an error; narrator reports the failure to the player rather than silently fabricating a confirmation.
- **Narrator surfaces a clue but the player doesn't engage.** No confirm call fires. The revelation stays pending; the same clue can be re-surfaced in a later scene if the scope matches again.
- **Multiple matching clues for the same scope.** Subagent returns all matches. Narrator chooses one (or none) per scene per revelation.
- **Revelation already delivered when narrator surfaces a clue.** Subagent's could-land filter skips delivered revelations by default. If the narrator queries for an already-delivered revelation explicitly via has-been-delivered, the subagent returns the status.
- **Three-clue-rule discipline violation (clue-count < 3).** Subagent returns warning annotation; narrator passes it through to the session log. The user sees the gap and can author additional clues out-of-band before the next session.
- **Hook text leaks the revelation phrasing.** This is an authoring discipline issue — the `## Revelation` body is narrator-internal phrasing, but if a clue's hook text quotes it directly, the player learns too much too early. Convention: hook text describes how the player perceives the clue, not what the underlying answer is. Phase 4 bookkeeper authoring tooling will lint for this; Phase 2b relies on author discipline.

## Open questions resolved during brainstorming

- **Slicing of original Phase 2:** Phase 2b covers revelations only. Mythic threads → Phase 2c. Mythic-event spotlight → Phase 2d.
- **Relationship to faction discovery:** Parallel systems (decision β). Phase 2a's faction discovery is unchanged; revelations cover everything else.
- **Subagent design:** New `revelation` subagent (decision A), separate from world-state. Tighter responsibility per agent yields better LLM behavior; pattern mirrors world-state's role in 2a.
- **File layout:** Per-revelation files at `dm/revelations/<id>.md` (decision A), mirroring 2a's per-faction file pattern. Single-file `list.md`+`delivered.md` rejected as predating 2a's empirical pattern.
- **Query timing:** On-demand mid-scene (decision B), not auto at session-start. Matches world-state NPC-behavior pattern; keeps `/session-start` cheap.
- **Three-clue rule discipline:** Soft warning (recommendation), not hard error. Authors can iterate; agent surfaces gap to session log.
- **Player-facing summary (`/status revelations`):** Deferred to Phase 5.
- **MCP tool changes:** None needed. Phase 2a's read/list/write/append cover Phase 2b.

## Phase 2b → Phase 2c handoff

Phase 2b's exit unlocks Phase 2c (Mythic threads): extension of the existing mythic subagent, `dm/threads/active.md`, open/close lifecycle, integration with the mythic CLI's random-event detection (currently the CLI returns event triples but no thread targeting). Phase 2d then composes threads × factions × revelations into the Mythic-event spotlight (e.g., a random event can promote a faction's clock or surface a clue for a pending revelation).

The revelation system in 2b is the substrate Phase 2d builds on — Mythic events with focus matching a pending revelation's scope can prompt the narrator to invoke the revelation subagent automatically.

## Roadmap context

Phase 2b sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(this design)*
4. **Phase 2c — Mythic threads.**
5. **Phase 2d — Mythic-event spotlight integration.**
6. **Phase 3 — Source ingestion.** `/intake`, librarian, secret-quarantine logic.
7. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals, revelation authoring formalization.
8. **Phase 5 — Progression.** Milestones, `/level-up`, `/status` family including revelations.
9. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
10. **Phase 7 — Downtime, banking, bastions.**

Phase 2b's scope is what's locked here.
