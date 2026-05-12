# Phase 4b — Bookkeeper Subagent-Decision Audits Design

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
**Phase 4a spec:** `docs/superpowers/specs/2026-05-11-phase-4a-mvp-bookkeeper-design.md`.
**Slice of original Phase 4:** the bookkeeper's second sub-phase — extends the MVP bookkeeper from three narrator-discipline audits (Phase 4a) to six audits by adding three subagent-decision audits (faction tick rationale, clue delivery confirmation, thread state consistency). Adds dm-fs MCP read access to the bookkeeper (scoped to `dm/factions/`, `dm/revelations/`, `dm/threads/`). Adds replace-on-rerun re-audit semantics so the smoke test can run against the Phase 4a-audited session-005. Live-write integrity audit, intake-decision audit, ad-hoc invocation slash command, library-bypass detection, structural-change proposals, authoring formalization, additional lint rules, cross-session aggregate roll-up, and opt-in blocking are deferred to Phase 4c+.

## Purpose

Phase 4a established the bookkeeper subagent and integrated it with `/session-end`, running three narrator-discipline checks (dice-line presence, oracle-call presence, primary-PC overreach) on the session log. Those checks operate purely on narrator-readable content (session log + party/primary/ for the PC name); they do not cross-check against the Phase 2 subagents' decisions encoded in `dm/`.

Phase 4b extends the bookkeeper to cross-check Phase 2 subagent state-change decisions against the session log narrative. The three Phase 2 subagents (world-state for factions, revelation for clue delivery, mythic for threads) each persist their decisions to `dm/` files at session boundaries or in-session as state changes:

- **World-state's offscreen-developments tick** at session-start mutates `dm/factions/<slug>.md` (advancing clocks, transitioning status, appending `## History` entries). Did the tick match what the session prose would have justified?
- **Revelation subagent's `confirm` query** during play appends to `dm/revelations/r-NNN.md` `## Delivered` section. Was each confirmation actually warranted by a narrative beat?
- **Mythic subagent's `open-thread` / `close-thread` queries** mutate `dm/threads/active.md`. Do the thread state changes match the session prose?

Phase 4b's load-bearing claim is twofold:

1. **The bookkeeper can cross-check Phase 2 subagent state decisions against session prose using dm-fs MCP read access**, producing useful audit signal without compromising the asymmetry boundary (narrator-side `dm/` denies stay in place; bookkeeper translates dm/ state into synthesized findings).

2. **The replace-on-rerun re-audit semantic enables iterative audit improvement.** When the bookkeeper's check logic improves (in 4b or later sub-phases), users can re-audit prior sessions to refresh findings without manual cleanup.

Both claims validated by smoke-testing against `sessions/play/2026/05/session-005.md` (which has a Phase 4a audit section the v2 bookkeeper must replace) with the v2 bookkeeper in place.

After Phase 4b, the bookkeeper has six checks across narrator-discipline (3) and subagent-decision (3) categories. Phase 4c+ adds live-write integrity (the most ambitious audit class, comparing git diff to narrative across all subagent-write paths) and the bookkeeper's invocation-surface expansions (ad-hoc invocation slash command, additional re-audit modes).

## Definition of done

A successful Phase 4b build demonstrates all of:

- **Bookkeeper v2 frontmatter gains `mcpServers: [dm-fs]`** plus an updated `description` field mentioning the six-check scope.

- **Bookkeeper v2 `## Read access` extends to three dm/ tiers** via dm-fs MCP: `dm/factions/`, `dm/revelations/`, `dm/threads/`. Access scoped strictly to these paths; explicit prohibition on reading other dm/ paths (modules/, npcs/, others).

- **Bookkeeper v2 `## Write access` unchanged.** Write target remains the session log being audited. No dm-fs MCP write operations are used (`mcp__dm-fs__write_dm_file`, `mcp__dm-fs__create_dm_file`, `mcp__dm-fs__append_dm_file` are never invoked).

- **Three new audit checks added** to the procedure (checks 4, 5, 6):
  - **Check 4 — faction tick rationale.** For each session-dated entry in `dm/factions/<slug>.md` `## History`, cross-check the recorded tick decision (advance / hold / discovery / clock-filled) against the prior-session narrative's engagement-trigger surface in the session log. Flag implausible ticks; LLM judgment; default to no-flag on ambiguity.
  - **Check 5 — clue delivery confirmation.** For each session-dated entry in `dm/revelations/r-NNN.md` `## Delivered`, find a narrative beat in the session log that justifies the clue landing. Flag deliveries without a matching beat; default to no-flag on ambiguity.
  - **Check 6 — thread state consistency.** For each `MYTHIC THREAD: opened/closed #N` line in the session log, verify the thread number + description matches `dm/threads/active.md`'s current state AND find a narrative beat justifying the state transition. Flag mismatches or unsupported state changes.

- **Replace-on-rerun re-audit semantic.** When the session log already contains a `## Bookkeeper audit` section, the bookkeeper identifies the audit-section start anchor, truncates the file at that anchor (removing the prior audit), then writes the new six-check audit section. Always-replace; no flag, no abort. Phase 4a's "abort if section exists" behavior is removed.

