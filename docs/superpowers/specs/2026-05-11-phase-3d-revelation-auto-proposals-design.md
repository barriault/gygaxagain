# Phase 3d — Revelation Auto-Proposals from Module Material Design

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
**Slice of original Phase 3:** auto-propose **revelations only** from module material. Factions deferred to Phase 3e (faction schema requires speculative authoring of clock state, ladder rungs, triggers that the librarian can only partially infer). Threads deferred indefinitely (session-driven, not intake-driven). Solo-engine intake, methodology intake, gazetteer-essay intake, URL ingestion, optional `consult-lore`, optional lore-side quarantine, and optional `rename_dm_file` MCP tool also deferred to Phase 3e or later.

## Purpose

Phase 3a/3b/3c shipped a complete module-and-lore intake + runtime-consultation pipeline. But the `intake-module` summary identifies opportunities for `dm/factions/`, `dm/revelations/`, and `dm/threads/` without acting on them — the Phandalin intake summary said "consider seeding dm/factions/ once Phase 4 authoring tools ship" and "the hidden priest reveal would naturally become a revelation; consider dm/revelations/r-NNN.md." Those candidates sat unactioned.

Phase 3d closes the loop for the cleanest of the three mappings: **revelations**. Module `secrets.md` content (twists, hidden NPC identities, plot reveals) maps almost 1:1 to Phase 2b's revelation schema (`status`, `clue-count`, `## Revelation` body, `## Clue vectors`, `## Delivered`). The librarian gains a new procedure step in `intake-module` plus a standalone retroactive query `propose-revelations <module-slug>` that writes seed files for reveal candidates. The user reviews the seeds via the commit-gate and edits/deletes as needed before commit. The Phase 2b revelation subagent then surfaces the seeds' clues during play naturally via `could-land` queries.

Phase 3d's load-bearing claim is that **the librarian can produce useful revelation seed files from module material** — useful enough that user editing during commit-gate review is light (mostly clue-vector anchor refinement and title polish, not full re-authoring). Validated by smoke-testing against the existing Phandalin intake.

## Definition of done

A successful Phase 3d build demonstrates all of:

- **Librarian gains write access to `dm/revelations/`** via the dm-fs MCP. This is the third dm-side write path on the librarian's contract (after `dm/modules/` from Phase 3a and the implicit retention of read access patterns from 3b).

- **`intake-module` procedure gains a new step 7.5 — "propose revelation seeds"** — that runs after writing `dm/modules/<slug>/` (step 6) and updating `library/index.md` (step 7), before emitting the structured summary (step 8). The librarian scans the `secrets.md` content it just wrote for reveal-quality candidates, allocates monotonic revelation IDs, and writes `dm/revelations/r-NNN.md` seeds via `mcp__dm-fs__create_dm_file`.

- **New query type on the librarian:** `propose-revelations <module-slug>`. For retroactive use on already-ingested modules. Reads the existing `dm/modules/<module-slug>/secrets.md`, runs the propose-revelations procedure, writes seeds. Used to backfill Phandalin (or any prior intake) without re-ingesting the whole module.

- **Revelation seed file produced by Phase 3d auto-propose** has the documented schema:
  - Frontmatter: `id` (`r-NNN`), `title` (narrator-internal phrasing), `status: pending`, `clue-count: 3`, plus two new provenance fields `proposed-from-module: <module-slug>` and `proposed: <YYYY-MM-DD>`.
  - `# Title` heading.
  - `## Revelation` body — the hidden fact derived from secrets.md content.
  - `## Clue vectors` with ≥3 entries (`c-NNNa`, `c-NNNb`, `c-NNNc`), each anchored to a specific module node (using the node slug or short location/NPC descriptor as the scope tag) with 1-2 sentence hook text describing how the clue would land.
  - `## Delivered` empty section with the standard schema reminder comment.

- **Updated `intake-module` summary** includes a new "Revelation seeds proposed" section listing the new `dm/revelations/r-NNN.md` files with their titles, or "None — no reveal-quality candidates identified in secrets.md."

- **`propose-revelations` query returns a parallel structured summary** with the same "Revelation seeds proposed" enumeration plus an "Existing revelation files for this module" count (skipped via idempotency) and the standard NEXT STEPS block.

