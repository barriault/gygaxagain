# Phase 2c — Mythic Threads Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Mythic 2e–canonical thread tracking — a single ordered "Threads List" at `dm/threads/active.md` that the narrator opens and closes during play. Phase 2d will then wire random-event focus rolls against thread positions; this phase ships the CRUD substrate.

**Architecture:** Extend the existing mythic subagent (`.claude/agents/mythic.md`) with three new query types (open-thread, close-thread, list-threads) plus `mcpServers: [dm-fs]` and the `Write` tool. The new query types layer on top of the existing oracle / random-event / chaos-factor responsibilities. CLAUDE.md gains routing rule 7. The seeded threads file is hand-authored at implementation time under the relaxed-denies dance Phase 2a/2b established. Reuses Phase 2a's MCP read/list/write/append — no new ops, no new tests, no Python changes.

**Tech Stack:** Markdown only — subagent prompt extension, narrator routing rules, seeded content. Zero Python this phase.

**Spec:** [docs/superpowers/specs/2026-05-10-phase-2c-mythic-threads-design.md](../specs/2026-05-10-phase-2c-mythic-threads-design.md)

---

## Task 1: Extend mythic subagent prompt

**Files:**
- Modify: `.claude/agents/mythic.md`

This task replaces the entire mythic subagent file. The existing oracle / event / chaos sections are preserved verbatim; new frontmatter fields are added; three new query-type sections are inserted before `## What you don't do`; and the "what you don't do" list is updated to permit `dm/threads/` writes while still forbidding everything else in `dm/`.

- [ ] **Step 1: Read the existing mythic subagent for the baseline**

Run: `cat .claude/agents/mythic.md`

This shows you the current Phase 1 mythic subagent. The existing structure has frontmatter, an intro, `## Your tools`, `## Oracle requests`, `## Chaos factor adjustments`, `## Random event sampling (standalone)`, and `## What you don't do`. After this task, the file gains three new query-type sections (`## Threads: open-thread query`, `## Threads: close-thread query`, `## Threads: list-threads query`) plus an `## Edge cases` section, with frontmatter updates and a revised "what you don't do" list.

- [ ] **Step 2: Replace the entire file with the new content**

Replace `.claude/agents/mythic.md` with exactly this content:

```markdown
---
name: mythic
description: Resolves Mythic GME 2e oracle questions, random events, chaos factor adjustments, and Mythic threads CRUD. Always invoked for genuinely uncertain yes/no questions and for thread lifecycle management — never decide such questions yourself.
tools: Read, Write, Edit, Bash
mcpServers: [dm-fs]
model: haiku
---

You are the mythic agent. You execute Mythic GME 2nd Edition procedures — Fate Chart oracle, random event detection, chaos factor management, and thread tracking. You do **not** interpret results into narrative; that's the caller's job.

## Your tools

- The `mythic` Python CLI is installed in this project's venv. Invoke with:
  ```
  source .venv/bin/activate && python -m mythic.cli <subcommand> ...
  ```
  Subcommands: `oracle`, `event`, `chaos`. All output is JSON.

- Read/write access to `meta/chaos-factor.md` (one integer 1..9).
- Read access to `meta/campaign-config.md`.
- Read and write access to `dm/threads/` via the `dm-fs` MCP. Use the `read_dm_file`, `list_dm_dir`, and `write_dm_file` tools the MCP exposes. Do not attempt direct filesystem reads or writes of `dm/` — they are denied at the project level.
- No access to other `dm/` paths (factions, npcs, revelations) — those belong to the world-state and revelation subagents.

## Oracle requests

When asked an oracle question, the caller provides a `likelihood` (one of: `impossible`, `nearly_impossible`, `very_unlikely`, `unlikely`, `50_50`, `likely`, `very_likely`, `nearly_certain`, `certain`). Default to `50_50` if not specified.

Procedure:
1. Read the current chaos factor from `meta/chaos-factor.md`:
   ```
   python -m mythic.cli chaos --file meta/chaos-factor.md --read
   ```
2. Resolve the oracle:
   ```
   python -m mythic.cli oracle --likelihood <likelihood> --cf <cf>
   ```
3. The CLI automatically checks for a random event; if triggered, the `random_event` field in the response will be a non-null `{focus, action, subject}` object.
4. Append a single line to the active session log at the path the caller specifies:
   ```
   - ORACLE (<likelihood>, CF=<n>): <outcome> [roll <r>]<event suffix if any>
   ```
5. Return to the caller: `outcome`, `roll`, `random_event`, plus a one-line plain-English summary.

## Chaos factor adjustments

When asked to adjust the chaos factor (typically at scene end), invoke:
```
python -m mythic.cli chaos --file meta/chaos-factor.md --adjust <+1 or -1>
```
Return the new chaos factor. The CLI clamps to 1..9.

## Random event sampling (standalone)

If asked for a random event without an oracle:
```
python -m mythic.cli event
```
Return the `{focus, action, subject}` triple.

## Threads: open-thread query

> "Open thread: `<description>`. Active session log: `<path>`."

The caller provides a 1-2 sentence description of the unresolved question and the active session log path.

Procedure:

1. Call `read_dm_file("threads/active.md")` via the `dm-fs` MCP.
   - If the file does not exist (read raises an error), construct a fresh schema header:
     ```
     ---
     last-updated: <today's date YYYY-MM-DD>
     ---

     # Mythic Threads — Active

     # Closed Threads
     ```
     Treat the open list as empty for this operation.
2. Parse the open list (numbered list under `# Mythic Threads — Active`). Determine the next number — `max existing number + 1`, or `1` if the open list is empty.
3. Append the new thread to the open list:
   ```
   N. <description>  *(opened: session NNN)*
   ```
   where `NNN` is derived from the active session log path (the filename `session-NNN.md`).
4. Update the `last-updated` frontmatter to today's date.
5. Call `write_dm_file("threads/active.md", <full updated file content>)`.
6. Append to the active session log via your `Edit` tool:
   ```
   - MYTHIC THREAD: opened #N — <description>
   ```
7. Return `{thread_number: N, description}` to the caller.

## Threads: close-thread query

> "Close thread #N. Resolution: `<one-line summary>`. Active session log: `<path>`."

The caller provides the thread number to close, a one-line resolution summary, and the active session log path.

Procedure:

1. Call `read_dm_file("threads/active.md")`.
2. Find thread `#N` in the open list. If not found, return `{error: "no open thread #<N>"}` and append to the active session log:
   ```
   - MYTHIC THREAD: close failed — no open thread #<N>
   ```
   Stop without mutating the file.
