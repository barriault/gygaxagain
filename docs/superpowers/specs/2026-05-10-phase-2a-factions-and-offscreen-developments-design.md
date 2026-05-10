# Phase 2a — Factions and Offscreen Developments: Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Slice of original Phase 2:** factions and offscreen developments only. Revelations and full Mythic-thread machinery deferred to Phase 2b/2c.

## Purpose

Make the world *move while the party isn't looking*. After Phase 2a, `/session-start` surfaces real, hidden-state-driven offscreen developments — rumors and observable consequences that build pressure as authored faction operations advance toward resolution. The narrator never sees the underlying clocks or operations; the world-state subagent translates them into narrative surface that the narrator weaves into the opening scene.

## Definition of done

A successful Phase 2a build demonstrates all of:

- One seeded faction exists at `dm/factions/<slug>.md`, tied to Ravenna's session-001 tells (chemical stains, herbal smell, unnatural cold, blade-grip calluses, door-watching). This keeps the testbed campaign coherent.
- The seeded faction has identity + one active operation + a clock + a four-rung observable-consequences ladder + engagement triggers + a discovery trigger + a clock-filled beat.
- `/session-start` reliably runs the offscreen tick: world-state advances the clock per the player-action-sensitive cadence, fires the matching ladder rung, optionally creates the public stub on discovery, persists state via the `dm-fs` MCP.
- The narrator weaves the surface text into the opening scene without naming undiscovered factions.
- The `dm-fs` MCP exposes new write tools (`write_dm_file`, `append_dm_file`, `create_dm_file`) constrained to `dm/`.
- The `dm-fs` MCP records all read and write calls to an access log at `tools/dm-fs-mcp/access.log` (Phase 1 deferred this; 2a commits to it).
- The narrator demonstrably never reads `dm/factions/`, `dm/npcs/`, or any other hidden state directly. The asymmetry boundary in `.claude/settings.json` remains intact.
- A second smoke-test session (session-002) runs end-to-end, exercising the new offscreen-developments flow.
- A scaffolded high-tier validation confirms mid- and high-tier rungs surface correctly without requiring four real sessions.

## Out of scope (deferred to later phases)

- Revelations and three-clue rule (Phase 2b).
- Full Mythic thread machinery (Phase 2b).
- Mythic-event spotlight of factions — random events promoting a faction's clock (Phase 2c).
- Multiple concurrent operations per faction. The schema accommodates one active operation; extending to N is a future schema change.
- Faction reputation tracking, faction-vs-faction relationships, faction-driven combat encounters.
- Automatic chained operations after a clock fills with a "next op TBD" handoff. Phase 2a supports `dormant` and `retired` post-op states only.
- Bookkeeper verification of faction state changes (Phase 4).
- User-facing authoring pipeline for new factions — `/intake`, librarian, structured seeding (Phase 4).

## Architecture

### Slice mapping

| Component                          | Phase 2a touches                                                                                       |
|------------------------------------|--------------------------------------------------------------------------------------------------------|
| Narrator (main agent)              | One new routing rule in `CLAUDE.md`. Otherwise unchanged.                                              |
| World-state subagent               | Replace Phase 1 stub for "offscreen changes" with the full tick procedure. Add discovery write flow.   |
| Dice subagent                      | Untouched.                                                                                             |
| Mythic subagent                    | Untouched in Phase 2a. Mythic-event spotlight integration deferred to 2c.                              |
| `dm-fs` MCP                        | Add three write tools. Read tools unchanged.                                                            |
| `.claude/settings.json`            | No deny-rule changes. Narrator's `dm/**` denies stay in place.                                         |
| `/session-start` command           | Fill in step 4 (offscreen developments query) — currently a stub.                                      |
| `/session-end`, `/roll`, `/ask-oracle` | Untouched.                                                                                          |
| Repository layout                  | New: `dm/factions/`, `world/factions/` (latter empty until first discovery).                          |
| `meta/` config files               | No changes.                                                                                            |