- **ID allocation is monotonic.** The librarian reads existing `dm/revelations/r-NNN.md` files via `mcp__dm-fs__list_dm_dir("revelations")`, parses the highest existing `r-NNN`, allocates new IDs starting at `max + 1`. If no revelations exist, starts at `r-001`.

- **Idempotency via provenance frontmatter.** Before allocating new IDs, the librarian scans existing revelation files for frontmatter `proposed-from-module: <module-slug>` matching the current module. If matches exist, those specific reveals are skipped — the user has already accepted/edited them in a prior intake or `propose-revelations` invocation. Re-running `propose-revelations <same-slug>` is a safe no-op for already-proposed reveals.

- **Backward compatibility with Phase 2b revelation subagent.** The two new frontmatter fields (`proposed-from-module`, `proposed`) are not in the original Phase 2b schema. The revelation subagent's parsing logic only acts on `status` and `clue-count` — unknown fields are ignored. Validated by smoke test: dispatch the revelation subagent's `could-land` query with a scope matching one of the Phase 3d-written seeds and confirm the subagent returns the new clue.

- **Smoke test:** run `propose-revelations ancient-tomb-of-phandalin` against the existing Phandalin intake. Verify at least one `dm/revelations/r-NNN.md` seed file is written with the documented schema, the new provenance frontmatter fields, and ≥3 clue vectors anchored to actual Phandalin nodes. Asymmetry audit confirms the main agent cannot `cat` the new seed file directly; the revelation subagent operates on the seed correctly.

- **CLAUDE.md** gains one paragraph in `## Library reference material` noting that revelation seeds created by Phase 3d are picked up by the Phase 2b revelation subagent at runtime once committed. No new routing rule. No new must-never bullet.

- All 87 existing tests continue to pass; no Python code added.

- **No new MCP tools.** Existing `mcp__dm-fs__create_dm_file` + `mcp__dm-fs__list_dm_dir` + `mcp__dm-fs__read_dm_file` cover all 3d operations.

- **No new slash command.** The `propose-revelations` query is dispatched directly via the Agent tool (or invoked as part of `/intake`).

## Out of scope (deferred to Phase 3e or later)

- **Faction auto-proposals.** `dm/factions/` seed-writing requires speculative authoring of clock-max, four-rung observable-consequences ladder, engagement triggers, discovery trigger, on-clock-filled beat — content the librarian can only partially infer from module material. The non-inferrable parts would be `<TODO>` stubs that may defeat the "useful starting point" goal. Phase 3e if it's worth the effort; the alternative is staying with hand-authoring at Phase 4 bookkeeper time.
- **Thread auto-proposals.** Threads are session-driven (e.g., "the missing Mercers"). Modules don't surface threads at intake time. Phase 2c's `open-thread` runtime query is the right authoring surface; intake-time thread creation isn't needed.
- **NPC seed proposals (`dm/npcs/`).** Phase 2 doesn't have an NPC system in the same sense as factions/revelations/threads. The Phandalin intake flagged Kodor as a candidate NPC; that stays as a summary flag until Phase 4 or a dedicated NPC-system phase.
- **Auto-propose for modules ingested before Phase 3d shipped** (other than via the standalone `propose-revelations` query). Phase 3d's `intake-module` step 7.5 only runs at intake time for new ingestions. Phandalin (intaken before 3d) is handled via the standalone `propose-revelations` query.
- **Bulk `propose-revelations` across all ingested modules.** Phase 3d's standalone query takes one module slug. If multiple modules need backfilling, the user invokes the query per module. Phase 3e or Phase 4 may add a bulk variant.
- **Solo-engine intake, methodology intake, gazetteer-essay intake, URL ingestion, optional `consult-lore`, optional lore-side quarantine, optional `rename_dm_file` MCP tool.** All deferred to Phase 3e+ or never.
- **Revelation seed schema migration tooling.** If Phase 4+ changes the revelation schema, the Phase 3d-written seeds may need migration. Out of scope for 3d; the auto-propose just produces files in the current Phase 2b schema.
- **Validation that a Phase 3d-proposed clue vector's scope tag actually matches the corresponding module node.** The librarian uses LLM judgment to anchor clue vectors to nodes. Validation that the anchor is "good" is the user's responsibility during commit-gate review. Phase 2b's `could-land` query uses LLM judgment to match scope tags to play moments anyway — imperfect anchors still work, just less optimally.

