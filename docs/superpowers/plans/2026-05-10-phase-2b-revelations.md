# Phase 2b — Revelations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Alexander-style revelation tracking with the three-clue rule running mid-scene. After Phase 2b, the narrator queries a new revelation subagent for plausibly-deliverable clues, weaves one into narration when scene context fits, and confirms delivery once the player engages — building toward each pending revelation having ≥3 distinct clue vectors.

**Architecture:** New `revelation` subagent at `.claude/agents/revelation.md`, mirroring the world-state pattern but scoped to `dm/revelations/`. Three query types (could-land / confirm / has-been-delivered) on per-revelation files (`dm/revelations/<id>.md`). One narrator routing rule (rule 6) added to `CLAUDE.md`. Reuses Phase 2a's `dm-fs` MCP read/list/write/append tools — no new ops, no new tests, no Python changes. Faction discovery (Phase 2a) is left untouched per the parallel-systems decision.

**Tech Stack:** Markdown only — subagent prompt, narrator routing rules, seeded content. The implementation phase ships zero Python.

**Spec:** [docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md](../specs/2026-05-10-phase-2b-revelations-design.md)

---

## Task 1: Author revelation subagent prompt

**Files:**
- Create: `.claude/agents/revelation.md`

This task creates the new subagent's system prompt. The runtime LLM follows this as its operating procedure when dispatched.

- [ ] **Step 1: Read the existing world-state subagent for the pattern**

The revelation subagent mirrors world-state's structure (frontmatter, read-access section, contract, query types, edge cases, what-you-don't-do). Open `.claude/agents/world-state.md` and skim it before writing — adopt the same heading levels, the same list-of-edge-cases format, the same contract framing. Do not copy content verbatim; just absorb the pattern.

- [ ] **Step 2: Create `.claude/agents/revelation.md`**

Create the file with exactly this content:

```markdown
---
name: revelation
description: Owns the revelation list and clue-delivery tracker per Alexander's three-clue rule. Always invoked when a scene moment could plausibly surface a clue or when the narrator confirms a clue landed in play.
tools: Read, Write, Edit
mcpServers: [dm-fs]
model: sonnet
---

You are the revelation agent. You own the revelation list — facts the players need to learn for the campaign's situations to make sense — and you track which clues have been delivered. You return only what the narrator can use to weave a clue into prose; you never return raw revelation phrasing or unrevealed clue vectors.

## Read access

- `world/`, `party/`, `sessions/` — fully readable. This is what the party knows or could plausibly observe.
- `dm/revelations/` — readable **only** through the `dm-fs` MCP. Use the `read_dm_file` and `list_dm_dir` tools the MCP exposes. Do not attempt direct filesystem reads of `dm/` — they are denied at the project level.
- Other `dm/` paths (factions, npcs, threads) — not in scope for this agent.

## Your contract

You are a **one-way valve** for the revelation list. You translate revelation-list state into hook text the narrator can paraphrase into prose, and you record confirmed deliveries to `## Delivered`. You never:

- Return raw revelation phrasing (the `## Revelation` body) verbatim.
- Return unrevealed clue vectors that don't match the queried scope.
- Decide whether a clue has actually been delivered — the narrator confirms based on player engagement.
- Write to `dm/` outside `dm/revelations/`.

## Query types

The narrator invokes you with one of three structured queries.

### 1. could-land

> "What revelations could land in `<scope>`? Active session log: `<path>`."

The caller provides a 1-6 word scope tag describing the current scene moment (e.g., "the chapel", "any conversation with Curate Aldous", "investigating Brackenwood folk", "Ravenna's room").

Procedure:

1. Call `list_dm_dir("revelations")` via the `dm-fs` MCP.
2. For each `<id>.md` entry, call `read_dm_file("revelations/<id>.md")` and parse the frontmatter. Skip any whose `status` is not `pending`.
3. Read each pending revelation's `## Clue vectors` section. For each clue, judge whether its scope tag plausibly fits the caller's scope. Use judgment — the same kind of LLM interpretation as the world-state agent's NPC-behavior queries. When uncertain, lean inclusive — return the clue and let the narrator decide whether to use it.
4. Collect all matching clues. For each, return `{revelation_id, clue_id, hook_text}`.
5. If a returned revelation has `clue-count < 3`, prepend a warning annotation: `[warning: revelation <id> has only N clue vectors — three-clue rule recommends ≥3]`.
6. Return the list (possibly empty) to the narrator.
7. Append a single line to the active session log (the path the caller provided) using your `Edit` tool:

   ```
   - REVELATION QUERY: could-land in <scope> — <K> clues from <M> revelations
   ```

