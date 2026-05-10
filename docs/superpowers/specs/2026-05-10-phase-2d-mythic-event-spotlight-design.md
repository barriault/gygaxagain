# Phase 2d — Mythic-Event Spotlight Integration Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Phase 2b spec:** `docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md`.
**Phase 2c spec:** `docs/superpowers/specs/2026-05-10-phase-2c-mythic-threads-design.md`.
**Closes the original Phase 2 arc.** Phase 2 = hidden-state machinery, sliced into 2a (factions), 2b (revelations), 2c (threads), 2d (this — event composition).

## Purpose

Compose Mythic random events with the Phase 2a/2b/2c subsystems so that when a random event fires during oracle resolution, the focus value automatically targets the right substrate. Mythic 2e canonically rolls against the thread list when focus is `Move Toward A Thread` / `Move Away From A Thread` / `Close A Thread` — Phase 2d implements that mechanical procedure in the mythic subagent. Other focus values (NPC Action, Investigate, Discover, etc.) compose with factions and revelations via narrator-driven routing per a new CLAUDE.md rule, matching the project's existing pattern of "narrator routes structured queries to scoped subagents."

After 2d, a random event that fires during an oracle question can land cleanly on a specific tracked thread (auto-targeted), nudge a faction beat (narrator-routed), or surface a revelation clue (narrator-routed) — without any subsystem leaking outside its lane.

## Definition of done

A successful Phase 2d build demonstrates all of:

- The mythic subagent's `## Oracle requests` procedure gains a new step 3a (thread spotlight composition) that fires when the random event's focus is one of the three thread-targeting Mythic focus values.
- The thread spotlight reads `dm/threads/active.md` via the dm-fs MCP, counts open threads, invokes the existing dice CLI (`python -m dice.cli roll "1d<count>"`) to pick a target, and returns the picked thread as `event_thread_target` (for `Move Toward` / `Move Away`) or `event_thread_close_suggestion` (for `Close A Thread`).
- `Close A Thread` returns a suggestion only — no automatic mutation of the threads file. Narrator decides via Phase 2c's `close-thread` flow whether the scene actually resolves the thread.
- The mythic subagent's session-log line for the oracle includes the composed thread target when applicable.
- CLAUDE.md gains routing rule 8 (Random event composition) plus one new must-never bullet.
- A smoke test (session-005) exercises the thread spotlight either through a naturally-firing event or via a fallback synthetic invocation.
- Existing 87 tests continue to pass; no Python code is added in this phase. Both the dice CLI (Phase 1) and the mythic CLI (Phase 1) are reused as-is.
- Asymmetry boundary holds: narrator never reads `dm/threads/` directly; thread target arrives only via the mythic subagent's response.

## Out of scope (deferred)

- **Auto-close of threads on Close-A-Thread focus.** Phase 2c established a "narrator confirms" pattern for thread lifecycle; auto-close would compete with that. The mythic subagent returns the suggestion; the narrator decides.
- **Mythic-internal faction targeting.** When focus is `NPC Action` and the NPC is faction-linked, the mythic subagent does *not* read `dm/factions/` (out of scope per its prompt). Narrator routes to world-state.
- **Mythic-internal revelation querying.** When focus is `Investigate` / `Discover` / similar, the mythic subagent does *not* read `dm/revelations/`. Narrator routes to the revelation subagent.
- **Auto-creating threads from random events.** Mythic doesn't have an "Open A Thread" focus, and an "Introduce A New NPC" event does not automatically open a thread. Narrator decides whether the event surfaces a new tracked question per rule 7.
- **Random event sampling outside oracle resolution.** The mythic CLI's existing event-firing mechanism (doubles within the Chaos range during fate chart) stays as-is. No standalone "spawn an event" command in 2d.
- **Spotlight rolls against the closed-threads archive.** Only open threads are rollable. A Close A Thread suggestion that targets a thread numbered higher than the current open count is treated as a no-op for the suggestion (the roll is `1d<open-count>`, so this is structurally impossible).
- **Player-facing event log / `/status events`.** Phase 5 progression.

## Architecture

### Slice mapping