## Architecture

### Slice mapping

| Component                          | Phase 3d touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | One paragraph addition to `## Library reference material` in `CLAUDE.md`. No new routing rule. No new must-never bullet. |
| World-state subagent               | Untouched.                                                                       |
| **Revelation subagent**            | Untouched at the prompt level. Seed files produced by Phase 3d contain new frontmatter fields (`proposed-from-module`, `proposed`); the revelation subagent's parsing is field-tolerant and ignores them. Backward compatibility validated by smoke test. |
| Mythic subagent                    | Untouched.                                                                       |
| Dice subagent                      | Untouched.                                                                       |
| **Librarian subagent**             | **MODIFIED** — `.claude/agents/librarian.md`. New `## Write access` bullet for `dm/revelations/`. New `intake-module` step 7.5. New `## Query type: propose-revelations` section. Frontmatter description updated to mention the fifth query. Contract section updated to triple-write-path framing. |
| `dm-fs` MCP                        | No tool changes. `mcp__dm-fs__create_dm_file` + `mcp__dm-fs__list_dm_dir` + `mcp__dm-fs__read_dm_file` cover all 3d operations. |
| `.claude/settings.json`            | No deny-rule changes.                                                            |
| `/intake` command                  | Untouched. The new auto-propose step is internal to the librarian's `intake-module` query. |
| Other slash commands               | Untouched.                                                                       |
| Repository layout                  | No new directories. `dm/revelations/` is existing from Phase 2b. Smoke-test artifacts: new `dm/revelations/r-NNN.md` seed files for Phandalin's reveal candidates. |

### Information-asymmetry preservation

**No new tiers introduced.** Phase 3d operates entirely within the existing three-tier model:

- Modules → `dm/modules/<slug>/` (dm-quarantined). Unchanged.
- Lore → `library/lore/<source-slug>/` (narrator-readable). Unchanged.
- **Revelations → `dm/revelations/`** (dm-quarantined). The librarian gains write access here, joining the existing Phase 2b revelation subagent (which has both read and write access). Both subagents write via the dm-fs MCP. The narrator has no access to `dm/revelations/` directly — Phase 2b's revelation subagent remains the sole runtime path (via `could-land`, `confirm`, `has-been-delivered` queries per rule 6).

The asymmetry boundary holds because:

- `dm/**` denies in `.claude/settings.json` stay in place. The narrator cannot directly read or write any `dm/` content.
- The librarian writes `dm/revelations/r-NNN.md` via `mcp__dm-fs__create_dm_file`, the same path the revelation subagent uses for its own writes (e.g., status updates during `confirm`).
- The narrator's runtime path to revelation content is still through the revelation subagent — Phase 3d does NOT give the narrator any new access. The Phase 2b rule 6 wording in CLAUDE.md is unchanged.

The dm-fs access log captures all librarian-issued writes to `dm/revelations/`, so the smoke-test asymmetry audit naturally extends — grep for non-revelation-subagent writes to `dm/revelations/` and confirm they're attributable to the librarian during `intake-module` step 7.5 or `propose-revelations` invocations.

### Integration with prior phases

- **Phase 1:** unchanged.
- **Phase 2a (factions), 2c (threads), 2d (Mythic-event spotlight):** unchanged. Phase 3d is revelations-only by design.
- **Phase 2b (revelations):** the revelation subagent is untouched at the prompt level. Seed files produced by Phase 3d are valid Phase 2b revelation files — the same `could-land` / `confirm` / `has-been-delivered` queries operate on them naturally. The seed's `status: pending` + ≥3 clue vectors satisfy Phase 2b's three-clue-rule discipline by construction.
- **Phase 3a (module intake):** the `intake-module` procedure gains a new step 7.5 between existing steps 7 (update `library/index.md`) and 8 (emit intake summary). The summary template is extended with the new "Revelation seeds proposed" section.
- **Phase 3b (runtime queries):** unchanged. `consult-library` and `reveal-from-module` still operate against `dm/modules/<slug>/`. Phase 3d's auto-propose does NOT depend on these runtime queries — it works directly from the module's `secrets.md` content read via dm-fs MCP during intake-module or propose-revelations.
- **Phase 3c (lore intake):** unchanged. The librarian's `intake-lore` procedure is unrelated to revelation auto-proposals.

