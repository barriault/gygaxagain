# Phase 2d — Mythic-Event Spotlight Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compose Mythic random events with the Phase 2a/2b/2c subsystems. When a random event fires during oracle resolution and its focus targets the threads list (`Move Toward A Thread` / `Move Away From A Thread` / `Close A Thread`), the mythic subagent auto-rolls d(open thread count) via the existing dice CLI, picks a target, and returns it in the response. Faction and revelation composition for other focus values is narrator-routed per new CLAUDE.md rule 8.

**Architecture:** Two markdown edits — `.claude/agents/mythic.md` gains a new step 3a (thread spotlight) in its oracle procedure plus a session-log line update plus one new don't-do bullet; `CLAUDE.md` gains routing rule 8 plus one new must-never bullet. Reuses the existing Phase 1 mythic CLI and Phase 1 dice CLI as-is. Reuses Phase 2c's `mcp__dm-fs__read_dm_file` access for threads. No Python changes, no new MCP tools, no new content seeded — the four existing threads in `dm/threads/active.md` provide spotlight targets.

**Tech Stack:** Markdown only — subagent prompt extension and narrator routing rules. Zero Python this phase.

**Spec:** [docs/superpowers/specs/2026-05-10-phase-2d-mythic-event-spotlight-design.md](../specs/2026-05-10-phase-2d-mythic-event-spotlight-design.md)

---

## Task 1: Extend mythic subagent oracle procedure with thread spotlight

**Files:**
- Modify: `.claude/agents/mythic.md`

This task adds the thread-spotlight composition step to the existing oracle procedure (after step 3), updates the session-log line in step 4 to include the composed thread target when applicable, and adds one new bullet to the "what you don't do" list to forbid auto-close on `Close A Thread` events.

- [ ] **Step 1: Read the current mythic.md as baseline**

Run: `cat .claude/agents/mythic.md`

The current Phase 2c file has frontmatter, `## Your tools`, `## Oracle requests` (with steps 1-5), `## Chaos factor adjustments`, `## Random event sampling (standalone)`, `## Threads: open-thread query`, `## Threads: close-thread query`, `## Threads: list-threads query`, `## Edge cases`, and `## What you don't do`. After this task: the `## Oracle requests` section gains a new step 3a, step 4's session-log line is updated, and `## What you don't do` gains one bullet.

- [ ] **Step 2: Insert new step 3a (thread spotlight composition) into the oracle procedure**

Open `.claude/agents/mythic.md`. Locate the `## Oracle requests` section. After the current step 3 (the line that reads "The CLI automatically checks for a random event; if triggered, the `random_event` field in the response will be a non-null `{focus, action, subject}` object.") and BEFORE the current step 4 (the line that reads "4. Append a single line to the active session log..."), insert this content with a blank line above and below:

```markdown
3a. **Thread spotlight composition.** If `random_event` (from step 3) is non-null and its `focus` is one of:
   - `Move Toward A Thread`
   - `Move Away From A Thread`
   - `Close A Thread`

   Then run the spotlight procedure:

   1. Call `mcp__dm-fs__read_dm_file("threads/active.md")` via the dm-fs MCP.
   2. Parse the open list under `# Mythic Threads — Active`. Count entries (call it `K`).
   3. If `K == 0`: skip targeting. Add `event_thread_target: null` with `reason: "no open threads"` to the random_event response. The narrator will interpret the event freeform.
   4. If the read errors (no such file): same treatment as `K == 0`, with `reason: "no threads file"`.
   5. If `K >= 1`: invoke the dice CLI via Bash to pick a target:
      ```
      python -m dice.cli roll "1d<K>"
      ```
      Parse the JSON output's `total` field — that is the picked thread number `N`. Validate `1 <= N <= K`; if not, error out and surface the failure rather than picking the wrong target.
   6. Read the open-list line at position `N` (1-indexed). Extract `{number: N, description}` where description is the prose before the `*(opened: session NNN)*` annotation.
   7. Add the target to the `random_event` response object:
      - For `Move Toward A Thread` and `Move Away From A Thread`: `event_thread_target: {number: N, description: "..."}`.
      - For `Close A Thread`: `event_thread_close_suggestion: {number: N, description: "..."}`. The distinct key name reminds the narrator this is a suggestion, not a confirmation — the narrator decides whether to actually invoke `close-thread` per CLAUDE.md rule 7.