### Information-asymmetry preservation

The boundary added in Phase 1 holds: narrator has no path to `dm/`. Phase 2a expands what *flows through the existing boundary* but does not weaken it.

- The new write tools live on the `dm-fs` MCP and are scoped to `dm/`. Only the world-state subagent has the MCP wired in. The narrator has no MCP.
- The narrator's `dm/**` denies in `.claude/settings.json` stay in place: the narrator cannot read, write, edit, glob, grep, cat, or otherwise touch `dm/`.
- Public-stub creation on discovery writes to `world/factions/<slug>.md` — within the world-state subagent's existing `world/` write access. No new permission surface for that path.
- The `.gitignore` and project structure don't change in any narrator-visible way.

## Component designs

### Faction file schema (`dm/factions/<slug>.md`)

```markdown
---
name: <Faction Name>
slug: <slug>
status: active | dormant | retired
discovered: false
known-as: null
clock-max: 6
---

# <Faction Name>

## Identity
<!-- Persistent. What this faction is and what it wants. -->

- Agenda: <1-2 sentence summary of their objective>
- Methods: <how they typically operate>
- Sphere of influence: <where in the world they reach>
- Linked NPCs:
  - <slug> — <one-line relationship note>
  - ...

## Active operation
<!-- Phase 2a supports exactly one active operation. -->

- Name: <op name>
- Goal: <1-sentence concrete objective>
- Clock: <current>/<max>
- Started: session <NNN>, <YYYY-MM-DD>

## Observable consequences ladder
<!-- World-state picks the rung matching the post-tick clock value. -->

- Low (1-2/6): <ambient atmosphere — barely noticeable>
- Mid (3-4/6): <concrete rumors — clearly being talked about>
- High (5/6):  <direct evidence — something the party can investigate>
- Full (6/6):  <see "On clock filled" below>

## Engagement triggers
<!-- World-state matches these against the prior session log narrative.
     Default if none match: clock += 1 (tick advances). -->

- <Trigger pattern in plain language>: <effect — "hold clock this session" or "tick -1">
- ...

## Discovery
<!-- The condition under which the faction becomes named to the party.
     World-state checks this on each tick. -->

- Trigger: <what specific event/clue surfaces the faction by name>
- On match: world-state creates `world/factions/<slug>.md` populated from the discovery template (see below); sets frontmatter `discovered: true`, `known-as: <Faction Name>`.

## On clock filled
<!-- Fires when clock reaches max. -->

- Beat: <major narrative event hitting the home base when the operation resolves>
- Post-op state: dormant | retired
  - dormant: faction stays on file, no tick, no surface — until later content reactivates it.
  - retired: faction is done; status flips to `retired`.

## History
<!-- Append-only audit trail. World-state writes every tick decision here. -->

- session <NNN>, <YYYY-MM-DD>: <one-line event>
```

**Schema notes:**

- Frontmatter `clock-max: 6` is per-faction; default 6 follows the Blades-in-the-Dark progress-clock convention common in solo RPG design (room for low/mid/high/full rungs without too-fast pacing). Per-faction override allowed if a faction's pace warrants it.
- The ladder uses four rungs keyed to fractions of `clock-max`. With `clock-max: 6`: low = 1-2, mid = 3-4, high = 5, full = 6. With other maxes, rungs scale proportionally (low ≤ 1/3, mid ≤ 2/3, high < max, full = max).
- A clock at 0 surfaces *no* rung. The faction is silent until first tick.
- Engagement triggers are described in plain language designed to match prose in session logs (e.g., "party visited the chapel," "party confronted Ravenna," "party left town for more than three days"). World-state interprets the match — this is judgment work, not regex.
- Discovery is its own trigger and *not* automatic with clock progression. A faction can sit at high-tier ladder for sessions without ever being named to the party.
- The `## On clock filled` post-op states for Phase 2a are limited to `dormant` and `retired`. Cascading into a new operation requires authoring infrastructure deferred to Phase 4.