## Component designs

### File schemas

#### `dm/revelations/r-NNN.md` (seed file produced by Phase 3d)

```markdown
---
id: r-NNN
title: <revelation title — narrator-internal phrasing, never surfaced verbatim>
status: pending
clue-count: 3
proposed-from-module: <module-slug>
proposed: <YYYY-MM-DD>
---

# <Title>

## Revelation

<The hidden fact players need to learn. 1-3 sentences. Narrator-internal phrasing — describes the answer, not how it's revealed. Derived from the corresponding entry in dm/modules/<module-slug>/secrets.md.>

## Clue vectors

- **c-NNNa** — <scope tag — typically a node-slug or short location/NPC descriptor>: <pre-authored hook text describing how this clue lands when surfaced, 1-2 sentences>.
- **c-NNNb** — <scope tag>: <hook text>.
- **c-NNNc** — <scope tag>: <hook text>.

## Delivered

<!-- Append-only. The revelation subagent writes here when the narrator confirms a clue landed. Each entry: "- session NNN, YYYY-MM-DD: clue <id> — <one-line context>" -->
```

Schema notes:

- **Two new frontmatter fields** vs Phase 2b's original revelation schema:
  - `proposed-from-module: <module-slug>` — documents auto-propose provenance. Used by the librarian for idempotency (skip re-proposing if a seed already references the same module).
  - `proposed: <YYYY-MM-DD>` — date stamp.
- **Backward-compatible with Phase 2b parsing.** The revelation subagent only acts on `status` and `clue-count` frontmatter; unknown fields are ignored. Smoke test validates by running `could-land` against a new seed.
- **`status: pending` + `clue-count: 3` + ≥3 clue vectors** — satisfies Phase 2b's three-clue-rule discipline by construction. The librarian is responsible for producing exactly 3 (or more) clue vectors per seed.
- **`## Delivered` empty initially** — accumulates entries as the narrator confirms clues during play. Phase 2b's `confirm` query appends to this section.
- **Title format:** narrator-internal phrasing (e.g., "Kodor Drannon is the undead mage behind the disturbance", "Rewalt Mason lied to the guards"). Quotation marks omitted. The title is the seed's narrator-internal handle and is never surfaced verbatim to the player.
- **Scope tags for clue vectors:** the librarian picks tags anchored to specific module nodes (e.g., `kodors-resting-place-f2`, `tomb-office-of-records-f1`) or NPC encounters (e.g., `rewalt mason conversation`). These map to scopes the narrator can recognize during play. Phase 2b's `could-land` query uses LLM judgment to match scope tags against caller-supplied scope tags, so imperfect anchors still work — they're just less optimally matched.

### Librarian subagent changes (`.claude/agents/librarian.md`)

Five targeted modifications to the existing Phase 3c v4 librarian:

1. **Frontmatter description** updated to mention `propose-revelations` alongside the existing four query types (`intake-module`, `intake-lore`, `consult-library`, `reveal-from-module`).

2. **`## Write access`** gains a new bullet:
   > - `dm/revelations/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file`. New under Phase 3d for revelation auto-proposals. Same gate as `dm/modules/`; no `Edit(dm/**)` access.

3. **`## Your contract`** updates the dual-write-path sentence (from Phase 3c v4) to a triple-write-path sentence:
   > "All module content writes go to `dm/modules/<slug>/` via the dm-fs MCP. Revelation seed writes go to `dm/revelations/r-NNN.md` via the dm-fs MCP (Phase 3d). All lore content writes go to `library/lore/<source-slug>/` via direct Write. All three dm/library paths result in (or update) a one-line enumeration entry in `library/index.md` for modules and lore; revelations are tracked by Phase 2b's revelation subagent independently."

