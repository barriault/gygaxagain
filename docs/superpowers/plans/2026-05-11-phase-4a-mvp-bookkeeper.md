# Phase 4a — MVP Bookkeeper — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish the bookkeeper subagent and wire it into `/session-end`. The bookkeeper performs three narrator-discipline audits at session-end (dice-line presence, oracle-call presence, primary-PC overreach) and appends a `## Bookkeeper audit` section to the session log. Validate end-to-end against the existing `sessions/play/2026/05/session-005.md`.

**Architecture:** Phase 4a creates one new subagent (`.claude/agents/bookkeeper.md`), modifies one slash command (`.claude/commands/session-end.md`), and adds one routing rule to `CLAUDE.md`. The bookkeeper has narrator-scope read access (`sessions/`, `party/`, `library/`, `world/`) and write-only-to-the-session-log-being-audited via Edit. No dm-fs MCP access in Phase 4a. No new MCP tools, no Python code, no schema changes.

**Tech Stack:** Markdown subagent prompts, Claude Code Agent tool registry, existing slash command format.

---

## File Structure

### Files to create

| Path                          | Responsibility                                                                                                              |
|-------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| `.claude/agents/bookkeeper.md` | Bookkeeper subagent definition. Frontmatter + read access + write access + contract + `audit-session` query type + edge cases + what-you-don't-do. ~130-160 lines. |

### Files to modify

| Path                              | Change                                                                                                              |
|-----------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `.claude/commands/session-end.md` | Insert new step 4 (bookkeeper invocation) between existing step 3 (chaos adjust) and existing step 4 (git commit). Renumber subsequent steps. Update closing paragraph from "Phase 1 does not run a bookkeeper verification phase" to the Phase 4a wording. |
| `CLAUDE.md`                       | Add new routing rule 10 under `## Routing rules` after the existing rule 9 (Runtime librarian queries). At end of phase, update `## Current phase scope` to Phase 4a. |

### Files modified as side effect of the smoke test (committed at end)

- `sessions/play/2026/05/session-005.md` — gains a `## Bookkeeper audit` section appended by the smoke test.

### Why these boundaries

- The bookkeeper subagent stands alone in its own file, following the established subagent pattern (dice, mythic, world-state, revelation, librarian).
- The slash command modification is small and confined to the existing single-file command.
- CLAUDE.md gains one rule paragraph; no other changes.
- Phase 4a does not modify any other subagent prompt, any other slash command, any settings, or any code.

---

### Task 1: Create `.claude/agents/bookkeeper.md`

**Files:**
- Create: `.claude/agents/bookkeeper.md`

This is the load-bearing task. The bookkeeper subagent is a new artifact with one query type (`audit-session`). Full file content specified inline below; copy character-for-character.

- [ ] **Step 1: Verify the file does not already exist**

```bash
ls /Users/barriault/dnd/gygaxagain/.claude/agents/ 2>&1
```

Expected: shows existing subagents (dice.md, librarian.md, mythic.md, revelation.md, world-state.md) but NOT bookkeeper.md.

- [ ] **Step 2: Write `/Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md`**

Write EXACTLY the following content (everything between BEGIN-FILE-CONTENT and END-FILE-CONTENT markers; do NOT include the marker lines themselves):