3. Construct the updated file:
   - Remove thread `N` from the open list.
   - Renumber remaining open threads so the list reads `1, 2, 3, ...` contiguous (preserving each thread's `*(opened: session NNN)*` annotation as-is).
   - Append the closed entry to `# Closed Threads`:
     ```
     - ~~<original description>~~  *(opened: session NNN, closed: session MMM — <resolution>)*
     ```
4. Update the `last-updated` frontmatter to today's date.
5. Call `write_dm_file("threads/active.md", <full updated file content>)`.
6. Append to the active session log:
   ```
   - MYTHIC THREAD: closed #N — <description> — <resolution>
   ```
7. Return `{closed_thread_number: N, description, resolution, renumbered}` where `renumbered` is `true` iff at least one open thread was renumbered (i.e., the closed thread was not the last open thread).

## Threads: list-threads query

> "List threads. Active session log: `<path>`."

Procedure:

1. Call `read_dm_file("threads/active.md")`.
   - If the file does not exist, return `{open: [], closed_count: 0}` without creating it.
2. Parse:
   - Open list: each entry is `N. <description>  *(opened: session NNN)*` → `{number: N, description, opened_session: NNN}`.
   - Closed section: count entries.
3. Return `{open: [<list>], closed_count: <int>}`.
4. Append to the active session log:
   ```
   - MYTHIC THREAD: list — <K> open, <N> closed
   ```

## Edge cases

- **Active session log path is empty or invalid.** The thread file write is the source of truth — proceed with that. If the session-log append fails, log the error to the dm-fs access log (via the MCP itself) but still return success on the thread operation.
- **Thread description contains markdown-significant characters** (numeric prefix, asterisks, etc.). Keep the description as-is; the open list's leading `N. ` prefix is what makes the line a numbered list item. Authoring discipline rather than runtime fault.
- **Thread file is malformed** (open-list parse fails). Return `{error: "threads file malformed"}` and do not mutate. The user can clean up out-of-band.
- **`open-thread` race-of-numbering.** Sequential by design; the agent reads, computes max+1, writes. No locking needed for single-session play.
- **`close-thread` on the only open thread.** Open list becomes empty after removal; Closed section gains the entry. `renumbered: false`.

## What you don't do

- Don't interpret oracle results or random events into narrative — return raw outputs.
- Don't fabricate results without invoking the CLI.
- Don't write to `dm/` outside `dm/threads/active.md` — only thread queries are authorized to mutate `dm/`.
- Don't use your `Edit` tool on `dm/` files — `Edit(dm/**)` is denied at the project level. All `dm/` mutations flow through `write_dm_file` via the dm-fs MCP.
- Don't read `dm/factions/`, `dm/npcs/`, `dm/revelations/`, or any other `dm/` paths — those belong to the world-state and revelation subagents.
- Don't author thread content beyond what the caller provides — descriptions are user/narrator-supplied.
```

CRITICAL: this content contains nested code blocks (the schema-header block inside open-thread step 1, the closed-entry format inside close-thread step 3). Use the Write tool with the full content as a single string.

- [ ] **Step 3: Verify file structure**

Run: `head -10 .claude/agents/mythic.md`

Expected: frontmatter (lines 1-7) with all five keys: `name: mythic`, `description: Resolves...`, `tools: Read, Write, Edit, Bash`, `mcpServers: [dm-fs]`, `model: haiku`.

Run: `grep -n "^## " .claude/agents/mythic.md`

Expected (in order):
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

Run: `wc -l .claude/agents/mythic.md`
Expected: roughly 130-160 lines (was 64; the three thread query types plus edge cases plus revised tool/don't-do sections add the bulk).

Run: `grep -c "deferred to Phase 2" .claude/agents/mythic.md`
Expected: `0` (the old "Don't write to `dm/threads/` (deferred to Phase 2)" bullet is gone).

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/mythic.md
git commit -m "Extend mythic subagent with thread CRUD: open-thread, close-thread, list-threads"
```

---

## Task 2: Add narrator routing rule 7 (thread management)

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Insert rule 7 after rule 6**

In `CLAUDE.md`, locate `### 6. Revelation routing`. After that whole rule (i.e., after the closing line "If a scene begs for a revelation that doesn't exist yet, note it under `## Notes for later phases` in the session log; the user or a later phase's authoring pipeline (Phase 4 librarian/intake) will add it.") and BEFORE `## Session log conventions`, insert exactly this content with one blank line above and below:

```markdown
### 7. Thread management

When play surfaces a question, mystery, or unresolved situation worth tracking — at scene transitions, at session-end loose-end review, or mid-scene when something concrete leaves a hanging beat — invoke the mythic subagent with "Open thread: `<1-2 sentence description>`. Active session log: `<path>`." The subagent appends a numbered thread to `dm/threads/active.md` and returns its number.

When play resolves a previously-opened thread — the question gets answered, the missing person turns up, the cult plot completes — invoke "Close thread #N. Resolution: `<one-line summary>`. Active session log: `<path>`."

To recall what threads are open mid-scene, invoke "List threads. Active session log: `<path>`."

You do not author thread content yourself or directly edit `dm/threads/`. Threads emerge from play and are persisted only via the mythic subagent.
```

- [ ] **Step 2: Add the new must-never bullet**

In `CLAUDE.md`, locate the `## What you must never do` section (currently the last section). Add this bullet to that list (placement at the end of the list is fine):

```markdown
- Never decide a thread is open or closed without invoking the mythic subagent — the audit trail in `dm/threads/active.md` is the source of truth.
```

- [ ] **Step 3: Verify file structure**

Run: `grep -n "^### " CLAUDE.md`

Expected (in order):
```
### 1. Dice routing
### 2. Oracle routing
### 3. Hidden-info routing
### 4. Primary PC authority
### 5. Offscreen developments
### 6. Revelation routing
### 7. Thread management
```

Run: `grep -n "^## " CLAUDE.md`

Expected: existing top-level headings preserved, `## Session log conventions` still appears after `### 7. Thread management`.

Run: `grep -c "Never decide a thread is open or closed" CLAUDE.md`
Expected: `1`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Add narrator routing rule 7: thread management via mythic subagent"
```

---

## Task 3: Author seeded threads file (under relaxed denies)

The seeded threads file lives at `dm/threads/active.md`. Because `.claude/settings.json` denies Write/Edit on `dm/**`, this requires temporarily relaxing the denies (same pattern as Phase 2a Task 10 and Phase 2b Task 3).

The seeded threads come from session-003's loose-ends list. Primary: the Mercer family of Brackenwood (concrete, named, surfaces during the chapel scene). Secondary (stretch goal): whatever Ravenna is waiting for at the front door (open since session 002's tell-laden encounter).

**Files:**
- Modify temporarily: `.claude/settings.json`
- Create: `dm/threads/active.md`
- Restore: `.claude/settings.json`

- [ ] **Step 1: Temporarily relax dm/ deny rules**

Edit `.claude/settings.json`. Replace its entire content with:

```json
{
  "_phase_2c_temp_relax": "TEMPORARY: deny rules disabled for seeded-threads authoring. Restore before testing.",
  "permissions": {
    "deny": []
  }
}
```

- [ ] **Step 2: Create the dm/threads/ directory**

```bash
mkdir -p dm/threads
```

If this command is denied even after relaxing settings.json (the in-process permission state may not refresh mid-session), skip directly to Step 3 — the `Write` tool implicitly creates the parent directory when given a path inside it (verified pattern in Phase 2a Task 10 and Phase 2b Task 3).

- [ ] **Step 3: Author the seeded threads file**

Create `dm/threads/active.md` with exactly this content:

```markdown
---
last-updated: 2026-05-10
---

# Mythic Threads — Active

1. The Mercer family of Brackenwood — six souls (matriarch Hanna and her boys), three weeks absent from chapel service; a tinker's message went out and never returned.  *(opened: session 003)*
2. Whatever Ravenna is waiting for at the front door of The Gilded Stallion — pattern of door-watching established in sessions 001-002, subject of the watch unknown.  *(opened: session 002)*

# Closed Threads
```

- [ ] **Step 4: Restore the deny rules**

Restore `.claude/settings.json` to its original content:

```json
{
  "permissions": {
    "deny": [
      "Read(dm/**)",
      "Write(dm/**)",
      "Edit(dm/**)",
      "Glob(dm/**)",
      "Grep(dm/**)",
      "Bash(cat dm/*)",
      "Bash(cat dm/**/*)",
      "Bash(grep dm/*)",
      "Bash(grep -r dm/*)",
      "Bash(rg dm/*)",
      "Bash(less dm/*)",
      "Bash(more dm/*)",
      "Bash(head dm/*)",
      "Bash(tail dm/*)",
      "Bash(find dm/*)"
    ]
  }
}
```

- [ ] **Step 5: Verify denies are restored — try to read the seeded threads**

Run: `cat dm/threads/active.md`
Expected: PERMISSION DENIED. (If this works, the denies are not restored — re-check `.claude/settings.json`.)

- [ ] **Step 6: Commit**

```bash
git add .claude/settings.json dm/threads/active.md
git commit -m "Seed Phase 2c threads from session-003 loose-ends (Brackenwood-Mercer + Ravenna's door-watch)"
```

---

## Task 4: Smoke test — primary path

This task is a coordinated exercise with the user. The implementer prepares; the user runs `/session-start` in a fresh Claude Code session and exercises a thread lifecycle event during play. The implementer verifies outputs.

**Note:** The smoke test only validates correctly in a *fresh* Claude Code session that picks up the modified mythic subagent (Task 1), the updated CLAUDE.md (Task 2), and the seeded threads file (Task 3). The current session loaded prior text and won't reflect the changes. The dm-fs MCP subprocess also reloads on session start.

- [ ] **Step 1: Verify pre-test state**

Confirm:

Run: `cat .claude/agents/mythic.md | grep -E "^(name|description|tools|mcpServers|model):"`

Expected:
```
name: mythic
description: Resolves Mythic GME 2e oracle questions, random events, chaos factor adjustments, and Mythic threads CRUD. ...
tools: Read, Write, Edit, Bash
mcpServers: [dm-fs]
model: haiku
```

Run: `grep -c "### 7. Thread management" CLAUDE.md`
Expected: `1`.

Run: `cat dm/threads/active.md`
Expected: PERMISSION DENIED — confirms denies are restored.

Run: `grep -c "Read(dm/\*\*)" .claude/settings.json`
Expected: `1`.

Run: `.venv/bin/python -m pytest tools/ -q 2>&1 | tail -3`
Expected: 87 passed (no regressions; this phase ships no Python).

- [ ] **Step 2: Prompt the user to run `/session-start` in a fresh Claude Code session**

Tell the user:

> "Phase 2c smoke test ready. Please:
> 1. End this Claude Code session (or open a new one in `/Users/barriault/dnd/gygaxagain` on branch `phase-2c`).
> 2. Run `/session-start` to begin session-004.
> 3. The narrator should: (a) run Phase 2a's offscreen tick on the Ashen Vintners, (b) optionally invoke `list-threads` mid-scene to see the seeded Brackenwood and Ravenna's-door-watch threads.
> 4. Play a short scene that exercises at least one thread lifecycle event:
>    - **Open** a new thread: do something in play that leaves a fresh question hanging (e.g., decide to investigate something specific, witness a new mystery), and the narrator should invoke open-thread.
>    - **Close** the seeded Ravenna's-door-watch thread: press Ravenna about who she's waiting for — even a deflection that establishes she's NOT waiting for someone in particular would close the thread. (Or close the Brackenwood thread by committing to or completing an investigation step.)
>    - **List** mid-scene: ask the narrator to remind you what's open.
> 5. Run `/session-end` when done.
> Come back here when finished."

- [ ] **Step 3: Verify the session-004 log was created and contains MYTHIC THREAD lines**

Run: `ls sessions/play/2026/*/session-004.md`
Expected: file exists.

Run: `grep -n "MYTHIC THREAD" sessions/play/2026/*/session-004.md`
Expected: at least one line of one of these forms:
- `- MYTHIC THREAD: opened #N — <description>`
- `- MYTHIC THREAD: closed #N — <description> — <resolution>`
- `- MYTHIC THREAD: list — <K> open, <N> closed`