```

CRITICAL: this content contains a nested code block (the `python -m dice.cli roll "1d<K>"` shell command is fenced with triple backticks). Use the Edit tool to insert this between step 3 and step 4 of the existing procedure. The outer markdown must not terminate at the inner triple backticks.

- [ ] **Step 3: Update step 4 (session-log line) to include the composed thread target**

In the `## Oracle requests` section, replace step 4. The current step 4 reads:

```markdown
4. Append a single line to the active session log at the path the caller specifies:
   ```
   - ORACLE (<likelihood>, CF=<n>): <outcome> [roll <r>]<event suffix if any>
   ```
```

Replace it with:

```markdown
4. Append a single line to the active session log at the path the caller specifies:
   ```
   - ORACLE (<likelihood>, CF=<n>): <outcome> [roll <r>] [event: <focus> / <action> / <subject>{thread target if any}]
   ```
   Where `{thread target if any}` is:
   - ` → thread #<N>: <description>` for `Move Toward A Thread` and `Move Away From A Thread`,
   - ` → close-suggestion #<N>: <description>` for `Close A Thread`,
   - nothing if `K == 0` or the focus is not thread-targeting.
   The event-suffix square brackets are only included if `random_event` was non-null.
```

- [ ] **Step 4: Add one new bullet to "What you don't do"**

In the `## What you don't do` section, add this bullet to the existing list (placement at the end of the list is fine):

```markdown
- Don't automatically invoke `close-thread` based on a `Close A Thread` random event focus — return the suggestion in the oracle response (`event_thread_close_suggestion`) and let the narrator decide whether the scene actually resolves the thread.
```

- [ ] **Step 5: Verify file structure**

Run: `grep -n "^## " .claude/agents/mythic.md`

Expected output (in order; sections unchanged from Phase 2c):
```
## Your tools
## Oracle requests
## Chaos factor adjustments
## Random event sampling (standalone)
## Threads: open-thread query
## Threads: close-thread query
## Threads: list-threads query
## Edge cases
## What you don't do
```

Run: `grep -c "3a\. \*\*Thread spotlight composition" .claude/agents/mythic.md`
Expected: `1` (the new step 3a inserted).

Run: `grep -c "event_thread_target" .claude/agents/mythic.md`
Expected: at least `2` (in step 3a's response shape AND in step 4's log-line format reference).

Run: `grep -c "event_thread_close_suggestion" .claude/agents/mythic.md`
Expected: at least `2` (in step 3a's response shape AND in the new don't-do bullet).

