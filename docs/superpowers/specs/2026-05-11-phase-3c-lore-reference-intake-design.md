# Phase 3c — Lore-Reference Intake Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Phase 2b spec:** `docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md`.
**Phase 2c spec:** `docs/superpowers/specs/2026-05-10-phase-2c-mythic-threads-design.md`.
**Phase 2d spec:** `docs/superpowers/specs/2026-05-10-phase-2d-mythic-event-spotlight-design.md`.
**Phase 3a spec:** `docs/superpowers/specs/2026-05-10-phase-3a-source-ingestion-modules-design.md`.
**Phase 3b spec:** `docs/superpowers/specs/2026-05-11-phase-3b-runtime-librarian-queries-design.md`.
**Slice of original Phase 3:** lore-reference intake only, with monster-manual-shaped entries as the primary validation case. Solo-engine intake, methodology intake, gazetteer-shape intake, URL ingestion, auto-proposals for `dm/factions/`/`dm/revelations/`/`dm/threads/` from module material, optional `consult-lore` runtime query, and optional lore-side quarantine all defer to Phase 3d.

## Purpose

Phase 3a + 3b made *module* content playable: modules ingest into `dm/modules/<slug>/` (dm-quarantined), and the narrator reaches their content during play through the librarian's `consult-library` and `reveal-from-module` queries. That covers future-scene state from the party's POV.

Phase 3c covers the **opposite** content tier: world-fact content the party can plausibly encounter at any time. Monster stat blocks, spell descriptions, random tables, regional gazetteer entries. This is *not* future-scene state — a goblin's stat block is true everywhere goblins exist, regardless of which scene is unfolding. The narrator needs ready access to such content; there is no asymmetry to enforce.

Phase 3c's load-bearing claim is that **`library/lore/<source-slug>/` is narrator-readable and directly readable via Read/Glob**, distinct from `library/modules/<slug>/` which stays empty by contract because module content is dm-quarantined. The two paths under `library/` have opposite semantics on purpose: modules are enumerated only (full content in `dm/`), while lore is fully populated and narrator-readable.

Phase 3c primarily validates **monster-manual-shaped** ingest (bestiary entries with stat blocks). The generic schema accommodates other entry-list shapes (spell lists, random-table compendia, gazetteer-of-regions), but those are not the primary smoke-test target.

## Definition of done

A successful Phase 3c build demonstrates all of:

- **New query type on the librarian:** `intake-lore`.
  - Invocation: `"Ingest lore material at <path>. Active session log: <path-or-null>."` (Or dispatched internally from `intake-module`'s pre-flight when the source is detected as entry-list-shaped.)
  - Procedure: librarian reads source, decomposes into per-entry markdown files, writes to `library/lore/<source-slug>/entries/<entry-slug>.md`, builds a per-source `library/lore/<source-slug>/index.md` enumerating entries, updates top-level `library/index.md`'s `## Lore references` section. Emits structured intake summary.
  - Returns: structured summary listing entries written, source citation, content shape, and any opportunities for later phases.

- **`intake-module`'s content-type pre-flight (step 2) updated** to route by source shape. The current Phase 3a/3b wording aborts on any non-module source. The new wording routes:
  - **Module-shaped** (location/scene/encounter decomposition + hooks + conditional connections + GM-only secrets): continue `intake-module`.
  - **Entry-list-shaped** (bestiary, spell list, random tables, gazetteer-entries): abort `intake-module` and dispatch to `intake-lore`.
  - **Solo engine / methodology / pure narrative reference**: abort with explicit Phase 3d deferral message.

- **Library structure for lore (NEW):**
  - `library/lore/.gitkeep` placeholder ensures the empty directory is tracked before first lore intake.
  - `library/lore/<source-slug>/index.md` — per-source enumeration, narrator-readable, designed for triage before per-entry reads.
  - `library/lore/<source-slug>/entries/<entry-slug>.md` — one file per entry, narrator-readable, body sections vary by content shape (bestiary entries use `## Description`, `## Stat block`, `## Tactics`, `## Ecology / lore`).

- **`library/lore/<source-slug>/` is narrator-readable by direct Read/Glob.** No dm-side quarantine for lore content. The librarian writes directly via Write/Edit (no dm-fs MCP involvement).

- **Top-level `library/index.md` `## Lore references` section** is populated by `intake-lore`. Entry format: `- **<source-slug>** — <one-line genre/theme descriptor>. Source: \`<reference path>\`. Ingested: <YYYY-MM-DD>. Entries: <N>.`

- **No `consult-lore` runtime query in Phase 3c.** The narrator reads `library/lore/<source-slug>/index.md` and `entries/<entry-slug>.md` files directly via Read/Glob. Narrator-direct-read works because lore is narrator-readable by design. A curated `consult-lore` query is deferred to Phase 3d if direct-read proves inadequate.

- **CLAUDE.md** gains one paragraph in `## Library reference material` noting that `library/lore/<source-slug>/` is narrator-readable for world-fact content, distinct from `library/modules/<slug>/` which stays empty by contract. No new routing rule. No new must-never bullets.

- **Smoke test:** ingest one bestiary source (Mode A: real monster manual PDF if available in `references/`; Mode B: synthetic 5-10-entry bestiary at `references/test-bestiary.md` otherwise). Verify: `library/lore/<source-slug>/` has `index.md` + `entries/` with one file per monster; `library/index.md`'s `## Lore references` section lists the source; main agent (narrator) can `cat` / `Read` files under `library/lore/<source-slug>/` directly with no permission denial (positive confirmation of narrator-readable design).

- All 87 existing tests continue to pass; no Python code added.

- **`/intake` slash command unchanged.** The librarian routes by content type internally. No new slash command surface.

- **No new MCP tools.** Lore writes use the librarian's existing direct Write/Edit access. dm-fs MCP is not involved in lore intake (lore is not under `dm/`).

## Out of scope (deferred to Phase 3d or later)

- **Solo-engine intake.** Mythic GME 2e and alternative engine support — `library/solo-engines/<name>/`. Phase 3d.
- **Methodology intake.** Justin Alexander's GM book and similar — `library/methodology/<topic>/`. Phase 3d.
- **Gazetteer-shape intake** (essay-style regional descriptions vs entry-list). Phase 3c's `intake-lore` is biased toward entry-list sources. Gazetteer-shape may need a different decomposition; defer if smoke test surfaces mismatch.
- **URL ingestion.** Phase 3d.
- **Auto-proposals for `dm/factions/`/`dm/revelations/`/`dm/threads/`** from module material. Phase 3d.
- **`consult-lore` runtime curated query.** Phase 3d if direct-read pattern proves inadequate. Trigger: large bestiaries (200+ entries) where direct-read costs too much narrator context, or narrator over-pulls and confuses scenes by absorbing too much lore at once.
- **`reveal-from-lore`-style explicit gated query.** Not applicable — lore is not gated by reveal moments. Lore is "always-on" world-fact content.
- **`rename_dm_file` MCP tool.** Defer indefinitely; commit-gate is sufficient.
- **Dm-side quarantine of lore content** (`dm/lore/<source-slug>/`). All lore is narrator-readable in 3c. If a real workflow surfaces a need (e.g., a custom monster manual entry with GM-only campaign-specific notes), Phase 3d may add lore-side quarantine. Until then, user is responsible for pre-stripping GM-only campaign-specific content before intake.
- **Cross-source lore composition** (one scope matches entries from multiple lore sources). Direct-read pattern handles this naturally — narrator reads from multiple sources as needed. Phase 3d may formalize if needed.

## Architecture

### Slice mapping

| Component                          | Phase 3c touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | One paragraph addition in `## Library reference material` in `CLAUDE.md`. No new routing rule. No new must-never bullets. |
| World-state, revelation, mythic, dice subagents | Untouched.                                                       |
| **Librarian subagent**             | **MODIFIED** — `.claude/agents/librarian.md`. New `intake-lore` query type. `intake-module`'s content-type pre-flight (step 2) rewritten to route entry-list sources to `intake-lore`. Frontmatter description updated. New `## Write access` bullet for `library/lore/` direct writes. |
| `dm-fs` MCP                        | No tool changes. Lore writes don't go through dm-fs MCP (lore is narrator-readable, not dm-quarantined). |
| `.claude/settings.json`            | No deny-rule changes.                                                            |
| `/intake` command                  | Untouched. The librarian routes by content type internally.                      |
| Other slash commands               | Untouched.                                                                       |
| Repository layout                  | NEW: `library/lore/`, `library/lore/.gitkeep`. Smoke-test artifacts: `library/lore/<source-slug>/index.md` + `entries/<entry-slug>.md` files; `library/index.md` modified to include the lore source. |

### Information-asymmetry preservation — three tiers

Phase 3c extends the asymmetry model with a third content tier. The full model:

| Tier              | Content type       | Where it lives                            | Narrator access                                                            |
|-------------------|--------------------|-------------------------------------------|----------------------------------------------------------------------------|
| Hidden state      | Modules            | `dm/modules/<source-slug>/`               | None direct; runtime via librarian's `consult-library` + `reveal-from-module` |
| World fact (NEW)  | Lore               | `library/lore/<source-slug>/`             | **Direct read** via Read/Glob                                              |
| Index             | Module enumeration | `library/index.md` `## Modules`           | Direct read                                                                |
| Index             | Lore enumeration   | `library/index.md` `## Lore references` + per-source `library/lore/<slug>/index.md` | Direct read         |

The Phase 3a/3b boundary is unchanged: `dm/modules/<slug>/` stays dm-quarantined. Phase 2 boundaries (`dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`) unchanged.

Lore content is narrator-readable by design because a goblin's stat block is a *world fact*, not future-scene state. The party can plausibly encounter goblins anywhere; the narrator needs the stat block ready. There's no asymmetry to enforce for world-fact content — the same logic applies to `world/factions/<slug>.md` public stubs (created on discovery, narrator-readable) and `world/regions/` content.

**One discipline carve-out:** if a lore source contains GM-only campaign-specific content (e.g., a custom monster manual entry that names a specific hidden NPC or boss location), the user is responsible for pre-stripping that before intake. Phase 3c does not implement lore-side quarantine. If real workflows surface a need, Phase 3d may add `dm/lore/<source-slug>/` and a gated query.

### Integration with prior phases

- **Phase 1:** unchanged.
- **Phase 2a-2d:** unchanged.
- **Phase 3a (module intake):** the `intake-module` query is unchanged in procedure body. Only its content-type pre-flight (step 2) is updated to route entry-list sources to `intake-lore` instead of aborting. Module content still goes entirely to `dm/modules/<slug>/`.
- **Phase 3b (runtime queries):** unchanged. `consult-library` and `reveal-from-module` still operate against `dm/modules/<slug>/`. Phase 3c does NOT add `consult-lore` — narrator reads lore directly.

## Component designs

### File schemas

#### `library/lore/<source-slug>/index.md`

Per-source enumeration. Narrator-readable. Designed for triage before reading individual entries.

```markdown
---
slug: <source-slug>
name: <Source Name>
source: references/<file>
ingested: <YYYY-MM-DD>
content-shape: bestiary | spell-list | random-tables | gazetteer-entries | mixed
entry-count: <N>
---

# <Source Name> — Index

## Summary

<1-2 sentence summary of what this source is and what kind of entries it contains.>

## Entries

- **<entry-slug>** — <one-line descriptor: e.g., "CR 1/4 humanoid raider", "evocation cantrip, ranged attack", "d20 weather table for autumn forest">
- **<entry-slug>** — ...
- ...
```

Schema notes:

- `content-shape` documents the source's entry type. Phase 3c's primary case is `bestiary`; other shapes are tolerated but not optimized for. Phase 3d may add per-shape decomposition logic.
- Entries listed alphabetically by slug.
- The one-line descriptor lets the narrator pick the right entry without reading every file.

#### `library/lore/<source-slug>/entries/<entry-slug>.md`

Per-entry file. Generic schema; section headings adapt to content shape.

```markdown
---
slug: <entry-slug>
name: <Entry Name>
parent-source: <source-slug>
category: <e.g., humanoid, undead, dragon for bestiary; evocation, abjuration for spells>
source-citation: <e.g., "MM p.166" or "PHB p.234">
---

# <Entry Name>

## Description

<Player-perceivable facts about the entry. For a monster: appearance, behavior, common encounters.>

## Stat block (or "Mechanics" / "Table" / etc. depending on shape)

<For a monster: AC, HP, ability scores, attacks, special abilities. Verbatim from source where possible.>

## Tactics / Usage notes

<For a monster: how it fights, what motivates it. For a spell: tactical use cases.>

## Ecology / lore

<Optional. Habitat, society, larger-world context.>
```

The librarian adapts section headings to the content shape declared in the per-source `index.md`. A bestiary entry uses `## Stat block` + `## Tactics`; a spell entry uses `## Mechanics` + `## Usage notes`; etc. The `intake-lore` procedure documents acceptable shape conventions.

#### Top-level `library/index.md` `## Lore references` section

Replaces the Phase 3a placeholder comment with one entry per ingested lore source:

```markdown
## Lore references

- **<source-slug>** — <one-line genre/theme descriptor>. Source: `<reference path>`. Ingested: <YYYY-MM-DD>. Entries: <N>.
- ...
```

### Librarian subagent changes (`.claude/agents/librarian.md`)

Four targeted modifications to the existing Phase 3b v3 librarian:

1. **Frontmatter description** updated to mention `intake-lore` alongside `intake-module`, `consult-library`, `reveal-from-module`.

2. **`## Write access`** gains a new bullet:
   > - `library/lore/<source-slug>/` and its contents (`index.md`, `entries/<entry-slug>.md`) — writable directly via Write and Edit. Lore content is narrator-readable; no dm-fs MCP involvement.

3. **`## Query type: intake-module`'s step 2 rewritten.** The current Phase 3b wording aborts on any non-module source. The new wording:
   > **2. Identify content type.** Judge the source's shape:
   > - **Module-shaped** (location/scene/encounter decomposition + hooks + conditional connections + GM-only secrets): continue this procedure (`intake-module`).
   > - **Entry-list-shaped** (bestiary, spell list, random-tables compendium, gazetteer-entries): abort this procedure and dispatch to `intake-lore` (see below).
   > - **Solo engine / methodology / pure narrative reference**: abort with `"Phase 3a/3b/3c only supports module and lore intake; this source appears to be <type>. Phase 3d will add <type> support."`

4. **New `## Query type: intake-lore`** added after `intake-module`. Procedure outline:
   > Invocation: `"Ingest lore material at <path>. Active session log: <path-or-null>."` (Or dispatched internally from `intake-module`'s step 2.)
   >
   > 1. **Pre-flight.** Read source path. Handle PDFs / markdown the same way as `intake-module` (use Read tool's PDF support with page ranges for large documents).
   > 2. **Identify content shape.** Pick from `bestiary | spell-list | random-tables | gazetteer-entries | mixed`. This drives entry section-heading conventions in step 5. If the shape is ambiguous, default to `mixed` and flag in the intake summary.
   > 3. **Derive source slug & name.** Slug-collision check against existing `library/lore/<slug>/` via direct Glob. If `library/lore/<slug>/` exists, abort with explicit error.
   > 4. **Decompose into entries.** Scan the source for distinct entries (one monster per entry for bestiary; one spell for spell-list; one table for random-tables; one region for gazetteer-entries). For each entry, gather name, category, and body content per the shape's conventions.
   > 5. **Write each entry to `library/lore/<source-slug>/entries/<entry-slug>.md`** directly via Write. Section headings vary by content shape:
   >    - `bestiary`: `## Description`, `## Stat block`, `## Tactics`, `## Ecology / lore`.
   >    - `spell-list`: `## Description`, `## Mechanics`, `## Usage notes`.
   >    - `random-tables`: `## Description`, `## Table`, `## Notes`.
   >    - `gazetteer-entries`: `## Description`, `## Notable features`, `## NPCs`, `## Connections to other entries`.
   >    - `mixed`: librarian picks the most appropriate sectioning per entry and flags in summary.
   > 6. **Build `library/lore/<source-slug>/index.md`** directly via Write. Frontmatter (`slug`, `name`, `source`, `ingested`, `content-shape`, `entry-count`) + `## Summary` (1-2 sentences) + `## Entries` (one bullet per entry, sorted alphabetically by slug, with one-line descriptor).
   > 7. **Update top-level `library/index.md`** via Edit — append an entry under `## Lore references`, update `last-updated`, re-sort the section alphabetically. Entry format: `- **<source-slug>** — <one-line genre/theme descriptor>. Source: \`<reference path>\`. Ingested: <YYYY-MM-DD>. Entries: <N>.`
   > 8. **Emit structured intake summary**:
   >    ```
   >    INTAKE SUMMARY (lore): <source-slug>
   >
   >    Source: <path>
   >    Name: <Source Name>
   >    Content shape: <shape>
   >    Entries written: <N>
   >
   >    Library artifacts (library/lore/<source-slug>/):
   >      - index.md (with <N> entries enumerated)
   >      - entries/<entry-slug-1>.md
   >      - entries/<entry-slug-2>.md
   >      - ...
   >
   >    library/index.md updated with one-line enumeration entry under ## Lore references.
   >
   >    Content-shape notes (if any):
   >      - <one-line note about ambiguous entries, mixed-shape handling, or GM-only content detected>
   >      (or: "None — all entries decomposed cleanly under content-shape <shape>.")
   >
   >    Opportunities flagged for later phases:
   >      - <e.g., "Source contains a random encounter table that could feed Phase 3d runtime encounter generation.">
   >      (or: "None.")
   >
   >    NEXT STEPS:
   >      1. Review the staged files: `library/lore/<source-slug>/index.md` and `library/lore/<source-slug>/entries/*.md`.
   >      2. Spot-check that no GM-only campaign-specific content slipped in (lore is narrator-readable; pre-strip such content if found).
   >      3. Confirm the per-source descriptor in library/index.md is genre-level only.
   >      4. Commit when satisfied.
   >    ```
   > 9. **Append session-log line** if active session log provided (via Edit):
   >    ```
   >    - LIBRARIAN QUERY: intake-lore <source-slug> — <N> entries, content-shape: <shape>
   >    ```

#### Edge cases for `intake-lore`

- **Source isn't entry-list-shaped.** The pre-flight (step 2) abort message routes it to `intake-module` consideration. If `intake-module` also rejects, the source goes to "Phase 3d will add <type> support" abort path.
- **Source produces zero entries.** Abort with `"source produced no entries; check that the source is entry-list-shaped"`. No partial writes.
- **Slug collision.** `library/lore/<slug>/` already exists. Abort; user resolves manually.
- **Partial intake state from prior failure.** `library/lore/<slug>/` exists with some files but missing `index.md`. Abort with explicit error.
- **Source contains GM-only / "Secret" / "DM Only" markers.** Librarian flags in summary's content-shape notes. Does NOT auto-quarantine — Phase 3c is lore-only-narrator-readable. User pre-strips if needed.
- **Mixed-shape source.** Librarian uses LLM judgment to pick per-entry sectioning. Flags in summary that mixed content was detected.
- **Very large bestiary (200+ entries).** Read in page-range chunks; write entries incrementally. If single source exceeds context budget, abort with `"source exceeds intake budget; pre-split into smaller lore sources"`.
- **Empty source path or unreadable file.** Pre-flight abort before any writes.
- **`library/index.md` write fails after entry writes succeed.** Surface error; user reconciles via direct edit. Unlike Phase 3a (where the index write was the last step), Phase 3c's order is identical — index update is last, so a failure here leaves entries written and only the index reference missing.

### CLAUDE.md update (Phase 3c)

Append one paragraph to the existing `## Library reference material` section. Insertion point: after the existing paragraph about runtime access via the librarian, before the `## What you must never do` heading.

New paragraph:

> `library/lore/<source-slug>/` contains narrator-readable lore content — world-fact reference material the party can plausibly encounter (monster stat blocks, spell descriptions, random tables, regional gazetteer entries). Unlike `library/modules/` (which stays empty by contract because module content is dm-quarantined), `library/lore/` IS populated and directly readable. Read `library/index.md` to see which lore sources are ingested, then read `library/lore/<source-slug>/index.md` for per-source entry triage, then read specific `library/lore/<source-slug>/entries/<entry-slug>.md` files as needed for the scene. The librarian owns intake for both modules and lore via `/intake`; runtime access to lore uses your direct Read/Glob (no librarian query needed in Phase 3c).

No new routing rule. No new must-never bullet. The narrator's existing `Read` and `Glob` tools cover lore consultation directly.

### Repository layout (Phase 3c additions)

```
gygaxagain/
├── .claude/agents/
│   └── librarian.md             # MODIFIED — intake-lore query + content-type routing in intake-module
├── library/
│   ├── lore/                     # NEW directory
│   │   └── .gitkeep              # NEW — placeholder before first lore intake
│   │   └── <smoke-test-slug>/    # NEW (smoke-test artifact)
│   │       ├── index.md
│   │       └── entries/
│   │           └── <entry-slug>.md (one per smoke-test entry)
│   └── index.md                  # modified by smoke-test intake (Lore references populated)
└── CLAUDE.md                     # one paragraph addition in ## Library reference material
```

## Smoke test for Phase 3c

### Mode A — real bestiary intake

If a real monster manual / bestiary PDF is available in `references/`, intake it directly.

1. With the v4 librarian prompt in place (`intake-lore` added, `intake-module`'s content-type pre-flight updated), the user runs `/intake references/<bestiary-source>`.
2. The `/intake` command invokes the librarian. The librarian's pre-flight (intake-module step 2) identifies the source as entry-list-shaped and dispatches `intake-lore`.
3. The `intake-lore` procedure:
   - Derives source slug from title.
   - Decomposes into per-monster entries.
   - Writes `library/lore/<source-slug>/entries/<entry-slug>.md` files (one per monster) via direct Write.
   - Writes `library/lore/<source-slug>/index.md`.
   - Updates `library/index.md`'s `## Lore references` section via Edit.
   - Returns structured summary.
4. The user reviews artifacts directly (narrator-readable; no shell-outside-Claude-Code required).
5. User commits.

**Pass criteria (Mode A):**
- `library/lore/<source-slug>/index.md` exists with one-line entry descriptors.
- `library/lore/<source-slug>/entries/<entry-slug>.md` files exist, one per monster, with the bestiary section structure (`## Description`, `## Stat block`, `## Tactics`, `## Ecology / lore`).
- `library/index.md` has a new entry under `## Lore references` with the prescribed format.
- The main agent (narrator) can `cat` and `Read` any file under `library/lore/<source-slug>/` directly — no permission denial. (Positive confirmation of narrator-readable design.)
- The librarian's intake summary correctly enumerates entry count, content shape, and any opportunities flagged.
- All 87 existing tests pass.

### Mode B — synthetic bestiary fallback

If no real monster manual is in `references/`, hand-author a synthetic 5-10-entry bestiary at `references/test-bestiary.md` with realistic structure. Suggested entries: goblin, kobold, zombie, wolf, brown bear, animated armor (mix of CRs and categories). Each entry has the four bestiary sections.

Run `/intake references/test-bestiary.md`. Same pass criteria as Mode A, scaled to ≥5 entries.

**Note:** Unlike Phase 3a's synthetic `test-module.md` fixture (which was discarded), Phase 3c's synthetic bestiary can be **committed** as a permanent reference for future testing (e.g., Phase 3d validation of `consult-lore` against known content). The synthetic-bestiary commit is part of the Phase 3c smoke-test deliverable.

### Asymmetry audit — lighter than 3a/3b

Phase 3c's load-bearing claim is the *opposite* of 3a/3b's: lore content IS narrator-readable. The audit confirms by positive test:

1. After intake, the main agent runs `cat library/lore/<source-slug>/entries/<entry-slug>.md`. **Expected: file content displays** (no deny).
2. Main agent runs `cat library/lore/<source-slug>/index.md`. **Expected: file content displays.**
3. Phase 3a/3b boundary still holds: `cat dm/modules/<slug>/secrets.md` is **denied**. Confirms the new lore tier doesn't accidentally weaken existing protections.

If steps 1-2 are denied, the `library/lore/` write permissions are misconfigured or settings.json was changed accidentally — investigate before merge.

## Failure modes Phase 3c must handle

- **Source isn't entry-list-shaped.** Librarian's content-type judgment misroutes (e.g., a methodology text gets routed to `intake-lore`). The `intake-lore` pre-flight (step 2) should bail with `"source does not decompose into per-entry files; please pre-structure or wait for Phase 3d <type> intake."` User intervenes.
- **Slug collision.** `library/lore/<slug>/` exists. Abort; user deletes or renames manually.
- **Partial intake state.** Abort with explicit error.
- **Source contains GM-only campaign-specific content.** Phase 3c does not implement lore-side quarantine. Librarian flags in summary; user pre-strips or accepts narrator-readable status. Phase 3d may add quarantine if surfaced.
- **Mixed-shape source.** Librarian extracts entry-list portion, flags non-entry content in summary.
- **Very large bestiary.** Page-range chunks; abort if budget exceeded.
- **Librarian-discipline regression** (Phase 3a lesson). The Phase 3b positive-framing rewrite for `intake-module` must extend to `intake-lore`. No "never write to X" framing for paths the librarian shouldn't write to. The contract for `intake-lore` should be stated positively (e.g., "Lore writes go directly to `library/lore/<source-slug>/`").
- **Schema mismatch within entries.** Librarian's content-shape decision is per-source. If entries genuinely vary, flag in summary; user reconciles.
- **Empty source / zero entries detected.** Abort with explicit error.
- **`library/index.md` write fails after entry writes succeed.** Entries are committed but index reference missing. User reconciles manually.

## Open questions resolved during brainstorming

- **Slicing of Phase 3c:** lore-reference intake only (with bestiary as primary case). Solo-engine, methodology, gazetteer (essay-shape), URL ingestion, auto-proposals, optional `consult-lore`, optional lore-side quarantine all defer to Phase 3d.
- **Asymmetry model for lore:** narrator-readable; no dm-side quarantine. User pre-strips GM-only material before intake.
- **Runtime query for lore:** none in Phase 3c. Narrator reads `library/lore/` directly via Read/Glob. `consult-lore` deferred to Phase 3d if direct-read insufficient.
- **`/intake` routing:** content-type judgment lives in the librarian's pre-flight, not in the slash command. No new slash command surface.
- **Per-entry schema:** flexible per content shape. Bestiary is the primary smoke-test case (`## Description`, `## Stat block`, `## Tactics`, `## Ecology / lore`).
- **Per-source index.md:** narrator-readable enumeration with one-line descriptors for triage.
- **MCP changes:** none. Lore writes via direct Write/Edit (lore is narrator-readable).
- **Python code added:** none.
- **CLAUDE.md changes:** one paragraph in `## Library reference material`. No new routing rule, no new must-never bullet.
- **Synthetic bestiary fixture (Mode B):** committed as a permanent test reference, distinct from Phase 3a's discarded synthetic module fixture.

## Phase 3c → Phase 3d handoff

Phase 3c's exit unlocks Phase 3d, which composes:

- **Solo-engine intake.** Mythic GME 2e and alternative engine support → `library/solo-engines/<name>/`. Schema to be designed when Phase 3d is brainstormed.
- **Methodology intake.** Justin Alexander's GM book and similar → `library/methodology/<topic>/`. May influence agent prompts directly via reference links.
- **Gazetteer-shape intake** (essay-style regional descriptions, distinct from entry-list lore). Probably extends `library/lore/` with a different content shape, or a separate top-level `library/regions/`.
- **URL ingestion.** Web-fetched sources behind a host allowlist.
- **Auto-proposals for `dm/factions/`, `dm/revelations/`, `dm/threads/`** from module intake. Librarian proposes seed files for user review during/after `intake-module`. Requires expanded librarian write scope (currently writes only to `dm/modules/` and `library/index.md` + `library/lore/`).
- **Optional `consult-lore` runtime curated query.** Phase 3d if Phase 3c's direct-read pattern is inadequate for large bestiaries or for narrator context-budget reasons.
- **Lore-side quarantine.** `dm/lore/<source-slug>/` for GM-only campaign-specific lore content, if Phase 3c surfaces a real need.
- **Optional `rename_dm_file` MCP tool.**

## Roadmap context

Phase 3c sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete; clue-level filter fix landed 2026-05-10)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(complete)*
6. **Phase 3a — Source ingestion: modules (intake-only, dm-quarantined).** *(complete)*
7. **Phase 3b — Runtime librarian queries (`consult-library` + `reveal-from-module`) + librarian prompt hardening.** *(complete)*
8. **Phase 3c — Source ingestion: lore-reference (bestiary-shaped entries; narrator-readable; no runtime curation yet).** *(this design)*
9. **Phase 3d — Solo-engine + methodology + gazetteer-essay + URL intake; auto-proposals for dm/factions/dm/revelations/dm/threads from module material; optional `consult-lore` runtime query; optional lore-side quarantine.**
10. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals, content authoring formalization.
11. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
12. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
13. **Phase 7 — Downtime, banking, bastions.**

Phase 3c's scope is what's locked here.