### Public-stub schema (`world/factions/<slug>.md`)

Created by world-state on discovery. Narrator-readable from that point forward.

```markdown
---
name: <Faction Name>
slug: <slug>
discovered-session: <NNN>
---

# <Faction Name>

## Public-known facts
<!-- What the party knows about this faction. World-state writes the
     initial fragment from the discovery template; the narrator may
     update on subsequent learning during play. -->

- <fact 1>
- <fact 2>

## Notes
<!-- Free-form. -->
```

The discovery template is a section in the dm/ file (extending the schema, conceptually) that world-state copies into the public stub on creation. Phase 2a keeps it implicit: world-state composes a 2-3-bullet "what the party now knows" fragment from the dm/ file's `## Identity` section and the narrative context of the discovery trigger. Explicit per-faction templates can be added later if needed.

### Tick procedure (run by world-state at `/session-start`)

The narrator invokes the world-state subagent with the structured query:

> "Run offscreen developments tick. Prior session log: `sessions/play/YYYY/MM/session-NNN.md`."

World-state procedure:

1. **Enumerate active factions.** List `dm/factions/*.md` via `dm-fs` MCP. For each file, read frontmatter; skip if `status` is not `active`.

2. **Per active faction, decide the tick:**
   a. Read the prior session log from `sessions/play/YYYY/MM/session-<N-1>.md` (path provided by caller; if N = 1 — there is no prior — skip ticks, return baseline message).
   b. Read the faction's `## Engagement triggers`.
   c. Match the prior session log narrative against each trigger. World-state interprets — this is the same kind of judgment Phase 1's NPC-behavior query already does.
   d. If a trigger matches, apply its effect (typically "hold this session" or "tick -1"). Otherwise: `clock += 1`.

3. **If clock now equals `clock-max`:**
   a. Read `## On clock filled`.
   b. Surface the beat as the faction's contribution to the offscreen brief.
   c. Update frontmatter `status` per `Post-op state` (`dormant` or `retired`).

4. **Else if clock > 0:**
   a. Pick the rung from `## Observable consequences ladder` matching the new clock value.
   b. That rung's text is the faction's contribution to the offscreen brief.

5. **Discovery check:**
   a. Read `## Discovery`. Match its trigger against (i) the prior session log and (ii) the surface text being returned this tick.
   b. If matched, create `world/factions/<slug>.md` from the public-stub schema, populated from `## Identity` and the discovery context. Update dm/ frontmatter: `discovered: true`, `known-as: <name>`.

6. **Persist state:**
   a. Use `write_dm_file` to update the dm/ file's frontmatter and clock value.
   b. Use `append_dm_file` to add a `## History` line summarizing the tick decision (engagement trigger matched / not, clock value, rung surfaced, discovery if any).

7. **Return to narrator:** A list of `(faction-name-or-null, surface-text)` pairs. `faction-name` is null if `discovered: false`. Plus any `## On clock filled` beats fired this tick.

8. **Log:** Append a single line to the active session log:
   ```
   - WORLD-STATE QUERY: offscreen tick — <N> active factions, <M> ticked, <K> beats fired, <D> discoveries
   ```
   Per the existing Phase 1 logging convention. No raw clock values or hidden details in the player-visible log.

The narrator weaves the returned surface text into the opening scene. Faction names appear only when `faction-name` is non-null. Beats are integrated as setting events ("a stagecoach driver was found dead this morning at the crossroads") rather than abstract announcements.

### Edge cases the procedure handles