| Component                          | Phase 2d touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | New routing rule 8 in `CLAUDE.md`. One new must-never bullet.                    |
| World-state subagent               | Untouched. Narrator routes `NPC Action`-class events here when relevant.         |
| Revelation subagent                | Untouched. Narrator routes `Investigate` / `Discover`-class events here when relevant. |
| **Mythic subagent**                | **MODIFIED** — `## Oracle requests` procedure gains step 3a (thread spotlight); step 4's session-log line gets an event-target suffix; "what you don't do" gains one bullet. |
| Dice subagent                      | Untouched. The dice CLI is invoked by the mythic subagent via existing Bash access.|
| `dm-fs` MCP                        | No changes. Phase 2c's read tools are sufficient.                                |
| `.claude/settings.json`            | No deny-rule changes.                                                            |
| `/session-start` and other commands | Untouched.                                                                       |
| Repository layout                  | No additions. No new files. The four threads currently in `dm/threads/active.md` are the spotlight targets. |

### Information-asymmetry preservation

Phase 2c's boundary holds. The mythic subagent's read scope stays at `dm/threads/` only (set in Phase 2c). It does not gain access to `dm/factions/` or `dm/revelations/`. Faction and revelation composition is narrator-driven by reading the event response's `focus` field and routing per rule 8 — the narrator never sees the underlying state, only the structured response from the appropriate subagent it routes to.

The dm-fs access log captures each thread-spotlight read, so the smoke-test asymmetry audit extends naturally.

### Integration with prior phases

- **Phase 1 (mythic CLI):** unchanged. The CLI's existing event detection (doubles within Chaos range during fate chart) and event sampling (`{focus, action, subject}` from Mythic tables) continue to operate as the trigger and source of the event triple. Phase 2d only adds post-CLI composition at the subagent level.
- **Phase 1 (dice CLI):** unchanged and reused. The mythic subagent invokes `python -m dice.cli roll "1d<K>"` via Bash to pick a target thread when K open threads exist.
- **Phase 2a (factions):** unchanged. Faction composition with random events is narrator-routed per rule 8 — narrator notices an `NPC Action`-class event, recognizes a faction-linked NPC, and queries world-state.
- **Phase 2b (revelations):** unchanged. Revelation composition with random events is narrator-routed — narrator notices an `Investigate` / `Discover`-class event and queries revelation could-land.
- **Phase 2c (threads):** the threads file is the spotlight read target. The narrator's existing `open-thread` / `close-thread` query types remain the only path to mutate the file; mythic's thread spotlight is read-only.

## Component designs

### Mythic subagent: new step 3a (thread spotlight)

Inserted into the `## Oracle requests` procedure after step 3:

> **3a. Thread spotlight composition.** If `random_event` (from step 3) is non-null and its `focus` is one of:
> - `Move Toward A Thread`
> - `Move Away From A Thread`
> - `Close A Thread`
>
> Then run the spotlight procedure:
>
> 1. Call `mcp__dm-fs__read_dm_file("threads/active.md")` via the dm-fs MCP.
> 2. Parse the open list under `# Mythic Threads — Active`. Count entries (call it `K`).
> 3. If `K == 0`: skip targeting. Surface the event with `event_thread_target: null` and a `reason: "no open threads"` annotation. The narrator will interpret the event freeform or as ambient atmosphere.
> 4. If `K >= 1`: invoke the dice CLI via Bash:
>    ```
>    python -m dice.cli roll "1d<K>"
>    ```
>    Parse the JSON output's `total` field — that's the picked thread number `N`.
> 5. Read the open list line at position `N` (1-indexed). Extract `{number: N, description}` where description is the prose before the `*(opened: session NNN)*` annotation.
> 6. Add the target to the `random_event` response object:
>    - For `Move Toward A Thread` and `Move Away From A Thread`: `event_thread_target: {number: N, description: "..."}`.
>    - For `Close A Thread`: `event_thread_close_suggestion: {number: N, description: "..."}`. The distinct key name reminds the narrator this is a suggestion, not a confirmation.

### Mythic subagent: session-log line update

Step 4 (the session-log append for oracle) is updated to optionally include the composed thread target. The existing format:

```
- ORACLE (<likelihood>, CF=<n>): <outcome> [roll <r>]<event suffix if any>
```

becomes:

```
- ORACLE (<likelihood>, CF=<n>): <outcome> [roll <r>] [event: <focus> / <action> / <subject>{thread target if any}]
```