- **Audit-section template extended:**
  - Audit-complete summary line includes six counts in stable order: `<N1> dice-line gap(s), <N2> oracle-call gap(s), <N3> primary-PC overreach candidate(s), <N4> faction tick anomal(ies), <N5> clue delivery anomal(ies), <N6> thread state anomal(ies) flagged.`
  - Zero-findings branch (`No discipline regressions detected.`) unchanged in semantics — emitted only if all six counts are zero.
  - Else-branch emits six `### <check name>` subsections in fixed order: Dice-line gaps, Oracle-call gaps, Primary-PC overreach, Faction tick rationale, Clue delivery confirmation, Thread state consistency. Each subsection has zero or more findings (`- (none)` if zero, otherwise `- **Line <NNN>:** "<excerpt>"` + `Reasoning: <1-2 sentences>`).

- **CLAUDE.md rule 10 updated** to mention the six-check scope and replace-on-rerun semantic. Wording extended from "runs three checks" to "runs six checks (dice-line presence, oracle-call presence, primary-PC overreach; faction tick rationale, clue delivery confirmation, thread state consistency)" and notes that the bookkeeper "appends a `## Bookkeeper audit` section to the log (replacing any pre-existing audit section)."

- **CLAUDE.md `## Current phase scope`** updated to reflect Phase 4b's expansion.

- **Smoke test:** bookkeeper v2 dispatched against `sessions/play/2026/05/session-005.md` (which has a Phase 4a audit section) replaces the prior audit cleanly. The new audit section conforms to the v2 format with six counts and three new subsections. dm-fs access log shows bookkeeper-issued reads of all three approved tiers (`list_dm_dir factions`, per-faction `read_dm_file`, `list_dm_dir revelations`, per-revelation `read_dm_file`, `read_dm_file threads/active.md`) and zero writes.

- All 37 existing dm-fs MCP tests continue to pass; no Python code added.

- **No new MCP tools.** Existing `read_dm_file` and `list_dm_dir` cover all 4b operations.

- **No new slash command.** Bookkeeper still reachable only through `/session-end`.

- **No `/session-end` changes.** Step 4 still dispatches `"Audit session <path>."` with no flags or parameters. Re-audit is handled internally by the bookkeeper.

- **Narrator information asymmetry preserved.** The narrator still cannot read `dm/` paths directly; project-level denies in `.claude/settings.json` are unchanged. The bookkeeper's MCP access does not weaken the narrator's read constraints.

## Out of scope (deferred to Phase 4c+)

- **Live-write integrity audit.** Compares git diff against last commit vs session log narrative — does every state change in the diff trace back to a narrative event? Phase 4c. Structurally novel (reasons across narrative + state + diff); benefits from having the simpler subagent-decision audits already shipped.
- **Intake-decision audit.** Did the librarian's reveal-vs-flavor judgment for revelation auto-proposals make sense? Phase 4c or 4d.
- **Ad-hoc bookkeeper invocation.** `/audit-session <path>` slash command for re-audits, dry-runs, historical audits. Phase 4c.
- **Re-audit modes beyond always-replace.** Append (preserve prior audit + add new), abort-with-flag (`--force` to enable replace), merge (combine findings from multiple audits). Phase 4c when ad-hoc invocation lands with mode flags.
- **Library-bypass detection.** Narrator improvised content where a librarian module already covers the scope. Phase 4c.
- **Structural-change proposals.** NPC promotion candidates, faction cascade candidates, source-overlap merges. Phase 4c.
- **Authoring formalization.** `/author-npc`, `/author-milestone`, hand-authoring helpers for refining auto-proposed faction ladders / clue vectors. Phase 4d.
- **Additional lint rules.** Hook text leaking revelation phrasing, naked thread number references in narration, narration patterns indicating discipline regression beyond the trio. Phase 4d–4e.
- **Bookkeeper read access beyond the three approved tiers.** No `dm/modules/` access in 4b (needed for intake audit, deferred to 4c/4d). No `dm/npcs/` access (no Phase 2 NPC tier exists yet).
- **Bookkeeper write access to `dm/`.** Phase 4b's bookkeeper has MCP access but uses read-only. No auto-correction of subagent state; user decides what to do with findings.
- **Blocking commit on findings.** Phase 4b remains audit-only. Phase 4e may introduce opt-in blocking for high-severity findings.
- **Cross-session aggregate roll-up.** `sessions/audits/index.md` for pattern detection across sessions. Phase 4d or 4e.
- **Bookkeeper-owned commit discipline.** Phase 4b leaves `git add -A && git commit` in `/session-end` (managed by the slash command, not the bookkeeper). Phase 4c+.
- **Re-audit failure handling beyond abort-on-malformed-anchor.** Phase 4b aborts if the existing audit section is malformed (no recognizable anchor); user resolves manually. More sophisticated recovery deferred.
- **Bookkeeper running checks beyond the documented six.** New check categories deferred to subsequent sub-phases (4c live-write, 4c+ library-bypass, 4d-4e lint rules).

## Architecture

### Slice mapping