- [ ] **Step 4: Verify the dm-fs access log shows the mythic subagent's MCP calls**

Run: `cat tools/dm-fs-mcp/access.log | grep threads`
Expected: at minimum:
- `read_dm_file threads/active.md <bytes>` — at least one read
- `write_dm_file threads/active.md <bytes>; first: '---'` — at least one write (if open or close fired; not present if only list-threads was invoked)

- [ ] **Step 5: Verify the threads file mutated as expected**

The narrator cannot read `dm/threads/active.md` directly. To verify the mutation, ask the user to invoke the mythic subagent with a debug query:

Prompt the user:

> "Please ask the mythic subagent: 'List threads. Active session log: sessions/play/2026/05/session-004.md.'"

Compare the response against what session-004 narrative described:
- If a new thread was opened, it should appear in the open list with the next available number.
- If a seeded thread was closed, it should NOT appear in the open list (and the closed_count should reflect it).
- Renumbering: if thread #1 was closed and a new thread was opened, the new thread should be #1 (the original #2 — Ravenna — should have renumbered to #1, and the new thread should append as #2 if it opened after the close; or vice versa depending on order).

- [ ] **Step 6: Verify no narrator tool-use touched dm/ directly**

Inspect the user-visible Claude Code tool-use trace for the session. Search for any `Read(dm/...)`, `Edit(dm/...)`, `Write(dm/...)`, `Bash(cat dm/...)`, etc. tool calls.

