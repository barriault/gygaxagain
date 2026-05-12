# Phase 4a — MVP Bookkeeper Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Phase 2b spec:** `docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md`.
**Phase 2c spec:** `docs/superpowers/specs/2026-05-10-phase-2c-mythic-threads-design.md`.
**Phase 2d spec:** `docs/superpowers/specs/2026-05-10-phase-2d-mythic-event-spotlight-design.md`.
**Phase 3a spec:** `docs/superpowers/specs/2026-05-10-phase-3a-source-ingestion-modules-design.md`.
**Phase 3b spec:** `docs/superpowers/specs/2026-05-11-phase-3b-runtime-librarian-queries-design.md`.
**Phase 3c spec:** `docs/superpowers/specs/2026-05-11-phase-3c-lore-reference-intake-design.md`.
**Phase 3d spec:** `docs/superpowers/specs/2026-05-11-phase-3d-revelation-auto-proposals-design.md`.
**Phase 3e spec:** `docs/superpowers/specs/2026-05-11-phase-3e-faction-auto-proposals-design.md`.
**Slice of original Phase 4:** the MVP bookkeeper — establishes the subagent artifact, integrates with `/session-end`, performs three narrator-discipline audits as a minimum viable verification pass. Subagent-decision audits (faction tick rationale, clue delivery confirmations, thread state, intake calls, library-bypass detection), structural-change proposals (NPC promotion, faction cascades, source-overlap merges), authoring formalization (NPC system, milestone authoring, hand-authoring helpers), additional lint rules, bookkeeper-owned commit discipline, cross-session aggregate roll-up, and ad-hoc audit slash commands all deferred to Phase 4b+.

## Purpose

Phase 1's `/session-end` slash command explicitly notes: *"Phase 1 does not run a bookkeeper verification phase — that lands in Phase 4. The working-tree-as-committed is trusted as the session record."* Phase 2a, 2b, 2c, 3a similarly defer audit-trail formalization, verification of subagent decisions, and structural-change proposals to "Phase 4 bookkeeper." After Phase 3a/3b/3c/3d/3e shipped the module/lore intake + auto-propose pipeline, the bookkeeper is the last major outstanding subagent in the engine's architecture.

Phase 4 as originally scoped is large — SPEC.md's bookkeeper duties include session-end verification across all subagent-write paths, commit discipline, structural-change proposals, authoring formalization, linting, and NPC-system ownership. That's too much for a single phase. Phase 4 follows the Phase 2 and Phase 3 pattern of sub-phases: Phase 4a is the MVP bookkeeper; 4b adds deeper subagent-decision audits; 4c adds structural-change proposals; 4d adds authoring formalization; 4e adds remaining lint rules.

Phase 4a's load-bearing claim is twofold:

1. **The bookkeeper subagent artifact ships and integrates cleanly with `/session-end`.** It is invoked from the slash command between chaos-factor adjustment and commit; it reads the session log and produces a `## Bookkeeper audit` section appended to that log; the commit proceeds unconditionally regardless of findings.

2. **The narrator-discipline trio produces useful audit signal on real session data.** Each of the three checks (dice-line presence for narrated mechanical outcomes, oracle-call presence for narrated answers to uncertain questions, primary-PC overreach detection) fires on plausible patterns and surfaces them with clear reasoning. False positives are acceptable in Phase 4a; pattern-tuning happens in subsequent sub-phases as audit signal/noise becomes clearer.

Both claims validated by smoke-testing against the existing `sessions/play/2026/05/session-005.md` plus a slash-command contract check.

After Phase 4a, the bookkeeper exists as a foundational artifact; Phase 4b+ extends its audit reach.

## Definition of done

A successful Phase 4a build demonstrates all of:

- **New `.claude/agents/bookkeeper.md` subagent file** with frontmatter (name, description, tools, model), intro paragraph, `## Read access`, `## Write access`, `## Your contract`, `## Query type: audit-session`, `## Edge cases`, `## What you don't do` sections.

- **Bookkeeper tools:** `Read, Edit, Glob, Bash`. No `mcpServers` (no dm-fs access in Phase 4a — all audits are narrator-readable-scope-equivalent operations).

- **Bookkeeper read access:** `sessions/`, `party/`, `library/`, `world/` readable directly via Read and Glob. **No `dm/` access** (project-level denies apply; bookkeeper does not have MCP access). Phase 4b+ may extend this.

- **Bookkeeper write access:** `sessions/play/YYYY/MM/session-NNN.md` writable via Edit, only for appending the `## Bookkeeper audit` section. No other writes anywhere — not to dm/, not to library/, not to party/, not to world/, not to other sessions/ files.

- **One query type: `audit-session <session-log-path>`.** Procedure: pre-flight path validation; identify primary PC via `Glob("party/primary/*.md")`; decompose log into prose vs subagent-log lines; run three checks in order; compose findings; Edit the session log to append the `## Bookkeeper audit` section. Returns a brief summary in the response; persistent findings live in the appended section.

- **Audit section format** (documented exactly in the bookkeeper prompt):
  - Append-blank-line + `---` separator + blank line + `## Bookkeeper audit` heading.
  - Audit-summary line: `**Audit complete:** <N> dice-line gaps, <N> oracle-call gaps, <N> primary-PC overreach candidates flagged.`
  - If all three counts are zero: literal text `No discipline regressions detected.` and no subsections.
  - Otherwise: three `### <check name>` subsections — `### Dice-line gaps`, `### Oracle-call gaps`, `### Primary-PC overreach` — each with zero or more findings of the form: `**Line <NNN>:** "<suspect text excerpt, 1-2 sentences>"` followed by `Reasoning: <1-2 sentences>`.