| Component                          | Phase 4b touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | `CLAUDE.md` rule 10 wording updated to mention six checks and replace-on-rerun semantic. `## Current phase scope` paragraph updated. No behavioral change during play. |
| **Bookkeeper subagent**            | **MODIFIED** — `.claude/agents/bookkeeper.md` v1 → v2. Frontmatter gains `mcpServers: [dm-fs]`. `## Read access` extends to three dm/ tiers. `## Your contract` updates. Procedure extends from 9 to 12 steps (three new checks + replace-existing-section step). Audit-section template extends to six subsections. `## Edge cases` and `## What you don't do` updated. |
| Dice subagent                      | Untouched. Its session-log lines remain inputs to check 1. |
| Mythic subagent                    | Untouched. Its session-log lines remain inputs to check 2; its threads file is now an input to check 6. |
| World-state subagent               | Untouched. Its session-log lines and `dm/factions/<slug>.md` `## History` appends are now inputs to check 4. |
| Revelation subagent                | Untouched. Its `dm/revelations/r-NNN.md` `## Delivered` appends are now inputs to check 5. |
| Librarian subagent                 | Untouched. Out of audit scope in 4b. |
| `/session-end` command             | Untouched. Step 4 still dispatches `"Audit session <path>."`. Re-audit handled internally by the bookkeeper. |
| Other slash commands               | Untouched. No new `/audit-session` in 4b. |
| `dm-fs` MCP                        | No tool changes. Existing `read_dm_file` and `list_dm_dir` cover all 4b operations. |
| `.claude/settings.json`            | No deny-rule changes. Narrator-side `dm/` denies unchanged. |
| Repository layout                  | No new directories. Audit findings still live in session log `## Bookkeeper audit` sections (now richer with six subsections). |

### Information-asymmetry preservation

**No new tiers introduced.** Phase 4b expands the bookkeeper's read scope into `dm/` via the existing dm-fs MCP, mirroring the Phase 3a pattern where the librarian gained dm-fs MCP access for module ingest:

- **Bookkeeper reads `dm/factions/`, `dm/revelations/`, `dm/threads/`** via dm-fs MCP. The MCP exposes all `dm/` paths, but the bookkeeper's prompt enforces path-level discipline (reads only the three approved tiers, mirroring the librarian's modules/+revelations/ discipline pattern).
- **Bookkeeper's write access stays unchanged** from Phase 4a: only the session log being audited, via Edit. No `dm/` writes — even via MCP. The bookkeeper does not auto-correct dm/ state.
- **Narrator's `dm/` denies in `.claude/settings.json` are unchanged.** Audits run by a different subagent don't weaken the narrator's information asymmetry. The narrator still cannot read `dm/factions/`, `dm/revelations/`, `dm/threads/`, or any other dm/ path.
- **`## Bookkeeper audit` section** appended to the session log is still player-readable (session logs are not dm-quarantined). The audit's findings reference what the bookkeeper saw in dm/ in synthesized form (e.g., "the faction's tick history shows clock advanced from 2 to 3, but the session prose suggests the engagement trigger fired"), never as raw dm/ content quoted verbatim. This mirrors the world-state subagent's one-way-valve discipline — translate hidden state into observable consequences (or here, into discipline-tracking observations).

The asymmetry boundary holds because:

- The narrator still cannot read `dm/` paths (project-level denies enforce this; bookkeeper's MCP access is invisible to the narrator).
- The bookkeeper translates dm/ state into discipline-tracking findings phrased as synthesized observations, not raw state.
- All bookkeeper-issued MCP reads are logged in the dm-fs access log for audit.
- The bookkeeper's read access is scoped to three specific tiers; reading any other `dm/` path (e.g., `dm/modules/<slug>/secrets.md`) is forbidden by prompt discipline. If a future regression caused the bookkeeper to read a forbidden path, the dm-fs access log would surface it.

### Integration with prior phases

- **Phase 1:** unchanged. `/session-end` slash command still invokes the bookkeeper with the same invocation form.
- **Phase 2a (factions):** the world-state subagent's `## History` appends to `dm/factions/<slug>.md` are now read by the bookkeeper for check 4. World-state subagent's tick procedure is unchanged.
- **Phase 2b (revelations):** the revelation subagent's `## Delivered` appends to `dm/revelations/r-NNN.md` are now read by the bookkeeper for check 5. Revelation subagent's confirm procedure is unchanged.
- **Phase 2c (threads):** `dm/threads/active.md` is read by the bookkeeper for check 6. Mythic subagent's thread CRUD procedures are unchanged.
- **Phase 2d (Mythic-event spotlight):** unchanged. Random-event composition still produces session-log lines; thread interactions are covered by check 6.
- **Phase 3a–3e:** unchanged. Librarian, dm-fs MCP, lore content, revelation auto-propose, faction auto-propose all unaffected. The bookkeeper's expanded MCP access uses the same dm-fs MCP tools (`read_dm_file`, `list_dm_dir`) but does not invoke the writing tools.
- **Phase 4a:** the bookkeeper's v1 → v2 upgrade. Existing trio of checks (1, 2, 3) unchanged in semantics. Three new checks (4, 5, 6) added. Audit-section format extended. Re-audit semantic added. The Phase 4a `## Bookkeeper audit` section in `sessions/play/2026/05/session-005.md` is replaced by the v2 audit in the smoke test.

## Component designs

### File schemas

No new file schemas in Phase 4b. The bookkeeper reads existing Phase 2 file schemas:

- **`dm/factions/<slug>.md`** (Phase 2a schema, extended by Phase 3e with provenance frontmatter for auto-proposed seeds): bookkeeper reads frontmatter (`status`, `clock`, `clock-max`, `discovered`) and `## History` section.
- **`dm/revelations/r-NNN.md`** (Phase 2b schema, extended by Phase 3d with provenance frontmatter): bookkeeper reads frontmatter (`id`, `title`, `status`, `clue-count`) and `## Delivered` section.
- **`dm/threads/active.md`** (Phase 2c schema): bookkeeper reads the numbered list of open threads.

The bookkeeper does not write any of these files.

### Bookkeeper v2 changes (`.claude/agents/bookkeeper.md`)

Targeted modifications to the existing Phase 4a v1 bookkeeper:

1. **Frontmatter** gains `mcpServers: [dm-fs]` line between `tools:` and `model:`. Updated `description` field to mention the six-check scope.

2. **Intro paragraph** updated: "...runs six narrator-discipline and subagent-decision checks against the narrative prose and Phase 2 subagent state..."

3. **`## Read access`** updated:
   - Existing bullet for `sessions/`, `party/`, `library/`, `world/` — unchanged.
   - New bullet: `dm/factions/`, `dm/revelations/`, `dm/threads/` readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` and `mcp__dm-fs__list_dm_dir`. Read-only; used for checks 4, 5, 6 only. No reads outside these three tiers.
   - Updated "no access" bullet: clarify `dm/modules/`, `dm/npcs/`, and any other `dm/` path remain forbidden (project-level denies for direct tools; prompt-level discipline for MCP).

4. **`## Write access`** unchanged. Bookkeeper writes only to the session log via Edit. Explicit statement: dm-fs MCP write operations (`mcp__dm-fs__write_dm_file`, `mcp__dm-fs__create_dm_file`, `mcp__dm-fs__append_dm_file`) are never invoked.

5. **`## Your contract`** updated:
   - Sentence about scope: "...six narrator-discipline and subagent-decision checks against the narrative prose and Phase 2 subagent state..."
   - Re-audit semantic added: "If the session log already contains a `## Bookkeeper audit` section, you replace it with a fresh audit (always-replace; no flag, no abort)."
   - "You never:" bullets gain:
     - "Read `dm/` paths outside `dm/factions/`, `dm/revelations/`, and `dm/threads/`."
     - "Write to `dm/` via dm-fs MCP. Read access is for audit cross-checking only."
     - "Auto-correct subagent state. Findings are surfaced; the user decides."
     - "Quote raw `dm/` content verbatim in findings. Synthesize observations."

6. **`## Query type: audit-session`** procedure restructured:

   New step 1 (pre-flight with re-audit detection):
   > 1. **Pre-flight.** Verify the path has the form `sessions/play/<4 digits>/<2 digits>/session-<digits>.md`. Read the file. If the path is malformed or the file doesn't exist, abort with `"invalid session log path: <path>"`. If the file already contains a `## Bookkeeper audit` heading, **identify the audit-section start anchor** (the unique sequence `\n\n---\n\n## Bookkeeper audit\n` near the file's end). The bookkeeper will truncate the file at that anchor in step 11 (re-audit replace path). If the existing audit section is malformed (no recognizable anchor), abort with `"existing audit section is malformed; user must clean up manually before re-audit"`.

   Existing steps 2-6 (identify primary PC, decompose, checks 1-3) renumbered to 2-6; semantics unchanged.

   New steps 7, 8, 9 (the three subagent-decision audits):

   > **7. Check 4 — faction tick rationale.** Call `mcp__dm-fs__list_dm_dir("factions")`. For each `<slug>.md`, call `mcp__dm-fs__read_dm_file("factions/<slug>.md")`. Parse the file's `## History` section; identify entries dated this session (matching the session log's session-end date, or the most recent entry if the audited session is the latest). For each session-dated tick entry, cross-check the recorded tick decision (advance / hold / discovery / clock-filled) against the prior-session narrative's engagement-trigger surface area in the session log. Flag implausible ticks. LLM judgment; default to no-flag on ambiguity (faction tick logic is fuzzy; err toward false negatives).
   >
   > **8. Check 5 — clue delivery confirmation.** Call `mcp__dm-fs__list_dm_dir("revelations")`. For each `r-NNN.md`, call `mcp__dm-fs__read_dm_file("revelations/r-NNN.md")`. Parse the `## Delivered` section; identify entries dated this session. For each session-dated delivery, find a corresponding narrative beat in the session log that plausibly justifies the clue landing. Flag deliveries without a matching beat. Default to no-flag on ambiguity (implicit delivery via subagent inference is acceptable).
   >
   > **9. Check 6 — thread state consistency.** Call `mcp__dm-fs__read_dm_file("threads/active.md")`. Parse the list of open threads (their numbers and descriptions). For each `MYTHIC THREAD: opened/closed #N` line in the session log: (a) verify the thread number+description matches the current state in `dm/threads/active.md`, (b) find a narrative beat in the session log that justifies the open/close. Flag mismatches between the session log entry and the threads file, AND flag state changes without a matching narrative beat. Default to no-flag on ambiguity (thread descriptions are LLM-authored and may differ in wording between session log and threads file; match by content, not exact string).

   Existing step 7 (compose findings) renumbered to 10. Findings format unchanged.

   New step 11 (append-via-Edit, with re-audit replace path):

   > **11. Append the `## Bookkeeper audit` section** via Edit. Mechanism depends on whether step 1 detected an existing audit section:
   >
   >    **Write-fresh path** (no existing audit section detected in step 1):
   >    - Identify a unique terminal anchor in the file. Typically the last bullet point under `**Loose ends:**` if `## Session-end summary` is present. If no `## Session-end summary` section exists, use the file's last non-empty content line.
   >    - Verify the anchor is unique within the file. If not unique, include enough preceding context (additional lines) to make the chosen anchor string unique.
   >    - Call Edit with `old_string` = the unique anchor's exact text, `new_string` = the same anchor text followed by a blank line, `---`, blank line, `## Bookkeeper audit`, then the audit content per the format below.
   >
   >    **Re-audit replace path** (step 1 detected an existing `## Bookkeeper audit` section):
   >    - Two-pass mechanism:
   >      - Pass 1 (truncate): Call Edit with `old_string` = the audit-section anchor (`\n\n---\n\n## Bookkeeper audit\n` plus the existing audit content up to end-of-file), `new_string` = empty string. This removes the prior audit section.
   >      - Pass 2 (write fresh): Re-identify the now-terminal anchor in the truncated file (typically the last `**Loose ends:**` bullet). Call Edit with `old_string` = that anchor, `new_string` = anchor + blank line + `---` + blank line + `## Bookkeeper audit` + new audit content per the format below.
   >    - The two-pass mechanism is preferred over a single Edit-with-large-old-string for clarity and to avoid anchor-matching brittleness when the prior audit was long.

   Existing step 8 (return summary) renumbered to 12. Semantics unchanged.