4. **`intake-module` procedure gains step 7.5** (between existing step 7 'Update library/index.md' and step 8 'Emit intake summary'):

   > **7.5. Propose revelation seeds from secrets.md content.** Scan the `secrets.md` content you wrote in step 6. For each entry under `## Twists & reveals` and `## Hidden NPC identities & motives` that represents a reveal-quality moment (the kind a party would unambiguously "earn" by investigating or progressing), propose a revelation seed:
   >
   > 1. Call `mcp__dm-fs__list_dm_dir("revelations")` via dm-fs MCP to enumerate existing revelation files.
   > 2. For each existing file, call `mcp__dm-fs__read_dm_file("revelations/r-NNN.md")` and parse its frontmatter. If `proposed-from-module: <current module slug>` matches, note that reveal as already proposed — skip re-proposing it.
   > 3. Find `max(existing_ids)`. Start new IDs at `max + 1` (zero-padded three digits, e.g., `r-002` after `r-001`). If no revelations exist, start at `r-001`.
   > 4. For each remaining reveal candidate, write `dm/revelations/r-NNN.md` via `mcp__dm-fs__create_dm_file` with the schema documented in the Phase 3d spec (frontmatter `id`, `title`, `status: pending`, `clue-count: 3`, `proposed-from-module: <module-slug>`, `proposed: <YYYY-MM-DD>`; body `# Title`, `## Revelation`, `## Clue vectors` with ≥3 entries each anchored to a specific module node, empty `## Delivered` section with schema-reminder comment).
   > 5. **Clue vector authoring:** for each revelation, identify 3+ nodes in the module where a clue would plausibly land. Use the node slug as the scope tag. Author 1-2 sentence hook text describing how the clue surfaces at that node (e.g., "if the party reads the records in this room, they find a journal entry referencing Kodor's burial here pre-resettlement").
   > 6. **Default to skip on ambiguity.** If a secret in secrets.md is flavor-only (e.g., a custom stat block detail with no player-perceivable arc significance), do NOT propose a revelation for it. The user can hand-author later if desired.

5. **New `## Query type: propose-revelations`** added after the `intake-module` section and before the `intake-lore` section:

   > Invocation: `"propose-revelations <module-slug>. Active session log: <path-or-null>."`
   >
   > For retroactive use on already-ingested modules — when the user wants revelation seeds for a module that was intaken before Phase 3d shipped, or wants to re-run propose-revelations after editing the module's `secrets.md`.
   >
   > Procedure:
   >
   > 1. **Pre-flight.** Verify `dm/modules/<module-slug>/secrets.md` exists via `mcp__dm-fs__list_dm_dir("modules/<module-slug>")`. If not, abort with `"no such module or no secrets.md for module <slug>"`.
   > 2. **Read `secrets.md`** via `mcp__dm-fs__read_dm_file("modules/<module-slug>/secrets.md")`.
   > 3. **Read existing revelation files** via `mcp__dm-fs__list_dm_dir("revelations")` and parse them for idempotency (note files with frontmatter `proposed-from-module: <current slug>`).
   > 4. **Run the propose-revelations procedure** identical to step 7.5 of `intake-module` (steps 1-6 above).
   > 5. **Emit a structured summary**:
   >    ```
   >    PROPOSE-REVELATIONS SUMMARY: <module-slug>
   >
   >    Existing revelation files for this module: <N> (skipped — already proposed)
   >    New revelation seeds proposed:
   >      - dm/revelations/r-NNN.md: <title>
   >      - dm/revelations/r-MMM.md: <title>
   >      (or: "None — no new reveal-quality candidates beyond those already proposed.")
   >
   >    NEXT STEPS:
   >      1. Review the proposed seeds via your own shell (the main agent cannot read dm/).
   >      2. Edit clue vectors as needed — the librarian's anchors are starting points.
   >      3. Adjust frontmatter title or status before commit if desired.
   >      4. Commit when satisfied. The revelation subagent will surface these clues during play once committed.
   >    ```
   > 6. **Append session-log line** if active session log provided (via Edit):
   >    ```
   >    - LIBRARIAN QUERY: propose-revelations <module-slug> — <K> new seeds proposed, <N> existing skipped
   >    ```

### Updated `intake-module` summary template

Add a new section to the structured summary (between "library/index.md updated with one-line enumeration entry" and "Secret-quality content notes flagged for human verification"):