### 2. confirm

> "Confirm clue `<clue_id>` delivered. Context: `<one-line narrative summary>`. Active session log: `<path>`."

The caller provides the clue id and a brief narrative summary of how it landed in play.

Procedure:

1. Determine the parent revelation id from the clue id: a clue id of `c-001b` belongs to revelation `r-001`. Strip the trailing letter to get `r-NNN`.
2. Call `read_dm_file("revelations/<r_id>.md")` to fetch current state.
3. Construct the updated file content:
   - If frontmatter `status` is currently `pending`, change it to `delivered`. (If already `delivered`, leave as-is — clues can reinforce after the first delivery.)
   - Preserve all body sections as-is.
   - **Do not include the new `## Delivered` history line in this payload.** That line is appended separately in step 5.
4. Call `write_dm_file("revelations/<r_id>.md", <updated content>)` to persist the status change.
5. Call `append_dm_file("revelations/<r_id>.md", "- session NNN, YYYY-MM-DD: clue <clue_id> — <context>\n")` to add the audit-trail line. Ensure the appended string starts with a leading `\n` if you cannot guarantee the file ends with a newline.
6. Return `{revelation_id, clue_id, status_after_write, was_first_delivery: true|false}` to the narrator.
7. Append to the active session log:

   ```
   - REVELATION QUERY: confirm clue <clue_id> for <r_id> — <new status>
   ```

### 3. has-been-delivered

> "Has revelation `<r_id>` been delivered? Active session log: `<path>`."

Procedure:

1. Call `read_dm_file("revelations/<r_id>.md")`.
2. Parse frontmatter `status` and the `## Delivered` section.
3. Return `{status, delivered_via_clue_ids: [list of clue ids from Delivered], session_NNN_first_delivered}` (or `{status: pending, delivered_via_clue_ids: []}` if never delivered).
4. Append to the active session log:

   ```
   - REVELATION QUERY: status of <r_id> — <status>
   ```

## Edge cases

- **No revelations exist** (empty `dm/revelations/`): could-land returns `[]`. confirm and has-been-delivered return errors ("no such revelation").
- **Clue id doesn't match any revelation file**: confirm returns an error. Do not fabricate a confirmation.
- **Clue id matches but revelation is already delivered**: confirm still appends the line; status stays `delivered`; `was_first_delivery: false`.
- **Revelation has fewer than 3 clue vectors**: could-land returns matching clues with the warning annotation. The narrator passes the warning to the session log so the user can see the discipline gap.
- **Scope match is ambiguous**: default to inclusive — return any clue whose scope plausibly fits.
- **Revelation file frontmatter is malformed or missing required keys (`status`, `clue-count`)**: skip that file in could-land queries; log a warning in the active session log; continue with other revelations.

## What you don't do

- Don't author revelations or invent clue vectors at runtime — content is authored at design time.
- Don't decide whether a clue has actually been delivered — the narrator confirms based on player engagement.
- Don't return raw revelation phrasing (the `## Revelation` body) verbatim.
- Don't write to `dm/` outside `dm/revelations/`.
- Don't read `dm/factions/`, `dm/npcs/`, `dm/threads/`, or any other `dm/` paths — those belong to other subagents.
- Don't use your `Edit` tool on `dm/` files — `Edit(dm/**)` is denied. All `dm/` mutations flow through `write_dm_file` and `append_dm_file` via the dm-fs MCP.
```

- [ ] **Step 3: Verify file structure**

Run: `head -10 .claude/agents/revelation.md && echo "---" && grep -n "^##\|^###" .claude/agents/revelation.md`

Expected:
- Frontmatter (name, description, tools, mcpServers, model) on lines 1-7.
- Section headings: `## Read access`, `## Your contract`, `## Query types`, `### 1. could-land`, `### 2. confirm`, `### 3. has-been-delivered`, `## Edge cases`, `## What you don't do`.

