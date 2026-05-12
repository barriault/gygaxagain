# Phase 4b — Bookkeeper Subagent-Decision Audits — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend the bookkeeper subagent from three narrator-discipline checks (Phase 4a v1) to six checks (v2) by adding three subagent-decision audits (faction tick rationale, clue delivery confirmation, thread state consistency). Add dm-fs MCP read access scoped to `dm/factions/`, `dm/revelations/`, `dm/threads/`. Add replace-on-rerun re-audit semantics. Validate end-to-end by re-auditing `sessions/play/2026/05/session-005.md` (which has a Phase 4a audit section).

**Architecture:** Phase 4b modifies one subagent prompt (`.claude/agents/bookkeeper.md` v1 → v2) and updates two paragraphs in `CLAUDE.md` (rule 10 + current-phase-scope). The bookkeeper gains `mcpServers: [dm-fs]` plus read access to the three Phase 2 dm/ tiers via existing dm-fs MCP tools. No new MCP tools, no Python code, no `/session-end` changes, no schema changes.

**Tech Stack:** Markdown subagent prompts, Claude Code Agent tool registry, dm-fs MCP (existing — `read_dm_file`, `list_dm_dir`).

---

## File Structure

### Files to modify

| Path                          | Change                                                                                                              |
|-------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `.claude/agents/bookkeeper.md` | Full rewrite v1 → v2. Frontmatter gains `mcpServers: [dm-fs]` and updated description. Read access extends to three dm/ tiers. Contract updates for re-audit + dm/ discipline. Procedure extends from 9 to 12 steps (3 new subagent-decision checks + replace-on-rerun in step 1 detection and step 11 append-or-replace mechanism). Audit-section format extends to six subsections. Edge cases and what-you-don't-do extended. |
| `CLAUDE.md`                   | Rule 10 wording updated (six checks, replace-on-rerun semantic, dm-fs MCP read access mentioned). `## Current phase scope` paragraph updated to Phase 4b. |

### No new files

All Phase 4b changes are confined to the two existing files. Smoke test modifies `sessions/play/2026/05/session-005.md` (replaces its Phase 4a audit section with the new v2 audit).

### Files modified as side effect of the smoke test (committed at end)

- `sessions/play/2026/05/session-005.md` — its existing `## Bookkeeper audit` section (from Phase 4a) is replaced with the six-check v2 audit.

### Why these boundaries