```
Revelation seeds proposed:
  - dm/revelations/r-NNN.md: <title>
  - dm/revelations/r-MMM.md: <title>
  (or: "None — no reveal-quality candidates identified in secrets.md.")
```

### CLAUDE.md update (Phase 3d)

Append one short paragraph to `## Library reference material` after the existing Phase 3c lore paragraph:

> **Revelation auto-proposals from module intake.** The librarian, during `intake-module` or via the `propose-revelations` query, may write `dm/revelations/r-NNN.md` seed files for reveal candidates identified in a module's `secrets.md`. These seeds are valid Phase 2b revelation files — the revelation subagent's `could-land` query surfaces their clue vectors during play (per rule 6) once you've reviewed and committed them. You have no path to `dm/revelations/` directly; revelation seeds are only visible to you through the revelation subagent's response surface.

No new routing rule. No new must-never bullet. The existing Phase 2b rule 6 (Revelation routing) covers everything the narrator needs.

### Repository layout (Phase 3d additions)

```
gygaxagain/
├── .claude/agents/
│   └── librarian.md             # MODIFIED — write-access bullet, intake-module step 7.5, new propose-revelations query
├── dm/
│   └── revelations/              # (existing from Phase 2b; gains new auto-propose seeds)
│       └── r-NNN.md              # smoke-test artifacts: Phandalin's reveal candidates (r-002, r-003 or similar)
└── CLAUDE.md                     # one paragraph addition in ## Library reference material
```

## Smoke test for Phase 3d

### Primary smoke test — `propose-revelations` against Phandalin

The Phandalin module from Phase 3a is already ingested at `dm/modules/ancient-tomb-of-phandalin/secrets.md` with documented reveal candidates (Rewalt Mason's post-rescue lie, Kodor Drannon's undead identity, plus potentially other twists). Phase 3d smoke test uses the standalone retroactive query against this existing module — it doesn't require re-ingesting and doesn't disturb the existing module state.

1. With the v5 librarian prompt in place (new `propose-revelations` query, new `intake-module` step 7.5, expanded write access), the user restarts Claude Code so the v5 prompt is loaded by the Agent tool's registry.
2. Dispatch the librarian directly:
   ```
   Agent(subagent_type="librarian", prompt="propose-revelations ancient-tomb-of-phandalin. Active session log: null.")
   ```