Where `{thread target if any}` is:
- ` → thread #<N>: <description>` for Move-Toward / Move-Away,
- ` → close-suggestion #<N>: <description>` for Close A Thread,
- nothing if `K == 0` or focus is not thread-targeting.

### Mythic subagent: "what you don't do" addition

Add one bullet to the existing list:

> - Don't automatically invoke `close-thread` based on a `Close A Thread` random event focus — return the suggestion in the oracle response and let the narrator decide whether the scene actually resolves the thread.

### CLAUDE.md routing rule 8

Inserted after rule 7 (Thread management), before `## Session log conventions`:

> ### 8. Random event composition
>
> When a Mythic random event fires (returned in the mythic subagent's oracle response as `random_event: {focus, action, subject}`), inspect the focus and route accordingly:
>
> - **`Move Toward A Thread` / `Move Away From A Thread`:** the mythic response includes `event_thread_target: {number, description}`. The event advances or recedes that specific thread — weave the action and subject into a scene beat that references the named thread by content. The thread stays open.
> - **`Close A Thread`:** the mythic response includes `event_thread_close_suggestion`. The event applies narrative pressure toward resolving the named thread, but does not automatically close it. If the scene naturally resolves the question, invoke "Close thread #N. Resolution: ..." per rule 7. If not, weave the event in as ambient pressure and leave the thread open.
> - **`NPC Action` / `NPC Negative` / `NPC Positive`:** if the action and subject involve an NPC the party has met, route to world-state with an NPC-behavior query. If the NPC is faction-linked (which the narrator may not know without asking), world-state will surface a faction-relevant beat where appropriate.
> - **`Introduce A New NPC`:** interpret freeform. You may improvise a new NPC sketch flagged under `## Notes for later phases` for the eventual librarian / intake to formalize.
> - **`PC Negative` / `PC Positive` / `PC Action`:** the event lands on the primary PC. Surface the implication as a setting beat or a perceptible consequence; the player decides the response.
> - **`Remote Event` / `Ambiguous Event`:** interpret freeform.
>
> You do not need to route every focus — the goal is to compose Mythic events with the campaign's tracked hidden state when the focus suggests a connection, not to invent connections that aren't there.

Plus one must-never bullet added to `## What you must never do`:

> - Never automatically close a thread based on a `Close A Thread` random event focus — the close-suggestion comes through the mythic subagent's response, but you decide via rule 7 whether to actually invoke `close-thread`.

### Repository layout (Phase 2d additions)

No new files. Two modifications:

```
gygaxagain/
├── .claude/agents/
│   └── mythic.md        # MODIFIED: oracle step 3a (thread spotlight), step 4 log line append, one new don't-do bullet
└── CLAUDE.md            # rule 8 added; one new must-never bullet
```

The existing four threads in `dm/threads/active.md` are the spotlight targets — no new content seeded.

## Smoke test for Phase 2d

### Primary path — session-005 with natural event firing

Random events fire on doubles within the Chaos range during fate chart oracle resolution. With CF=5, doubles 11 / 22 / 33 / 44 / 55 are within range (Mythic 2e). Statistically, ~10-20% of oracle questions trigger an event.

Procedure:
1. The user runs `/session-start` to begin session-005.
2. Play a scene that involves enough genuine uncertainty to drive multiple oracle queries.
3. When a random event fires, the mythic subagent returns the standard `{focus, action, subject}` triple plus the new composition. If the focus is thread-targeting, the response also includes `event_thread_target` (or `event_thread_close_suggestion`).
4. The narrator weaves the composed event into narration referencing the picked thread by content, not by number.
5. If a non-thread focus fires (e.g., `NPC Action`), the narrator follows rule 8 and routes to the appropriate subagent.

**Pass criteria:**
- Session-005 log contains at least one `ORACLE ... [event: ... → thread #N: ...]` line.
- dm-fs access log shows `read_dm_file threads/active.md` from the mythic subagent at the moment the event fired.
- Narration references the picked thread by content (e.g., "Brackenwood" or "Ravenna's door-watch"), not by naked number.
- If a Close-A-Thread event fires: thread is NOT auto-closed. Either the narrator invokes `close-thread` based on narrative fit (producing a `MYTHIC THREAD: closed #N` log line) or the thread stays open and the event lands as ambient pressure.
- Asymmetry held: no narrator tool-use directly reads `dm/`.

### Fallback path — synthetic event injection

If 5-10 oracle questions in session-005 fail to trigger any event, or if no event with thread-targeting focus fires, the smoke test falls back to a deliberate invocation:

The user (or narrator at user's prompt) invokes the mythic subagent directly:

> "Sample an event. If the focus is thread-relevant (Move Toward A Thread / Move Away From A Thread / Close A Thread), run the thread spotlight composition against the current open threads list and return the composed event."

This validates the procedure without relying on natural firing. If the first event sample isn't thread-focused, the user can sample again.

### Asymmetry audit

Same as prior phases. Grep session-005's tool-use trace and the dm-fs access log for any narrator-issued tool call touching `dm/`. There must be none.

## Failure modes Phase 2d must handle

- **Threads file doesn't exist when an event fires.** `read_dm_file` errors. The mythic subagent treats this identically to `K == 0`: return `event_thread_target: null, reason: "no threads file"`. Narrator interprets the event freeform.
- **Threads file exists but the open list is empty.** Same as `K == 0`.
- **Dice CLI invocation fails.** The mythic subagent surfaces the error in the oracle response and falls back to returning the event without a target. Narrator informs the player rather than silently fabricating a target.
- **Picked thread number out of range** (e.g., off-by-one parsing error). Validate `1 <= N <= K`; if not, error out rather than picking the wrong target.
- **Event fires with `Close A Thread` focus but the narrator forgets to evaluate whether the scene resolves the thread.** Mitigation: rule 8's wording explicitly states the close is the narrator's decision; the suggestion key (`event_thread_close_suggestion`) is named distinctly from `event_thread_target` to flag this distinction at parse time.
- **Narrator references a thread by naked number in narration** (e.g., "thread #3 advances"). Authoring discipline rather than runtime fault. Rule 8 instructs reference-by-content. Bookkeeper (Phase 4) will lint for this.
- **The same thread is targeted by multiple consecutive Move-Toward events.** Acceptable per Mythic canon — a thread can attract attention repeatedly. Narrator may choose to elevate it to a clock-filled beat narratively (no mechanical consequence; threads don't have clocks in Phase 2c).

## Open questions resolved during brainstorming

- **Slicing:** Phase 2d composes threads × factions × revelations × random events but in a way that doesn't require further slicing. Thread spotlight is mythic-canonical and mechanical; faction/revelation composition is narrator-routed via the existing pattern. One phase ships the integration.
- **Composition owner:** Mythic owns thread spotlight only (decision B). Faction and revelation composition is narrator-driven via rule 8. Mythic's read scope stays at `dm/threads/`.
- **Auto-close vs suggestion:** Suggestion only. Matches Phase 2c's narrator-driven close pattern; avoids competing close-thread paths.
- **CLI changes:** None. Mythic CLI and dice CLI are reused as-is.
- **Smoke test reliability:** Primary path via natural event firing; fallback synthetic injection if natural firing doesn't produce a thread-focused event within 5-10 oracle queries.
- **New content seeded:** None. Existing four threads provide spotlight targets.

## Phase 2d → Phase 3 handoff

Phase 2d's exit closes the original Phase 2 arc. With factions, revelations, threads, and Mythic-event spotlight all in place, the hidden-state machinery is feature-complete for narrative play. Phase 3 (Source ingestion) introduces `/intake`, the librarian agent, and the secret-quarantine logic that lets the user pour module content (One-Page One-Shots, Tales from the Yawning Portal nodes, etc.) into the engine without leaking secrets to the narrator. Phase 3 will populate `dm/factions/`, `dm/revelations/`, and (occasionally) `dm/threads/` from real source material, displacing the implementation-time content-authoring pattern that 2a/2b/2c/2d relied on.

The mythic-event composition surface from 2d will become more interesting once Phase 3 populates the world with more threads and factions and revelations — events can target a richer hidden-state graph.

## Roadmap context

Phase 2d sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(this design)*
6. **Phase 3 — Source ingestion.** `/intake`, librarian, secret-quarantine logic.
7. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals.
8. **Phase 5 — Progression.** Milestones, `/level-up`, `/status` family.
9. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
10. **Phase 7 — Downtime, banking, bastions.**

Phase 2d's scope is what's locked here.