- **No factions exist.** World-state returns the Phase 1 baseline message: "Nothing observable from offscreen has reached the home base."
- **No prior session.** First-ever `/session-start` (session-001 or a fresh campaign): no tick happens. Phase 1 behavior preserved.
- **Faction at clock 0.** No rung surfaces. Faction may still be subject to engagement triggers (e.g., a trigger that pre-empts it from starting); default is `+1` so first session 0 → 1.
- **Faction at clock-max with status: active.** Defensive: idempotent — fire the beat once, transition status. The frontmatter status field is the gate; once it's `dormant` or `retired`, no further tick fires.
- **Engagement trigger judgment is ambiguous.** World-state defaults to "no match" → `+1 tick`. Conservative; the world keeps moving unless the party meaningfully pressed.
- **Discovery trigger fires the same session as a clock-filled beat.** Order: write public stub *before* surfacing the beat, so when the beat names the faction, the public stub exists.

### `dm-fs` MCP — write tools

Three new tools added to the existing Python MCP server, alongside the read tools from Phase 1:

- `write_dm_file(relative_path: str, content: str) -> None`
  - Full-file write. Used to update frontmatter and clock values on `dm/factions/<slug>.md`.
- `append_dm_file(relative_path: str, content: str) -> None`
  - Append-only write. Used for `## History` lines on faction files (and any future append-only `dm/` log).
- `create_dm_file(relative_path: str, content: str) -> None`
  - Creates a new file. Errors if the file already exists. Rare in Phase 2a (the seeded faction file is hand-authored during implementation, not created at runtime); reserved for future faction-spawn scenarios.

**Path safety** — same scheme as Phase 1's read tools:
- All paths resolved relative to project's `dm/`.
- Reject `..` segments and absolute paths.
- Reject symlinks pointing outside `dm/`.
- Reject paths that resolve outside `dm/` after canonicalization.
- Cap content size (suggest 64 KiB; revisit if a real faction file ever needs more).

**Audit:** Phase 1 left the `dm-fs` access log as a deferrable nice-to-have. Phase 2a commits to it: every read and write call appends a line to `tools/dm-fs-mcp/access.log` (outside `dm/`, so unaffected by `dm/**` denies) recording timestamp, tool, path, and a content-length / first-line summary for writes — never the full content. The log is required for Phase 2a's smoke test asymmetry audit, which verifies which agent accessed `dm/`.

### World-state subagent updates (`.claude/agents/world-state.md`)

Replace the Phase 1 stub for query type 2 ("Has anything changed offscreen since last session?") with the full tick procedure above. Specifically:

- Add `mcpServers: [dm-fs]` already present from Phase 1; the new tools are auto-available without frontmatter changes.
- Tools section gains nothing new — `Read, Edit` plus the MCP cover everything. The subagent's permission to `Edit` files in `world/` covers public-stub creation on discovery.
- System prompt expands the offscreen-developments query type with the procedure as written, including the path-safety reminder for MCP write calls and the logging convention.
- The "what you don't do" list adds: "Don't tick a clock without first checking engagement triggers against the prior session log. Don't fabricate engagement matches that aren't supported by the log."

### `CLAUDE.md` routing rules update

One new rule, inserted after rule 4 (primary PC authority):

> **5. Offscreen developments.** At `/session-start`, you must invoke the world-state subagent with "Run offscreen developments tick. Prior session log: `<path>`" before greeting the player. World-state will return surface text per faction (some named, some not, depending on whether the party has discovered them). Weave it into the opening scene as setting and atmosphere — name a faction only if world-state's response named it. You do not advance clocks mid-session; that is a session-boundary procedure.

The "what you must never do" list adds: "Never name a faction the world-state agent did not name in its response."

### `/session-start` command update

The Phase 1 `/session-start` command already has step 4 reserved for offscreen developments — currently a stub returning the Phase 1 baseline message. Phase 2a fills it in:

```
4. Invoke world-state subagent: "Run offscreen developments tick.
   Prior session log: sessions/play/YYYY/MM/session-<N-1>.md"
   - World-state returns a list of (faction-or-null, surface-text)
     pairs and any clock-filled beats.
   - Use the returned text to inform your opening narration.
```

No other slash commands change in Phase 2a.