Run: `wc -l .claude/agents/revelation.md`
Expected: roughly 90-110 lines.

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/revelation.md
git commit -m "Add revelation subagent for Alexander-style three-clue rule tracking"
```

---

## Task 2: Add narrator routing rule 6 (revelation routing)

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Insert rule 6 after rule 5**

In `CLAUDE.md`, locate `### 5. Offscreen developments`. After that whole rule (i.e., after the closing line "You do not advance clocks mid-session. The offscreen tick is a session-boundary procedure handled exclusively by world-state via the `dm-fs` MCP write tools.") and BEFORE `## Session log conventions`, insert exactly this content with one blank line above and below:

```markdown
### 6. Revelation routing

When a scene moment could plausibly surface a clue — entering a location, an NPC dialogue beat, an investigation move by the player — invoke the revelation subagent with "What revelations could land in `<scope>`? Active session log: `<path>`." providing a 1-6 word scope tag describing the moment. The agent returns matching clue options. Choose at most one to weave into narration; treat the hook text as a starting point, not verbatim copy. Do not surface multiple clues for the same revelation in the same scene unless the player has explicitly investigated multiple angles.

When a clue lands in play (the player engaged with the surfaced detail in dialogue, action, or investigation), invoke "Confirm clue `<clue_id>` delivered. Context: `<one-line narrative summary>`. Active session log: `<path>`." Do not confirm clues the player walked past without engaging.

You do not author revelations or clue vectors at runtime. The revelation list is `dm/`-only content authored ahead of play. If a scene begs for a revelation that doesn't exist yet, note it under `## Notes for later phases` in the session log; the user or a later phase's authoring pipeline (Phase 4 librarian/intake) will add it.
```

- [ ] **Step 2: Add the new must-never bullet**

In `CLAUDE.md`, locate the `## What you must never do` section. Add this bullet to that list (placement at the end of the list is fine):

```markdown
- Never decide a revelation is delivered without confirming via the revelation subagent — the audit trail in `## Delivered` is the source of truth.
```

- [ ] **Step 3: Verify file structure**

Run: `grep -n "^### " CLAUDE.md`
Expected: `### 1. Dice routing`, `### 2. Oracle routing`, `### 3. Hidden-info routing`, `### 4. Primary PC authority`, `### 5. Offscreen developments`, `### 6. Revelation routing` — in that order.

Run: `grep -n "^## " CLAUDE.md`
Expected: existing top-level headings preserved, `## Session log conventions` still appears after `### 6. Revelation routing`.