Expected: none. The narrator's only path to thread state is through the mythic subagent.

- [ ] **Step 7: Verify the narrator's narration referenced the threads naturally (not by ID)**

Read the session-004 log narrative. Confirm:
- If a thread was woven into narration, the narrator referenced its content (e.g., "the Brackenwood Mercers", "Ravenna's door-watch") rather than naked thread IDs ("thread #1").
- The narrator did not paraphrase the underlying revelation phrasing or faction state when referencing threads — threads are independent of revelations and factions in 2c.

- [ ] **Step 8: Run the full pytest suite**

Run: `.venv/bin/python -m pytest tools/ -q`
Expected: 87 passed (no regressions from Phase 2c's markdown-only changes).

- [ ] **Step 9: No standalone commit needed**

The user's `/session-end` already committed session-004.md and any thread mutations. Phase 2c's implementation is complete after the smoke test passes.

---

## Self-review — spec coverage

| Spec section | Implementing tasks |
|---|---|
| Threads file schema (frontmatter, open numbered list, Closed Threads strikethrough archive, length convention) | Task 3 (the seeded `active.md` instantiates the schema); Task 1 (the open-thread / close-thread / list-threads procedures construct files matching the schema) |
| Mythic subagent extension: `mcpServers: [dm-fs]`, `Write` tool, three new query types, edge cases, revised tool list, revised "what you don't do" | Task 1 |
| `description` frontmatter mentions threads | Task 1 |
| CLAUDE.md routing rule 7 | Task 2 |
| New must-never bullet | Task 2 |
| `dm/threads/` directory | Task 3 (created during the relaxed-denies window; the Write tool will implicitly create it if `mkdir` is denied) |
| Seeded threads tied to existing campaign content (Brackenwood-Mercer, Ravenna's-door-watch) | Task 3 |
| Renumbering on close | Task 1 (close-thread procedure step 3 explicitly renumbers) |
| Single-file storage (single `active.md`, not per-file) | Task 3 (file structure) and Task 1 (procedures all reference the single file) |
| Open / closed binary lifecycle (no withdraw/promote/merge) | Task 1 (only three query types: open, close, list) |
| Narrator-driven open/close (no auto-closure from random events) | Task 2 (rule 7 documents narrator invocation pattern); spec out-of-scope makes 2d-deferral explicit |
| No `/session-start` auto-list | Plan does not modify `/session-start`; mythic agent prompt explicitly does not run on its own at session-start |
| No new dm-fs MCP tools | Plan introduces no Python tasks |
| No new tests | Plan introduces no test tasks |
| Smoke test (real session-004) | Task 4 |
| Asymmetry audit | Task 4 Step 6 |
| Existing oracle / event / chaos behavior preserved | Task 1 (the new file content keeps those sections verbatim from the Phase 1 prompt) |
| `world-state` and `revelation` subagents untouched | No tasks modify their files |
| Faction discovery (Phase 2a) and revelations (Phase 2b) untouched | No tasks modify those files |

All spec sections have implementing tasks. No gaps.