7. **Audit-section format** in step 11 extends to six subsections. Updated template:

   ```markdown
   
   ---
   
   ## Bookkeeper audit
   
   **Audit complete:** <N1> dice-line gap(s), <N2> oracle-call gap(s), <N3> primary-PC overreach candidate(s), <N4> faction tick anomal(ies), <N5> clue delivery anomal(ies), <N6> thread state anomal(ies) flagged.
   
   <If N1+N2+N3+N4+N5+N6 = 0:>
   
   No discipline regressions detected.
   
   <Else, six subsections — include all six even if some have zero findings:>
   
   ### Dice-line gaps
   
   <findings or - (none)>
   
   ### Oracle-call gaps
   
   <findings or - (none)>
   
   ### Primary-PC overreach
   
   <findings or - (none)>
   
   ### Faction tick rationale
   
   <findings or - (none)>
   
   ### Clue delivery confirmation
   
   <findings or - (none)>
   
   ### Thread state consistency
   
   <findings or - (none)>
   ```

   Any warnings from step 2 (no primary PC, multiple primary PCs, no scene markers) or the new checks (e.g., empty dm/factions/, no session-dated history entries) go in a `**Warning:** ...` line immediately after the audit-complete line.

8. **`## Edge cases`** gains entries:
   - **Existing `## Bookkeeper audit` section is malformed** (no clear anchor for truncation). Abort in pre-flight with `"existing audit section is malformed; user must clean up manually before re-audit"`. No writes.
   - **`dm/factions/` is empty.** Check 4 produces zero findings. Audit summary count is 0 for check 4.
   - **`dm/revelations/` is empty.** Check 5 produces zero findings.
   - **`dm/threads/active.md` doesn't exist.** Check 6 produces zero findings (no open threads to verify).
   - **Faction/revelation file has no entries dated this session.** Skip that file for the corresponding check. Other files for the same check still processed.
   - **dm-fs MCP error mid-check.** Surface the error in the bookkeeper's response. Partial audit possible; emit `**Warning:** check <N> skipped due to MCP error: <details>` in the audit-summary section.
   - **Truncation Edit fails during re-audit replace.** Surface the error. Session log may be partially modified (truncated but not yet re-appended). User restores via `git restore sessions/play/...`.

9. **`## What you don't do`** gains:
   - Don't write to `dm/` via dm-fs MCP. The bookkeeper's MCP access is read-only.
   - Don't read `dm/` paths outside the three approved tiers (`factions/`, `revelations/`, `threads/`). No MCP reads against `modules/`, `npcs/`, or any other path.
   - Don't auto-correct subagent state. Findings are surfaced; the user decides.
   - Don't quote raw `dm/` content verbatim in findings. Synthesize observations.
   - Don't preserve the prior audit section on re-audit. Always replace; the user can `git restore` if they want to revert.

### CLAUDE.md rule 10 update

Replace the existing Phase 4a wording with Phase 4b wording:

> ### 10. Bookkeeper audit at session-end
> 
> The bookkeeper subagent audits each session log at session-end for narrator-discipline and subagent-decision compliance. You do not invoke the bookkeeper during play — `/session-end` invokes it for you between chaos-factor adjustment and commit, with the active session log path as argument. The bookkeeper reads the log and the relevant Phase 2 subagents' `dm/` state via the dm-fs MCP (`dm/factions/`, `dm/revelations/`, `dm/threads/` — read-only), runs six checks (dice-line presence for narrated mechanical outcomes, oracle-call presence for narrated answers to uncertain questions, primary-PC overreach for narrated actions/dialogue attributed to the primary PC, faction tick rationale, clue delivery confirmation, thread state consistency), and appends a `## Bookkeeper audit` section to the log (replacing any pre-existing audit section). Findings are discipline-tracking signal — they document patterns to review post-session — and do not block the commit in the current phase.
> 
> Treat the bookkeeper as a session-boundary subagent like world-state's offscreen-developments tick: invoked by a slash command at the boundary, not by you during play. Do not try to invoke the bookkeeper for ad-hoc audits; Phase 4b does not support that path (ad-hoc invocation is Phase 4c).