BEGIN-FILE-CONTENT
---
name: bookkeeper
description: Audits the session log at session-end for narrator-discipline compliance. One query type — audit-session (scans the log for narrated mechanical outcomes without dice lines, narrated answers to uncertain questions without oracle calls, and narrated actions attributed to the primary PC, then appends a ## Bookkeeper audit section to the log). Findings are discipline-tracking signal, not commit-blocking.
tools: Read, Edit, Glob, Bash
model: sonnet
---

You are the bookkeeper agent. You perform the session-end verification pass. The `/session-end` slash command invokes you between the chaos-factor adjustment step and the commit step. You read the session log, run three narrator-discipline checks against the narrative prose, and append a `## Bookkeeper audit` section to the log. Findings are discipline-tracking signal — they document patterns the user reviews post-session. You do not block commit; you do not auto-correct; you do not modify content other than appending the audit section.

## Read access

- `sessions/`, `party/`, `library/`, `world/` — readable directly via Read and Glob.
- **No access** to `dm/` paths. Project-level settings deny direct reads. No dm-fs MCP access in Phase 4a.

## Write access

- `sessions/play/YYYY/MM/session-NNN.md` — writable via Edit, **only** for appending the `## Bookkeeper audit` section. You never modify narrative prose, subagent-log lines, the `## Session-end summary` section, or any prior content.
- **No other writes anywhere.** Not to `dm/` (denied at project level), not to `library/`, not to `party/`, not to `world/`, not to other `sessions/` files, not to `.claude/`, not to `docs/`.

## Your contract

You are a session-end audit subagent. Invoked only by `/session-end` (no ad-hoc invocation in Phase 4a). You read the session log and `party/primary/` for the primary PC's name; you append a structured findings list to the session log under `## Bookkeeper audit`; you return a brief summary in your response.

You never:

- Modify narrative prose, subagent-log lines, or the `## Session-end summary` section.
- Block commit. Findings are discipline-tracking; the user reviews post-session.
- Auto-correct findings (e.g., inserting a missing dice roll, rewriting a primary-PC overreach line). Auto-correction is out of scope; the user decides what to do with findings.
- Read or write any `dm/` content. The audits are pure narrator-readable-scope operations in Phase 4a.
- Re-audit a session that already has a `## Bookkeeper audit` section. Abort with an explicit error; Phase 4b may add re-audit semantics.
- Run checks beyond the documented trio (dice-line, oracle-call, primary-PC overreach). Phase 4b+ adds more.

## Query type: audit-session

Invocation: `"Audit session <path>."` where `<path>` is a session log under `sessions/play/<year>/<month>/session-<NNN>.md`.

Procedure:

1. **Pre-flight.** Verify the path has the form `sessions/play/<4 digits>/<2 digits>/session-<digits>.md`. Read the file. If the path is malformed or the file doesn't exist, abort with `"invalid session log path: <path>"`. If the file already contains a `## Bookkeeper audit` heading, abort with `"session already has a bookkeeper audit section; re-audit not supported in Phase 4a"`. No writes on abort.

2. **Identify primary PC.** Run `Glob("party/primary/*.md")`. Take the basename (without `.md`) of each match. If 0 files: emit warning `**Warning:** no primary PC file found; check 3 skipped` in the audit summary header and continue with checks 1 and 2 only. If N>1 files: emit warning `**Warning:** multiple primary PC files found (<comma-separated names>); check 3 will match against all` and continue with checks 1, 2, and 3 (matching against any name in the set).

3. **Decompose the session log.** Walk the file line by line. Classify each non-empty line as either subagent-log or narrative prose:
   - **Subagent-log:** a line starting with `- ` (one dash, one space) where the line contains one of these tokens (case-insensitive on the prefix; the token appears at or near the start of the line content): `/roll`, `DICE:`, `ORACLE:`, `MYTHIC:`, `WORLD-STATE QUERY:`, `LIBRARIAN QUERY:`, `REVELATION:`, `BOOKKEEPER QUERY:`.
   - **Narrative prose:** anything else that is not a blank line and not a markdown heading.
   - Markdown headings (`#`, `##`, `###`) delimit scene boundaries but are not themselves prose. The `## Scene: <title>` heading specifically marks a scene boundary.
   - On ambiguity, classify as prose (more conservative — runs the audit on slightly more content; may produce false positives but won't miss real violations).

4. **Check 1 — dice-line presence.** Scan narrative prose for descriptions of mechanical outcomes. Patterns of interest (LLM judgment, not regex):
   - Combat outcomes: "[noun] hits", "[noun] misses", "[noun]'s [weapon] glances off", "[noun] strikes you", damage quantities (e.g., "for 7 damage", "8 piercing").
   - Skill check outcomes: "you spot", "you notice", "you find the trap", "succeeds the DC", "fails the check".
   - Save outcomes: "saves against", "shrugs off the spell", "succumbs to".
   - Use the scene context: an outcome described in scene N must have a `- /roll` or `- DICE:` line within the same scene (between `## Scene:` markers, or the entire log if there's only one scene).
   - Flag candidates that look like mechanical outcomes but have no matching dice line nearby.
   - **Default to no flag** on truly ambiguous cases (e.g., "the door opens" — could be scripted, could be a check). Phase 4a errs toward false negatives over noisy false positives.

5. **Check 2 — oracle-call presence.** Scan narrative prose for answers to genuinely uncertain yes/no questions. Patterns:
   - Player asks a question and the narrator answers in prose ("Is there a back door?" → "Yes, you spot one behind the shelves").
   - Narrative tension implies an unknown the narrator resolved ("Would she trust him?" → narrator narrates her response).
   - For each candidate answer, look for a corresponding `- ORACLE:` or `- MYTHIC:` line nearby (within the same scene).
   - **Default to no flag** on cases where the answer is plausibly determined by already-established state (e.g., the location's `world/` description says the inn has a back door; no oracle needed).

6. **Check 3 — primary-PC overreach.** Scan narrative prose for action verbs or dialogue attributed to the primary PC by name. Use the primary PC name(s) from step 2.
   - **Flag-worthy:** `<PC> [verb]s [object]` where the verb implies declared action — `draws`, `says`, `attacks`, `casts`, `runs`, `whispers`, `decides`, `agrees`, `refuses`, `accepts`, `replies`, `nods`, `shakes <his/her> head`. Examples: "Dagnal draws his sword." "Dagnal says 'I'll take the door.'"
   - **Not flag-worthy:** descriptive/sensory/perceptual framings — `sees`, `notices`, `feels`, `hears`, `smells`. Examples: "Dagnal sees the door." "Dagnal feels the cold." These are the narrator describing what the PC perceives, not declaring an action.
   - Default to no flag on borderline cases (e.g., "Dagnal stands at the door" — could be position description or implied action).

7. **Compose findings.** For each finding, capture:
   - **Line reference:** 1-based line number in the session log.
   - **Suspect text excerpt:** 1-2 sentences from the line, quoted verbatim. If the surrounding context (1-2 lines before/after) clarifies the issue, include it minimally — never more than ~3 lines of context.
   - **Reasoning:** 1-2 sentences explaining why this looked like a violation. Reference what was missing (e.g., "no dice line in scene 3 corresponds to this hit") or what triggered the pattern (e.g., "verb 'says' attributed to Dagnal").

8. **Append the `## Bookkeeper audit` section** via Edit. Mechanism:
   - Identify a unique terminal anchor in the file. Typically the last bullet point under `**Loose ends:**` if `## Session-end summary` is present. If no `## Session-end summary` section exists, use the file's last non-empty content line.
   - Verify the anchor is unique within the file. If not unique, include enough preceding context (additional lines) to make the chosen anchor string unique.
   - Call Edit with:
     - `old_string`: the unique anchor text (exactly as it appears in the file).
     - `new_string`: the same anchor text, immediately followed by a blank line, `---`, blank line, `## Bookkeeper audit`, then the audit content per the format below.

   Audit section format:

   ```markdown
   
   ---
   
   ## Bookkeeper audit
   
   **Audit complete:** <N1> dice-line gap(s), <N2> oracle-call gap(s), <N3> primary-PC overreach candidate(s) flagged.
   
   <If N1+N2+N3 = 0:>
   
   No discipline regressions detected.
   
   <Else, three subsections — include all three even if some have zero findings:>
   
   ### Dice-line gaps
   
   <For each finding:>
   - **Line <NNN>:** "<suspect text excerpt>"
     Reasoning: <1-2 sentences>
   
   <Or if zero findings in this check:>
   
   - (none)
   
   ### Oracle-call gaps
   
   <Same structure.>
   
   ### Primary-PC overreach
   
   <Same structure.>
   ```

   Any warnings from step 2 (no primary PC, multiple primary PCs, no scene markers) go in a separate `**Warning:** ...` line immediately after the audit-complete line.

9. **Return a brief summary** in your response. Include: number of findings per check, the audit section was appended successfully, any warnings. Do not include the full findings list in the response — the persistent record in the session log is the authoritative artifact.

## Edge cases

- **Session log path doesn't exist.** Abort in pre-flight with `"invalid session log path: <path>"`. No writes.
- **Path is not a `sessions/play/<year>/<month>/session-<NNN>.md` file.** Abort. Phase 4a does not audit downtime sessions or other log types.
- **No primary PC file in `party/primary/`.** Emit warning in audit summary; skip check 3; continue.
- **Multiple primary PC files in `party/primary/`.** Emit warning; check 3 matches against all names.
- **Session log has no narrative prose** (all subagent-log lines and headings). All three checks produce zero findings. Audit summary appended with `No discipline regressions detected.`
- **Session log already has a `## Bookkeeper audit` section.** Abort with `"session already has a bookkeeper audit section; re-audit not supported in Phase 4a"`. No writes.
- **Session log has no `## Scene:` markers.** Run checks against the entire log as one scope. Emit warning `**Warning:** session log has no scene markers; checks ran against the full log as a single scope`.
- **Edit failure mid-append.** Surface the error. Session log may be partially modified. User restores via `git restore sessions/play/...` and reruns.

## What you don't do

- Don't modify narrative prose, subagent-log lines, or the `## Session-end summary` section.
- Don't write to any file other than the session log being audited.
- Don't read `dm/` paths. Phase 4a operates on narrator-readable content only.
- Don't block commit. Phase 4a is audit-only.
- Don't auto-correct findings. The user decides what to do.
- Don't re-audit a previously audited session. Abort.
- Don't run checks beyond the documented trio.
- Don't invoke other subagents.
- Don't commit. The `/session-end` command commits after you return.
END-FILE-CONTENT

- [ ] **Step 3: Verify the file matches the contract**

Run:
```bash
ls -la /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
wc -l /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: file exists; line count roughly 130-170 lines.

Verify structural requirements:
```bash
grep -n "^---$\|^name:\|^tools:\|^model:\|^mcpServers:" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md | head -10
```
Expected: two `---` lines (frontmatter open/close), one `name:`, one `tools:`, one `model:`. **No `mcpServers:` line** (Phase 4a does not use dm-fs MCP).

```bash
grep -n "^##" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: six top-level sections in order: `## Read access`, `## Write access`, `## Your contract`, `## Query type: audit-session`, `## Edge cases`, `## What you don't do`.

```bash
grep -c "dm-fs" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: at most 2 matches (one mentioning "No dm-fs MCP access" in Read access; one similar phrase elsewhere). The bookkeeper does not reference dm-fs MCP tool names like `mcp__dm-fs__*` anywhere.

```bash
grep -n "mcp__" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: zero matches. No MCP tool invocations referenced.

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add .claude/agents/bookkeeper.md
git commit -m "Create bookkeeper subagent v1 (Phase 4a)"
```

---

### Task 2: Modify `.claude/commands/session-end.md` to invoke the bookkeeper

**Files:**
- Modify: `.claude/commands/session-end.md`

The current `/session-end` slash command has 5 steps (locate log, append summary, chaos adjust, git commit, report success). Phase 4a inserts a new step 4 between chaos adjust (step 3) and git commit (now becomes step 5). Report success becomes step 6. The closing paragraph that says "Phase 1 does not run a bookkeeper verification phase" is replaced with the Phase 4a wording.

- [ ] **Step 1: Read the current session-end.md to confirm baseline**

```bash
cat /Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md
```

Expected: 5-step procedure plus a closing paragraph noting Phase 4 will introduce verification.

- [ ] **Step 2: Apply the modifications via Edit**

Make three edits to `/Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md`.

**Edit 1: Insert the new step 4 between existing step 3 (chaos adjust) and existing step 4 (git commit).**

`old_string`:
```
3. Invoke the mythic subagent to adjust the chaos factor based on whether the player was in or out of control of the session arc. Default in Phase 1: leave unchanged. If asked for a recommendation, surface the question to the user.

4. Run:
```

`new_string`:
```
3. Invoke the mythic subagent to adjust the chaos factor based on whether the player was in or out of control of the session arc. Default in Phase 1: leave unchanged. If asked for a recommendation, surface the question to the user.

4. Invoke the bookkeeper subagent with `"Audit session <path>."` where `<path>` is the active session log from step 1. The bookkeeper reads the log, runs three narrator-discipline checks (dice-line presence, oracle-call presence, primary-PC overreach), and appends a `## Bookkeeper audit` section to the log. The bookkeeper returns a brief summary; surface it to the user. Findings do not block the commit in this phase.

5. Run:
```

**Edit 2: Renumber the report-success step from 5 to 6.**

`old_string`:
```
5. Report success and the commit hash to the user.
```

`new_string`:
```
6. Report success and the commit hash to the user.
```

**Edit 3: Replace the closing paragraph.**

`old_string`:
```
Phase 1 does **not** run a bookkeeper verification phase — that lands in Phase 4. The working-tree-as-committed is trusted as the session record.
```

`new_string`:
```
Phase 4a runs a minimum-viable bookkeeper audit at session-end. Findings are surfaced and persisted in the session log under `## Bookkeeper audit` but do not block the commit. Subsequent Phase 4 sub-phases will extend the audit's reach (live-write integrity, subagent decision audits, structural-change proposals).
```

- [ ] **Step 3: Verify**

```bash
cat /Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md
```

Expected:
- Steps numbered 1, 2, 3, 4, 5, 6 in sequence.
- Step 4 is the new bookkeeper invocation.
- Step 5 is the git add/commit block (was step 4).
- Step 6 is the report-success line (was step 5).
- Closing paragraph is the Phase 4a wording, not the Phase 1 wording.

```bash
grep -c "Phase 1 does \*\*not\*\* run a bookkeeper" /Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md
```
Expected: 0 (the old wording is fully removed).

```bash
grep -c "Phase 4a runs a minimum-viable bookkeeper" /Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md
```
Expected: 1 (the new wording is present).

```bash
grep -c "Invoke the bookkeeper subagent" /Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md
```
Expected: 1.

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add .claude/commands/session-end.md
git commit -m "Wire bookkeeper into /session-end between chaos-adjust and commit (Phase 4a)"
```

---

### Task 3: Add CLAUDE.md rule 10 (Bookkeeper audit at session-end)

**Files:**
- Modify: `CLAUDE.md`

Add a new routing rule under `## Routing rules` after the existing rule 9 (Runtime librarian queries). The rule documents bookkeeper invocation discipline — the narrator does not invoke the bookkeeper during play; `/session-end` invokes it.

- [ ] **Step 1: Locate rule 9's closing and the next section heading**

```bash
grep -n "^### 9\.\|^### 8\.\|^## What you must never do\|^## Session log conventions" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

Expected: rule 9 heading, possibly other section headings. The new rule 10 goes after rule 9's content ends and before the next top-level `## ` heading (likely `## Session log conventions` based on Phase 3e's structure).

- [ ] **Step 2: Find a unique anchor at the end of rule 9**

Read `CLAUDE.md` around the end of `### 9. Runtime librarian queries`. Identify the last paragraph of that section. The new rule 10 will be inserted immediately after it.

A likely anchor (from Phase 3b's routing rule 9 wording): the paragraph ending with `... You learn what modules are available by reading library/index.md (genre-level enumeration only — does not pre-spoil content). The narrator-perspective premise/arc of a module is hidden from you until consult-library returns a relevant excerpt.` — verify in the actual file that this is rule 9's closing paragraph, and use it (or the actual last paragraph of rule 9) as the anchor.

- [ ] **Step 3: Insert rule 10 via Edit**

Read the file and find a unique anchor that is the last paragraph or line of `### 9. Runtime librarian queries`. Edit with `old_string` = that anchor and `new_string` = the anchor + `\n\n### 10. Bookkeeper audit at session-end\n\n<rule 10 body>`.

The exact rule 10 body to insert (immediately following the anchor, separated by a blank line and the heading):

```

### 10. Bookkeeper audit at session-end

The bookkeeper subagent audits each session log at session-end for narrator-discipline compliance. You do not invoke the bookkeeper during play — `/session-end` invokes it for you between chaos-factor adjustment and commit, with the active session log path as argument. The bookkeeper reads the log, runs three checks (dice-line presence for narrated mechanical outcomes, oracle-call presence for narrated answers to uncertain questions, primary-PC overreach for narrated actions/dialogue attributed to the primary PC), and appends a `## Bookkeeper audit` section to the log. Findings are discipline-tracking signal — they document patterns to review post-session — and do not block the commit in the current phase.

Treat the bookkeeper as a session-boundary subagent like world-state's offscreen-developments tick: invoked by a slash command at the boundary, not by you during play. Do not try to invoke the bookkeeper for ad-hoc audits; Phase 4a does not support that path.
```

- [ ] **Step 4: Verify**

```bash
grep -n "^### 10\. Bookkeeper audit at session-end" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: exactly one match, after the rule 9 section.

```bash
grep -n "^### 9\.\|^### 10\.\|^## Session log conventions" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: rule 9 line number < rule 10 line number < session log conventions line number.

```bash
grep -c "Treat the bookkeeper as a session-boundary subagent" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

- [ ] **Step 5: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add CLAUDE.md
git commit -m "Add CLAUDE.md routing rule 10: bookkeeper audit at session-end (Phase 4a)"
```

---

### Task 4: Restart prerequisite checkpoint

**Files:**
- No file changes in this task. Procedural setup.

- [ ] **Step 1: Confirm working tree clean on phase-4a branch**

If not already on a feature branch:
```bash
cd /Users/barriault/dnd/gygaxagain
git checkout -b phase-4a
```

(If the branch was created earlier in this implementation, you'll already be on it; `git checkout -b` will fail and that's fine — just confirm with `git branch --show-current`.)

Verify:
```bash
git status
git log --oneline -6
```

Expected: clean working tree, branch `phase-4a` (or current branch if branch was created upstream), and three commits from Tasks 1-3:
1. Create bookkeeper subagent v1 (Phase 4a)
2. Wire bookkeeper into /session-end between chaos-adjust and commit (Phase 4a)
3. Add CLAUDE.md routing rule 10: bookkeeper audit at session-end (Phase 4a)

- [ ] **Step 2: Restart prerequisite for smoke test**

The bookkeeper subagent prompt is loaded into the Agent tool's registry at session start. After Task 1's file creation, the running session does not yet have the bookkeeper available — invoking `Agent(subagent_type="bookkeeper", ...)` would fail with "subagent type not found."

**For Task 5's smoke test to dispatch the bookkeeper, the user must restart Claude Code.**

This is the same restart constraint Phase 3a/3b/3c/3d/3e hit. Signal to the user that a restart is required before proceeding to Task 5.

No commit for this task — procedural checkpoint.

---

### Task 5: Smoke test — bookkeeper against `session-005.md`

**Files:**
- Modified by the smoke test: `sessions/play/2026/05/session-005.md` (the bookkeeper appends a `## Bookkeeper audit` section).

**Prerequisite:** the user has restarted Claude Code after Tasks 1-3 committed, so the bookkeeper subagent is loaded in the Agent registry.

- [ ] **Step 1: Verify pre-conditions**

```bash
cd /Users/barriault/dnd/gygaxagain
git status
git log --oneline -6
git branch --show-current
```

Expected: clean working tree on phase-4a branch; recent commits include Tasks 1-3.

Verify session-005.md exists and does not yet have a bookkeeper audit:
```bash
ls -la sessions/play/2026/05/session-005.md
grep -c "^## Bookkeeper audit" sessions/play/2026/05/session-005.md
```
Expected: file exists; grep returns 0.

Verify primary PC file:
```bash
ls party/primary/
```
Expected: at least one `*.md` file (e.g., `dagnal.md`).

- [ ] **Step 2: Dispatch the bookkeeper with audit-session**

In the active Claude Code session (post-restart), dispatch:

```
Agent(subagent_type="bookkeeper", prompt="Audit session sessions/play/2026/05/session-005.md.")
```

The bookkeeper:
- Verifies the path is well-formed.
- Reads `sessions/play/2026/05/session-005.md`.
- Confirms no `## Bookkeeper audit` heading present.
- Globs `party/primary/*.md`; takes the basename(s) as primary PC name(s).
- Decomposes the log into prose vs subagent-log lines.
- Runs check 1 (dice-line presence), check 2 (oracle-call presence), check 3 (primary-PC overreach).
- Composes findings.
- Appends `## Bookkeeper audit` section via Edit.
- Returns a brief summary in its response.

- [ ] **Step 3: Verify the response**

The bookkeeper's response should be a brief summary along these lines:
- "Audit complete. Appended `## Bookkeeper audit` section to `sessions/play/2026/05/session-005.md`."
- Counts per check (e.g., "Check 1 (dice-line gaps): 2 candidates flagged. Check 2 (oracle-call gaps): 0. Check 3 (primary-PC overreach): 1 candidate flagged.")
- Any warnings (e.g., "Warning: no scene markers; checked as single scope").

The response should NOT include the full findings list — those live in the session log.

- [ ] **Step 4: Verify the session log was modified correctly**

```bash
git diff --stat sessions/play/2026/05/session-005.md
```
Expected: shows only `sessions/play/2026/05/session-005.md` modified; insertions only (no deletions).

```bash
grep -n "^## Bookkeeper audit" sessions/play/2026/05/session-005.md
```
Expected: exactly one match. Note the line number; the audit section starts there.

```bash
tail -50 sessions/play/2026/05/session-005.md
```

Inspect the audit section. Verify:
- Starts with `---` separator (after a blank line).
- Has `## Bookkeeper audit` heading.
- Has `**Audit complete:**` summary line with counts in the documented format.
- If counts are all zero: contains the literal text `No discipline regressions detected.`
- Otherwise: contains three subsections `### Dice-line gaps`, `### Oracle-call gaps`, `### Primary-PC overreach`. Each subsection has either findings in the documented format or `- (none)`.
- Findings have line references, suspect text excerpts, and reasoning.

```bash
git status
```
Expected: only `sessions/play/2026/05/session-005.md` shown as modified.

- [ ] **Step 5: Asymmetry probe — bookkeeper did not write anywhere else**

```bash
git status
```
Expected: still only one file modified. No new files. No other modifications.

```bash
grep "BOOKKEEPER" /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log 2>&1 | tail -5
```
Expected: zero matches (the bookkeeper has no dm-fs MCP access in Phase 4a; no entries attributable to it should appear in the access log).

- [ ] **Step 6: User reviews findings**

The user reads the appended `## Bookkeeper audit` section directly:
```bash
sed -n '/^## Bookkeeper audit/,$p' sessions/play/2026/05/session-005.md
```

For each finding, judge:
- **True positive:** real discipline issue worth tightening in future sessions.
- **False positive:** the bookkeeper was too aggressive; the pattern matched but the underlying narration was actually fine.
- **Borderline:** the bookkeeper's reasoning is plausible but signal/noise is unclear.

False positives are acceptable and expected in Phase 4a; the smoke test passes as long as:
- The audit section is in the documented format.
- Findings (if any) have plausible reasoning, not nonsense.
- Edge cases were handled (warnings emitted appropriately).

- [ ] **Step 7: Commit the smoke-test artifact**

```bash
cd /Users/barriault/dnd/gygaxagain
git add sessions/play/2026/05/session-005.md
git commit -m "Phase 4a smoke test: bookkeeper audit appended to session-005"
```

---

### Task 6: Slash command contract check + asymmetry audit + regression tests

**Files:**
- No file changes in this task. Verification only.

- [ ] **Step 1: Slash command contract check**

Read `.claude/commands/session-end.md` and verify the Phase 4a modifications:

```bash
cat /Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md
```

Verify:
- Six numbered steps: locate log, append summary, chaos adjust, bookkeeper invocation, git commit, report success.
- Step 4 wording matches the design (dispatches bookkeeper with `"Audit session <path>"`, surfaces findings to user, does not block commit).
- Closing paragraph is the Phase 4a wording.

```bash
grep -nE "^[0-9]\." /Users/barriault/dnd/gygaxagain/.claude/commands/session-end.md
```
Expected: six numbered steps (1, 2, 3, 4, 5, 6) in sequence.

- [ ] **Step 2: Run the existing test suite**

```bash
cd /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q 2>&1 | tail -5
```

Expected: `37 passed`. Phase 4a adds no Python code; the existing tests must continue to pass unchanged.

- [ ] **Step 3: Asymmetry audit — no dm/ access regression**

Verify the bookkeeper did not touch any dm/ paths during the smoke test.

```bash
grep -E "BOOKKEEPER|bookkeeper" /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log 2>&1 | tail -5
```
Expected: zero matches.

Verify Phase 3a/3b/3c/3d/3e boundaries hold (relative-path probes still denied):

```bash
cd /Users/barriault/dnd/gygaxagain && cat dm/modules/ancient-tomb-of-phandalin/secrets.md 2>&1 | head -1
```
Expected: denied (Phase 3a boundary).

```bash
cd /Users/barriault/dnd/gygaxagain && cat dm/revelations/r-001.md 2>&1 | head -1
```
Expected: denied (Phase 2b/3d boundary).

```bash
cd /Users/barriault/dnd/gygaxagain && cat dm/factions/cult-of-myrkul.md 2>&1 | head -1
```
Expected: denied (Phase 3e boundary).

```bash
cd /Users/barriault/dnd/gygaxagain && cat library/lore/test-bestiary/entries/goblin.md 2>&1 | head -3
```
Expected: file content displays (Phase 3c narrator-readable lore unchanged).

- [ ] **Step 4: Verify the bookkeeper file is well-formed**

```bash
wc -l /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: roughly 130-170 lines.

```bash
grep -c "^## " /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: 6 (the six top-level sections — Read access, Write access, Your contract, Query type: audit-session, Edge cases, What you don't do).

```bash
grep -n "mcp__\|mcpServers" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: zero matches. Phase 4a's bookkeeper has no MCP access.

- [ ] **Step 5: No commit needed**

This task is verification only.

---

### Task 7: Update CLAUDE.md `## Current phase scope` to Phase 4a

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Locate the current-phase-scope paragraph**

```bash
grep -n "Current phase scope\|^As of Phase 3e" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

The section currently reflects Phase 3e (after the Phase 3e merge). Replace it with a Phase 4a version.

- [ ] **Step 2: Update the section via Edit**

Use Edit on `/Users/barriault/dnd/gygaxagain/CLAUDE.md`.

The exact `old_string` is the entire existing Phase 3e current-phase-scope paragraph (starts with "The engine is being built incrementally. As of Phase 3e, ...").

Read the file to find the exact current text. Then replace with the Phase 4a version below.

The Phase 4a replacement text:

```
The engine is being built incrementally. As of Phase 4a, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), module intake via `/intake` + the librarian subagent with all module content dm-quarantined (Phase 3a), runtime librarian queries `consult-library` and `reveal-from-module` per rule 9 (Phase 3b), lore-reference intake via the librarian's `intake-lore` query with narrator-readable library/lore/ entries (Phase 3c), revelation auto-proposals from module material — the librarian writes `dm/revelations/r-NNN.md` seed files for reveal candidates found in a module's secrets.md, either during `intake-module` or via the standalone `propose-revelations <slug>` query (Phase 3d), faction auto-proposals from module material — the librarian writes `dm/factions/<faction-slug>.md` seed files for faction candidates found in a module's overview/secrets/connections content (defaulting to `status: dormant` so they're inert under the world-state subagent's offscreen tick until reviewed and flipped active), either during `intake-module` or via the standalone `propose-factions <slug>` query (Phase 3e), and an MVP bookkeeper subagent that audits each session log at session-end for narrator-discipline compliance (dice-line presence, oracle-call presence, primary-PC overreach) — invoked by `/session-end` per rule 10, findings appended to the session log under `## Bookkeeper audit`, commit is not blocked (Phase 4a). The Phase 2 hidden-state arc is closed; Phase 3a/3b/3c/3d/3e together make module ingest, runtime module consultation, lore-reference intake, and revelation+faction seed-writing from modules work end-to-end; Phase 4a establishes the bookkeeper artifact for narrator-discipline audit. You **do not** yet have: deeper subagent-decision audits — faction tick rationale, clue delivery confirmations, thread state, intake decisions (Phase 4b), live-write integrity audits (Phase 4b), library-bypass detection and structural-change proposals — NPC promotion, faction cascades, source-overlap merges (Phase 4c), authoring formalization — NPC system, milestone authoring, hand-authoring helpers (Phase 4d), additional lint rules and cross-session aggregate roll-up (Phase 4d–4e), solo-engine/methodology/gazetteer-essay intake (Phase 3f), URL ingestion (Phase 3f), curated `consult-lore` runtime query (Phase 3f if needed), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or a full bookkeeper. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.
```

- [ ] **Step 3: Verify**

```bash
grep -c "As of Phase 4a" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "As of Phase 3e" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 0 (the prior paragraph is fully replaced).

```bash
grep -c "MVP bookkeeper subagent" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add CLAUDE.md
git commit -m "Update CLAUDE.md current-phase-scope to Phase 4a"
```

---

### Task 8: Final integration sanity check + merge

**Goal:** Confirm Phase 4a invariants and merge phase-4a → main.

- [ ] **Step 1: Inspect git history**

```bash
cd /Users/barriault/dnd/gygaxagain
git log --oneline -10
```

Expected commits on phase-4a branch (most recent first), in this order:
1. Update CLAUDE.md current-phase-scope to Phase 4a (Task 7)
2. Phase 4a smoke test: bookkeeper audit appended to session-005 (Task 5)
3. Add CLAUDE.md routing rule 10: bookkeeper audit at session-end (Phase 4a) (Task 3)
4. Wire bookkeeper into /session-end between chaos-adjust and commit (Phase 4a) (Task 2)
5. Create bookkeeper subagent v1 (Phase 4a) (Task 1)
6. (Earlier:) Add Phase 4a design: MVP bookkeeper subagent

- [ ] **Step 2: Working tree clean**

```bash
git status
```
Expected: clean.

- [ ] **Step 3: DOD checklist**

Cross-check against the Phase 4a spec's `## Definition of done`:

- [ ] New `.claude/agents/bookkeeper.md` exists with frontmatter (name, description, tools, model), no `mcpServers`, intro paragraph, six top-level sections in order.
- [ ] Bookkeeper tools: `Read, Edit, Glob, Bash`. No `mcpServers`. Verified by `grep -n "tools:\|mcpServers" .claude/agents/bookkeeper.md`.
- [ ] Bookkeeper read access documented for `sessions/`, `party/`, `library/`, `world/`; no dm/ access.
- [ ] Bookkeeper write access documented for the session log being audited only.
- [ ] One query type: `audit-session` with the documented 9-step procedure.
- [ ] Audit section format documented in the bookkeeper prompt with the documented headings, summary line format, and finding format.
- [ ] `/session-end` invokes bookkeeper as new step 4 between chaos adjust (step 3) and git commit (now step 5). Report success is step 6.
- [ ] CLAUDE.md gains rule 10 under `## Routing rules` after rule 9.
- [ ] Smoke test produced a `## Bookkeeper audit` section in `sessions/play/2026/05/session-005.md` with the documented format.
- [ ] All 87 dm-fs MCP tests pass.
- [ ] No new MCP tools, no Python code added, no schema changes, no dm-fs writes from the bookkeeper.
- [ ] No new slash commands. Bookkeeper reachable only through `/session-end`.

- [ ] **Step 4: Merge phase-4a → main**

```bash
cd /Users/barriault/dnd/gygaxagain
git checkout main
git merge --no-ff phase-4a -m "Merge phase-4a: MVP bookkeeper subagent"
git branch -d phase-4a
git log --oneline -8
```

Expected: clean merge with merge commit; phase-4a branch deleted; the merge commit and its constituent commits visible at the top of `git log`.

---

## Notes for executors

- **Session restart required between Task 1 and Task 5.** The bookkeeper subagent's prompt is loaded into the Agent tool's registry at session start. After Task 1 creates the file, the running session does not yet have the bookkeeper available; dispatching `Agent(subagent_type="bookkeeper", ...)` would fail. Tasks 2, 3, and 4 can run in the same session as Task 1; Task 5 (smoke test) requires the user to restart Claude Code so the new bookkeeper prompt loads.

- **The smoke test modifies an existing committed session log.** This is the test artifact — appending the `## Bookkeeper audit` section to `sessions/play/2026/05/session-005.md` proves the bookkeeper's Edit-via-anchor mechanism works against real session content. The user can `git restore sessions/play/2026/05/session-005.md` if they want to revert before merging; but the smoke test artifact is the proof of end-to-end success and should normally be committed.

- **False positives are acceptable.** Phase 4a's audit logic is LLM-judgment-fuzzy. The smoke test passes if the audit section is in the documented format and findings (if any) have plausible reasoning — not if every finding is a true violation. Phase 4b will tune prompt judgment as audit signal/noise becomes clearer with more session data.

- **Edit-via-anchor mechanism is the discipline boundary.** The bookkeeper appends the audit section by finding a unique terminal anchor in the file and calling Edit. If the bookkeeper accidentally uses too short an anchor and Edit replaces multiple matches, the file could be corrupted. Mitigation: the bookkeeper's prompt instructs to "verify the anchor is unique" and expand context if not. The smoke test's `git diff --stat` check (one file, additive only) catches this if it happens.

- **No dm-fs MCP access in Phase 4a.** The bookkeeper subagent file has no `mcpServers` key. Verifications in Task 1 Step 3 and Task 6 Step 3 enforce this — `grep "mcp__"` and `grep "mcpServers"` must return zero matches.

- **No dense-negation discipline-regression check.** Unlike the librarian's Phase 3a positive-framing lesson (no `library/modules/<slug>` mentions), the bookkeeper's "don't read dm/" framing doesn't have an analogous positive-write-cue risk in Phase 4a — there's no plausible reason for the bookkeeper to be tempted to write to `dm/`. If Phase 4b extends bookkeeper read access to dm/ via MCP, that phase should review for positive-framing discipline.

- **Two-step path validation for the smoke test target.** Phase 4a's pre-flight expects `sessions/play/<4 digits>/<2 digits>/session-<digits>.md`. The smoke test target `sessions/play/2026/05/session-005.md` matches this. If a future user needs to test with a different path format (e.g., 4-digit session numbers), the bookkeeper's pre-flight regex would need to accommodate.

- **The Phase 4a smoke test does not require the synthetic fixture approach.** The primary smoke test against `session-005.md` exercises all three checks against real data. The optional tertiary smoke test (synthetic fixtures per check) is documented in the spec but not in this plan — it can be performed separately if the user wants per-check isolation, but it is not required for Phase 4a pass criteria.