- **`/session-end` modified** to insert a new step between the existing chaos-factor-adjust step (step 3) and the existing git-commit step. New step invokes the bookkeeper with `"Audit session <active-session-log-path>."` Findings are surfaced in the bookkeeper's response and persisted in the log; commit proceeds unconditionally.

- **CLAUDE.md rule 10 added** under `## Routing rules`, after rule 9, documenting bookkeeper invocation discipline. The rule clarifies that the narrator does not invoke the bookkeeper directly during play; `/session-end` invokes it. Findings are discipline-tracking signal, not blocking.

- **Smoke test:** bookkeeper dispatched directly against `sessions/play/2026/05/session-005.md` produces an audit section conforming to the documented format. Findings (if any) are plausible — false positives acceptable; obvious nonsense indicates the prompt needs tightening before merge.

- **Slash command contract check:** the modified `.claude/commands/session-end.md` contains the new bookkeeper-invocation step between chaos-adjust and commit; step numbering is consistent.

- All 87 existing tests continue to pass; no Python code added.

- **No new MCP tools.** No `mcpServers` on the bookkeeper. No `.claude/settings.json` deny-rule changes.

- **No new slash command** for ad-hoc audits in Phase 4a (no `/audit-session`).

## Out of scope (deferred to Phase 4b+)