Run: `grep -c "Don't automatically invoke \`close-thread\`" .claude/agents/mythic.md`
Expected: `1` (the new don't-do bullet).

Run: `wc -l .claude/agents/mythic.md`
Expected: roughly 175-200 lines (was 158 after Phase 2c's defensive fix; ~20 lines added for step 3a, ~5 for step 4 expansion, ~2 for the new don't-do).

- [ ] **Step 6: Commit**

```bash
git add .claude/agents/mythic.md
git commit -m "Extend mythic subagent with thread spotlight composition on random events"
```

## Context for Task 1

The mythic subagent already handles oracle questions and detects random events via the mythic CLI. Phase 2d adds composition: when an event's focus targets the thread list (the three Mythic-canonical thread-focus values), the agent reads the threads file via MCP, rolls against the open-list count via the existing dice CLI, and returns the picked thread in the response. The Phase 2c defensive fix commit (`6d3f651`) established `mcp__dm-fs__*` as the canonical naming for MCP tool references; this task follows that convention.

The dice CLI is at `tools/dice/` and is invoked via `python -m dice.cli roll "<expression>"`. It returns JSON like `{"expression": "1d4", "raw_rolls": [3], "modifier": 0, "total": 3, ...}` — the `total` field is what the agent reads to pick the thread.

The threads file format (per Phase 2c) lists open threads as numbered Markdown items: `N. <description>  *(opened: session NNN)*`. Parsing is straightforward.

The Close-A-Thread suggestion path is intentionally distinct from the auto-target path: the response key `event_thread_close_suggestion` (not `event_thread_target`) flags to the narrator that this requires a separate decision per CLAUDE.md rule 7.

Branch: `phase-2d` (will be created from clean main before starting). Working directory: `/Users/barriault/dnd/gygaxagain`.

---

## Task 2: Add narrator routing rule 8 (random event composition)

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Insert rule 8 after rule 7 and before "## Session log conventions"**

In `CLAUDE.md`, locate `### 7. Thread management`. After that whole rule (i.e., after the closing line "You do not author thread content yourself or directly edit `dm/threads/`. Threads emerge from play and are persisted only via the mythic subagent.") and BEFORE `## Session log conventions`, insert exactly this content with one blank line above and below:

```markdown
### 8. Random event composition

When a Mythic random event fires (returned in the mythic subagent's oracle response as `random_event: {focus, action, subject}`), inspect the focus and route accordingly:

- **`Move Toward A Thread` / `Move Away From A Thread`:** the mythic response includes `event_thread_target: {number, description}`. The event advances or recedes that specific thread — weave the action and subject into a scene beat that references the named thread by content. The thread stays open.
- **`Close A Thread`:** the mythic response includes `event_thread_close_suggestion`. The event applies narrative pressure toward resolving the named thread, but does not automatically close it. If the scene naturally resolves the question, invoke "Close thread #N. Resolution: ..." per rule 7. If not, weave the event in as ambient pressure and leave the thread open.
- **`NPC Action` / `NPC Negative` / `NPC Positive`:** if the action and subject involve an NPC the party has met, route to world-state with an NPC-behavior query. If the NPC is faction-linked (which you may not know without asking), world-state will surface a faction-relevant beat where appropriate.
- **`Introduce A New NPC`:** interpret freeform. You may improvise a new NPC sketch flagged under `## Notes for later phases` for the eventual librarian / intake to formalize.
- **`PC Negative` / `PC Positive` / `PC Action`:** the event lands on the primary PC. Surface the implication as a setting beat or a perceptible consequence; the player decides the response.
- **`Remote Event` / `Ambiguous Event`:** interpret freeform.

You do not need to route every focus — the goal is to compose Mythic events with the campaign's tracked hidden state when the focus suggests a connection, not to invent connections that aren't there.
```

- [ ] **Step 2: Add the new must-never bullet**

In `CLAUDE.md`, locate the `## What you must never do` section (currently the last section, contains existing bullets from Phase 1+2a+2b+2c). Add this bullet to that list (placement at the end of the list is fine):

```markdown
- Never automatically close a thread based on a `Close A Thread` random event focus — the close-suggestion comes through the mythic subagent's response, but you decide via rule 7 whether to actually invoke `close-thread`.
```

- [ ] **Step 3: Verify file structure**

Run: `grep -n "^### " CLAUDE.md`

Expected output (in this order):
```
### 1. Dice routing
### 2. Oracle routing
### 3. Hidden-info routing
### 4. Primary PC authority
### 5. Offscreen developments
### 6. Revelation routing
### 7. Thread management
### 8. Random event composition
```

Run: `grep -n "^## " CLAUDE.md`
Expected: existing top-level headings preserved, `## Session log conventions` still appears AFTER `### 8. Random event composition`.

Run: `grep -c "Never automatically close a thread" CLAUDE.md`
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Add narrator routing rule 8: random event composition (factions, revelations, threads)"
```

## Context for Task 2

CLAUDE.md is the project's narrator system prompt. Phase 2a added rule 5 (offscreen developments), Phase 2b added rule 6 (revelation routing), Phase 2c added rule 7 (thread management). Phase 2d's rule 8 covers the COMPOSITION step: when a random event fires, which subagent owns the response. Three categories:

1. **Thread-targeting focuses** — mythic subagent has already auto-rolled and returned the target. Narrator weaves it in.
2. **NPC / Investigate / Discover focuses** — narrator routes to world-state or revelation as appropriate.
3. **Free-form focuses (PC, Remote Event, Ambiguous)** — narrator interprets directly.

The must-never bullet enforces the Close-A-Thread-is-suggestion-only contract that mythic.md's new don't-do bullet (Task 1) establishes on the agent side.

---

## Task 3: Smoke test — primary path

This task is a coordinated exercise with the user. The implementer prepares; the user runs `/session-start` in a fresh Claude Code session and plays a short scene that triggers a random event with thread-targeting focus. The implementer verifies outputs.

**Note:** The smoke test only validates correctly in a *fresh* Claude Code session that picks up the modified mythic subagent (Task 1) and the updated CLAUDE.md (Task 2). The current session loaded prior text. The dm-fs MCP subprocess also reloads on session start.

- [ ] **Step 1: Verify pre-test state**

Confirm:

Run: `grep -c "^3a\. \*\*Thread spotlight composition" .claude/agents/mythic.md`
Expected: `1`.

Run: `grep -c "### 8. Random event composition" CLAUDE.md`
Expected: `1`.

Run: `grep -c "Never automatically close a thread" CLAUDE.md`
Expected: `1`.

Run: `cat dm/threads/active.md`
Expected: PERMISSION DENIED (confirms denies are still in effect).

Run: `grep -c "Read(dm/\*\*)" .claude/settings.json`
Expected: `1` (denies restored from Phase 2c's relax-and-restore cycle).

Run: `.venv/bin/python -m pytest tools/ -q 2>&1 | tail -3`
Expected: 87 passed (no regressions; this phase ships no Python).

- [ ] **Step 2: Prompt the user to run `/session-start` in a fresh Claude Code session**

Tell the user:

> "Phase 2d smoke test ready. Please:
> 1. End this Claude Code session (or open a new one in `/Users/barriault/dnd/gygaxagain` on branch `phase-2d`).
> 2. Run `/session-start` to begin session-005.
> 3. Play a scene that involves genuine uncertainty. Ask the oracle questions naturally — events fire on doubles within the Chaos range (CF=5 → doubles 11/22/33/44/55 trigger). Statistically ~10-20% of oracle questions trigger an event.
> 4. When an event fires with a thread-targeting focus (`Move Toward A Thread` / `Move Away From A Thread` / `Close A Thread`), the mythic subagent should auto-roll d(open thread count) and return the picked thread in `event_thread_target` (or `event_thread_close_suggestion`). The narrator should weave the event into narration referencing the picked thread by content.
> 5. If no thread-focused event fires in 5-10 oracle queries, fall back: ask the mythic subagent directly with 'Sample an event. If the focus is thread-relevant, run the thread spotlight composition against the current open threads list and return the composed event.'
> 6. Run `/session-end` when done.
> Come back here when finished."

- [ ] **Step 3: Verify the session-005 log shows event composition**

Run: `ls sessions/play/2026/*/session-005.md`
Expected: file exists.

Run: `grep -nE "ORACLE.*\[event:" sessions/play/2026/*/session-005.md`
Expected: at least one line that contains `[event: <focus> / <action> / <subject>`. If the event was thread-targeting, the line should also include ` → thread #<N>: <description>` or ` → close-suggestion #<N>: <description>`.

If no natural-fire event surfaced, look for the fallback synthetic invocation in the session log instead.

- [ ] **Step 4: Verify the dm-fs access log shows the spotlight read**

Run: `tail -30 tools/dm-fs-mcp/access.log | grep threads`
Expected: at least one `read_dm_file threads/active.md <bytes>` entry timestamped during the event composition. NO `write_dm_file threads/*` entries from this composition (the spotlight is read-only; only narrator-driven `open-thread` / `close-thread` mutate the file).

- [ ] **Step 5: Verify the narrator referenced the thread by content, not by number**

Read the relevant narrative paragraphs in session-005.md. Confirm:
- The narrator's narration references the picked thread by content (e.g., "the Brackenwood Mercer family", "Ravenna's door-watch", "the unnatural cold around Ravenna", "the knitting woman") rather than naked "thread #N".
- If the event was `Close A Thread`: the narrator did NOT automatically invoke `close-thread` from the suggestion. Either the thread was closed via a deliberate `MYTHIC THREAD: closed #N` line (because the scene resolved it) or the thread stays open and the event landed as ambient pressure.

- [ ] **Step 6: Verify asymmetry held**

Inspect the user-visible Claude Code tool-use trace for the session. Search for any `Read(dm/...)`, `Edit(dm/...)`, `Write(dm/...)`, `Bash(cat dm/...)`, etc. tool calls.

Expected: none. The narrator's only path to thread state is through the mythic subagent's composed event response.

- [ ] **Step 7: Run the full pytest suite**

Run: `.venv/bin/python -m pytest tools/ -q`
Expected: 87 passed (no regressions from Phase 2d's markdown-only changes).

- [ ] **Step 8: Run a focused Phase 2b regression check**

The Phase 2c smoke test surfaced a Phase 2b regression (revelation confirm write was blocked by local-Write-vs-MCP-write_dm_file ambiguity). The defensive fix in commit `6d3f651` renamed all MCP tool references to `mcp__dm-fs__*` across all three subagents. Verify the fix held in session-005 if a revelation confirm fired:

Run: `grep -E "REVELATION QUERY: confirm" sessions/play/2026/*/session-005.md || echo "no confirms this session"`

If a confirm line is present and does NOT include "WRITE BLOCKED", the Phase 2b fix held. If it does include "WRITE BLOCKED", escalate — the renaming wasn't sufficient and the deny rule itself may be catching MCP writes (which would require narrowing the deny pattern to tool-specific names, deferred from the Phase 2c follow-up).

If no confirm fired this session, skip — the regression check happens whenever a revelation confirm naturally lands.

- [ ] **Step 9: No standalone commit needed**

The user's `/session-end` already committed session-005.md. Phase 2d's implementation is complete after the smoke test passes.

## Context for Task 3

This task validates the end-to-end spotlight composition path. The primary path relies on a natural event fire during play; the fallback synthetic invocation provides a deterministic test if natural firing is uncooperative.

The Phase 2c smoke test naturally exercised three other routing systems (Phase 2a offscreen tick, Phase 2b could-land, Phase 1 oracle) all in one session, so this scene is also expected to compose multiple subsystems. Phase 2d's specific signal is the `[event: ... → thread #N: ...]` line in the oracle log and the corresponding access-log read.

Branch: `phase-2d`. Working directory: `/Users/barriault/dnd/gygaxagain`.

---

## Self-review — spec coverage

| Spec section | Implementing tasks |
|---|---|
| Mythic subagent step 3a (thread spotlight composition) | Task 1, Step 2 |
| Step 3a triggers on three focus values (Move Toward / Move Away / Close A Thread) | Task 1, Step 2 |
| K=0 / file-missing / dice-CLI-failure / out-of-range handling | Task 1, Step 2 |
| Move-Toward / Move-Away returns `event_thread_target` | Task 1, Step 2 |
| Close-A-Thread returns `event_thread_close_suggestion` (distinct key for narrator) | Task 1, Step 2 |
| Session-log line includes event target when applicable | Task 1, Step 3 |
| Mythic subagent must-not-auto-close bullet | Task 1, Step 4 |
| CLAUDE.md routing rule 8 with full focus-to-route mapping | Task 2, Step 1 |
| New must-never bullet (Never automatically close a thread...) | Task 2, Step 2 |
| Dice CLI reused as-is (no Python changes) | No Python tasks in plan |
| Mythic CLI reused as-is (no Python changes) | No Python tasks in plan |
| `dm-fs` MCP unchanged (no new tools) | No MCP tasks in plan |
| `.claude/settings.json` unchanged (no deny changes) | No settings tasks in plan |
| No new content seeded — existing 4 threads provide spotlight targets | No content tasks in plan |
| `world-state` and `revelation` subagents untouched | No tasks modify their files |
| Smoke test (primary path with natural fire) | Task 3 |
| Smoke test fallback (synthetic event invocation) | Task 3, Step 2 |
| Asymmetry audit | Task 3, Step 6 |
| Phase 2b regression check piggybacked | Task 3, Step 8 |

All spec sections have implementing tasks. No gaps.