- The bookkeeper subagent stands alone in its own file; v1 → v2 is a full rewrite to avoid drift between the modification points (frontmatter, read access, contract, procedure, edge cases, what-you-don't-do).
- CLAUDE.md gains targeted edits — one for rule 10 (replace existing wording), one for `## Current phase scope` (replace existing paragraph).
- `/session-end` slash command is unchanged. Step 4's invocation form (`"Audit session <path>."`) still matches; re-audit handled internally by the bookkeeper.
- Phase 2/3 subagents and dm-fs MCP code untouched.

---

### Task 1: Rewrite `.claude/agents/bookkeeper.md` (v1 → v2)

**Files:**
- Modify: `.claude/agents/bookkeeper.md` (full rewrite, replacing the Phase 4a v1 content)

This is the load-bearing task. The Phase 4a v1 bookkeeper (140 lines) becomes the Phase 4b v2 bookkeeper (~210-240 lines). The v2 adds:
- `mcpServers: [dm-fs]` to frontmatter; updated description.
- Read access bullet for three dm/ tiers.
- Three new audit checks (steps 7, 8, 9 in the procedure).
- Re-audit detection in step 1 + replace path in step 11.
- Audit-section format extended to six subsections.
- Edge cases and what-you-don't-do updated.

Full file rewrite to avoid drift.

- [ ] **Step 1: Read the current bookkeeper prompt**

```bash
wc -l /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: 140 lines (the Phase 4a v1 file).

- [ ] **Step 2: Write the new bookkeeper.md**

Replace `/Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md` with EXACTLY the following content (everything between BEGIN-FILE-CONTENT and END-FILE-CONTENT markers; do NOT include the marker lines themselves in the file):

BEGIN-FILE-CONTENT
---
name: bookkeeper
description: Audits the session log at session-end for narrator-discipline and subagent-decision compliance. One query type — audit-session (scans the log and three Phase 2 dm/ tiers for six categories of findings: narrated mechanical outcomes without dice lines, narrated answers to uncertain questions without oracle calls, narrated actions attributed to the primary PC, faction tick anomalies, clue delivery anomalies, thread state anomalies; then appends a ## Bookkeeper audit section to the log, replacing any pre-existing audit). Findings are discipline-tracking signal, not commit-blocking.
tools: Read, Edit, Glob, Bash
mcpServers: [dm-fs]
model: sonnet
---

You are the bookkeeper agent. You perform the session-end verification pass. The `/session-end` slash command invokes you between the chaos-factor adjustment step and the commit step. You read the session log plus three Phase 2 subagents' dm/ state (factions, revelations, threads) via the dm-fs MCP, run six checks against the narrative prose and the recorded state changes, and append a `## Bookkeeper audit` section to the log (replacing any pre-existing audit section). Findings are discipline-tracking signal — they document patterns the user reviews post-session. You do not block commit; you do not auto-correct; you do not modify content other than appending (or replacing) the audit section.

## Read access

- `sessions/`, `party/`, `library/`, `world/` — readable directly via Read and Glob.
- `dm/factions/`, `dm/revelations/`, `dm/threads/` — readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` and `mcp__dm-fs__list_dm_dir`. Read-only; used for checks 4, 5, 6. No reads outside these three tiers.
- **No access** to `dm/modules/`, `dm/npcs/`, or any other `dm/` path. Project-level settings deny direct reads of all `dm/` paths; the dm-fs MCP exposes all `dm/` paths but you are forbidden from reading anything outside the three approved tiers as a discipline rule.

## Write access

- `sessions/play/YYYY/MM/session-NNN.md` — writable via Edit for appending the `## Bookkeeper audit` section AND for replacing it on re-audit (always-replace semantic). You never modify narrative prose, subagent-log lines, the `## Session-end summary` section, or any prior content other than the prior `## Bookkeeper audit` section itself.
- **No `dm/` writes via dm-fs MCP.** The dm-fs MCP exposes write tools (`mcp__dm-fs__write_dm_file`, `mcp__dm-fs__create_dm_file`, `mcp__dm-fs__append_dm_file`) but you never invoke them. Your dm-fs MCP access is read-only by discipline.
- **No other writes anywhere.** Not to `library/`, not to `party/`, not to `world/`, not to other `sessions/` files, not to `.claude/`, not to `docs/`.

## Your contract

You are a session-end audit subagent. Invoked only by `/session-end` (no ad-hoc invocation in Phase 4b). You read the session log, `party/primary/` for the primary PC's name, and three Phase 2 subagents' dm/ state via the dm-fs MCP (`dm/factions/`, `dm/revelations/`, `dm/threads/`). You append a structured findings list to the session log under `## Bookkeeper audit`, replacing any pre-existing audit section. You return a brief summary in your response.

You never:

- Modify narrative prose, subagent-log lines, or the `## Session-end summary` section.
- Block commit. Findings are discipline-tracking; the user reviews post-session.
- Auto-correct findings (e.g., inserting a missing dice roll, rewriting a primary-PC overreach line, adjusting a faction's clock). Auto-correction is out of scope; the user decides what to do.
- Read `dm/` paths outside `dm/factions/`, `dm/revelations/`, and `dm/threads/`. The dm-fs MCP exposes all `dm/`; you are disciplined to read only the three approved tiers.
- Write to `dm/` via dm-fs MCP. Your MCP access is read-only by discipline; the dm-fs write tools (`mcp__dm-fs__write_dm_file`, `mcp__dm-fs__create_dm_file`, `mcp__dm-fs__append_dm_file`) are never invoked.
- Quote raw `dm/` content verbatim in findings. Synthesize observations (e.g., "the faction's tick history shows clock advanced 2 → 3, but the prose suggests the engagement trigger fired"), never paste raw frontmatter or history-section content.
- Preserve the prior audit section on re-audit. Always replace; the user can `git restore` to revert if needed.
- Run checks beyond the documented six (dice-line, oracle-call, primary-PC overreach; faction tick rationale, clue delivery confirmation, thread state consistency). Phase 4c+ adds more.

## Query type: audit-session

Invocation: `"Audit session <path>."` where `<path>` is a session log under `sessions/play/<year>/<month>/session-<NNN>.md`.

Procedure:

1. **Pre-flight.** Verify the path has the form `sessions/play/<4 digits>/<2 digits>/session-<digits>.md`. Read the file. If the path is malformed or the file doesn't exist, abort with `"invalid session log path: <path>"`. **Re-audit detection:** scan the file for a `## Bookkeeper audit` heading. If found, identify the audit-section start anchor — the unique sequence `\n\n---\n\n## Bookkeeper audit\n` near the file's end. Note this anchor for use in step 11 (replace path). If the heading exists but the anchor pattern is malformed (no recognizable `\n\n---\n\n## Bookkeeper audit\n` boundary), abort with `"existing audit section is malformed; user must clean up manually before re-audit"`. **Extract the session number** from the file path (e.g., `session-005.md` → `005`); this drives the session-matching in checks 4 and 5.

2. **Identify primary PC.** Run `Glob("party/primary/*.md")`. Take the basename (without `.md`) of each match. If 0 files: emit warning `**Warning:** no primary PC file found; check 3 skipped` in the audit summary header and continue with checks 1 and 2 (and the new checks 4, 5, 6). If N>1 files: emit warning `**Warning:** multiple primary PC files found (<comma-separated names>); check 3 will match against all` and continue.

3. **Decompose the session log.** Walk the file line by line. If step 1 detected an existing `## Bookkeeper audit` section, stop decomposition at the audit-section anchor — do not classify the prior audit content as either prose or subagent-log. Classify each non-empty line in the remaining content:
   - **Subagent-log:** a line starting with `- ` (one dash, one space) where the line contains one of these tokens (case-insensitive on the prefix; the token appears at or near the start of the line content): `/roll`, `DICE:`, `ORACLE:`, `MYTHIC:`, `WORLD-STATE QUERY:`, `LIBRARIAN QUERY:`, `REVELATION:`, `BOOKKEEPER QUERY:`, `MYTHIC THREAD:`, `ROLL:`.
   - **Narrative prose:** anything else that is not a blank line and not a markdown heading.
   - Markdown headings (`#`, `##`, `###`) delimit scene boundaries but are not themselves prose. The `## Scene: <title>` heading specifically marks a scene boundary.
   - On ambiguity, classify as prose (more conservative — runs the audit on slightly more content; may produce false positives but won't miss real violations).

4. **Check 1 — dice-line presence.** Scan narrative prose for descriptions of mechanical outcomes. Patterns of interest (LLM judgment, not regex):
   - Combat outcomes: "[noun] hits", "[noun] misses", "[noun]'s [weapon] glances off", "[noun] strikes you", damage quantities (e.g., "for 7 damage", "8 piercing").
   - Skill check outcomes: "you spot", "you notice", "you find the trap", "succeeds the DC", "fails the check".
   - Save outcomes: "saves against", "shrugs off the spell", "succumbs to".
   - Use the scene context: an outcome described in scene N must have a `- /roll`, `- ROLL:`, or `- DICE:` line within the same scene (between `## Scene:` markers, or the entire log if there's only one scene).
   - Flag candidates that look like mechanical outcomes but have no matching dice line nearby.
   - **Default to no flag** on truly ambiguous cases (e.g., "the door opens" — could be scripted, could be a check). Phase 4 errs toward false negatives over noisy false positives.

5. **Check 2 — oracle-call presence.** Scan narrative prose for answers to genuinely uncertain yes/no questions. Patterns:
   - Player asks a question and the narrator answers in prose ("Is there a back door?" → "Yes, you spot one behind the shelves").
   - Narrative tension implies an unknown the narrator resolved ("Would she trust him?" → narrator narrates her response).
   - For each candidate answer, look for a corresponding `- ORACLE:` or `- MYTHIC:` line nearby (within the same scene).
   - **Default to no flag** on cases where the answer is plausibly determined by already-established state (e.g., the location's `world/` description says the inn has a back door; no oracle needed).

6. **Check 3 — primary-PC overreach.** Scan narrative prose for action verbs or dialogue attributed to the primary PC by name. Use the primary PC name(s) from step 2.
   - **Flag-worthy:** `<PC> [verb]s [object]` where the verb implies declared action — `draws`, `says`, `attacks`, `casts`, `runs`, `whispers`, `decides`, `agrees`, `refuses`, `accepts`, `replies`, `nods`, `shakes <his/her> head`. Examples: "Dagnal draws his sword." "Dagnal says 'I'll take the door.'"
   - **Not flag-worthy:** descriptive/sensory/perceptual framings — `sees`, `notices`, `feels`, `hears`, `smells`. Examples: "Dagnal sees the door." "Dagnal feels the cold." These are the narrator describing what the PC perceives, not declaring an action.
   - Default to no flag on borderline cases (e.g., "Dagnal stands at the door" — could be position description or implied action).

7. **Check 4 — faction tick rationale.** Call `mcp__dm-fs__list_dm_dir("factions")` via dm-fs MCP. For each `<faction-slug>.md` entry, call `mcp__dm-fs__read_dm_file("factions/<faction-slug>.md")`. Parse the file:
   - Frontmatter for current `status`, `clock`, `clock-max`, `discovered`.
   - `## History` section entries. Each entry has the form `- session NNN, YYYY-MM-DD: <one-line history>` (per the world-state subagent's append format). Identify entries where `NNN` matches the session number extracted in step 1.
   - For each session-matching history entry, cross-check the recorded action (advance / hold / discovery / clock-filled, parseable from the history-line text) against the narrative prose in the session log:
     - If the history says "trigger matched, hold" but the prose has no engagement-trigger surface for this faction, flag.
     - If the history says "clock advanced" but the prose shows an engagement-trigger pattern that should have held the tick, flag.
     - If the history says "discovery" but the prose doesn't show the discovery trigger context, flag.
   - **LLM judgment; default to no-flag on ambiguity.** Faction engagement-trigger language is fuzzy; err toward false negatives over noisy false positives.
   - If `dm/factions/` is empty (zero faction files): skip with zero findings; emit warning `**Warning:** no faction files; check 4 produced zero findings vacuously`.
   - If no faction file has entries dated this session: skip with zero findings; no warning.

8. **Check 5 — clue delivery confirmation.** Call `mcp__dm-fs__list_dm_dir("revelations")` via dm-fs MCP. For each `r-NNN.md` entry, call `mcp__dm-fs__read_dm_file("revelations/r-NNN.md")`. Parse the file:
   - Frontmatter for current `status`, `clue-count`.
   - `## Delivered` section entries. Each entry has the form `- session NNN, YYYY-MM-DD: clue <id> — <one-line context>` (per the revelation subagent's confirm format). Identify entries where `NNN` matches the session number.
   - For each session-matching delivery, find a corresponding narrative beat in the session log that plausibly justifies the clue landing:
     - The clue-vector hook text from the revelation file describes how the clue should surface; the narrative should reflect that surfacing (in some form — synonymous, restated, or implicit).
     - If a clue is recorded delivered but the session prose has no plausible beat where it could have landed, flag.
   - **LLM judgment; default to no-flag on ambiguity.** Implicit delivery via subagent inference is acceptable.
   - If `dm/revelations/` is empty (zero revelation files): skip with zero findings; emit warning.
   - If no revelation file has entries dated this session: skip with zero findings; no warning.

9. **Check 6 — thread state consistency.** Call `mcp__dm-fs__read_dm_file("threads/active.md")`. Parse the list of currently open threads (their numbers and one-line descriptions). For each `MYTHIC THREAD: opened/closed #N` line in the session log:
   - For `opened #N`: verify thread #N appears in `dm/threads/active.md` with a description that matches the session-log description (content-match, not exact-string-match — descriptions may be reworded between session log and threads file).
   - For `closed #N`: verify thread #N is **absent** from `dm/threads/active.md` (a closed thread should have been removed from the active list).
   - For both: find a narrative beat in the session log that justifies the open/close transition.
   - Flag any mismatch (opened-but-absent, closed-but-still-present) or unsupported state change (no narrative beat justifying the transition).
   - **LLM judgment for content-matching descriptions; default to no-flag on ambiguity** when descriptions plausibly refer to the same thread.
   - If `dm/threads/active.md` doesn't exist: if the session log also has no `MYTHIC THREAD:` lines, skip with zero findings; if the session log has thread state changes but the file doesn't exist, every `opened/closed` line is a discrepancy and gets flagged.

10. **Compose findings.** For each finding from checks 1-6, capture:
    - **Line reference:** 1-based line number in the session log (for line-anchored findings) or the relevant dm/ file (for cross-check findings, use the session log line for the suspect entry when possible).
    - **Suspect text excerpt:** 1-2 sentences from the relevant line, quoted verbatim. If the surrounding context (1-2 lines before/after) clarifies the issue, include it minimally — never more than ~3 lines of context.
    - **Reasoning:** 1-2 sentences explaining why this looked like an anomaly. Reference what was missing (e.g., "no dice line in scene 3 corresponds to this hit") or what triggered the pattern (e.g., "faction history shows clock advanced; prose shows engagement-trigger pattern that should have held the tick"). Never quote raw dm/ content verbatim — synthesize observations.

11. **Append the `## Bookkeeper audit` section** via Edit. Mechanism depends on step 1's detection:

    **Write-fresh path** (no existing audit section detected in step 1):
    - Identify a unique terminal anchor in the file. Typically the last bullet point under `**Loose ends:**` if `## Session-end summary` is present. If no `## Session-end summary` section exists, use the file's last non-empty content line.
    - Verify the anchor is unique within the file. If not unique, include enough preceding context (additional lines) to make the chosen anchor string unique.
    - Call Edit with `old_string` = the unique anchor's exact text, `new_string` = the same anchor text, immediately followed by a blank line, `---`, blank line, `## Bookkeeper audit`, then the audit content per the format below.

    **Re-audit replace path** (step 1 detected an existing `## Bookkeeper audit` section):
    - Two-pass mechanism:
      1. **Truncate.** Construct `old_string` = the full audit-section content from its anchor to end-of-file (i.e., starting with `\n\n---\n\n## Bookkeeper audit\n` and including all of the prior audit). Call Edit with `old_string` = that exact text, `new_string` = empty string. This removes the prior audit section.
      2. **Append.** Re-identify the now-terminal anchor in the truncated file (typically the last `**Loose ends:**` bullet). Call Edit with `old_string` = that anchor, `new_string` = anchor + blank line + `---` + blank line + `## Bookkeeper audit` + new audit content per the format below.

    Audit section format:

    ```markdown
    
    ---
    
    ## Bookkeeper audit
    
    **Audit complete:** <N1> dice-line gap(s), <N2> oracle-call gap(s), <N3> primary-PC overreach candidate(s), <N4> faction tick anomal(ies), <N5> clue delivery anomal(ies), <N6> thread state anomal(ies) flagged.
    
    <If N1+N2+N3+N4+N5+N6 = 0:>
    
    No discipline regressions detected.
    
    <Else, six subsections — include all six even if some have zero findings:>
    
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
    
    ### Faction tick rationale
    
    <Same structure.>
    
    ### Clue delivery confirmation
    
    <Same structure.>
    
    ### Thread state consistency
    
    <Same structure.>
    ```

    Any warnings from step 2 (no primary PC, multiple primary PCs) or the new checks (e.g., empty dm/factions/, MCP error mid-check) go in `**Warning:** ...` line(s) immediately after the audit-complete line.

12. **Return a brief summary** in your response. Include: number of findings per check, whether the audit section was appended (write-fresh) or replaced (re-audit), any warnings. Do not include the full findings list in the response — the persistent record in the session log is the authoritative artifact.

## Edge cases

- **Session log path doesn't exist.** Abort in pre-flight with `"invalid session log path: <path>"`. No writes.
- **Path is not a `sessions/play/<year>/<month>/session-<NNN>.md` file.** Abort. Phase 4 does not audit downtime sessions or other log types.
- **No primary PC file in `party/primary/`.** Emit warning in audit summary; skip check 3; continue with the other five checks.
- **Multiple primary PC files in `party/primary/`.** Emit warning; check 3 matches against all names.
- **Session log has no narrative prose** (all subagent-log lines and headings). Checks 1-3 produce zero findings; checks 4-6 still run against dm/ state.
- **Session log already has a `## Bookkeeper audit` section.** Re-audit replace path activates (Phase 4b behavior); the prior audit is removed via Edit-truncate, then the new audit is appended. Not an abort condition in Phase 4b.
- **Existing `## Bookkeeper audit` section is malformed** (no clear `\n\n---\n\n## Bookkeeper audit\n` anchor). Abort with `"existing audit section is malformed; user must clean up manually before re-audit"`. No writes.
- **Session log has no `## Scene:` markers.** Run checks against the entire log as one scope. Emit warning `**Warning:** session log has no scene markers; checks ran against the full log as a single scope`.
- **`dm/factions/` is empty.** Check 4 produces zero findings; emit warning `**Warning:** no faction files; check 4 produced zero findings vacuously`.
- **`dm/revelations/` is empty.** Check 5 produces zero findings; emit warning analogously.
- **`dm/threads/active.md` doesn't exist.** Check 6 produces zero findings if the session log has no thread state changes; otherwise every `MYTHIC THREAD: opened/closed` line is flagged.
- **Faction/revelation file has no entries dated this session.** Skip that file for the corresponding check; other files still processed. No warning.
- **dm-fs MCP error mid-check.** Surface error in audit summary as `**Warning:** check <N> skipped due to MCP error: <details>`. Other checks proceed.
- **Truncation Edit fails during re-audit replace** (pass 1 of two-pass). Surface error. Session log may be partially modified; user restores via `git restore sessions/play/...`.
- **Append Edit fails after successful truncation** (pass 2 fails). Session log in worse state — prior audit removed but new not yet written. User restores via `git restore` and re-runs.

## What you don't do

- Don't modify narrative prose, subagent-log lines, or the `## Session-end summary` section.
- Don't write to any file other than the session log being audited.
- Don't write to `dm/` via dm-fs MCP. Your MCP access is read-only by discipline; the dm-fs write tools are never invoked.
- Don't read `dm/` paths outside the three approved tiers (`factions/`, `revelations/`, `threads/`). No MCP reads against `modules/`, `npcs/`, or any other dm/ path.
- Don't block commit. Phase 4b is audit-only.
- Don't auto-correct findings. The user decides what to do.
- Don't quote raw `dm/` content verbatim in findings. Synthesize observations.
- Don't preserve the prior audit section on re-audit. Always replace.
- Don't run checks beyond the documented six.
- Don't invoke other subagents.
- Don't commit. The `/session-end` command commits after you return.
END-FILE-CONTENT

- [ ] **Step 3: Verify the file matches the contract**

Run:
```bash
wc -l /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: roughly 200-260 lines.

Run:
```bash
grep -n "^---$\|^name:\|^tools:\|^model:\|^mcpServers:" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md | head -10
```
Expected: two `---` lines (frontmatter open/close), one `name:`, one `tools:`, one `mcpServers:`, one `model:`. **`mcpServers: [dm-fs]` is now present.**

Run:
```bash
grep -n "^## " /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: six top-level sections in this order: `## Read access`, `## Write access`, `## Your contract`, `## Query type: audit-session`, `## Edge cases`, `## What you don't do`.

Run:
```bash
grep -nE "^[0-9]+\. \*\*(Pre-flight|Identify primary PC|Decompose|Check [1-6]|Compose findings|Append|Return)" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: 12 numbered procedure steps (1 pre-flight, 2 identify PC, 3 decompose, 4 check 1, 5 check 2, 6 check 3, 7 check 4, 8 check 5, 9 check 6, 10 compose, 11 append, 12 return).

Run:
```bash
grep -c "mcp__dm-fs__read_dm_file\|mcp__dm-fs__list_dm_dir" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: at least 5 references (checks 4, 5, 6 each invoke read_dm_file and/or list_dm_dir).

Run:
```bash
grep -c "mcp__dm-fs__write_dm_file\|mcp__dm-fs__create_dm_file\|mcp__dm-fs__append_dm_file" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: matches only in the "never invoke" prohibition prose; specifically zero invocation instructions. Acceptable count: 1-3 (each appears once in the "no dm/ writes" disclaimer; verify by reading the matching lines they're in prohibition prose, not procedure prose).

Run:
```bash
grep -c "Faction tick rationale\|Clue delivery confirmation\|Thread state consistency" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: at least 6 (each new check name appears in: the description, the procedure, the audit format template, the `## What you don't do` section). The exact count depends on phrasing variation.

Run:
```bash
grep -c "anomal" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: at least 4 matches (audit-summary template + audit-format placeholders use "anomal(ies)" for the three new check categories).

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add .claude/agents/bookkeeper.md
git commit -m "Rewrite bookkeeper v1 → v2: add subagent-decision audits (Phase 4b)"
```

---

### Task 2: Update CLAUDE.md rule 10 wording

**Files:**
- Modify: `CLAUDE.md`

Phase 4a's rule 10 wording mentions "three checks" and the abort-on-existing-audit behavior. Phase 4b updates it to mention "six checks" and the replace-on-rerun semantic. The second paragraph (about treating the bookkeeper as a session-boundary subagent) gets a small wording update to reflect that Phase 4b still doesn't support ad-hoc invocation (that's Phase 4c).

- [ ] **Step 1: Locate the rule 10 paragraphs**

```bash
grep -n "^### 10\. Bookkeeper audit at session-end\|^## Session log conventions" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: rule 10 at some line N; Session log conventions at some line M > N. Rule 10's content spans the lines between.

- [ ] **Step 2: Apply two Edits**

**Edit 1: Replace rule 10's first paragraph (Phase 4a wording → Phase 4b wording).**

`old_string`:
```
The bookkeeper subagent audits each session log at session-end for narrator-discipline compliance. You do not invoke the bookkeeper during play — `/session-end` invokes it for you between chaos-factor adjustment and commit, with the active session log path as argument. The bookkeeper reads the log, runs three checks (dice-line presence for narrated mechanical outcomes, oracle-call presence for narrated answers to uncertain questions, primary-PC overreach for narrated actions/dialogue attributed to the primary PC), and appends a `## Bookkeeper audit` section to the log. Findings are discipline-tracking signal — they document patterns to review post-session — and do not block the commit in the current phase.
```

`new_string`:
```
The bookkeeper subagent audits each session log at session-end for narrator-discipline and subagent-decision compliance. You do not invoke the bookkeeper during play — `/session-end` invokes it for you between chaos-factor adjustment and commit, with the active session log path as argument. The bookkeeper reads the log and the relevant Phase 2 subagents' `dm/` state via the dm-fs MCP (`dm/factions/`, `dm/revelations/`, `dm/threads/` — read-only), runs six checks (dice-line presence for narrated mechanical outcomes, oracle-call presence for narrated answers to uncertain questions, primary-PC overreach for narrated actions/dialogue attributed to the primary PC, faction tick rationale, clue delivery confirmation, thread state consistency), and appends a `## Bookkeeper audit` section to the log (replacing any pre-existing audit section). Findings are discipline-tracking signal — they document patterns to review post-session — and do not block the commit in the current phase.
```

**Edit 2: Replace rule 10's second paragraph (Phase 4a wording → Phase 4b wording).**

`old_string`:
```
Treat the bookkeeper as a session-boundary subagent like world-state's offscreen-developments tick: invoked by a slash command at the boundary, not by you during play. Do not try to invoke the bookkeeper for ad-hoc audits; Phase 4a does not support that path.
```

`new_string`:
```
Treat the bookkeeper as a session-boundary subagent like world-state's offscreen-developments tick: invoked by a slash command at the boundary, not by you during play. Do not try to invoke the bookkeeper for ad-hoc audits; Phase 4b does not support that path (ad-hoc invocation is Phase 4c).
```

Note: em-dashes (—, U+2014) appear in the new text:
- "the dm-fs MCP (`dm/factions/`, `dm/revelations/`, `dm/threads/` — read-only)"
- "discipline-tracking signal — they document patterns to review post-session — and do not block"

Preserve them exactly.

- [ ] **Step 3: Verify**

```bash
grep -c "runs three checks" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 0 (Phase 4a's "three checks" wording is fully replaced).

```bash
grep -c "runs six checks" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "faction tick rationale, clue delivery confirmation, thread state consistency" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "replacing any pre-existing audit section" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "Phase 4b does not support that path (ad-hoc invocation is Phase 4c)" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "Phase 4a does not support that path" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 0.

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add CLAUDE.md
git commit -m "Update CLAUDE.md rule 10: six checks + replace-on-rerun (Phase 4b)"
```

---

### Task 3: Restart prerequisite checkpoint

**Files:**
- No file changes in this task. Procedural setup.

- [ ] **Step 1: Confirm working tree clean on phase-4b branch**

If not already on a feature branch:
```bash
cd /Users/barriault/dnd/gygaxagain
git checkout -b phase-4b
```

(If the branch was created earlier by the controller, you'll already be on it; `git checkout -b` will fail and that's fine — just confirm with `git branch --show-current`.)

Verify:
```bash
git status
git log --oneline -5
```

Expected: clean working tree on phase-4b branch; recent commits include Tasks 1-2:
1. Update CLAUDE.md rule 10: six checks + replace-on-rerun (Phase 4b) (Task 2)
2. Rewrite bookkeeper v1 → v2: add subagent-decision audits (Phase 4b) (Task 1)
(Plus earlier commits: plan + design.)

- [ ] **Step 2: Restart prerequisite for smoke test**

The bookkeeper subagent's prompt is loaded into the Agent tool's registry at session start. After Task 1's rewrite, the running session does not yet have the v2 prompt loaded; dispatching `Agent(subagent_type="bookkeeper", ...)` would use the v1 prompt (which doesn't have `mcpServers: [dm-fs]` configured, so dm-fs MCP calls would fail).

**For Task 4's smoke test to dispatch the v2 bookkeeper, the user must restart Claude Code.**

This is the same restart constraint Phase 3a/3b/3c/3d/3e/4a hit. Signal to the user (or to the executing subagent's controller) that a restart is required before proceeding to Task 4.

No commit for this task — procedural checkpoint.

---

### Task 4: Smoke test — bookkeeper v2 re-audit of `session-005.md` (post-restart)

**Files:**
- Modified by the smoke test: `sessions/play/2026/05/session-005.md` (the bookkeeper replaces its Phase 4a `## Bookkeeper audit` section with the v2 six-check audit).

**Prerequisite:** the user has restarted Claude Code after Tasks 1-2 committed, so the v2 bookkeeper subagent is loaded in the Agent registry with `mcpServers: [dm-fs]` configured.

- [ ] **Step 1: Verify pre-conditions**

```bash
cd /Users/barriault/dnd/gygaxagain
git status
git log --oneline -5
git branch --show-current
```

Expected: clean working tree on phase-4b branch; Tasks 1-2 commits present.

Verify session-005.md exists and has the Phase 4a audit section to be replaced:
```bash
ls -la sessions/play/2026/05/session-005.md
grep -c "^## Bookkeeper audit" sessions/play/2026/05/session-005.md
```
Expected: file exists; grep returns 1 (the Phase 4a audit section is present).

Verify primary PC file:
```bash
ls party/primary/
```
Expected: at least one `*.md` file (e.g., `dagnal.md`).

Verify the three dm/ tiers are populated:
```bash
ls dm/factions/ 2>&1 || echo "(may be denied; the bookkeeper will check via dm-fs MCP)"
ls dm/revelations/ 2>&1 || echo "(may be denied; the bookkeeper will check via dm-fs MCP)"
ls dm/threads/ 2>&1 || echo "(may be denied; the bookkeeper will check via dm-fs MCP)"
```
Expected: either the directory listings succeed showing populated dirs, or they fail with permission denied (in which case the bookkeeper will list via MCP).

- [ ] **Step 2: Dispatch the bookkeeper with audit-session**

In the active Claude Code session (post-restart), dispatch:

```
Agent(subagent_type="bookkeeper", prompt="Audit session sessions/play/2026/05/session-005.md.")
```

The bookkeeper:
- Verifies the path; reads `sessions/play/2026/05/session-005.md`.
- Detects the existing `## Bookkeeper audit` section; identifies the anchor.
- Globs `party/primary/`; identifies `dagnal`.
- Decomposes the log (excluding the prior audit section) into prose vs subagent-log lines.
- Runs checks 1-3 (narrator-discipline trio).
- Calls `mcp__dm-fs__list_dm_dir("factions")` + per-faction `read_dm_file` for check 4.
- Calls `mcp__dm-fs__list_dm_dir("revelations")` + per-revelation `read_dm_file` for check 5.
- Calls `mcp__dm-fs__read_dm_file("threads/active.md")` for check 6.
- Composes findings.
- Truncates the file at the prior audit-section anchor (Pass 1 of replace path).
- Writes the new six-check audit section (Pass 2 of replace path).
- Returns a brief summary.

- [ ] **Step 3: Verify the response**

The bookkeeper's response should include:
- A brief summary line/sentence.
- Per-check counts (e.g., "Check 1: 0 findings. Check 2: 0 findings. Check 3: 0 findings. Check 4: 1 finding. Check 5: 0 findings. Check 6: 0 findings.")
- Confirmation that the audit section was REPLACED (re-audit path), not appended.
- Any warnings (e.g., from check 4/5 if dm/factions/ or dm/revelations/ have unexpected state).

The response should NOT include the full findings list — those live in the session log.

- [ ] **Step 4: Verify the session log was modified correctly**

```bash
grep -c "^## Bookkeeper audit" sessions/play/2026/05/session-005.md
```
Expected: exactly 1 (the prior audit was replaced, not duplicated).

```bash
git diff sessions/play/2026/05/session-005.md
```
Expected: the diff shows the Phase 4a audit content being removed and the v2 audit content being added. The non-audit content (narrative prose, subagent log lines, `## Session-end summary`) is unchanged byte-for-byte.

Tail the file to see the new audit:
```bash
tail -50 sessions/play/2026/05/session-005.md
```

Verify the new audit:
- Starts with `---` separator after a blank line (after the `## Session-end summary` and Loose ends section).
- Has `## Bookkeeper audit` heading.
- Has `**Audit complete:**` summary line with **six** counts (dice-line, oracle-call, PC-overreach, faction-tick, clue-delivery, thread-state).
- If counts are all zero: contains the literal text `No discipline regressions detected.`
- Otherwise: contains six subsections `### Dice-line gaps`, `### Oracle-call gaps`, `### Primary-PC overreach`, `### Faction tick rationale`, `### Clue delivery confirmation`, `### Thread state consistency`. Each subsection has findings (`- **Line <NNN>:** ...` format) or `- (none)`.

```bash
git status
```
Expected: only `sessions/play/2026/05/session-005.md` shown as modified.

- [ ] **Step 5: Verify dm-fs access log shows expected reads, zero writes**

```bash
tail -30 /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log
```

Expected new entries (post-restart timestamps):
- `list_dm_dir factions` (1 entry)
- `read_dm_file factions/ashen-vintners.md` (1 entry)
- `read_dm_file factions/cult-of-myrkul.md` (1 entry)
- `list_dm_dir revelations` (1 entry)
- `read_dm_file revelations/r-001.md` (1 entry)
- `read_dm_file revelations/r-002.md` (1 entry)
- `read_dm_file revelations/r-003.md` (1 entry)
- `read_dm_file revelations/r-004.md` (1 entry)
- `read_dm_file revelations/r-005.md` (1 entry)
- `read_dm_file threads/active.md` (1 entry)

**Zero** `create_dm_file`, `write_dm_file`, `append_dm_file` entries from the bookkeeper post-restart.

**Zero** reads against `modules/`, `npcs/`, or any other path outside the three approved tiers.

- [ ] **Step 6: Asymmetry probe — narrator still cannot read dm/ paths**

Run the standard relative-path probes (these should all be denied):
```bash
cd /Users/barriault/dnd/gygaxagain && cat dm/factions/cult-of-myrkul.md 2>&1 | head -1
cd /Users/barriault/dnd/gygaxagain && cat dm/revelations/r-001.md 2>&1 | head -1
cd /Users/barriault/dnd/gygaxagain && cat dm/threads/active.md 2>&1 | head -1
cd /Users/barriault/dnd/gygaxagain && cat dm/modules/ancient-tomb-of-phandalin/secrets.md 2>&1 | head -1
```
Expected: all four denied (Phase 3a/3d/3e + Phase 2c boundaries hold for the narrator; bookkeeper MCP access doesn't weaken them).

Verify Phase 3c lore boundary holds:
```bash
cd /Users/barriault/dnd/gygaxagain && cat library/lore/test-bestiary/entries/goblin.md 2>&1 | head -3
```
Expected: file content displays.

- [ ] **Step 7: User reviews findings**

The user reads the appended `## Bookkeeper audit` section directly:
```bash
sed -n '/^## Bookkeeper audit/,$p' sessions/play/2026/05/session-005.md
```

For each finding, judge:
- **True positive:** real discipline issue worth tightening in future sessions or a real anomaly in subagent-decision tracking.
- **False positive:** the bookkeeper was too aggressive; the pattern matched but the underlying behavior was actually fine.
- **Borderline:** the bookkeeper's reasoning is plausible but signal/noise is unclear.

False positives are acceptable and expected in Phase 4b for the new checks (4, 5, 6) since they involve LLM judgment across narrative + dm/ state. The smoke test passes as long as:
- The audit section is in the documented format with six subsections (or zero-findings literal).
- Findings (if any) have plausible reasoning, not nonsense.
- The replace-on-rerun path completed cleanly (exactly one `## Bookkeeper audit` section in the file).
- dm-fs access log shows only reads to the three approved tiers; zero writes.

- [ ] **Step 8: Commit the smoke-test artifact**

```bash
cd /Users/barriault/dnd/gygaxagain
git add sessions/play/2026/05/session-005.md
git commit -m "Phase 4b smoke test: bookkeeper v2 re-audit of session-005"
```

---

### Task 5: Optional secondary smoke test (write-fresh path) + asymmetry audit + regression tests

**Files:**
- Optionally modified: `sessions/play/2026/05/session-004.md` (or revert via `git restore`).
- No other file changes in this task.

This task validates the write-fresh path (no existing audit) and runs the standard end-of-phase verifications. The secondary smoke test is optional but recommended for confidence; if skipped, the asymmetry audit and regression tests still run.

- [ ] **Step 1: Run the existing test suite**

```bash
cd /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q 2>&1 | tail -5
```

Expected: `37 passed`. Phase 4b adds no Python code; the existing tests must continue to pass unchanged.

- [ ] **Step 2: Optional secondary smoke test — write-fresh path on session-004**

Skip this step if you want to keep the secondary smoke test for a separate session, or if session-004 is in active use.

If you want to validate the write-fresh path, dispatch:

```
Agent(subagent_type="bookkeeper", prompt="Audit session sessions/play/2026/05/session-004.md.")
```

Verify:
- The bookkeeper appended (not replaced — session-004 had no prior audit) a `## Bookkeeper audit` section.
- The section format matches v2 (six counts; six subsections or zero-findings literal).
- `grep -c "^## Bookkeeper audit" sessions/play/2026/05/session-004.md` returns 1.
- dm-fs access log shows additional reads against factions/, revelations/, threads/.

After verification, either:
- **Commit:** `git add sessions/play/2026/05/session-004.md && git commit -m "Phase 4b secondary smoke test: bookkeeper v2 fresh audit of session-004"`. This commits the secondary test artifact.
- **Revert:** `git restore sessions/play/2026/05/session-004.md` to discard the secondary test artifact.

- [ ] **Step 3: Asymmetry audit — dm-fs access log review**

```bash
grep -E "factions|revelations|threads/active" /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log | tail -30
```

Verify post-restart bookkeeper entries (timestamps after Task 4's smoke test):
- `list_dm_dir factions` — at least 1 entry from Task 4 (plus 1 more if Task 5 Step 2 ran).
- `read_dm_file factions/<slug>.md` — one entry per faction file per smoke test.
- `list_dm_dir revelations` — at least 1 entry.
- `read_dm_file revelations/r-NNN.md` — one entry per revelation per smoke test.
- `read_dm_file threads/active.md` — at least 1 entry.
- **Zero `create_dm_file`, `write_dm_file`, `append_dm_file` entries from the bookkeeper.**

```bash
grep -E "modules|npcs" /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log | tail -10
```
Expected: any entries here are from the librarian or world-state subagents (not from the bookkeeper). The bookkeeper must NOT have read `dm/modules/` or `dm/npcs/` post-restart. If you see bookkeeper-attributable entries in modules/ or npcs/, that's a discipline regression — block the merge and fix the bookkeeper prompt.

(Note: the access log doesn't tag entries by subagent name; you have to infer from timestamps and surrounding operations. Phase 4b's bookkeeper operations cluster around the smoke test invocation timestamp.)

- [ ] **Step 4: Bookkeeper file discipline checks**

```bash
grep -n "mcp__dm-fs__write_dm_file\|mcp__dm-fs__create_dm_file\|mcp__dm-fs__append_dm_file" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: matches only in `## What you don't do` prohibitions (verify by reading the matched lines — they should be in the "never invoke" disclaimer). No procedure-instructions to invoke these tools.

```bash
grep -n "dm/modules\|dm/npcs" /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md
```
Expected: matches only in the "no access" / "don't read" prohibitions (verify by reading the matched lines).

```bash
grep -nE "^[0-9]+\. " /Users/barriault/dnd/gygaxagain/.claude/agents/bookkeeper.md | head -15
```
Expected: 12 numbered procedure steps (1-12).

- [ ] **Step 5: No commit needed**

This task is verification only (unless the optional Step 2 ran and committed).

---

### Task 6: Update CLAUDE.md `## Current phase scope` to Phase 4b

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Locate the current-phase-scope paragraph**

```bash
grep -n "Current phase scope\|^As of Phase 4a" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

The section currently reflects Phase 4a. Replace it with a Phase 4b version.

- [ ] **Step 2: Update via Edit**

Read the file to find the exact existing text. The Phase 4a paragraph starts with "The engine is being built incrementally. As of Phase 4a, you have:" and ends with "...note it in the session log under `## Notes for later phases` rather than improvising it."

Use Edit on `/Users/barriault/dnd/gygaxagain/CLAUDE.md`.

`old_string`: the entire Phase 4a paragraph.

`new_string`: the entire Phase 4b paragraph below. Substantive changes:
- "As of Phase 4a" → "As of Phase 4b".
- The MVP-bookkeeper clause "an MVP bookkeeper subagent that audits each session log at session-end for narrator-discipline compliance (dice-line presence, oracle-call presence, primary-PC overreach) — invoked by `/session-end` per rule 10, findings appended to the session log under `## Bookkeeper audit`, commit is not blocked (Phase 4a)." extends to mention the new subagent-decision audits and the dm-fs read access.
- "Phase 4a establishes the bookkeeper artifact for narrator-discipline audit." → updated to mention 4b's expansion.
- Deferred list: remove "deeper subagent-decision audits — faction tick rationale, clue delivery confirmations, thread state, intake decisions (Phase 4b)" (these landed in 4b); keep "intake decisions" and add it to a Phase 4c bucket; keep "live-write integrity audits (Phase 4b)" → bump to Phase 4c.

Full Phase 4b paragraph (`new_string`):

```
The engine is being built incrementally. As of Phase 4b, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), module intake via `/intake` + the librarian subagent with all module content dm-quarantined (Phase 3a), runtime librarian queries `consult-library` and `reveal-from-module` per rule 9 (Phase 3b), lore-reference intake via the librarian's `intake-lore` query with narrator-readable library/lore/ entries (Phase 3c), revelation auto-proposals from module material — the librarian writes `dm/revelations/r-NNN.md` seed files for reveal candidates found in a module's secrets.md, either during `intake-module` or via the standalone `propose-revelations <slug>` query (Phase 3d), faction auto-proposals from module material — the librarian writes `dm/factions/<faction-slug>.md` seed files for faction candidates found in a module's overview/secrets/connections content (defaulting to `status: dormant` so they're inert under the world-state subagent's offscreen tick until reviewed and flipped active), either during `intake-module` or via the standalone `propose-factions <slug>` query (Phase 3e), an MVP bookkeeper subagent that audits each session log at session-end for narrator-discipline compliance — dice-line presence, oracle-call presence, primary-PC overreach (Phase 4a), and a six-check bookkeeper that extends the trio with subagent-decision audits — faction tick rationale, clue delivery confirmation, thread state consistency — by reading `dm/factions/`, `dm/revelations/`, `dm/threads/` via the dm-fs MCP (read-only), with replace-on-rerun re-audit semantics so audits can be refreshed as the bookkeeper's logic improves (Phase 4b). The Phase 2 hidden-state arc is closed; Phase 3a/3b/3c/3d/3e together make module ingest, runtime module consultation, lore-reference intake, and revelation+faction seed-writing from modules work end-to-end; Phase 4a/4b establish the bookkeeper artifact and extend it through narrator-discipline and subagent-decision audits. You **do not** yet have: live-write integrity audits (Phase 4c), intake-decision audits — was the librarian's reveal-vs-flavor judgment sound (Phase 4c), library-bypass detection and structural-change proposals — NPC promotion, faction cascades, source-overlap merges (Phase 4c), ad-hoc bookkeeper invocation `/audit-session` slash command and re-audit mode flags beyond always-replace (Phase 4c), authoring formalization — NPC system, milestone authoring, hand-authoring helpers (Phase 4d), additional lint rules and cross-session aggregate roll-up (Phase 4d–4e), solo-engine/methodology/gazetteer-essay intake (Phase 3f), URL ingestion (Phase 3f), curated `consult-lore` runtime query (Phase 3f if needed), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or the full bookkeeper completing Phase 4c–4e duties. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.
```

Note the em-dashes (—, U+2014) in:
- "Mythic random-event composition — thread spotlight..."
- "faction auto-proposals from module material — the librarian writes..."
- "...narrator-discipline compliance — dice-line presence, oracle-call presence, primary-PC overreach (Phase 4a), and..."
- "...extends the trio with subagent-decision audits — faction tick rationale, clue delivery confirmation, thread state consistency — by reading..."
- "intake-decision audits — was the librarian's reveal-vs-flavor judgment sound (Phase 4c)"
- "library-bypass detection and structural-change proposals — NPC promotion..."
- "authoring formalization — NPC system..."

Preserve all em-dashes exactly. Use the string character-for-character.

- [ ] **Step 3: Verify**

```bash
grep -c "As of Phase 4b" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "As of Phase 4a" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 0.

```bash
grep -c "a six-check bookkeeper that extends the trio" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "completing Phase 4c–4e duties" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 1.

```bash
grep -c "completing Phase 4b–4e duties" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 0 (the Phase 4a wording is updated since 4b is now in the shipped list).

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add CLAUDE.md
git commit -m "Update CLAUDE.md current-phase-scope to Phase 4b"
```

---

### Task 7: Final integration sanity check + merge

**Goal:** Confirm Phase 4b invariants and merge phase-4b → main.

- [ ] **Step 1: Inspect git history**

```bash
cd /Users/barriault/dnd/gygaxagain
git log --oneline -10
```

Expected commits on phase-4b branch (most recent first), in this order:
1. Update CLAUDE.md current-phase-scope to Phase 4b (Task 6)
2. Phase 4b smoke test: bookkeeper v2 re-audit of session-005 (Task 4 step 8)
3. (Optional: Phase 4b secondary smoke test, if Task 5 step 2 ran and committed)
4. Update CLAUDE.md rule 10: six checks + replace-on-rerun (Phase 4b) (Task 2)
5. Rewrite bookkeeper v1 → v2: add subagent-decision audits (Phase 4b) (Task 1)
6. (Earlier:) Add Phase 4b implementation plan
7. (Earlier:) Add Phase 4b design: bookkeeper subagent-decision audits

- [ ] **Step 2: Working tree clean**

```bash
git status
```
Expected: clean.

- [ ] **Step 3: DOD checklist**

Cross-check against the Phase 4b spec's `## Definition of done`:

- [ ] Bookkeeper v2 frontmatter has `mcpServers: [dm-fs]` and updated description.
- [ ] `## Read access` extends to three dm/ tiers (`dm/factions/`, `dm/revelations/`, `dm/threads/`) via dm-fs MCP.
- [ ] `## Write access` unchanged (session log only via Edit; explicit prohibition on dm/ MCP writes).
- [ ] Three new audit checks (4, 5, 6) in the procedure for faction tick rationale, clue delivery confirmation, thread state consistency.
- [ ] Replace-on-rerun re-audit semantic (always-replace; no flag, no abort).
- [ ] Audit-section format extended with three new subsections; audit-complete summary line has six counts.
- [ ] CLAUDE.md rule 10 updated to mention six checks and replace-on-rerun.
- [ ] CLAUDE.md `## Current phase scope` updated to Phase 4b.
- [ ] Smoke test re-audited session-005.md cleanly (exactly one `## Bookkeeper audit` section; replace path completed).
- [ ] dm-fs access log shows bookkeeper reads against the three approved tiers; zero bookkeeper-issued writes; zero reads outside the three tiers.
- [ ] All 37 existing dm-fs MCP tests pass.
- [ ] No new MCP tools, no Python code added, no schema changes.
- [ ] No new slash command.
- [ ] No `/session-end` changes.
- [ ] Narrator-side `dm/` denies intact (asymmetry probes still deny).

- [ ] **Step 4: Merge phase-4b → main**

```bash
cd /Users/barriault/dnd/gygaxagain
git checkout main
git merge --no-ff phase-4b -m "Merge phase-4b: bookkeeper subagent-decision audits"
git branch -d phase-4b
git log --oneline -8
```

Expected: clean merge with merge commit; phase-4b branch deleted; merge commit and constituent commits visible at top of `git log`.

---

## Notes for executors

- **Session restart required between Task 1 and Task 4.** The bookkeeper subagent's prompt is loaded into the Agent tool's registry at session start. After Task 1 rewrites the file, the running session still has the v1 prompt cached (without `mcpServers: [dm-fs]`). Tasks 2 and 3 can run in the same session as Task 1; Task 4 (smoke test) requires the user to restart Claude Code so the v2 prompt loads with MCP access.

- **The smoke test re-audits an existing committed session log.** Session-005's prior Phase 4a audit section will be replaced by the v2 audit. This is the test artifact — replacing the audit cleanly proves both the new checks and the replace-on-rerun path work. The user can `git restore sessions/play/2026/05/session-005.md` if they want to revert before merging; but the smoke test artifact is the proof of end-to-end success and should normally be committed.

- **False positives are acceptable for the new checks.** Phase 4b's checks 4, 5, 6 involve LLM judgment across narrative + dm/ state. Some false positives are expected. The smoke test passes if the audit is well-formed and findings have plausible reasoning — not if every finding is a true anomaly. Phase 4c+ tunes prompt judgment as more session data accumulates.

- **Read-only dm-fs MCP discipline is the key boundary.** The bookkeeper has `mcpServers: [dm-fs]` and the MCP exposes write tools (`mcp__dm-fs__write_dm_file`, `mcp__dm-fs__create_dm_file`, `mcp__dm-fs__append_dm_file`). The bookkeeper's prompt forbids invoking these. Task 5's asymmetry audit verifies via the dm-fs access log that zero write operations are attributable to the bookkeeper. If a regression caused the bookkeeper to write to dm/, the access log would surface it.

- **The two-pass replace mechanism is the discipline boundary for re-audit.** Pass 1 truncates the prior audit section via Edit; Pass 2 appends the new audit section. If Pass 1 succeeds but Pass 2 fails, the session log is in an intermediate state (prior audit removed, new not yet written). User restores via `git restore` and re-runs.

- **The bookkeeper's MCP access is prompt-disciplined, not MCP-configured.** The dm-fs MCP exposes all dm/ paths; the bookkeeper's prompt is the only barrier preventing reads against `dm/modules/`, `dm/npcs/`, etc. If the bookkeeper's discipline regresses (e.g., a future revision reads `dm/modules/<slug>/secrets.md`), the dm-fs access log captures the violation but doesn't prevent it. Future phases may add path filtering at the MCP layer if this becomes a real risk.

- **Session-005's Phase 4a audit had zero findings.** The Phase 4b re-audit may find new anomalies in checks 4, 5, 6 (which weren't run in Phase 4a) but should still find zero in checks 1, 2, 3 (since the narrative content is unchanged). If checks 1-3 produce different findings in v2 than v1, the v2 prompt's check 1-3 logic regressed — investigate before merging.

- **Editing the existing audit section anchor.** The Phase 4a smoke test wrote the audit section using a specific anchor pattern (`\n\n---\n\n## Bookkeeper audit\n`). The Phase 4b bookkeeper's pre-flight detection logic must match this pattern. Verify by reading session-005's existing audit section to confirm the anchor format before relying on it.