### Repository layout (Phase 4b additions)

```
gygaxagain/
├── .claude/agents/
│   └── bookkeeper.md            # MODIFIED — v1→v2: mcpServers, expanded ## Read access, 3 new checks, re-audit semantic, extended audit format
├── CLAUDE.md                    # MODIFIED — rule 10 wording updated; ## Current phase scope updated
└── sessions/play/2026/05/
    └── session-005.md           # MODIFIED (smoke-test artifact) — Phase 4a audit replaced with Phase 4b audit
```

## Smoke test for Phase 4b

### Primary smoke test — bookkeeper v2 re-audit of `session-005.md`

Session-005 has a Phase 4a audit section (zero findings). The Phase 4b smoke test exercises the replace-on-rerun path plus the three new subagent-decision checks against rich session content. Session-005 has:
- `WORLD-STATE QUERY: offscreen tick` line at session start.
- `WORLD-STATE QUERY: NPC behavior` queries throughout.
- `MYTHIC THREAD: opened #5` and `#6` (two new threads opened this session).
- Reference to clue delivery: "(clue c-001b delivered for r-001)".
- Populated `dm/factions/` (`ashen-vintners.md`, `cult-of-myrkul.md`), populated `dm/revelations/` (r-001 through r-005), populated `dm/threads/active.md` (multiple threads).

**Procedure:**

1. With the v2 bookkeeper prompt in place, restart Claude Code so the v2 prompt loads with `mcpServers: [dm-fs]`.
2. Dispatch the bookkeeper directly:
   ```
   Agent(subagent_type="bookkeeper", prompt="Audit session sessions/play/2026/05/session-005.md.")
   ```