3. The librarian:
   - Verifies `dm/modules/ancient-tomb-of-phandalin/secrets.md` exists via `list_dm_dir`.
   - Reads `secrets.md` via `read_dm_file`.
   - Reads existing revelation files via `list_dm_dir("revelations")` and parses for idempotency.
   - Identifies reveal candidates: at least Rewalt's lie and Kodor's identity (potentially more depending on the librarian's reveal-vs-flavor judgment of the other entries in secrets.md).
   - Allocates IDs sequentially from `max(existing) + 1`.
   - Writes seed files via `create_dm_file` with the documented schema, including the new provenance frontmatter (`proposed-from-module: ancient-tomb-of-phandalin`, `proposed: <today's date>`).
   - Returns the structured summary listing new seeds.
4. User reviews seeds via their own shell (`cat dm/revelations/r-NNN.md`). The main agent cannot read these files.
5. User edits clue vectors if needed during commit-gate review.
6. User commits.

**Pass criteria:**

- At least one `dm/revelations/r-NNN.md` seed file is written for Phandalin reveals (Rewalt's lie or Kodor's identity at minimum).
- Each seed has the documented frontmatter: `id`, `title`, `status: pending`, `clue-count: 3`, `proposed-from-module: ancient-tomb-of-phandalin`, `proposed: <YYYY-MM-DD>`.
- Each seed has `# Title` heading, `## Revelation` body (1-3 sentences describing the hidden fact narrator-internally), `## Clue vectors` with ≥3 entries (`c-NNNa`, `c-NNNb`, `c-NNNc`), each anchored to a specific Phandalin node by slug, and an empty `## Delivered` section with the schema-reminder comment.
- The dm-fs access log shows librarian-issued: `list_dm_dir modules/ancient-tomb-of-phandalin` (pre-flight), `read_dm_file modules/ancient-tomb-of-phandalin/secrets.md`, `list_dm_dir revelations` (idempotency check + ID allocation), and one or more `create_dm_file revelations/r-NNN.md` entries.
- **Asymmetry probe (positive):** main agent attempts `cat dm/revelations/r-NNN.md` after the librarian write — expected to be denied (dm-quarantine intact for the new file). User verifies via their own shell.
- **Phase 2b backward compatibility (positive):** dispatch the revelation subagent with a `could-land` query whose scope matches one of the new seeds' clue vectors (e.g., `"investigating the tomb office of records"` for a Rewalt-related clue). The revelation subagent should return the matching clue with no errors about unknown frontmatter fields.
- All 87 existing tests continue to pass; no Python code added.

### Secondary smoke test — `intake-module` auto-propose during fresh intake (optional)

Validates the auto-propose-during-intake path (step 7.5 of `intake-module`). Not required for Phase 3d pass criteria — the primary smoke test (retroactive against Phandalin) exercises the same underlying procedure.

If a user wants to validate this path, they can hand-author a small synthetic test module at `references/test-module-3d.md` with a `## Secret` section containing at least one reveal-quality candidate, run `/intake references/test-module-3d.md`, and verify:
- The structured summary's "Revelation seeds proposed" section lists at least one new seed.
- `dm/revelations/r-NNN.md` exists with the documented schema.
- The seed's `proposed-from-module` frontmatter matches the new module's slug.

The synthetic fixture can be discarded after the test (unlike the Phase 3c bestiary fixture which is committed as a permanent reference).

### Asymmetry audit

Same shape as Phase 3a/3b/3c:

1. dm-fs access log shows librarian-issued reads and writes against `revelations/` paths. Verify the writes are `create_dm_file` (Phase 3d only creates new files; the revelation subagent's `confirm` query mutates existing ones via `write_dm_file` + `append_dm_file`, which is unchanged).
2. Main agent's `cat dm/revelations/r-NNN.md` is denied (dm-quarantine intact for the new tier of librarian-written content).
3. No narrator-issued reads/writes to any `dm/` path during smoke test.
4. The revelation subagent's `could-land` query against scopes that match the new seeds correctly surfaces clues — confirms backward compatibility with Phase 2b parsing.
5. Phase 3a/3b/3c boundaries hold: `cat dm/modules/.../secrets.md` denied; `library/lore/.../entries/*.md` readable. The new revelation auto-propose tier doesn't weaken existing protections.

## Failure modes Phase 3d must handle

- **Module doesn't exist (no `dm/modules/<slug>/`).** `propose-revelations` aborts in pre-flight with `"no such module or no secrets.md for module <slug>"`. No partial writes.
- **Module has empty or missing `secrets.md`.** Procedure step 2 reads the file; if empty or missing, abort with explicit error.
- **All reveal candidates already proposed (idempotent re-run).** The librarian's existing-revelation scan (step 3) returns matches with `proposed-from-module: <slug>`. Summary returns "None — no new reveal-quality candidates beyond those already proposed." No new writes. Safe to re-run.
- **ID allocation race.** Between `list_dm_dir("revelations")` and `create_dm_file`, another librarian invocation could theoretically allocate the same ID (e.g., if `propose-revelations` is run concurrently against two modules — not a real Phase 3d concern since subagent invocations are sequential, but documented for completeness). Mitigated by `create_dm_file`'s error-on-existing semantics: if collision, abort with explicit error. Phase 3d does not retry; the user re-runs after conflict resolution.
- **Librarian's reveal-vs-flavor judgment is wrong.** Some twists in `secrets.md` may not be reveal-quality (e.g., minor flavor text about a custom stat block). The librarian uses LLM judgment, default-to-skip on ambiguity. Some seeds may need to be deleted by the user during review; others may need to be hand-created if the librarian missed a candidate. The commit-gate is the discipline.
- **Clue vector anchoring quality varies.** The librarian's anchors (scope tags like `kodors-resting-place-f2`) are starting points. The user edits them during review if the chosen anchors aren't ideal. Phase 2b's `could-land` query uses LLM judgment to match scope tags to play moments anyway, so imperfect anchors still work — just less optimally.
- **Backward-compat with Phase 2b revelation subagent.** The two new frontmatter fields are not in the original Phase 2b schema. The revelation subagent's parsing logic only acts on `status` and `clue-count`; unknown fields are ignored. Smoke test verifies via `could-land` invocation.
- **Librarian write failure mid-propose.** Partial state — some seeds written, others not. Surface error in summary. User reviews via shell, deletes partial seeds or completes manually.
- **Slug collision in revelation IDs from prior phases.** The Phase 2b spec's seeded `r-001.md` may still exist. The librarian's `max + 1` allocation handles this correctly (starts at `r-002`).
- **Librarian-discipline regression** (Phase 3a lesson). The Phase 3d additions must maintain positive framing. No "never write to X" mentions for new paths. The new `## Write access` bullet and `propose-revelations` procedure use positive contract language.

## Open questions resolved during brainstorming

- **Sub-slicing of Phase 3d:** revelations only. Factions deferred to Phase 3e (faction schema requires speculative authoring of clock state, ladder rungs, triggers); threads deferred indefinitely (session-driven, not intake-driven).
- **Auto-during-intake AND standalone retroactive:** both. `intake-module` step 7.5 covers new ingest; `propose-revelations <slug>` query covers existing modules.
- **ID allocation:** monotonic `max(existing) + 1`. No reuse of deleted IDs.
- **Idempotency mechanism:** frontmatter `proposed-from-module: <slug>` matching. Re-running `propose-revelations <same-slug>` is a safe no-op for already-proposed reveals.
- **New frontmatter fields backward-compat:** yes — the Phase 2b revelation subagent ignores unknown frontmatter fields. Smoke test validates.
- **Seed file content quality:** "useful starting point" rather than "finished product." User edits clue vectors during commit-gate review.
- **CLAUDE.md changes:** one paragraph in `## Library reference material`. No new routing rule. No new must-never bullet.
- **MCP changes:** none. `create_dm_file` + `list_dm_dir` + `read_dm_file` cover all 3d operations.
- **Python code added:** none.
- **`/intake` command:** unchanged. Auto-propose is internal to the librarian.

## Phase 3d → Phase 3e+ handoff

Phase 3d's exit opens potential Phase 3e content (or further deferral to Phase 4):

- **Faction auto-proposals from module material.** `dm/factions/<slug>.md` seed-writing. Harder than revelations because faction schema demands clock + ladder + triggers — partly inferrable from module content, partly speculative. Phase 3e or Phase 4.
- **Solo-engine intake.** Mythic GME tables and alternative engines → `library/solo-engines/<name>/`.
- **Methodology intake.** Justin Alexander's GM book → `library/methodology/<topic>/`.
- **Gazetteer-essay-shape lore intake.** Extends `library/lore/` to handle regional descriptions.
- **URL ingestion.** Web-fetched sources behind a host allowlist.
- **Optional `consult-lore` runtime curated query.** If direct-read proves inadequate.
- **Lore-side quarantine.** `dm/lore/<source-slug>/` if a real source needs it.
- **`rename_dm_file` MCP tool.** Defer indefinitely.

The pattern Phase 3d establishes — "librarian writes to a new `dm/` path via existing dm-fs MCP for content auto-derived from module material, with provenance frontmatter for idempotency" — is the substrate for faction auto-propose in Phase 3e if/when that ships.

## Roadmap context

Phase 3d sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete; clue-level filter fix landed 2026-05-10)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(complete)*
6. **Phase 3a — Source ingestion: modules (intake-only, dm-quarantined).** *(complete)*
7. **Phase 3b — Runtime librarian queries (`consult-library` + `reveal-from-module`) + librarian prompt hardening.** *(complete)*
8. **Phase 3c — Source ingestion: lore-reference (bestiary-shaped entries; narrator-readable).** *(complete)*
9. **Phase 3d — Auto-propose revelation seeds from module material (extends `intake-module` + new `propose-revelations` query).** *(this design)*
10. **Phase 3e — Faction auto-proposals and/or other deferred Phase 3 work (solo-engine, methodology, gazetteer-essay, URL ingestion, optional `consult-lore`, optional lore-side quarantine). Further slicing determined when Phase 3e is brainstormed.**
11. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals from session play, content authoring formalization.
12. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
13. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
14. **Phase 7 — Downtime, banking, bastions.**

Phase 3d's scope is what's locked here.
