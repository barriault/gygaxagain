# Phase 3e — Faction Auto-Proposals from Module Material Design

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
**Slice of original Phase 3:** auto-propose **factions only** from module material. Mirrors the Phase 3d revelation-auto-propose pattern structurally. Solo-engine intake, methodology intake, gazetteer-essay-shape lore intake, URL ingestion, optional `consult-lore`, optional lore-side quarantine, and optional librarian.md split (intake/runtime/shared) deferred to Phase 3f or later.

## Purpose

Phase 3d closed the auto-propose loop for revelations — module `secrets.md` content maps cleanly to Phase 2b's revelation schema, and the librarian writes `dm/revelations/r-NNN.md` seed files at intake time and via the standalone `propose-revelations` query. Factions were deferred from 3d because the Phase 2a faction schema demands speculative content (clock-max, four-rung observable-consequences ladder, engagement triggers, on-clock-filled beat) that the librarian can only partially infer from module material.

Phase 3e closes the loop for factions using a TODO-marker discipline: the librarian fills inferrable fields (Identity, Active operation, Discovery, ladder rungs Mid/High/Full, on-fill beat) from source content and TODO-marks the genuinely speculative fields (ladder rungs Low for offscreen pre-engagement consequences, additional engagement-trigger patterns, post-op state). The seed defaults to `status: dormant` + `discovered: false`, which makes it inert under the Phase 2a world-state subagent's skip-non-active rule until the user reviews, completes the TODOs, and flips status.

Phase 3e's load-bearing claim is twofold:

1. **The librarian can produce useful faction seed files from module material** — useful enough that user editing during commit-gate review is a manageable fraction of authoring rather than full re-authoring.
2. **The `status: dormant` default is a safe inert state.** Seed files committed without further editing are picked up by the world-state subagent's tick but skipped via the existing skip-non-active rule, so partial seeds don't disrupt session play.

Both claims validated by smoke-testing against the existing Phandalin intake plus a Phase 2a backward-compatibility probe.