### `.claude/settings.json`

No changes. The narrator's `dm/**` denies stay exactly as they are. The new `dm-fs` MCP write tools are accessible only to subagents with the MCP wired in (only world-state, per Phase 1).

### Repository layout (Phase 2a additions)

```
gygaxagain/
├── dm/
│   └── factions/
│       └── <seeded-faction-slug>.md   (NEW — hand-authored during implementation)
├── world/
│   └── factions/                       (NEW empty directory; .gitkeep)
└── tools/
    └── dm-fs-mcp/                      (existing; gets write tools added)
```

`world/factions/` ships as an empty directory with `.gitkeep`. It will populate on first discovery during play.

### Seeded faction (content authoring)

The Phase 2a seeded faction ties to Ravenna's session-001 tells. Concrete lore is drafted during implementation; the design commits only to:

- The faction is the entity Ravenna is connected to (via her hand calluses, chemical stains, herbal scent, unnatural cold, and door-vigil).
- The seeded operation is something coherent with those tells whose progression would plausibly produce rumors → concrete events → direct evidence → a clock-filled beat in Amphail.
- The discovery trigger is something a curious party can plausibly stumble into in 2-3 sessions of investigation in Amphail.
- The clock-filled beat is a single-session-scale event hitting the home base — not a campaign-ending finale.

The lore draft is reviewed during implementation and adjustable before the first run. The testbed campaign retires after this Phase 2a smoke test.

## Smoke test for Phase 2a

### Primary smoke test — session-002 end-to-end

1. With the seeded faction in place at clock 0 and `status: active`, the user runs `/session-start`.
2. Main agent invokes world-state offscreen tick.
3. World-state reads session-001 log; matches against the seeded faction's engagement triggers; no triggers match (session 001 was observational only); `clock: 0 → 1`; surfaces low-tier ladder rung; checks discovery trigger (does not match); persists state via MCP; logs the query.
4. Narrator receives surface text (no faction name); weaves it into Dagnal's opening at The Gilded Stallion the next morning.
5. Free-form play. Player engages with the rumor or doesn't.
6. `/session-end` commits the session as one logical commit.