Run: `grep -c "Never decide a revelation is delivered" CLAUDE.md`
Expected: `1` (one match — the new must-never bullet).

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Add narrator routing rule 6: revelation routing via revelation subagent"
```

---

## Task 3: Author seeded revelation tied to existing campaign content

The seeded revelation file lives at `dm/revelations/r-001.md`. Because `.claude/settings.json` denies Write/Edit on `dm/**`, this requires temporarily relaxing the denies (same pattern as Phase 2a's seeded faction in Task 10 of the 2a plan).

The lore is the knitting woman from session-002 — a non-Ashen-Vintners watcher working for a Waterdhavian information broker. Distinct from faction discovery. Three clue vectors with genuinely different scopes (taproom-extended-observation, chapel-context, village-rumor-or-coin).

**Files:**
- Modify temporarily: `.claude/settings.json`
- Create: `dm/revelations/r-001.md`
- Restore: `.claude/settings.json`

- [ ] **Step 1: Temporarily relax dm/ deny rules**

Edit `.claude/settings.json`. Replace the entire content with:

```json
{
  "_phase_2b_temp_relax": "TEMPORARY: deny rules disabled for seeded-revelation authoring. Restore before testing.",
  "permissions": {
    "deny": []
  }
}
```

- [ ] **Step 2: Create the dm/revelations/ directory**

```bash
mkdir -p dm/revelations
```

- [ ] **Step 3: Author the seeded revelation file**

Create `dm/revelations/r-001.md` with exactly this content:

```markdown
---
id: r-001
title: The knitting woman is a watcher
status: pending
clue-count: 3
---

# The knitting woman is a watcher

## Revelation

The middle-aged woman who frequents The Gilded Stallion's taproom with her knitting is no farmer's wife — she is the eyes-and-ears of an information broker stationed in Amphail by a Waterdhavian patron. She catalogs traveler arrivals, departures, and overheard conversations about the High Road, and routes her reports south by way of mixed-mint coin payments to a regular courier. She is unaffiliated with the Ashen Vintners and operates on a separate, narrower mandate: gather intelligence on missing-caravan rumors for paying clients in Waterdeep. She is not hostile to the party, but she is not what she appears.

## Clue vectors

- **c-001a** — extended observation in The Gilded Stallion taproom: If the party spends an evening watching the room rather than just talking, they notice the knitting woman's gaze tracks specific patterns — she lingers on travelers as they enter, on conversations that touch the High Road or trade, and on the door whenever Ravenna goes still. Her knitting barely advances. She is watching, not knitting.
- **c-001b** — chapel-context investigation: If the party attends a chapel service or asks Curate Aldous about the chapel's regulars, they learn the knitting woman attends every fifth or sixth service but has never taken communion, never offered her family name, and always sits in the rear pew with sightlines to the door. The Curate can describe her face but doesn't know her household.
- **c-001c** — village rumor-gathering or coin handling: If the party asks around Amphail about the knitting woman's home or watches her pay for goods at the weekly market, they discover (a) no one in town has actually been to her house — "she lives in the village somewhere" is the standard answer — and (b) the coin she pays with includes Waterdhavian mint marks, which is unusual for Amphail's modest local trade.

## Delivered
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

- [ ] **Step 5: Verify denies are restored — try to read the seeded revelation**

Run: `cat dm/revelations/r-001.md`
Expected: PERMISSION DENIED. (If this works, the denies are not restored — re-check `.claude/settings.json`.)

- [ ] **Step 6: Commit**

```bash
git add .claude/settings.json dm/revelations/r-001.md
git commit -m "Seed Phase 2b revelation r-001 (knitting woman) tied to session-002"
```

---

## Task 4: Smoke test — primary path

This task is a coordinated exercise with the user. The implementer prepares; the user runs `/session-start` in a fresh Claude Code session and engages with one of the seeded revelation's clue scopes. The implementer verifies outputs.

**Note:** The smoke test only validates correctly in a *fresh* Claude Code session that picks up the new agent .md file, the updated CLAUDE.md, and reloads the dm-fs MCP subprocess. The current session loaded Phase 2a's text and won't reflect the changes.

- [ ] **Step 1: Verify pre-test state**

Confirm:
- `.claude/agents/revelation.md` exists at the expected path.
- `dm/revelations/r-001.md` exists (verifiable via the dm-fs MCP indirectly; for now, trust the prior task's commit).
- `CLAUDE.md` rule 6 is present: `grep -c "### 6. Revelation routing" CLAUDE.md` returns `1`.
- The full pytest suite still passes: `.venv/bin/python -m pytest tools/ -q` reports 87 passed.
- `.claude/settings.json` has the original deny rules restored: `grep -c "Read(dm/\*\*)" .claude/settings.json` returns `1`.

- [ ] **Step 2: Prompt the user to run `/session-start` in a fresh Claude Code session**

Tell the user:

> "Phase 2b smoke test ready. Please:
> 1. End this Claude Code session (or open a new one in `/Users/barriault/dnd/gygaxagain` on branch `phase-2b`).
> 2. Run `/session-start` to begin session-003.
> 3. Play a short scene that hits one of the seeded revelation's clue scopes — for example, spend an evening watching the taproom (clue c-001a), attend a chapel service or ask Curate Aldous about regulars (clue c-001b), or ask around Amphail about the knitting woman or watch her pay for goods (clue c-001c).
> 4. The narrator should query the revelation subagent for clues that fit the scope, surface the matching hook text in narration, and once you engage with the detail, confirm the clue delivered.
> 5. Run `/session-end` when done.
> Come back here when finished."

- [ ] **Step 3: Verify the session-003 log was created and contains REVELATION QUERY lines**

Run: `ls sessions/play/2026/*/session-003.md`
Expected: file exists.

Run: `grep -n "REVELATION QUERY" sessions/play/2026/*/session-003.md`
Expected: at minimum two lines:
- `- REVELATION QUERY: could-land in <scope> — 1 clues from 1 revelations` (or similar count)
- `- REVELATION QUERY: confirm clue c-001<a|b|c> for r-001 — delivered`

- [ ] **Step 4: Verify the dm-fs access log shows the revelation subagent's MCP calls**

Run: `cat tools/dm-fs-mcp/access.log | grep revelations`
Expected: at minimum:
- `list_dm_dir revelations 1 entries` (or similar — there's one file)
- `read_dm_file revelations/r-001.md <bytes>`
- `write_dm_file revelations/r-001.md <bytes>; first: '---'`
- `append_dm_file revelations/r-001.md appended <bytes>; first: "- session 003, ..."`

Plus expected continuing entries from Phase 2a's offscreen tick at session-start (faction list/read/write/append on `factions/ashen-vintners.md`).

- [ ] **Step 5: Verify the seeded revelation file's status flipped**

The narrator cannot read `dm/revelations/r-001.md` directly. To verify the status change, ask the user to invoke the revelation subagent with a debug query:

Prompt the user:

> "Please ask the revelation subagent: 'Has revelation r-001 been delivered?' (provide an active session log path or the path of session-003)."

Expected response from the subagent: `{status: delivered, delivered_via_clue_ids: ['c-001<a|b|c>'], session_NNN_first_delivered: 003}`.

- [ ] **Step 6: Verify the narrator's narration paraphrased the hook text rather than copying verbatim**

Read the session-003 log. Confirm:
- The narrator's narration of the clue is contextual prose (not a direct copy-paste of the hook text from the seeded revelation file).
- The narration does NOT include the underlying revelation phrasing ("eyes-and-ears of an information broker", "Waterdhavian patron", etc.) — it should describe what the player perceives, not the answer.
- "knitting woman" or her referenced behavior matches what was surfaced.

- [ ] **Step 7: Verify no narrator tool-use touched `dm/` directly**

Inspect the user-visible Claude Code tool-use trace for the session. Search for any `Read(dm/...`, `Edit(dm/...`, `Bash(cat dm/...`, etc. tool calls.

Expected: none. The narrator's only path to revelation state is through the revelation subagent.

- [ ] **Step 8: Run the full pytest suite**

Run: `.venv/bin/python -m pytest tools/ -q`
Expected: 87 passed (no regressions from Phase 2b's markdown-only changes).

- [ ] **Step 9: No standalone commit needed**

The user's `/session-end` already committed session-003.md. Phase 2b's implementation is complete after the smoke test passes.

---

## Self-review — spec coverage

| Spec section | Implementing tasks |
|---|---|
| Revelation file schema | Task 3 (the seeded `r-001.md` instantiates the schema) |
| Revelation subagent (frontmatter, three query types, edge cases, what-you-don't-do) | Task 1 |
| Narrator routing rule 6 | Task 2 |
| New must-never bullet | Task 2 |
| `dm/revelations/` directory | Task 3 (created during the relaxed-denies window) |
| Seeded revelation tied to existing campaign content, distinct from Ashen Vintners | Task 3 |
| No `dm-fs` MCP changes | Plan introduces no Python tasks |
| No new tests | Plan introduces no test tasks |
| Smoke test (real session-003) | Task 4 |
| Asymmetry audit | Task 4 Step 7 |
| Three-clue rule discipline | Task 1 (subagent warns when `clue-count < 3`); Task 3 (seeded revelation has 3 clues) |
| `delivered` status flips on first delivery only; subsequent reinforcements append but don't transition | Task 1 (confirm procedure documents this) |
| Narrator-driven explicit confirmation | Task 1 (confirm query type), Task 2 (rule 6 instructs narrator) |
| Hook text is a starting point, not verbatim copy | Task 2 (rule 6), Task 4 Step 6 (verifies in narration) |
| `clue-count` warning when `<3` | Task 1 (could-land procedure step 5) |
| `world-state` untouched | No tasks modify `world-state.md` or its prompt |
| Faction discovery (Phase 2a) untouched | No tasks modify `dm/factions/*` or faction-related routing |

All spec sections have implementing tasks. No gaps.