After Phase 3e, the dm-side auto-propose loop is closed for both major Phase 2 content tiers (revelations + factions). Threads remain intentionally session-driven (Phase 2c's `open-thread` is the right authoring surface); NPCs have no Phase 2 system to auto-propose into.

## Definition of done

A successful Phase 3e build demonstrates all of:

- **Librarian gains write access to `dm/factions/`** via the dm-fs MCP. Fourth dm-side write path on the librarian's contract (after `dm/modules/` from Phase 3a, `dm/revelations/` from Phase 3d, and now `dm/factions/`).

- **Librarian gains read access to `dm/factions/`** via the dm-fs MCP, used exclusively for `propose-factions` idempotency scans (reading existing faction files to detect slug collisions and provenance matches). No reads outside idempotency scans.

- **`intake-module` procedure gains a new step 9 — "Propose faction seeds from module material"** — that runs after the existing step 8 (propose-revelations) and before the structured summary (which becomes step 10; the session-log line becomes step 11). The librarian scans `dm/modules/<slug>/` content (overview.md `faction-archetypes` frontmatter, secrets.md hidden NPC identities & motives, connections.md faction-conditional logic, selected nodes for faction-NPC context), identifies faction candidates, performs an idempotency scan against `dm/factions/`, and writes `dm/factions/<faction-slug>.md` seed files via `mcp__dm-fs__create_dm_file`.

- **New query type on the librarian:** `propose-factions <module-slug>`. For retroactive use on already-ingested modules. Reads the existing `dm/modules/<module-slug>/` content, runs the propose-factions procedure, writes seeds. Used to backfill Phandalin (or any prior intake) without re-ingesting the whole module.

- **Faction seed file produced by Phase 3e auto-propose** has the documented schema:
  - Frontmatter: `name`, `slug`, `status: dormant`, `discovered: false`, `clock-max: 6`, plus two new provenance fields `proposed-from-module: <module-slug>` and `proposed: <YYYY-MM-DD>`. **All frontmatter values are valid YAML — no TODO markers in frontmatter positions.**
  - `# <Faction Name>` heading.
  - `## Identity` — 2-4 sentences, filled from source (overview.md faction-archetypes + secrets.md hidden NPC identities + nodes/* NPCs).
  - `## Active operation` — 2-3 sentences, filled from source (module's central arc/pressure).
  - `## Observable consequences ladder` — four rung bullets (Low / Mid / High / Full). Mid/High/Full filled from source (module climax content). Low TODO-marked with prose hint (the module doesn't tell us what pre-engagement offscreen consequence the party should notice; user fills in based on campaign cadence).
  - `## Engagement triggers` — one or two patterns filled from source (module hooks + connections.md conditional logic), plus one TODO-marked bullet for additional patterns.
  - `## Discovery` — `**Trigger:**` and `**Public name on discovery:**` both filled from source (secrets.md hidden-identity reveal moments).
  - `## On clock filled` — `**Beat:**` filled from source (module's climax beat). `**Post-op state:**` TODO-marked (dormant vs retired is a campaign-arc decision).
  - `## History` — empty with schema-reminder comment; the world-state subagent appends per tick once status is active.

- **Updated `intake-module` summary template** includes a new "Faction seeds proposed" section between the existing "Revelation seeds proposed" and "Secret-quality content notes flagged for human verification" sections. NEXT STEPS list extended with a faction-review step describing the TODO-completion-and-flip-status workflow.

- **`propose-factions` query returns a parallel structured summary** with the same "Faction seeds proposed" enumeration plus "Existing faction files for this module" count (skipped via idempotency) and the standard NEXT STEPS block.

- **Idempotency via slug-collision check.** Before writing a candidate, the librarian reads `dm/factions/` via `mcp__dm-fs__list_dm_dir` and reads each existing file's frontmatter via `mcp__dm-fs__read_dm_file` to build a set of existing slugs. Candidates whose slug already exists are skipped (whether the existing file is hand-authored Phase 2a content or 3e-authored from a previous run or different module — the existing file always takes precedence). Slug derivation from faction names in source content is expected to be stable across runs: same module content → same slug derivations → safe re-run idempotency. The `proposed-from-module` provenance frontmatter is metadata for audit and summary messaging only — it does not gate skip decisions.

- **Backward compatibility with Phase 2a world-state subagent.** The two new frontmatter fields (`proposed-from-module`, `proposed`) are not in the original Phase 2a schema. The world-state subagent's frontmatter parsing acts on `status`, `clock-max`, `discovered`, `known-as`; unknown fields are ignored. The `status: dormant` default makes seeds inert under world-state's step 1 ("Skip any whose `status` is not `active`"). Validated by smoke test: run an offscreen-developments tick with a Phase 3e-written seed present, confirm the seed is skipped without parse errors and without modification.

- **Smoke test:** run `propose-factions ancient-tomb-of-phandalin` against the existing Phandalin intake. Verify at least one `dm/factions/<faction-slug>.md` seed file is written with the documented schema (frontmatter all valid YAML, body sections present, TODO discipline correctly applied). Asymmetry audit confirms the main agent cannot `cat` the new seed file directly. Phase 2a backward-compat probe confirms the world-state subagent's offscreen tick skips the dormant seed without error.

- **CLAUDE.md** gains one paragraph in `## Library reference material` noting that faction seeds created by Phase 3e default to dormant + undiscovered and are inert until reviewed and flipped active. No new routing rule. No new must-never bullet.

- All 87 existing tests continue to pass; no Python code added.

- **No new MCP tools.** Existing `mcp__dm-fs__create_dm_file` + `mcp__dm-fs__list_dm_dir` + `mcp__dm-fs__read_dm_file` cover all 3e operations.

- **No new slash command.** The `propose-factions` query is dispatched directly via the Agent tool (or invoked as part of `/intake`).

- **Librarian stays single-file.** Decided this brainstorm to defer any `librarian.md` split until/unless a future phase demonstrates that discipline regresses with the larger file.

## Out of scope (deferred to Phase 3f or later)

- **Thread auto-proposals.** Threads remain session-driven (e.g., "the missing Mercers"). Modules don't surface threads at intake time. Phase 2c's `open-thread` runtime query is the right authoring surface; intake-time thread creation isn't needed. Deferred indefinitely.
- **NPC seed proposals (`dm/npcs/`).** Phase 2 doesn't have an NPC system in the same sense as factions/revelations. The Phandalin intake summary flagged Kodor as a candidate NPC; that stays as a summary flag until Phase 4 or a dedicated NPC-system phase.
- **Auto-propose for modules ingested before Phase 3e shipped** (other than via the standalone `propose-factions` query). Phase 3e's `intake-module` step 9 only runs at intake time for new ingestions. Phandalin (intaken before 3e) is handled via the standalone `propose-factions` query.
- **Bulk `propose-factions` across all ingested modules.** Phase 3e's standalone query takes one module slug. If multiple modules need backfilling, the user invokes the query per module. Phase 3f or Phase 4 may add a bulk variant.
- **Solo-engine intake, methodology intake, gazetteer-essay-shape lore intake, URL ingestion, optional `consult-lore` runtime curated query, optional lore-side quarantine, optional `rename_dm_file` MCP tool.** All deferred to Phase 3f+ or never.
- **Librarian split (intake/runtime/shared).** Decided this brainstorm to defer. The faction additions push librarian.md past the rough ~450-line threshold to ~475–495 lines. The threshold is a smell, not a hard limit; revisit if/when a later phase reveals discipline regression.
- **Validation that a Phase 3e-proposed ladder rung or engagement trigger is well-anchored to module content.** The librarian uses LLM judgment. Validation is the user's responsibility during commit-gate review. The TODO markers make the unanchored fields explicit.
- **Schema migration tooling.** If Phase 4+ changes the faction schema, the Phase 3e-written seeds may need migration. Out of scope for 3e; auto-propose produces files in the current Phase 2a schema.
- **Two-pass librarian "co-author" mode.** A future phase might let the librarian propose faction seeds, present them to the user inline, accept edits, and re-write. Out of scope here — current 3e is one-shot-write + user-edits-via-shell, same as 3d.
- **World-state subagent changes.** Phase 2a is untouched at the prompt level.

## Architecture

### Slice mapping

| Component                          | Phase 3e touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | One paragraph addition to `## Library reference material` in `CLAUDE.md`. No new routing rule. No new must-never bullet. |
| **World-state subagent**           | **Untouched at the prompt level.** Seed files produced by 3e are valid Phase 2a faction files; the `status: dormant` default makes them inert by the existing skip-non-active rule. Backward compatibility validated by smoke test. |
| Revelation subagent                | Untouched. |
| Mythic subagent                    | Untouched. |
| Dice subagent                      | Untouched. |
| **Librarian subagent**             | **MODIFIED** — `.claude/agents/librarian.md`. New `## Read access` bullet for `dm/factions/` (idempotency-scan use only). New `## Write access` bullet for `dm/factions/`. Frontmatter description updated to mention six query types. `## Your contract` updates from triple-write-path to quadruple-write-path. New `intake-module` step 9 + renumbered summary/log steps. New `## Query type: propose-factions` section. Edge cases and `## What you don't do` lists updated. |
| `dm-fs` MCP                        | No tool changes. `mcp__dm-fs__create_dm_file` + `mcp__dm-fs__list_dm_dir` + `mcp__dm-fs__read_dm_file` cover all 3e operations. |
| `.claude/settings.json`            | No deny-rule changes. |
| `/intake` command                  | Untouched. The new auto-propose step is internal to the librarian's `intake-module` query. |
| Other slash commands               | Untouched. |
| Repository layout                  | No new directories. `dm/factions/` is existing from Phase 2a. Smoke-test artifacts: one or more new `dm/factions/<faction-slug>.md` seed files for Phandalin's faction candidates. |

### Information-asymmetry preservation

**No new tiers introduced.** Phase 3e operates entirely within the existing three-tier model:

- Modules → `dm/modules/<slug>/` (dm-quarantined). Unchanged.
- Lore → `library/lore/<source-slug>/` (narrator-readable). Unchanged.
- Revelations → `dm/revelations/` (dm-quarantined). Unchanged.
- **Factions → `dm/factions/`** (dm-quarantined; Phase 2a established this). The librarian gains write access here, joining the existing Phase 2a world-state subagent (which has both read and write access). Both subagents write via the dm-fs MCP. The narrator has no access to `dm/factions/` directly — Phase 2a's world-state subagent remains the sole runtime path (via offscreen-developments tick at session-start, which surfaces observable consequences without naming the faction unless `discovered: true`).

The asymmetry boundary holds because:

- `dm/**` denies in `.claude/settings.json` stay in place. The narrator cannot directly read or write any `dm/` content.
- The librarian writes `dm/factions/<faction-slug>.md` via `mcp__dm-fs__create_dm_file`, the same path the world-state subagent uses for its own Phase 2a writes (`mcp__dm-fs__write_dm_file` for tick updates, `mcp__dm-fs__append_dm_file` for history-trail lines).
- The narrator's runtime path to faction content remains the world-state subagent's offscreen-developments tick. Phase 3e does NOT give the narrator any new access. The Phase 2a routing wording in CLAUDE.md is unchanged.

The dm-fs access log captures all librarian-issued writes to `dm/factions/`, so the smoke-test asymmetry audit naturally extends — librarian writes are `create_dm_file` only; world-state writes are `write_dm_file`/`append_dm_file`; the asymmetry probe greps for non-world-state writes to `dm/factions/` and confirms they're attributable to the librarian during `intake-module` step 9 or `propose-factions` invocations.

### Integration with prior phases

- **Phase 1:** unchanged.
- **Phase 2a (factions):** world-state subagent is untouched at the prompt level. Seed files produced by Phase 3e are valid Phase 2a faction files — frontmatter values are all valid YAML (TODOs in body only), and the `status: dormant` default makes them inert under world-state's step 1 skip-non-active rule. The defensive "skipped: malformed frontmatter" path remains for the (unintended) case where TODO discipline regresses and a future librarian revision lets a TODO into a frontmatter position. Backward compatibility validated by smoke test.
- **Phase 2b (revelations), 2c (threads), 2d (Mythic-event spotlight):** unchanged.
- **Phase 3a (module intake):** the `intake-module` procedure gains a new step 9 between existing step 8 (propose-revelations) and what becomes step 10 (emit intake summary; the existing step 10 — session-log line — becomes step 11). The summary template is extended with the new "Faction seeds proposed" section. NEXT STEPS list gets a faction-review step describing the TODO-completion-and-flip-status workflow.
- **Phase 3b (runtime queries):** unchanged. `consult-library` and `reveal-from-module` still operate against `dm/modules/<slug>/`. Phase 3e's auto-propose does NOT depend on these runtime queries — it works directly from module content read via dm-fs MCP during intake-module or propose-factions.
- **Phase 3c (lore intake):** unchanged. The librarian's `intake-lore` procedure is unrelated to faction auto-proposals.
- **Phase 3d (revelation auto-propose):** unchanged. The two auto-propose steps run sequentially in `intake-module` — revelations first (step 8), factions second (step 9). Both share the provenance-frontmatter idempotency pattern but use different idempotency keys (revelations: subject-matter LLM judgment; factions: slug-collision + provenance scan).

## Component designs

### File schemas

#### `dm/factions/<faction-slug>.md` (seed file produced by Phase 3e)

```markdown
---
name: <Faction Name — narrator-internal phrasing>
slug: <faction-slug>
status: dormant
discovered: false
clock-max: 6
proposed-from-module: <module-slug>
proposed: <YYYY-MM-DD>
---

# <Faction Name>

## Identity

<2-4 sentences. Who they are, who's in them, what their broad agenda is. Derived from overview.md faction-archetypes + secrets.md hidden NPC identities + nodes/* NPCs. Always filled from source — never TODO.>

## Active operation

<2-3 sentences. What they're currently doing in the world. Module-aligned: this is the module's central pressure. Always filled from source — never TODO.>

## Observable consequences ladder

- **Low (clock 1-2):** <TODO: what offscreen consequence does the party notice before they directly engage this faction? The module doesn't suggest one — fill in based on your campaign cadence.>
- **Mid (clock 3-4):** <module-derived mid-pressure consequence, filled from source>
- **High (clock 5):** <module-derived high-pressure consequence, filled from source>
- **Full (clock 6):** <module's climax-tier consequence, filled from source>

## Engagement triggers

- <module-hook-derived trigger pattern, 1-2 the librarian can infer from hooks.md + connections.md, filled from source>
- <TODO: add more patterns based on how you want this faction to slow when the party presses>

## Discovery

**Trigger:** <module-derived discovery moment — when the party would unambiguously learn this faction exists. Filled from secrets.md hidden-identity reveal context.>

**Public name on discovery:** <name the party would call this faction in-fiction>

## On clock filled

**Beat:** <the module's climax beat for this faction, 1-2 sentences>

**Post-op state:** <TODO: `dormant` (faction recedes, may return) or `retired` (resolved). Pick based on how you want this faction's arc to close.>

## History

<!-- Append-only. The world-state subagent writes here per offscreen-developments tick once status is active. Each entry: "- session NNN, YYYY-MM-DD: <one-line history entry>" -->
```

Schema notes:

- **Two new frontmatter fields** vs Phase 2a's original schema:
  - `proposed-from-module: <module-slug>` — documents auto-propose provenance. Used by the librarian for idempotency (skip re-proposing if a seed already references the same module from a same-slug candidate).
  - `proposed: <YYYY-MM-DD>` — date stamp.
- **Backward-compatible with Phase 2a parsing.** The world-state subagent's frontmatter parsing acts on `status`, `clock-max`, `discovered`, `known-as`; unknown fields are ignored. Smoke test validates by running an offscreen tick against the new seed.
- **`status: dormant` + `discovered: false` defaults** are the safety guarantee. The world-state subagent's step 1 skips non-active factions; the seed is inert until the user reviews, completes the TODOs, and flips `status` to `active`.
- **`clock-max: 6` default** matches Phase 2a's documented default. Some campaigns prefer 4 (matching a four-rung ladder cleanly); the user adjusts during commit-gate review if desired. Note: Phase 2a's tick procedure scales ladder rung selection proportionally for any `clock-max`, so the four-rung ladder works whether the clock is 4 or 6.
- **TODO markers in body only.** Frontmatter values are always valid YAML. This is the discipline boundary: the seed must parse correctly as a Phase 2a faction file even before the user fills in TODO markers. Defensive: if the discipline regresses and a TODO leaks into a frontmatter position, the world-state subagent's existing "skipped: malformed frontmatter" path catches it without disrupting other factions.
- **Why `status: dormant` not `status: active`:** an actively-ticking seed with TODO-marked ladder rungs would, on first session-start after commit, ask the world-state subagent to surface "Low (clock 1-2): TODO: what offscreen consequence does the party notice..." as observable consequence text. That would either leak the TODO marker into narrator prose or cause the world-state subagent to substitute opaque text. Dormant default avoids the problem cleanly — the user explicitly flips status when ready.

### Librarian subagent changes (`.claude/agents/librarian.md`)

Six targeted modifications to the existing Phase 3d v5 librarian:

1. **Frontmatter description** updated to mention `propose-factions` alongside the existing five query types (`intake-module`, `intake-lore`, `consult-library`, `reveal-from-module`, `propose-revelations`).

2. **`## Read access`** gains a new bullet:

   > - `dm/factions/` — readable **only** through the `dm-fs` MCP. Used during `propose-factions` for idempotency scans (reading existing faction files to check slug collisions and `proposed-from-module` frontmatter matches). No reads outside idempotency scans.

3. **`## Write access`** gains a new bullet:

   > - `dm/factions/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file`. New under Phase 3e for faction auto-proposals. Same gate as `dm/modules/` and `dm/revelations/`; no `Edit(dm/**)` access. You only create new faction files; existing ones are owned by Phase 2a's world-state subagent and may not be mutated.

4. **`## Your contract`** updates the triple-write-path sentence to quadruple-write-path:

   > "All module content writes go to `dm/modules/<slug>/` via the dm-fs MCP. Revelation seed writes go to `dm/revelations/r-NNN.md` via the dm-fs MCP (Phase 3d). Faction seed writes go to `dm/factions/<faction-slug>.md` via the dm-fs MCP (Phase 3e). All lore content writes go to `library/lore/<source-slug>/` via direct Write. Module and lore writes also produce a one-line enumeration entry in `library/index.md`; revelations and factions are tracked by their respective Phase 2 subagents (revelation, world-state) independently."

5. **`intake-module` procedure gains step 9** (between existing step 8 'Propose revelation seeds' and the renumbered step 10 'Emit intake summary'; existing step 10 'Log a single line to the active session log' becomes step 11):

   > **9. Propose faction seeds from module material.** Scan the module content you wrote in step 6. For each plausible faction candidate (a faction the module establishes through `overview.md` `faction-archetypes` frontmatter, `secrets.md` hidden NPC identities & motives, `connections.md` faction-conditional logic, or `nodes/*.md` NPCs with faction context), propose a faction seed:
   >
   > 1. Identify candidate factions. For each one, derive a slug (kebab-case from the faction name, e.g., `kodors-thrall-cult`). Build a list of `(slug, name, sources-touched)` tuples.
   > 2. Call `mcp__dm-fs__list_dm_dir("factions")` via dm-fs MCP to enumerate existing faction files.
   > 3. For each existing faction file, call `mcp__dm-fs__read_dm_file("factions/<faction-slug>.md")` and parse its frontmatter. Build a set of existing slugs. Also note which existing files have `proposed-from-module: <current module slug>` (this is metadata for the summary — distinguishes "skipped because already proposed from this module" from "skipped because slug collides with hand-authored faction"). **Skip a candidate** if its slug appears in the existing-slugs set. The existing file always takes precedence regardless of whether it's hand-authored Phase 2a content or 3e-authored from a prior run.
   > 4. For each remaining candidate, write `dm/factions/<faction-slug>.md` via `mcp__dm-fs__create_dm_file` with the schema documented in the Phase 3e spec:
   >    - **Frontmatter:** `name` (narrator-internal phrasing), `slug` (kebab-case), `status: dormant`, `discovered: false`, `clock-max: 6`, `proposed-from-module: <module-slug>`, `proposed: <YYYY-MM-DD>`. All values valid YAML — no TODO markers in frontmatter positions.
   >    - **Body:** seven sections in this order: `## Identity`, `## Active operation`, `## Observable consequences ladder`, `## Engagement triggers`, `## Discovery`, `## On clock filled`, `## History`.
   > 5. **Fill discipline.** Apply the fill-vs-TODO discipline:
   >    - **Fill from source (never TODO):** `## Identity`, `## Active operation`, `## Discovery` (both `**Trigger:**` and `**Public name on discovery:**`), `## On clock filled` `**Beat:**`, and ladder rungs Mid (clock 3-4), High (clock 5), Full (clock 6). These derive from module content the librarian has already classified into `dm/modules/<slug>/`.
   >    - **TODO-mark with prose hints:** ladder rung Low (clock 1-2; the module doesn't tell us what offscreen pre-engagement consequence the party should notice), at least one additional `## Engagement triggers` bullet beyond the 1-2 inferable from hooks/connections, and `## On clock filled` `**Post-op state:**` (dormant-vs-retired is a campaign-arc decision).
   >    - **Always empty:** `## History` (with schema-reminder comment for the world-state subagent's per-tick append discipline).
   > 6. **Default to skip on ambiguity.** If a faction-archetype in overview.md is too vague to ground (e.g., "shadowy patrons" with no NPCs or hooks attached), do NOT propose a seed. The user can hand-author later if desired.
   > 7. **Edge case — overview.md has no `faction-archetypes` and secrets.md has no `## Hidden NPC identities & motives` section.** Emit "None — no faction-quality candidates identified in module material" in step 10's summary. Do not propose from other sources (e.g., random `nodes/*.md` NPCs without faction context).

6. **New `## Query type: propose-factions`** section added after the existing `## Query type: propose-revelations` section and before the `## Query type: intake-lore` section:

   > Invocation: `"propose-factions <module-slug>. Active session log: <path-or-null>."`
   >
   > For retroactive use on already-ingested modules — when the user wants faction seeds for a module that was intaken before Phase 3e shipped, or wants to re-run propose-factions after editing the module's overview/secrets/connections content.
   >
   > Procedure:
   >
   > 1. **Pre-flight.** Verify `dm/modules/<module-slug>/` exists via `mcp__dm-fs__list_dm_dir("modules/<module-slug>")`. If not, abort with `"no such module for slug <slug>"`.
   > 2. **Read source files.** `mcp__dm-fs__read_dm_file("modules/<module-slug>/overview.md")` (for `faction-archetypes` frontmatter), `mcp__dm-fs__read_dm_file("modules/<module-slug>/secrets.md")` (for hidden identities/motives), `mcp__dm-fs__read_dm_file("modules/<module-slug>/connections.md")` (for faction-conditional logic). Optionally read selected `nodes/*.md` files where module content references faction NPCs (use `mcp__dm-fs__list_dm_dir("modules/<module-slug>/nodes")` to enumerate first; sample a small subset based on what overview/secrets surface).
   > 3. **Idempotency scan.** `mcp__dm-fs__list_dm_dir("factions")`; for each existing file, `mcp__dm-fs__read_dm_file("factions/<faction-slug>.md")` and parse frontmatter. Build the existing-slugs set. Note which existing files have `proposed-from-module: <current slug>` for summary messaging.
   > 4. **Run candidate identification, idempotency-filter, and write steps** with semantics identical to `intake-module` step 9 (sub-steps 9.1 + 9.3 + 9.4 + 9.5 + 9.6 + 9.7). Sub-step 9.2 (the list_dm_dir call) is already covered by step 3 above; reuse its result. For each candidate that survives the slug-collision filter, write `dm/factions/<faction-slug>.md` via `mcp__dm-fs__create_dm_file` applying the fill-vs-TODO discipline.
   > 5. **Emit a structured summary**:
   >    ```
   >    PROPOSE-FACTIONS SUMMARY: <module-slug>
   >
   >    Existing faction files relevant to this module: <N> (skipped — slug-collision or already-proposed)
   >    New faction seeds proposed:
   >      - dm/factions/<faction-slug>.md: <name>
   >      - dm/factions/<faction-slug>.md: <name>
   >      (or: "None — no new faction candidates beyond those already proposed.")
   >
   >    NEXT STEPS:
   >      1. Review the proposed seeds via your own shell (the main agent cannot read dm/).
   >      2. Fill in TODO markers (ladder rung 1-2, additional engagement triggers, post-op state).
   >      3. Frontmatter is committable as-is — status: dormant keeps seeds inert under the world-state subagent's offscreen tick until you flip them active.
   >      4. Adjust frontmatter (e.g., clock-max if you prefer 4-rung pacing) before commit if desired.
   >      5. Commit when satisfied. Flip status: active when you want the faction to start ticking in offscreen developments.
   >    ```
   > 6. **Append session-log line** if active session log provided (via Edit):
   >    ```
   >    - LIBRARIAN QUERY: propose-factions <module-slug> — <K> new seeds proposed, <N> existing skipped
   >    ```

7. **Edge cases** list gains four new entries:
   - **Module doesn't exist (`propose-factions`).** Abort in pre-flight with `"no such module for slug <slug>"`. No partial writes.
   - **Module has no `faction-archetypes` in overview.md and no `## Hidden NPC identities & motives` section in secrets.md.** Emit "None — no faction-quality candidates identified in module material" in summary. No writes.
   - **All faction candidates already proposed (idempotent re-run).** Summary returns "None — no new faction candidates beyond those already proposed." No new writes. Safe to re-run.
   - **Slug collision with existing faction file.** Whether hand-authored Phase 2a faction or 3e-authored seed from a different module, the existing file takes precedence. Skip with a summary flag describing the collision (e.g., "Skipped — slug `<slug>` already exists; review whether existing faction subsumes this module's archetype").

8. **`## What you don't do`** list gains:
   - Don't write to `dm/factions/<slug>.md` for factions whose slug already exists. Hand-authored Phase 2a factions and 3e-authored seeds from other modules take precedence.
   - Don't mutate existing faction content. Phase 2a's world-state subagent owns mutations.
   - Don't put TODO markers in frontmatter positions. Frontmatter values are always valid YAML. TODOs only appear in body sections (`## Observable consequences ladder` rung Low, `## Engagement triggers` additional bullet, `## On clock filled` `**Post-op state:**`).
   - Don't speculate `status: active` for new seeds. Always `status: dormant` + `discovered: false` — keeps the seed inert under the world-state subagent's skip-non-active rule until the user reviews and flips.

### Updated `intake-module` summary template

Add a new section between "Revelation seeds proposed:" and "Secret-quality content notes flagged for human verification:":

```
Faction seeds proposed:
  - dm/factions/<faction-slug>.md: <name>
  - dm/factions/<faction-slug>.md: <name>
  (or: "None — no faction-quality candidates identified in module material.")
```

Extend the NEXT STEPS list with a new item between the revelation-review step and the secret-notes-inspection step (other items renumber):

```
3. Review the proposed faction seeds; fill in TODO markers (ladder rung 1-2, additional engagement triggers, post-op state). Frontmatter is committable as-is — status: dormant keeps seeds inert under the world-state subagent's offscreen tick until you flip them active.
```

### CLAUDE.md update (Phase 3e)

Append one short paragraph to `## Library reference material` after the existing Phase 3d revelation paragraph:

> **Faction auto-proposals from module intake.** The librarian, during `intake-module` or via the `propose-factions` query, may write `dm/factions/<faction-slug>.md` seed files for faction candidates identified in a module's overview/secrets/connections content. These seeds default to `status: dormant` + `discovered: false`, keeping them inert under the Phase 2a world-state subagent's offscreen-developments tick until you review them, fill in TODO markers (ladder rungs 1–2, engagement triggers, post-op state), and flip status to `active`. You have no path to `dm/factions/` directly; faction content is only visible to you through the world-state subagent's response surface.

No new routing rule. No new must-never bullet. The existing Phase 2a routing covers everything the narrator needs.

### Repository layout (Phase 3e additions)

```
gygaxagain/
├── .claude/agents/
│   └── librarian.md             # MODIFIED — read/write-access bullets for dm/factions/, intake-module step 9, new propose-factions query
├── dm/
│   └── factions/                # (existing from Phase 2a; gains new auto-propose seeds)
│       └── <faction-slug>.md    # smoke-test artifacts: one or more Phandalin faction candidates (Kodor's cult at minimum)
└── CLAUDE.md                    # one paragraph addition in ## Library reference material
```

## Smoke test for Phase 3e

### Primary smoke test — `propose-factions` against Phandalin

The Phandalin module from Phase 3a is already ingested at `dm/modules/ancient-tomb-of-phandalin/` with documented faction candidates in overview.md `faction-archetypes` and secrets.md hidden-NPC content (Kodor Drannon's thrall-cult is the most plausible candidate; possibly a second depending on the librarian's judgment of the other entries). Phase 3e smoke test uses the standalone retroactive query against this existing module — doesn't require re-ingesting and doesn't disturb existing module state.

1. With the v6 librarian prompt in place (new `propose-factions` query, new `intake-module` step 9, expanded read+write access for `dm/factions/`), restart Claude Code so the v6 prompt is loaded by the Agent tool's registry.
2. Dispatch the librarian directly:
   ```
   Agent(subagent_type="librarian", prompt="propose-factions ancient-tomb-of-phandalin. Active session log: null.")
   ```
3. The librarian:
   - Verifies `dm/modules/ancient-tomb-of-phandalin/` exists via `list_dm_dir`.
   - Reads `overview.md`, `secrets.md`, `connections.md`, and selected `nodes/*.md` via `read_dm_file`.
   - Reads existing faction files via `list_dm_dir("factions")` and `read_dm_file` for idempotency (slug-collision + provenance scan).
   - Identifies faction candidates: at least Kodor's thrall-cult (potentially more depending on the librarian's reveal-vs-flavor judgment of other entries).
   - Writes seed files via `create_dm_file` with the documented schema, including provenance frontmatter (`proposed-from-module: ancient-tomb-of-phandalin`, `proposed: <today's date>`) and TODO markers in speculative body sections.
   - Returns the structured PROPOSE-FACTIONS SUMMARY listing new seeds.
4. User reviews seeds via own shell (`cat dm/factions/<faction-slug>.md`). Main agent cannot read.
5. User edits TODO markers if desired during commit-gate review (or leaves them as-is and commits the inert dormant seed to revisit later).
6. User commits.

**Pass criteria:**

- At least one `dm/factions/<faction-slug>.md` seed file is written for the Phandalin module (Kodor's thrall-cult at minimum).
- Each seed has the documented frontmatter: `name`, `slug`, `status: dormant`, `discovered: false`, `clock-max: 6`, `proposed-from-module: ancient-tomb-of-phandalin`, `proposed: <YYYY-MM-DD>`. **All frontmatter values are valid YAML — no TODO markers in frontmatter positions.**
- Each seed has all seven Phase 2a body sections present in order: `## Identity`, `## Active operation`, `## Observable consequences ladder` (with four rung bullets — Low/Mid/High/Full), `## Engagement triggers`, `## Discovery`, `## On clock filled`, `## History`. The History section is empty (with schema-reminder comment).
- The librarian filled (no TODO) `## Identity`, `## Active operation`, `## Discovery` (both Trigger and Public name), `## On clock filled` Beat, and ladder rungs Mid/High/Full from source content.
- The librarian TODO-marked ladder rung Low (clock 1-2), at least one additional engagement trigger slot, and the On-clock-filled Post-op state. TODO markers contain prose hints describing what the user should consider.
- The dm-fs access log shows librarian-issued: `list_dm_dir("modules/ancient-tomb-of-phandalin")` (pre-flight), `read_dm_file` calls against `overview.md`, `secrets.md`, `connections.md`, and one or more nodes; `list_dm_dir("factions")` (idempotency); and one or more `create_dm_file("factions/<faction-slug>.md")` entries.
- **Asymmetry probe (positive):** main agent attempts `cat dm/factions/<faction-slug>.md` after the librarian write — expected to be denied (dm-quarantine intact for the new tier of librarian-written content). User verifies via own shell.
- **Phase 2a backward-compatibility probe — dormant skip (positive):** dispatch the world-state subagent's offscreen-developments query against a synthetic prior-session-log fixture (or an existing session log if available) that contains the kind of session prose that *would* trigger Kodor's cult engagement triggers if status were `active`. With the seed at `status: dormant`, the world-state subagent must skip the faction per its existing step 1 rule. Confirm: tick completes without error, the new seed file is not modified (no clock tick, no history line appended), and the world-state subagent's session-log line reflects the seed was skipped (or simply doesn't reference it among ticked factions).
- **Phase 2a backward-compatibility probe — active flip (optional, recommended):** user edits the seed to flip `status: active` and minimally completes the ladder rung Low TODO with placeholder text. Re-run the offscreen tick. World-state's tick now considers the faction; depending on the session-log prose used, either clock advances or a trigger holds it. Confirm the tick completes without frontmatter-parse errors and the seed's `## History` section gains a single audit-trail line via the world-state subagent's `append_dm_file` call.
- All 87 existing tests continue to pass; no Python code added.

### Optional secondary smoke test — `intake-module` auto-propose during fresh intake

Validates the auto-propose-during-intake path (step 9 of `intake-module`). Not required for Phase 3e pass criteria — the primary smoke test (retroactive against Phandalin) exercises the same underlying procedure.

If the user wants to validate this path, they hand-author a small synthetic test module at `references/test-module-3e.md` with `## Faction archetypes` content in the overview-equivalent section and `## Secrets — Hidden NPC identities & motives` content implying a faction. Run `/intake references/test-module-3e.md` and verify:

- The structured summary populates both "Revelation seeds proposed" (Phase 3d) and "Faction seeds proposed" (Phase 3e) sections.
- `dm/factions/<faction-slug>.md` exists with the documented schema and TODO discipline.
- The seed's `proposed-from-module` matches the new module's slug.

The synthetic fixture can be discarded after the test (unlike the Phase 3c bestiary fixture which is committed as a permanent reference).

### Asymmetry audit

Same shape as Phase 3a/3b/3c/3d:

1. dm-fs access log shows librarian-issued reads and writes against `factions/` paths during the smoke test. Verify librarian writes are `create_dm_file` only (Phase 3e only creates new files; the Phase 2a world-state subagent's `write_dm_file` + `append_dm_file` calls for tick updates remain unchanged).
2. Main agent's `cat dm/factions/<faction-slug>.md` is denied (dm-quarantine intact for the new librarian-written content).
3. No narrator-issued reads/writes to any `dm/` path during smoke test.
4. The world-state subagent's offscreen tick against the new dormant seed correctly skips it — confirms backward compatibility with Phase 2a parsing.
5. Phase 3a/3b/3c/3d boundaries hold: `cat dm/modules/.../secrets.md` denied; `cat dm/revelations/r-NNN.md` denied; `library/lore/.../entries/*.md` readable. The new faction auto-propose tier doesn't weaken existing protections.

## Failure modes Phase 3e must handle

- **Module doesn't exist (no `dm/modules/<slug>/`).** `propose-factions` aborts in pre-flight with `"no such module for slug <slug>"`. No partial writes.
- **Module has empty or missing `overview.md` / `secrets.md` / `connections.md`.** Procedure attempts to read each; if any are missing, fall back gracefully (treat as "no signal from that source"). If all three are missing, emit "None — no faction-quality candidates identified in module material" in summary. No writes.
- **Module has no `faction-archetypes` in overview.md frontmatter and no `## Hidden NPC identities & motives` section in secrets.md.** Emit "None — no faction-quality candidates identified in module material" in summary. Do not propose from other sources (e.g., random `nodes/*.md` NPCs without faction context).
- **All faction candidates already proposed (idempotent re-run).** The librarian's idempotency scan returns matches. Summary returns "None — no new faction candidates beyond those already proposed." No new writes. Safe to re-run.
- **Slug collision with hand-authored Phase 2a faction.** The Phase 2a faction was authored by the user and has no `proposed-from-module` frontmatter. Slug collision is detected during the idempotency scan; the librarian skips the candidate with a summary flag describing the collision ("Skipped — slug `<slug>` already exists; review whether existing faction subsumes this module's archetype").
- **Slug collision with Phase 3e-authored faction from a different module.** Two modules independently surface the same faction archetype (e.g., a campaign-wide cult that appears in two modules). The librarian skips the candidate from the second module with the same summary flag pattern. The user can choose to merge module-derived content into the existing faction during commit-gate review.
- **TODO marker discipline regression.** A future librarian revision could accidentally let TODO strings leak into frontmatter positions (e.g., `clock-max: <TODO: 4 or 6>`). This would cause the world-state subagent's frontmatter parse to fail and the faction to be skipped with a "skipped: malformed frontmatter" history line (Phase 2a's existing defensive path). The smoke test catches this — pass criteria require "all frontmatter values are valid YAML."
- **Librarian write failure mid-propose.** Partial state — some seeds written, others not. Surface the error in summary. User reviews via shell, deletes partial seeds or completes manually.
- **Librarian's faction-vs-no-faction judgment is wrong.** Some `faction-archetypes` may not actually be faction-quality (e.g., a one-off NPC noted as "loosely affiliated with shadowy backers" without further development). The librarian uses LLM judgment, defaults to skip on ambiguity. Some seeds may need to be deleted by user during review; others may need hand-creation if the librarian missed a candidate. The commit-gate is the discipline.
- **Ladder rung anchoring quality varies.** The librarian's Mid/High/Full rungs anchor to module climax content; quality depends on how clearly the module surfaces escalation. The user adjusts during commit-gate review if anchors aren't ideal. The Low rung is always TODO-marked, so the user is explicitly prompted to author it.
- **Engagement trigger inference quality varies.** The librarian's trigger patterns are derived from module hooks/connections. The user adds more during commit-gate review (one TODO bullet is always provided as a prompt).
- **Backward-compat with Phase 2a world-state subagent.** The two new frontmatter fields are not in the original Phase 2a schema. The world-state subagent's parsing only acts on `status`, `clock-max`, `discovered`, `known-as`; unknown fields are ignored. Smoke test verifies via offscreen-tick invocation against the new seed.
- **`status: dormant` default safety.** Even if a TODO marker leaks into a body section the world-state subagent reads (e.g., ladder rung Low text being TODO-marked when the user flips status active without completing it), the dormant default keeps the seed out of consideration entirely. Only when status flips active does any body content come into play. The user's commit-gate review is the discipline boundary for completing TODOs before flipping status.
- **Librarian-discipline regression** (Phase 3a lesson). The Phase 3e additions must maintain positive framing. The new `## Read access` and `## Write access` bullets, the new `## Query type: propose-factions` section, and the `intake-module` step 9 procedure use positive contract language. No "never write to X" framing for new paths.

## Open questions resolved during brainstorming

- **Sub-slicing of Phase 3e:** factions only. Solo-engine, methodology, gazetteer-essay-shape lore, URL ingestion, optional `consult-lore`, optional lore-side quarantine, and the librarian split decision are all deferred to Phase 3f or later.
- **Librarian split:** deferred. The faction additions push librarian.md to ~475–495 lines (past the rough ~450-line threshold), but the threshold is a smell, not a hard limit. The 3d v5 librarian held discipline at 399 lines; the structurally-mirrored faction additions are expected to preserve it. Revisit if a later phase reveals discipline regression.
- **Auto-during-intake AND standalone retroactive:** both. `intake-module` step 9 covers new ingest; `propose-factions <slug>` query covers existing modules.
- **Schema speculation discipline:** TODO markers in body sections only; frontmatter values always valid YAML. The librarian fills inferrable body fields (Identity, Active operation, Discovery, On-clock-filled Beat, ladder rungs Mid/High/Full) from source content; TODO-marks the genuinely speculative fields (ladder rung Low, additional engagement triggers, Post-op state).
- **Safety guarantee for partial seeds:** `status: dormant` + `discovered: false` defaults make the seed inert under the Phase 2a world-state subagent's existing skip-non-active rule. The user must explicitly flip status to active before the seed participates in offscreen ticks.
- **Idempotency mechanism:** slug-collision check. Slug derivation from source content is expected to be stable across runs, so re-running `propose-factions <same-slug>` is safe by virtue of producing the same slugs (which then collide with the existing files). Hand-authored Phase 2a factions take precedence over Phase 3e candidates with the same slug; cross-module slug collisions skip the second-mover candidate with a summary flag. The `proposed-from-module` provenance frontmatter is metadata for audit and summary messaging only — it does not gate skip decisions.
- **New frontmatter fields backward-compat:** yes — the Phase 2a world-state subagent ignores unknown frontmatter fields. Smoke test validates.
- **`clock-max` default:** 6 (matches Phase 2a's documented default). The user can adjust during commit-gate review.
- **CLAUDE.md changes:** one paragraph in `## Library reference material`. No new routing rule. No new must-never bullet.
- **MCP changes:** none. `create_dm_file` + `list_dm_dir` + `read_dm_file` cover all 3e operations.
- **Python code added:** none.
- **`/intake` command:** unchanged. Auto-propose is internal to the librarian.

## Phase 3e → Phase 3f+ handoff

Phase 3e's exit opens potential Phase 3f content (or further deferral to Phase 4):

- **Solo-engine intake.** Mythic GME tables and alternative engines → `library/solo-engines/<name>/`. Narrator-readable like lore.
- **Methodology intake.** Justin Alexander's GM book → `library/methodology/<topic>/`. Narrator-readable.
- **Gazetteer-essay-shape lore intake.** Extends `library/lore/` to handle regional descriptions in essay form (current Phase 3c entry-list shape doesn't cover essays).
- **URL ingestion.** Web-fetched sources behind a host allowlist. Layered over existing `intake-module` / `intake-lore` queries.
- **Optional `consult-lore` runtime curated query.** If direct-read proves inadequate.
- **Lore-side quarantine.** `dm/lore/<source-slug>/` if a real source needs it.
- **`rename_dm_file` MCP tool.** Defer indefinitely.
- **Librarian split** (intake/runtime/shared). Revisit if 3e+ phases reveal discipline regression with the larger file.
- **Bulk `propose-revelations` / `propose-factions` across all modules.** A Phase 3f or Phase 4 convenience query.

The pattern Phase 3d + Phase 3e jointly establishes — "librarian writes to a dm-quarantined Phase 2 content path via existing dm-fs MCP for content auto-derived from module material, with provenance frontmatter for idempotency and a safe-inert default (revelation `status: pending` or faction `status: dormant`) so partial seeds don't disrupt session play" — is the substrate for any future per-content-tier auto-proposes (e.g., NPC seed proposals if Phase 4 introduces an NPC system).

## Roadmap context

Phase 3e sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(complete)*
6. **Phase 3a — Source ingestion: modules (intake-only, dm-quarantined).** *(complete)*
7. **Phase 3b — Runtime librarian queries (`consult-library` + `reveal-from-module`).** *(complete)*
8. **Phase 3c — Source ingestion: lore-reference (bestiary-shaped entries; narrator-readable).** *(complete)*
9. **Phase 3d — Auto-propose revelation seeds from module material.** *(complete)*
10. **Phase 3e — Auto-propose faction seeds from module material (extends `intake-module` + new `propose-factions` query).** *(this design)*
11. **Phase 3f — Further deferred Phase 3 work (solo-engine intake, methodology intake, gazetteer-essay lore, URL ingestion, optional `consult-lore`, optional lore-side quarantine, optional librarian split). Further slicing determined when Phase 3f is brainstormed.**
12. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals from session play, content authoring formalization.
13. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
14. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
15. **Phase 7 — Downtime, banking, bastions.**

Phase 3e's scope is what's locked here.