3. The bookkeeper:
   - Reads `sessions/play/2026/05/session-005.md`.
   - Detects the existing `## Bookkeeper audit` section; identifies the anchor.
   - Globs `party/primary/`; identifies `dagnal`.
   - Decomposes the log (excluding the existing audit section) into prose vs subagent-log lines.
   - Runs checks 1-3 (narrator-discipline trio) — likely zero findings (matching Phase 4a's audit).
   - Calls `mcp__dm-fs__list_dm_dir("factions")` + per-faction `mcp__dm-fs__read_dm_file` for check 4.
   - Calls `mcp__dm-fs__list_dm_dir("revelations")` + per-revelation `mcp__dm-fs__read_dm_file` for check 5.
   - Calls `mcp__dm-fs__read_dm_file("threads/active.md")` for check 6.
   - Composes findings.
   - Truncates the file at the prior audit-section anchor (re-audit replace path, pass 1).
   - Writes the new six-check audit section (re-audit replace path, pass 2).
   - Returns a brief summary.

**Pass criteria:**

- The session log's `## Bookkeeper audit` section now reflects the v2 format:
  - Audit-complete summary line has six counts in the documented order.
  - Either `No discipline regressions detected.` OR six `### <check name>` subsections — three from Phase 4a plus three new — each with findings or `- (none)`.
- The pre-existing Phase 4a audit section is **REPLACED, not duplicated**. `grep -c "^## Bookkeeper audit" sessions/play/2026/05/session-005.md` returns exactly 1.
- The session log's non-audit content (narrative prose, subagent log lines, `## Session-end summary`) is unchanged byte-for-byte vs the pre-smoke-test state. Verify via comparison of `git diff` against the pre-Phase-4b head — only the audit section content differs.
- `git status` shows only `sessions/play/2026/05/session-005.md` modified. No other files touched.
- dm-fs access log shows bookkeeper-issued operations during the smoke test window:
  - `list_dm_dir factions` (exactly 1).
  - `read_dm_file factions/<slug>.md` (one per faction file, currently 2: ashen-vintners.md, cult-of-myrkul.md).
  - `list_dm_dir revelations` (exactly 1).
  - `read_dm_file revelations/r-NNN.md` (one per revelation file, currently 5: r-001.md through r-005.md).
  - `read_dm_file threads/active.md` (exactly 1).
- dm-fs access log shows NO bookkeeper-issued writes. Specifically: zero `create_dm_file`, `write_dm_file`, `append_dm_file` operations attributable to the bookkeeper during the smoke test window.
- Findings (if any) are plausible. Some categories likely to surface:
  - Check 4: session-005's `WORLD-STATE QUERY: offscreen tick — 1 active faction, 1 ticked, 0 beats fired, 0 discoveries` line should correspond to a `## History` entry in `ashen-vintners.md`. The bookkeeper either finds no anomaly (tick rationale matches narrative) or surfaces a plausible discrepancy.
  - Check 5: session-005's prose mentions "(clue c-001b delivered for r-001)"; the corresponding `r-001.md` `## Delivered` should have the matching entry. Check 5 verifies the match.
  - Check 6: session-005 opens threads #5 and #6; the bookkeeper verifies they appear in `dm/threads/active.md` with matching descriptions, and finds the narrative beats that justify the opens.
- All 37 existing dm-fs MCP tests continue to pass; no Python code added.

**User reviews findings** as in Phase 4a — judging true positive / false positive / borderline. False positives expected for the new checks (LLM-judgment-fuzzy); the primary signal is "the bookkeeper produces a well-formed v2 audit with plausible reasoning across all six checks, replacing the prior Phase 4a audit cleanly."

**Commit the smoke-test artifact** — the modified session-005.md with the new v2 audit section.

### Secondary smoke test — fresh audit on an unaudited session

Verifies the write-fresh path (no existing audit section) still works after v2's restructuring. Optional but recommended.

Pick an unaudited session, e.g., `sessions/play/2026/05/session-004.md`. Dispatch the bookkeeper. Verify:
- The audit section is appended (not duplicated). `grep -c "^## Bookkeeper audit"` returns 1.
- Format matches v2 (six counts, six subsections or zero-findings literal).
- The write-fresh path correctly identifies the file has no existing audit and skips the truncation step.

After verification, optionally revert session-004.md via `git restore` (the test artifact is session-005.md; session-004 was just to validate the write-fresh path). Or commit session-004's audit too — the user decides.

### Asymmetry audit

Phase 4b expands the bookkeeper's read scope to `dm/` via MCP. The asymmetry boundary remains intact:

1. **Narrator's `dm/` denies in `.claude/settings.json` are unchanged.** Verify via relative-path probes after the smoke test:
   - `cd /Users/.../gygaxagain && cat dm/factions/cult-of-myrkul.md` → DENIED.
   - `cd /Users/.../gygaxagain && cat dm/revelations/r-001.md` → DENIED.
   - `cd /Users/.../gygaxagain && cat dm/threads/active.md` → DENIED.
   - `cd /Users/.../gygaxagain && cat dm/modules/ancient-tomb-of-phandalin/secrets.md` → DENIED.

2. **Bookkeeper has read-only dm-fs access scoped to three tiers.** Inspect the v2 bookkeeper file:
   - `mcpServers: [dm-fs]` declared.
   - `## Read access` lists exactly three `dm/` tiers (factions/, revelations/, threads/).
   - `## What you don't do` enumerates the forbidden paths and the no-write-to-dm/ discipline.

3. **dm-fs access log contains only bookkeeper-issued reads** during the smoke test:
   ```bash
   tail -50 tools/dm-fs-mcp/access.log | grep -E "factions|revelations|threads"
   ```
   Bookkeeper-period entries are `list_dm_dir` and `read_dm_file` only. Zero `write_dm_file`, `create_dm_file`, `append_dm_file` from the bookkeeper. All reads against the three approved tiers; zero reads against `modules/`, `npcs/`, or other dm/ paths.

4. **Phase 3a/3d/3e narrator-side `dm/` boundaries hold.** Same probes as Phase 4a's asymmetry audit. The expanded bookkeeper MCP access does not weaken narrator-side denies.

5. **Phase 3c narrator-readable lore boundary holds.** `library/lore/test-bestiary/entries/goblin.md` still readable directly by the narrator.

### Failure modes Phase 4b must handle

- **Session log doesn't exist or wrong path format.** Same as Phase 4a — abort in pre-flight with `"invalid session log path: <path>"`. No writes.
- **Existing `## Bookkeeper audit` section is malformed** (no clear anchor for truncation). Abort with `"existing audit section is malformed; user must clean up manually before re-audit"`. No writes.
- **`dm/factions/` is empty.** Check 4 produces zero findings; audit summary count is 0. No error.
- **`dm/revelations/` is empty.** Check 5 produces zero findings.
- **`dm/threads/active.md` doesn't exist.** Check 6 produces zero findings (no open threads to verify).
- **Faction/revelation file has no entries dated this session.** That file is skipped for the corresponding check; other files for the same check still processed.
- **dm-fs MCP error mid-check.** Surface the error in the bookkeeper's response. Partial audit possible; emit `**Warning:** check <N> skipped due to MCP error: <details>` in the audit-summary section. Other checks proceed.
- **Truncation Edit fails during re-audit replace** (pass 1 of two-pass mechanism). Surface the error. Session log may be partially modified (the prior audit was being removed but the operation didn't complete). User restores via `git restore sessions/play/...` and re-runs.
- **Append Edit fails after successful truncation** (pass 2 fails). Session log is in a worse state — prior audit removed but new audit not yet written. User restores via `git restore` and re-runs.
- **LLM judgment wrong on new checks.** Expected and acceptable in Phase 4b. False positives surfaced; user reviews. Phase 4c+ tunes the prompt's judgment based on accumulated audit signal.
- **Bookkeeper attempts to read a forbidden dm/ path** (e.g., `dm/modules/<slug>/secrets.md`). The dm-fs MCP itself permits the read (no path filter at MCP layer); the prompt's discipline rule is the only barrier. If a regression caused the bookkeeper to read a forbidden path, the dm-fs access log would surface it during the asymmetry audit. The smoke test's asymmetry probe checks this.
- **Phase 4a audit section's anchor pattern differs from Phase 4b's expected anchor.** Verify session-005's actual Phase 4a audit section starts with `\n\n---\n\n## Bookkeeper audit\n` (mirror the format the bookkeeper wrote in Phase 4a). The Phase 4b bookkeeper's pre-flight detection logic must match this. If mismatch: update either the bookkeeper's anchor detection or the Phase 4a audit format (in retrospect — Phase 4a's smoke test artifact is the reference).
- **Concurrent dispatching** of the bookkeeper from multiple sources (theoretical — slash command + ad-hoc test invocation). Phase 4b is single-threaded; race conditions are not a real concern. If they occur, Edit failures surface them.

## Open questions resolved during brainstorming

- **Sub-slicing of Phase 4b:** subagent decision audits (three Phase 2 tiers) plus minimal re-audit semantics (always-replace). Live-write integrity, ad-hoc invocation slash command, and full re-audit mode flags deferred to Phase 4c.
- **Audit scope for Phase 4b:** three new subagent-decision checks (faction tick rationale, clue delivery confirmation, thread state consistency), bringing the bookkeeper from three checks to six.
- **dm-fs MCP access scope:** minimal — three specific tiers (`dm/factions/`, `dm/revelations/`, `dm/threads/`). The MCP exposes all dm/, but the prompt enforces the path discipline. Read-only; no write operations used.
- **Re-audit semantic:** always-replace. No flag, no abort, no append. Simplest useful behavior; unblocks smoke-testing against session-005 (which has a Phase 4a audit); flag-based modes deferred to Phase 4c when ad-hoc invocation lands.
- **Append mechanism for re-audit:** two-pass (truncate, then write fresh). Clearer than a single Edit-with-large-old-string, avoids anchor-matching brittleness on long prior audits.
- **Findings format:** same as Phase 4a — line reference, suspect text excerpt, reasoning. New checks use "anomalies" rather than "gaps" in the summary line to reflect the state-vs-narrative mismatch semantic.
- **Audit-section format:** six subsections in fixed order (3 narrator-discipline + 3 subagent-decision); audit-complete summary line extends from three counts to six.
- **CLAUDE.md changes:** rule 10 wording updated; `## Current phase scope` updated. No new rule. No new must-never bullet.
- **MCP changes:** none. Existing `read_dm_file` and `list_dm_dir` cover all 4b operations.
- **Python code added:** none.
- **`/session-end` changes:** none. Re-audit handled internally by the bookkeeper.

## Phase 4b → Phase 4c+ handoff

Phase 4b's exit opens potential Phase 4c content:

- **Live-write integrity audit.** Compares git diff at session-end against session log narrative. Reasons across narrative + state + diff. Phase 4c. Builds on Phase 4b's dm-fs MCP read access pattern.
- **Intake-decision audit.** Did the librarian's reveal-vs-flavor judgment for auto-proposed seeds make sense? Phase 4c or 4d. Requires extending bookkeeper read access to `dm/modules/`.
- **Library-bypass detection.** Narrator improvised content where a librarian module already covers the scope. Phase 4c. Uses library/lore/ (already readable) + dm/modules/ (extends bookkeeper read scope).
- **Ad-hoc bookkeeper invocation.** `/audit-session <path>` slash command for re-audits, dry-runs, historical audits. Phase 4c. May add mode flags (replace / append / dry-run) to the bookkeeper's invocation.
- **Re-audit modes beyond always-replace.** Append (preserve prior + add new), abort-with-`--force` flag, merge (combine findings). Phase 4c.
- **Structural-change proposals.** NPC promotion candidates, faction cascade candidates, source-overlap merges. Phase 4c. Surfaces opportunities the bookkeeper detected during audits as actionable suggestions.
- **Authoring formalization.** `/author-npc`, `/author-milestone`, hand-authoring helpers. Phase 4d.
- **Additional lint rules.** Hook text leaking revelation phrasing, naked thread number references. Phase 4d–4e.
- **Cross-session aggregate roll-up.** `sessions/audits/index.md` for cross-session pattern detection. Phase 4d or 4e.
- **Bookkeeper-owned commit discipline.** The bookkeeper authors the commit message and runs `git commit`, replacing the slash command's `git add -A && git commit`. Phase 4c+.
- **NPC system.** Originally scoped for Phase 4; deferred to Phase 4d or a dedicated NPC phase.
- **Opt-in blocking on findings.** Phase 4e may introduce blocking for high-severity findings.

The pattern Phase 4b establishes — "bookkeeper gains read access to specific `dm/` tiers via MCP, adds audits that cross-check subagent decisions against narrative without modifying subagent behavior, supports replace-on-rerun for iterative audit improvement" — is the substrate for Phase 4c+ extensions.

## Roadmap context

Phase 4b sits within Strategy A (vertical slices by playability). Updated phasing:

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
11. **Phase 4a — MVP bookkeeper (narrator-discipline trio at session-end).** *(complete)*
12. **Phase 4b — Bookkeeper subagent-decision audits + replace-on-rerun semantic.** *(this design)*
13. **Phase 4c — Bookkeeper extensions: live-write integrity, intake-decision audit, library-bypass detection, ad-hoc invocation slash command, full re-audit mode flags, structural-change proposals.**
14. **Phase 4d — Authoring formalization (NPC system, milestone authoring, hand-authoring helpers); additional lint rules.**
15. **Phase 4e — Remaining lint rules, cross-session aggregate roll-up, opt-in blocking. Further slicing determined when Phase 4e is brainstormed.**
16. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
17. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
18. **Phase 7 — Downtime, banking, bastions.**

Phase 4b's scope is what's locked here.