- **Live-write integrity audit.** Working-tree diff vs session log consistency check — does every state change in the diff trace back to a narrative event in the log? Phase 4b. Requires reading `dm/` content via dm-fs MCP for cross-checking faction history appends, revelation `## Delivered` entries, thread file mutations.
- **Subagent decision audits.** Faction tick rationale audit (did world-state advance/hold clocks correctly given the session prose?), clue delivery confirmation audit (did revelation confirm clues that actually landed?), thread state audit (do open/close calls match the session narrative?), intake decision audit (did the librarian's reveal-vs-flavor judgment for revelation auto-proposals make sense?). Phase 4b–4c.
- **Library-bypass detection.** Narrator improvised content where a librarian module already covers the scope. Phase 4c.
- **Structural-change proposals.** NPC promotion candidates (party encountered NPC repeatedly → promote to `party/companions/`), faction cascade candidates (on-clock-filled with follow-on operation suggestion), source-overlap merges (librarian intake flagged module overlap with existing campaign content). Phase 4c.
- **Authoring formalization.** `/author-npc`, `/author-milestone`, hand-authoring helpers for refining auto-proposed faction ladders / clue vectors. Phase 4d. Note: Phase 3d/3e auto-proposals already cover revelation+faction seed-writing; the remaining authoring slice is narrower than originally scoped in earlier specs.
- **Additional lint rules.** Hook text leaking revelation phrasing (Phase 2b deferral); naked thread number references in narration (Phase 2d deferral); narration patterns indicating discipline regression beyond the trio. Phase 4d–4e.
- **Bookkeeper write access to `dm/`.** No audit findings persisted to dm/; no auto-correction of subagent state. Phase 4b extends read access via MCP; write access to dm/ may never be added (auto-correction is risky discipline).
- **Blocking commit on findings.** Phase 4a is audit-only. Phase 4b–4c may introduce opt-in blocking for high-severity findings; the default remains "audit, don't enforce."
- **Cross-session aggregate roll-up.** `sessions/audits/index.md` with per-check counts across sessions for pattern detection. Phase 4b or 4d.
- **Bookkeeper-owned commit discipline.** Phase 4a leaves `git add -A && git commit` in `/session-end` (managed by the slash command, not the bookkeeper). The bookkeeper-as-commit-author pattern from SPEC.md (`## Save during play; commit at session end`) is Phase 4b+ work.
- **Ad-hoc bookkeeper invocation.** No `/audit-session <path>` slash command in 4a. Bookkeeper is reachable only through `/session-end`. Phase 4b may add ad-hoc invocation for re-audits, dry-runs, and historical audits.
- **Re-audit of an already-audited session.** Phase 4a aborts if the session log already has a `## Bookkeeper audit` section. Phase 4b may add re-audit semantics (replace, append, or merge).
- **NPC system.** Phase 4 was originally scoped to include NPC tier authoring (`dm/npcs/` + public stubs). Deferred to Phase 4d or a dedicated NPC phase.
- **Library/lore content used in audits.** Bookkeeper has read access to library/ and world/ but Phase 4a's three checks don't use them. Phase 4b–4c will use library content for library-bypass detection.
- **Companion read scope.** Phase 4a's primary-PC check is against `party/primary/<name>.md` only. Companions and NPC party members in `party/companions/` and `party/npcs/` are out of scope. Phase 4b extends companion-overreach detection.

## Architecture

### Slice mapping

| Component                          | Phase 4a touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | `CLAUDE.md` gains rule 10 under `## Routing rules` documenting bookkeeper invocation. No behavioral change during play — the narrator never invokes the bookkeeper directly. |
| **Bookkeeper subagent**            | **NEW** — `.claude/agents/bookkeeper.md`. Full subagent definition with one query type. |
| Dice subagent                      | Untouched. Its `- /roll ...` and `DICE:` session-log lines are an input to the bookkeeper's check 1. |
| Mythic subagent                    | Untouched. Its `- ORACLE:` and `- MYTHIC:` session-log lines are inputs to check 2. |
| World-state subagent               | Untouched. Out of audit scope in 4a. |
| Revelation subagent                | Untouched. Out of audit scope in 4a. |
| Librarian subagent                 | Untouched. Out of audit scope in 4a. |
| **`/session-end` command**         | **MODIFIED** — `.claude/commands/session-end.md`. New step between existing chaos-adjust (step 3) and existing git-commit (step 4) invokes the bookkeeper. Subsequent steps renumber. |
| Other slash commands               | Untouched. |
| `dm-fs` MCP                        | No tool changes, no new access. Bookkeeper does not use dm-fs MCP in Phase 4a. |
| `.claude/settings.json`            | No deny-rule changes. |
| Repository layout                  | No new directories. Audit findings live in existing `sessions/play/YYYY/MM/session-NNN.md` files under a new `## Bookkeeper audit` section appended at session-end. |

### Information-asymmetry preservation

**No new tiers introduced.** Phase 4a operates entirely on narrator-readable content:

- Bookkeeper reads `sessions/`, `party/`, `library/`, `world/` — the same scope the narrator has.
- Bookkeeper writes only to `sessions/play/YYYY/MM/session-NNN.md` via Edit, appending the audit section.
- **No `dm/` access** in Phase 4a — neither read nor write. The audits are about narrator behavior, which lives in narrator-readable content. Phase 4b+ may extend read access to `dm/` via MCP for subagent-decision audits.
- The `## Bookkeeper audit` section is player-readable by the same convention as the rest of the session log. There is no hidden-state quarantine for audit findings — they are discipline-tracking artifacts, not GM-side secrets.

The asymmetry boundary holds because:

- `dm/**` denies in `.claude/settings.json` stay in place. The bookkeeper has no need to bypass them in 4a.
- The bookkeeper sees what the narrator wrote into session logs; it does not see what world-state, revelation, or librarian wrote into `dm/`. That's a deliberate scope decision — auditing those subagents' decisions is Phase 4b.
- The bookkeeper has no privilege escalation vs the narrator — both have narrator-scope read access; the bookkeeper additionally has Edit access to a specific session log file (which the narrator also has, per Phase 1's session log convention).

### Integration with prior phases

- **Phase 1 (MVP session):** `/session-end` existed and explicitly noted "Phase 4 introduces verification." Phase 4a fulfills that contract by inserting the bookkeeper-invocation step between chaos-adjust and commit. The session log convention (append-only during play; `## Session-end summary` appended at session-end) is preserved — the bookkeeper's `## Bookkeeper audit` section is another append at session-end.
- **Phase 2a (factions):** the world-state subagent continues to produce `- WORLD-STATE QUERY:` lines in the session log. The bookkeeper recognizes these as subagent-log lines (not narrative prose) during decomposition. Faction-tick rationale auditing is deferred to Phase 4b.
- **Phase 2b (revelations):** the revelation subagent continues to produce `- REVELATION:` lines. Same treatment — recognized as subagent-log, not prose. Clue-delivery audit is Phase 4b.
- **Phase 2c (threads), 2d (Mythic-event spotlight):** mythic subagent's `- MYTHIC:` and `- ORACLE:` lines are inputs to check 2 (oracle-call presence). Thread state audit is Phase 4b.
- **Phase 3a–3e:** librarian's `- LIBRARIAN QUERY:` session-log lines are recognized as subagent-log. Library content (library/lore/) is in the bookkeeper's read scope but not used by 4a's checks. Library-bypass detection is Phase 4c.

## Component designs

### Bookkeeper subagent (`.claude/agents/bookkeeper.md`)

Frontmatter:
```yaml
---
name: bookkeeper
description: Audits the session log at session-end for narrator-discipline compliance. One query type — audit-session (scans the log for narrated mechanical outcomes without dice lines, narrated answers to uncertain questions without oracle calls, and narrated actions attributed to the primary PC, then appends a ## Bookkeeper audit section to the log). Findings are discipline-tracking signal, not commit-blocking.
tools: Read, Edit, Glob, Bash
model: sonnet
---
```

(No `mcpServers` key — Phase 4a does not use dm-fs MCP.)

Body sections:

**Intro paragraph:**

> You are the bookkeeper agent. You perform the session-end verification pass. The `/session-end` slash command invokes you between the chaos-factor adjustment step and the commit step. You read the session log, run three narrator-discipline checks against the narrative prose, and append a `## Bookkeeper audit` section to the log. Findings are discipline-tracking signal — they document patterns the user reviews post-session. You do not block commit; you do not auto-correct; you do not modify content other than appending the audit section.

**`## Read access`:**

- `sessions/`, `party/`, `library/`, `world/` — readable directly via Read and Glob.
- **No access** to `dm/` paths. Project-level settings deny direct reads. No dm-fs MCP access in Phase 4a.

**`## Write access`:**

- `sessions/play/YYYY/MM/session-NNN.md` — writable via Edit, **only** for appending the `## Bookkeeper audit` section. You never modify narrative prose, subagent-log lines, the `## Session-end summary` section, or any prior content. Edit operates by appending after the existing content (anchored on a known terminal marker or the file's end-of-content).
- **No other writes anywhere.** Not to `dm/` (denied at project level), not to `library/`, not to `party/`, not to `world/`, not to other `sessions/` files, not to `.claude/`, not to `docs/`.

**`## Your contract`:**

> You are a session-end audit subagent. Invoked only by `/session-end` (no ad-hoc invocation in Phase 4a). You read the session log and party/primary/ for the primary PC's name; you append a structured findings list to the session log under `## Bookkeeper audit`; you return a brief summary in your response.
>
> You never:
> - Modify narrative prose, subagent-log lines, or the `## Session-end summary` section.
> - Block commit. Findings are discipline-tracking; the user reviews post-session.
> - Auto-correct findings (e.g., inserting a missing dice roll, rewriting a primary-PC overreach line). Auto-correction is out of scope; the user decides what to do with findings.
> - Read or write any `dm/` content. The audits are pure narrator-readable-scope operations in Phase 4a.
> - Re-audit a session that already has a `## Bookkeeper audit` section. Abort with an explicit error; Phase 4b may add re-audit semantics.
> - Run checks beyond the documented trio (dice-line, oracle-call, primary-PC overreach). Phase 4b+ adds more.

**`## Query type: audit-session`:**

> Invocation: `"Audit session <path>."` where `<path>` is `sessions/play/YYYY/MM/session-NNN.md`.
>
> Procedure:
>
> 1. **Pre-flight.** Verify the path matches `sessions/play/YYYY/MM/session-NNN.md`. Read the file. If the path is invalid or the file doesn't exist, abort with `"invalid session log path: <path>"`. If the file already contains a `## Bookkeeper audit` heading, abort with `"session already has a bookkeeper audit section; re-audit not supported in Phase 4a"`. No writes on abort.
>
> 2. **Identify primary PC.** Run `Glob("party/primary/*.md")`. Take the basename (without `.md`) as the primary PC name. If 0 files: flag `**Warning:** no primary PC file found; check 3 skipped` and continue with checks 1 and 2. If N>1 files: flag `**Warning:** multiple primary PC files found (<names>); check 3 will match against all` and continue.
>
> 3. **Decompose the session log.** Walk the file line by line. Classify each non-empty line as either subagent-log or narrative prose:
>    - **Subagent-log:** a line starting with `- ` (one dash, one space) followed by any of these tokens (case-insensitive on the prefix): `/roll`, `DICE:`, `ORACLE:`, `MYTHIC:`, `WORLD-STATE QUERY:`, `LIBRARIAN QUERY:`, `REVELATION:`. Also: any line under a recognized subagent's section heading (e.g., a continuation indented under a subagent line).
>    - **Narrative prose:** anything else, except blank lines and markdown headings.
>    - Markdown headings (`#`, `##`, `###`) delimit scene boundaries but are not themselves prose. Use them to define "scene" for check 1's "within the same scene" rule.
>    - On ambiguity, classify as prose (more conservative — runs the audit on slightly more content; may produce false positives but won't miss real violations).
>
> 4. **Check 1 — dice-line presence.** Scan narrative prose for descriptions of mechanical outcomes. Patterns of interest (LLM judgment, not regex):
>    - Combat outcomes: "[noun] hits", "[noun] misses", "[noun]'s [weapon] glances off", "[noun] strikes you", damage quantities (e.g., "for 7 damage", "8 piercing").
>    - Skill check outcomes: "you spot", "you notice", "you find", "succeeds the DC", "fails the check".
>    - Save outcomes: "saves against", "shrugs off the spell", "succumbs to".
>    - Use the scene context: an outcome described in scene N must have a `- /roll` or `- DICE:` line within the same scene (between `## Scene:` markers, or the entire log if there's only one scene).
>    - Flag candidates that look like mechanical outcomes but have no matching dice line nearby.
>    - **Default to no flag** on truly ambiguous cases (e.g., "the door opens" — could be scripted, could be a check). Phase 4a errs toward false negatives over noisy false positives.
>
> 5. **Check 2 — oracle-call presence.** Scan narrative prose for answers to genuinely uncertain yes/no questions. Patterns:
>    - Player asks a question and the narrator answers in prose ("Is there a back door?" → "Yes, you spot one behind the shelves").
>    - Narrative tension implies an unknown the narrator resolved ("Would she trust him?" → narrator narrates her response).
>    - For each candidate answer, look for a corresponding `- ORACLE:` or `- MYTHIC:` line nearby (within the same scene).
>    - **Default to no flag** on cases where the answer is plausibly determined by already-established state (e.g., the location's `world/` description says the inn has a back door; no oracle needed).
>
> 6. **Check 3 — primary-PC overreach.** Scan narrative prose for action verbs or dialogue attributed to the primary PC by name. Use the primary PC name from step 2.
>    - **Flag-worthy:** `<PC> [verb]s [object]` where the verb implies declared action — `draws`, `says`, `attacks`, `casts`, `runs`, `whispers`, `decides`, `agrees`, `refuses`, `accepts`. Examples: "Dagnal draws his sword." "Dagnal says 'I'll take the door.'"
>    - **Not flag-worthy:** descriptive/sensory/perceptual framings — `sees`, `notices`, `feels`, `hears`, `smells`. Examples: "Dagnal sees the door." "Dagnal feels the cold." These are the narrator describing what the PC perceives, not declaring an action.
>    - Default to no flag on borderline cases (e.g., "Dagnal stands at the door" — could be position description or implied action).
>
> 7. **Compose findings.** For each finding, capture:
>    - **Line reference:** 1-based line number in the session log.
>    - **Suspect text excerpt:** 1-2 sentences from the line, quoted verbatim. If the surrounding context (1-2 lines before/after) clarifies the issue, include it minimally — never more than ~3 lines of context.
>    - **Reasoning:** 1-2 sentences explaining why this looked like a violation. Reference what was missing (e.g., "no dice line in scene 3 corresponds to this hit") or what triggered the pattern (e.g., "verb 'says' attributed to Dagnal").
>
> 8. **Append the `## Bookkeeper audit` section** via Edit. The exact format:
>
>    ```markdown
>    
>    ---
>    
>    ## Bookkeeper audit
>    
>    **Audit complete:** <N1> dice-line gap(s), <N2> oracle-call gap(s), <N3> primary-PC overreach candidate(s) flagged.
>    
>    <If N1+N2+N3 = 0:>
>    
>    No discipline regressions detected.
>    
>    <Else:>
>    
>    ### Dice-line gaps
>    
>    <For each finding:>
>    - **Line <NNN>:** "<suspect text excerpt>"
>      Reasoning: <1-2 sentences>
>    
>    <Or if zero findings in this check:>
>    
>    - (none)
>    
>    ### Oracle-call gaps
>    
>    <Same structure as Dice-line gaps.>
>    
>    ### Primary-PC overreach
>    
>    <Same structure.>
>    ```
>
>    The section is appended after the last existing content in the file. Use Edit with a unique anchor (e.g., the closing line of `## Session-end summary` if present, or the file's last non-empty line) to position the append.
>
> 9. **Return a brief summary** in your response. Include: number of findings per check, the audit section was appended successfully, any warnings (e.g., "no primary PC file found; check 3 skipped"). Do not include the full findings list in the response — the persistent record in the session log is the authoritative artifact.

**`## Edge cases`:**

- **Session log path doesn't exist.** Abort in pre-flight with `"invalid session log path: <path>"`. No writes.
- **Path is not a `sessions/play/YYYY/MM/session-NNN.md` file.** Abort in pre-flight. Phase 4a does not audit downtime sessions or other log types.
- **No primary PC file in `party/primary/`.** Flag warning in audit summary; skip check 3; continue.
- **Multiple primary PC files in `party/primary/`.** Flag warning; check 3 matches against all names (treat as the union set).
- **Session log has no narrative prose** (all subagent-log lines and headings). All three checks produce zero findings. Audit summary still appended.
- **Session log already has a `## Bookkeeper audit` section.** Abort with `"session already has a bookkeeper audit section; re-audit not supported in Phase 4a"`. No writes.
- **Session log is malformed** (no `## Scene:` markers, broken markdown). Run checks against the full file as one scene; flag in the audit summary as `**Warning:** session log has no scene markers; checks ran against the full log as a single scope`.
- **Edit failure mid-append.** Surface the error. Session log may be partially modified. User restores via `git restore sessions/play/...` and reruns.
- **Bookkeeper's LLM judgment is wrong.** Expected and acceptable in Phase 4a. False positives are surfaced; user reviews; pattern-tightening is Phase 4b+ work.

**`## What you don't do`:**

- Don't modify narrative prose, subagent-log lines, or the `## Session-end summary` section.
- Don't write to any file other than the session log being audited.
- Don't read `dm/` paths. Phase 4a operates on narrator-readable content only.
- Don't block commit. Phase 4a is audit-only.
- Don't auto-correct findings. Don't insert missing dice rolls or rewrite primary-PC overreach. The user decides what to do.
- Don't re-audit a previously audited session. Abort.
- Don't run checks beyond the documented trio.
- Don't invoke other subagents. Phase 4a's bookkeeper is self-contained.
- Don't commit. The `/session-end` command commits after you return.

### `/session-end` modifications

Existing `.claude/commands/session-end.md` has 5 steps. Phase 4a inserts a new step 4 between the existing step 3 (chaos adjust) and step 4 (git commit), renumbering subsequent steps.

Current step 4 (git commit) becomes step 5. Current step 5 (report success) becomes step 6.

New step 4 text:

> 4. Invoke the bookkeeper subagent with `"Audit session <path>."` where `<path>` is the active session log from step 1. The bookkeeper reads the log, runs three narrator-discipline checks (dice-line presence, oracle-call presence, primary-PC overreach), and appends a `## Bookkeeper audit` section to the log. The bookkeeper returns a brief summary; surface it to the user. Findings do not block the commit in this phase.

The closing paragraph of the slash command is updated:

> ~~Phase 1 does **not** run a bookkeeper verification phase — that lands in Phase 4. The working-tree-as-committed is trusted as the session record.~~

is replaced with:

> Phase 4a runs a minimum-viable bookkeeper audit at session-end. Findings are surfaced and persisted in the session log but do not block the commit. Subsequent Phase 4 sub-phases will extend the audit's reach (live-write integrity, subagent decision audits, structural-change proposals).

### CLAUDE.md rule 10

Add a new section under `## Routing rules`, after the existing rule 9 (Runtime librarian queries):

> ### 10. Bookkeeper audit at session-end
> 
> The bookkeeper subagent audits each session log at session-end for narrator-discipline compliance. You do not invoke the bookkeeper during play — `/session-end` invokes it for you between chaos-factor adjustment and commit, with the active session log path as argument. The bookkeeper reads the log, runs three checks (dice-line presence for narrated mechanical outcomes, oracle-call presence for narrated answers to uncertain questions, primary-PC overreach for narrated actions/dialogue attributed to the primary PC), and appends a `## Bookkeeper audit` section to the log. Findings are discipline-tracking signal — they document patterns to review post-session — and do not block the commit in the current phase.
> 
> Treat the bookkeeper as a session-boundary subagent like world-state's offscreen-developments tick: invoked by a slash command at the boundary, not by you during play. Do not try to invoke the bookkeeper for ad-hoc audits; Phase 4a does not support that path.

No corresponding `## What you must never do` bullet is added (the rule itself is the constraint, and there is no behavior the narrator must avoid for the bookkeeper to function).

### Repository layout (Phase 4a additions)

```
gygaxagain/
├── .claude/
│   ├── agents/
│   │   └── bookkeeper.md            # NEW — Phase 4a bookkeeper subagent
│   └── commands/
│       └── session-end.md           # MODIFIED — new step 4 invokes bookkeeper
├── CLAUDE.md                        # MODIFIED — new rule 10 under ## Routing rules
└── sessions/play/2026/05/
    └── session-005.md               # MODIFIED (smoke-test artifact) — appends ## Bookkeeper audit
```

## Smoke test for Phase 4a

### Primary smoke test — bookkeeper against `session-005.md`

The Phase 3 testbed campaign has five committed session logs in `sessions/play/2026/05/`. Session-005 is the most recent and largest (~11KB), with the broadest mix of dice rolls, oracle calls, scene transitions, and NPC dialogue — the best target for exercising all three audit checks.

**Procedure:**

1. With the v1 bookkeeper subagent in place and `/session-end` modified, restart Claude Code so the bookkeeper prompt loads into the Agent tool's registry.
2. Dispatch the bookkeeper directly (retroactive audit pattern, mirroring Phase 3d's `propose-revelations` and Phase 3e's `propose-factions` smoke tests):
   ```
   Agent(subagent_type="bookkeeper", prompt="Audit session sessions/play/2026/05/session-005.md.")
   ```
3. The bookkeeper:
   - Verifies the session log path exists; reads it.
   - Globs `party/primary/*.md`; takes the basename (`dagnal`) as the primary PC name.
   - Decomposes the log into narrative prose vs subagent-log lines.
   - Runs check 1 (dice-line presence), check 2 (oracle-call presence), check 3 (primary-PC overreach).
   - Composes findings.
   - Appends `## Bookkeeper audit` section via Edit.
   - Returns a brief summary.

**Pass criteria:**

- The bookkeeper appends a `## Bookkeeper audit` section to `sessions/play/2026/05/session-005.md` with:
  - The audit-summary header line in the form `**Audit complete:** <N1> dice-line gap(s), <N2> oracle-call gap(s), <N3> primary-PC overreach candidate(s) flagged.`
  - Either the literal text `No discipline regressions detected.` (zero findings across all three) OR three `### <check name>` subsections — `### Dice-line gaps`, `### Oracle-call gaps`, `### Primary-PC overreach` — each with zero or more findings or `(none)` placeholder.
  - Each finding has the documented format: line reference, suspect text excerpt, reasoning.
- The bookkeeper does NOT modify any other content in the session log (prior prose + summary section intact). Confirm via `git diff sessions/play/2026/05/session-005.md` — diff should be purely additive.
- The bookkeeper does NOT write to any file outside `sessions/play/2026/05/session-005.md`. Confirm via `git status` — only that one file should be modified.
- The audit section is well-formed markdown (parses cleanly).
- Findings (if any) are plausible. False positives are acceptable and expected. Obvious nonsense (e.g., flagging dialogue from a clearly-named NPC as primary-PC overreach when Dagnal isn't named near the line) indicates the prompt needs tightening before merge.
- All 87 existing dm-fs MCP tests continue to pass; no Python code added.

**User reviews findings.** Read the appended `## Bookkeeper audit` section. For each finding, judge: true positive (real discipline issue worth tightening in future sessions), false positive (the bookkeeper was too aggressive), or borderline (the bookkeeper's reasoning is plausible but the audit's signal/noise is unclear from one sample). Phase 4a establishes the artifact; subsequent sub-phases tune the audit prompt's judgment.

**Commit the smoke-test artifact** — the modified session-005.md with the audit section, committed on the phase-4a branch.

### Secondary smoke test — `/session-end` slash command contract check

Phase 4a modifies `.claude/commands/session-end.md` to invoke the bookkeeper between chaos-adjust and commit. A live functional test would require running `/session-end` against an active session, which isn't natural to set up mid-phase.

Instead:

1. Read the modified `.claude/commands/session-end.md`.
2. Verify the new step exists between the existing chaos-adjust step and the existing git-commit step.
3. Verify the new step's wording matches the design: dispatches the bookkeeper with `"Audit session <path>"`, surfaces findings to the user, does not block commit.
4. Verify subsequent steps renumber correctly (the git-commit step is now step 5; report-success is step 6).
5. Verify the closing paragraph is updated from "Phase 1 does not run a bookkeeper verification phase" to the Phase 4a wording.

This is a contract check, not a functional test. Real functional validation happens the next time the user runs `/session-end` against an active session.

### Optional tertiary smoke test — synthetic fixtures per check

Validates each audit check fires independently against controlled inputs. Not required for Phase 4a pass criteria — the primary smoke test against session-005 exercises all three checks against real data.

If desired, hand-author three synthetic session logs at `/tmp/phase-4a-smoke/`, one per check, each containing a single known violation:
- `check-1-fixture.md`: narrative prose describing an attack hit/miss with NO `- /roll` or `- DICE:` line. Dispatch the bookkeeper; verify check 1 fires.
- `check-2-fixture.md`: narrative prose answering an explicit player yes/no question with NO `- ORACLE:` or `- MYTHIC:` line. Dispatch; verify check 2 fires.
- `check-3-fixture.md`: narrative prose containing `Dagnal draws his sword and steps forward`. Dispatch; verify check 3 fires.

Note: fixtures must be in a valid `sessions/play/YYYY/MM/session-NNN.md` path for the bookkeeper's pre-flight to accept them. Either place them under `sessions/play/2099/01/session-001.md` (a clearly synthetic future year) for the test, or amend the bookkeeper's pre-flight to accept a `/tmp/` path — the former is cleaner. Discard fixtures after the test.

### Asymmetry audit (Phase 4a-specific shape)

Phase 4a is information-asymmetry neutral — no new tiers, no new dm/ access. The asymmetry audit is therefore minimal:

1. **dm-fs access log shows zero bookkeeper-issued operations.** The bookkeeper has no `mcpServers` in Phase 4a; the access log should have no entries attributed to it. Confirm by checking the log's last entries after the smoke test — they should be the Phase 3e librarian/world-state entries from prior smoke tests, with no new bookkeeper-issued lines.
2. **Bookkeeper's writes are exclusively to the session log being audited.** Confirmable via `git status` after the smoke test: only `sessions/play/2026/05/session-005.md` should be modified. Confirmable via `git diff --stat`: one file, additive change only.
3. **Phase 3a/3b/3c/3d/3e boundaries hold.** Relative-path probes against `dm/modules/.../secrets.md`, `dm/revelations/r-001.md`, `dm/factions/cult-of-myrkul.md` all denied. `library/lore/test-bestiary/entries/goblin.md` readable. The Phase 4a additions do not weaken existing protections.
4. **The bookkeeper has narrator-scope read access only.** Verify by inspecting the bookkeeper subagent file: no `mcpServers` line; only `Read, Edit, Glob, Bash` in `tools`. No privilege escalation vs the narrator.

## Failure modes Phase 4a must handle

- **Session log path doesn't exist.** Bookkeeper aborts in pre-flight with `"invalid session log path: <path>"`. No writes. `/session-end` should surface the error and abort commit.
- **Path is not a `sessions/play/YYYY/MM/session-NNN.md` file.** Bookkeeper aborts. Same error path as above.
- **Session log already has a `## Bookkeeper audit` section** (re-running against a previously audited session). Bookkeeper aborts with explicit error. No writes. Phase 4b may add re-audit semantics.
- **No primary PC file in `party/primary/`.** Bookkeeper flags warning in the audit summary header, skips check 3, continues with checks 1 and 2. Audit section is still appended.
- **Multiple primary PC files in `party/primary/`.** Bookkeeper flags warning; check 3 runs against the union of names.
- **Session log has no narrative prose** (all subagent-log lines and headings). All three checks produce zero findings. Audit summary appended with `No discipline regressions detected.` line.
- **Session log has no `## Scene:` markers.** Bookkeeper runs checks against the entire log as one scope; flags as a warning in the audit summary.
- **Edit failure mid-append.** Bookkeeper surfaces the error. Session log may be partially modified. User restores via `git restore sessions/play/...` and re-runs.
- **Bookkeeper's LLM judgment is wrong** (false positives or false negatives). Expected and acceptable in Phase 4a. The user reviews findings and exercises judgment; recurring false-positive patterns inform Phase 4b prompt tuning.
- **Bookkeeper crash or unexpected error.** `/session-end` surfaces the error. The bookkeeper invocation step in the slash command should be wrapped such that the rest of the command can proceed if the user explicitly accepts (manual override); but in 4a, the simpler behavior is: if the bookkeeper fails, the user resolves manually and either re-runs `/session-end` or skips the audit by hand-appending a stub `## Bookkeeper audit` section before re-running.
- **Slash command file changes don't take effect** until session restart. Same constraint as Phase 3a/3b/3c/3d/3e for subagent prompts — handled by the restart checkpoint in the implementation plan.
- **Audit section format regression.** The bookkeeper produces an audit section that violates the documented format (missing summary header, missing subsections, malformed line references). Smoke test catches this; iterate on the bookkeeper prompt and re-run.

## Open questions resolved during brainstorming

- **Sub-slicing of Phase 4:** MVP bookkeeper first, expand outward. Phase 4a establishes the artifact + integration + minimum-viable audit (three narrator-discipline checks). Phase 4b adds subagent-decision audits and live-write integrity. Phase 4c adds structural-change proposals. Phase 4d adds authoring formalization. Phase 4e adds remaining lint rules.
- **Audit scope for Phase 4a:** narrator-discipline trio — dice-line presence, oracle-call presence, primary-PC overreach. Each is independently testable; all three share the "scan session log for patterns" implementation strategy. Live-write integrity deferred to Phase 4b (requires dm/ read access via MCP).
- **Findings persistence:** append to the session log under `## Bookkeeper audit`. Single file per session, co-located with the audited content. Matches Phase 1's existing append-at-session-end convention. Cross-session aggregate roll-up deferred to later sub-phase.
- **Blocking behavior:** none. Findings are surfaced and persisted; commit proceeds unconditionally. The user retains every option to act on findings (`git amend`, follow-up commit, hand-fix) without the command itself blocking. Enforcement is Phase 4b+ work.
- **Read access:** narrator-scope only in Phase 4a — `sessions/`, `party/`, `library/`, `world/`. No `dm/` access. Phase 4b+ extends to dm/ via MCP for subagent-decision audits.
- **Write access:** Edit on the session log only. No other writes.
- **MCP changes:** none. Bookkeeper has no `mcpServers` in Phase 4a.
- **Python code added:** none.
- **New slash commands:** none. Bookkeeper is reachable only through `/session-end` in Phase 4a.
- **CLAUDE.md changes:** new rule 10 under `## Routing rules`. No new must-never bullet.
- **Order in `/session-end`:** bookkeeper runs between chaos-factor adjust (existing step 3) and git commit (existing step 4). Findings are part of the same commit as the session log + summary + chaos adjust.
- **Bookkeeper-authored commit:** out of scope for Phase 4a. The slash command's `git add -A && git commit` is unchanged. Bookkeeper-owned commit discipline (per SPEC.md "save during play; commit at session end") is Phase 4b+.
- **Re-audit support:** abort on existing audit section in Phase 4a. Phase 4b may add re-audit semantics (replace, append, or merge).

## Phase 4a → Phase 4b+ handoff

Phase 4a's exit opens potential Phase 4b content:

- **Subagent decision audits.** Faction tick rationale (did world-state advance/hold clocks correctly given session prose?), clue delivery confirmations (did revelation confirm clues that actually landed?), thread state (do open/close calls match the narrative?), intake decisions. Phase 4b. Requires bookkeeper read access to `dm/` via dm-fs MCP.
- **Live-write integrity audit.** Working-tree diff at session-end vs session log narrative — does every state change in the diff trace back to a narrative event? Phase 4b.
- **Library-bypass detection.** Narrator improvised content where a librarian module already covers the scope. Phase 4c.
- **Structural-change proposals.** NPC promotion candidates, faction cascade candidates, source-overlap merges. Phase 4c.
- **Authoring formalization.** `/author-npc`, `/author-milestone`, hand-authoring helpers for refining auto-proposed faction ladders / clue vectors. Phase 4d.
- **Additional lint rules.** Hook text leaking revelation phrasing, naked thread number references, library-bypass detection. Phase 4d–4e.
- **Cross-session aggregate roll-up.** `sessions/audits/index.md` with per-check counts across sessions for pattern detection. Phase 4b or 4d.
- **Bookkeeper-owned commit discipline.** The bookkeeper authors the commit message and runs `git commit`, replacing the slash command's `git add -A && git commit`. Phase 4b+.
- **Ad-hoc bookkeeper invocation.** `/audit-session <path>` slash command for re-audits, dry-runs, historical audits. Phase 4b.
- **Re-audit semantics.** Phase 4b may decide how to handle audits against already-audited sessions (replace, append, merge).
- **NPC system.** Originally scoped for Phase 4; deferred to Phase 4d or a dedicated NPC phase.
- **Blocking behavior.** Phase 4b–4c may introduce opt-in blocking for high-severity findings.

The pattern Phase 4a establishes — "bookkeeper subagent invoked by `/session-end` at the session boundary, appends a structured findings section to the session log, does not block commit" — is the substrate for subsequent Phase 4 sub-phases. Each later sub-phase extends a dimension (read scope, audit checks, persistence aggregation, enforcement gating, authoring support) without restructuring the artifact.

## Roadmap context

Phase 4a sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(complete)*
6. **Phase 3a — Source ingestion: modules (intake-only, dm-quarantined).** *(complete)*
7. **Phase 3b — Runtime librarian queries (`consult-library` + `reveal-from-module`).** *(complete)*
8. **Phase 3c — Source ingestion: lore-reference (bestiary-shaped entries; narrator-readable).** *(complete)*
9. **Phase 3d — Auto-propose revelation seeds from module material.** *(complete)*
10. **Phase 3e — Auto-propose faction seeds from module material.** *(complete)*
11. **Phase 4a — MVP bookkeeper (narrator-discipline trio at session-end).** *(this design)*
12. **Phase 4b — Bookkeeper extension: subagent decision audits, live-write integrity, ad-hoc audit invocation, re-audit semantics.**
13. **Phase 4c — Bookkeeper extension: structural-change proposals (NPC promotion, faction cascades, source-overlap merges); library-bypass detection.**
14. **Phase 4d — Authoring formalization (NPC system, milestone authoring, hand-authoring helpers); additional lint rules.**
15. **Phase 4e — Remaining lint rules, cross-session aggregate roll-up, opt-in blocking. Further slicing determined when Phase 4e is brainstormed.**
16. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
17. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
18. **Phase 7 — Downtime, banking, bastions.**

Phase 4a's scope is what's locked here.