**Pass criteria:**
- Clock value in `dm/factions/<slug>.md` advanced from 0 to 1 (verifiable post-session).
- Session-001 log was read by world-state (verifiable in the dm-fs access log).
- Narrator's opening included low-tier rumor without naming the faction.
- Session log shows the WORLD-STATE QUERY line.
- No narrator tool-use accessed `dm/` directly (verifiable in the session's tool-use log).

### Secondary smoke test — scaffolded high-tier validation

To validate mid-, high-, and full-tier rungs without four real sessions:

1. After primary smoke test, snapshot the faction file.
2. For each target clock value (3, 5, 6 — mid, high, full):
   a. Set `dm/factions/<slug>.md` clock to `target - 1`.
   b. Stage a stub prior-session log in a scratch path or use session-001 again as the "prior session."
   c. Run a fresh `/session-start` (in a throwaway scratch session log).
   d. Confirm: clock advances to target; correct rung surfaces; for full, the beat fires and status flips to `dormant`/`retired`; for any tier, discovery is checked correctly.
3. Restore the faction file from snapshot.

This validates the procedure breadth in a single sitting. Not a substitute for real play, but sufficient for Phase 2a exit.

### Asymmetry audit

Grep the session-002 tool-use trace (and the dm-fs access log) for any narrator-issued tool call touching `dm/`. There must be none. World-state is the sole `dm/` accessor.

## Failure modes Phase 2a must handle

- **MCP write tool fails.** World-state surfaces the error to the narrator; narrator informs the player rather than silently fabricating offscreen developments. The session can continue with a stale clock; the user can re-run the tick after debugging.

- **Engagement-trigger judgment drifts.** World-state interprets ambiguously and ticks (or holds) when the player would have judged differently. Mitigation: every tick decision is logged in `## History` with the trigger-match reasoning. The user can review post-session and manually adjust the clock if drift is confirmed. Phase 4 bookkeeper formalizes this audit.

- **Surface text leaks faction identity prematurely.** The narrator names a faction the world-state response didn't name. Mitigation: the new "never name a faction world-state did not name" rule in CLAUDE.md, plus inspection of session logs for early naming.

- **Public stub created prematurely.** Discovery trigger fires when the party hasn't actually learned the name. Mitigation: discovery triggers are authored conservatively; world-state's `## History` line records the discovery decision so the user can audit.

- **Clock advances past max.** Defensive: world-state never ticks past `clock-max`; once `status` flips off `active`, no further tick fires.

- **Frontmatter corruption.** A write_dm_file truncates or malforms YAML. Mitigation: world-state validates by reading-back after write. If validation fails, error surfaces to the narrator.

- **Path-traversal attempt via MCP write.** Path-safety logic from Phase 1 applies identically; reject and log.

## Open questions resolved during brainstorming

- **Scope of Phase 2a vs original Phase 2:** Phase 2a covers factions and offscreen developments only. Revelations and full Mythic-thread machinery move to Phase 2b. Mythic-event spotlight of factions moves to 2c (after both threads and factions exist).
- **Faction data model:** Identity sheet + one active operation per faction. Single concurrent clock at MVP. Multiple concurrent operations is a future extension.
- **Tick cadence:** Player-action sensitive at session-start. World-state reads prior session log, matches engagement triggers, holds or advances. Default-on-no-match is `+1`.
- **Authoring of faction content:** Implementation-time, by the assistant, drawing from `references/` and existing campaign content. No user-facing authoring command in Phase 2a. Phase 4 owns the production pipeline.
- **Public-vs-hidden file split:** Hidden only until discovered. World stub created on first discovery; until then, the narrator has no path to know the faction exists.
- **Surface mechanism:** Tiered ladder authored on the faction file, four rungs (low / mid / high / full). World-state picks the rung matching the post-tick clock value. No improvised surface text.
- **MCP write scope:** `write_dm_file`, `append_dm_file`, `create_dm_file`, all path-scoped to `dm/` with the same path-safety scheme as Phase 1 reads.
- **Mythic threads in Phase 2a:** Deferred. Phase 2a does not create or manage Mythic threads. Faction operations are independent of the Mythic thread list.
- **Settings.json:** Unchanged. The narrator's `dm/**` denies stay in place. New write tools are MCP-scoped.

## Phase 2a → Phase 2b handoff

Phase 2a's exit unlocks Phase 2b (revelations + threads): full revelation list and three-clue tracker, dm/revelations/ machinery, Mythic threads list with open/close lifecycle, expanded random-event handling. The faction system from 2a is the substrate Phase 2c then builds on (Mythic events spotlighting factions, threads composing with operations).

Schema-extensibility notes for downstream phases:

- The `## Engagement triggers` and `## Discovery` sections are language-pattern matched today; Phase 4 bookkeeper may formalize them as structured triggers without breaking the schema.
- Multiple-operation extension: replace the singular `## Active operation` section with a list. Tick procedure iterates per operation. Schema additive, not breaking.
- Mythic-event integration: 2c adds an "on event focus matches faction" hook into the tick procedure as an additional `+1`. No schema change to faction file itself.

## Roadmap context

Phase 2a sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(this design)*
3. **Phase 2b — Revelations and Mythic threads.**
4. **Phase 2c — Mythic-event spotlight integration.**
5. **Phase 3 — Source ingestion.** `/intake`, librarian, secret-quarantine logic.
6. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals, faction authoring formalization.
7. **Phase 5 — Progression.** Milestones, `/level-up`.
8. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
9. **Phase 7 — Downtime, banking, bastions.**

Phases 2a/2b/2c are the original Phase 2, sliced by what can be shipped and validated independently. Phase 2a's scope is what's locked here.
