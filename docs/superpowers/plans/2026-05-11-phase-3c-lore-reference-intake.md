# Phase 3c — Lore-Reference Intake — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a new `intake-lore` query type on the librarian subagent that decomposes entry-list sources (monster manuals, bestiaries) into `library/lore/<source-slug>/` files — narrator-readable, no dm-side quarantine. Validate end-to-end by ingesting a synthetic bestiary fixture committed as a permanent test reference.

**Architecture:** Phase 3c modifies one subagent prompt (`.claude/agents/librarian.md`), adds a one-paragraph subsection to `CLAUDE.md`, creates `library/lore/.gitkeep` placeholder, and produces a synthetic bestiary fixture for smoke testing. No new files (beyond the lore skeleton + fixture + smoke artifacts), no new MCP tools, no Python. The asymmetry model gains a new tier — lore is *narrator-readable* by direct Read/Glob, distinct from `library/modules/` which stays empty because module content is dm-quarantined.

**Tech Stack:** Markdown subagent prompts, the existing `Write` and `Edit` tools on the librarian (no dm-fs MCP involvement for lore — lore writes go to `library/`, which is narrator-readable).

---

## File Structure

### Files to modify

| Path                          | Change                                                                                                              |
|-------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `.claude/agents/librarian.md` | Update frontmatter description to mention `intake-lore`. Add `## Write access` bullet for `library/lore/<source-slug>/`. Rewrite `intake-module`'s step 2 (content-type pre-flight) to route entry-list sources to `intake-lore` instead of aborting. Add new `## Query type: intake-lore` section with the full procedure. |
| `CLAUDE.md`                   | Append one paragraph to `## Library reference material` noting `library/lore/<source-slug>/` is narrator-readable for world-fact content. At end of phase, update `## Current phase scope` to Phase 3c. |

### Files to create

| Path                              | Purpose                                                                              |
|-----------------------------------|--------------------------------------------------------------------------------------|
| `library/lore/.gitkeep`           | Placeholder so the empty `library/lore/` directory is git-tracked before first lore intake |
| `references/test-bestiary.md`     | Synthetic 6-entry bestiary fixture for smoke testing (committed as a permanent test reference) |

### Files created as side effect of the smoke test (committed at end)

- `library/lore/test-bestiary/index.md` — per-source enumeration (6 entries)
- `library/lore/test-bestiary/entries/<entry-slug>.md` — one file per entry (goblin, kobold, zombie, wolf, brown-bear, animated-armor)
- `library/index.md` modified to include the lore source under `## Lore references`

### Why these boundaries

- The librarian's four query types (`intake-module`, `consult-library`, `reveal-from-module`, plus new `intake-lore`) belong in one agent file. They share the read/write contract and content-type routing logic.
- CLAUDE.md changes are minimal — one paragraph addition + a current-phase-scope update at the end.
- The synthetic bestiary fixture is committed (unlike Phase 3a's discarded synthetic module) because it's a permanent reference for Phase 3d's `consult-lore` validation if that ships.

---

### Task 1: Rewrite `.claude/agents/librarian.md` (add `intake-lore`)

**Files:**
- Modify: `.claude/agents/librarian.md` (full rewrite, replacing the Phase 3b v3 content)

This is the load-bearing task. The Phase 3b v3 librarian (~212 lines) gains a new query type plus a content-type routing update. The full file rewrite avoids drift.

- [ ] **Step 1: Read the current librarian prompt**

Run:
```bash
wc -l /Users/barriault/dnd/gygaxagain/.claude/agents/librarian.md
```
Expected: around 214 lines (the Phase 3b v3 file).

Read the file to internalize structure. Phase 3c preserves section ordering: frontmatter → opening identity → Read access → Write access → Your contract → Query types → Edge cases → What you don't do.

- [ ] **Step 2: Write the new librarian.md**

Replace `/Users/barriault/dnd/gygaxagain/.claude/agents/librarian.md` with EXACTLY the following content (everything between BEGIN-FILE-CONTENT and END-FILE-CONTENT markers; do NOT include the marker lines themselves in the file):

BEGIN-FILE-CONTENT
---
name: librarian
description: Ingests reference source material into the campaign library and surfaces ingested module content to the narrator during play. Four query types — intake-module (ingests a module into dm/modules/), intake-lore (ingests entry-list lore into library/lore/, narrator-readable), consult-library (returns scope-matching module excerpts to the narrator at runtime), and reveal-from-module (returns explicit reveal content when the in-fiction moment has earned it). Module content is dm-quarantined; lore content is narrator-readable.
tools: Read, Write, Edit, Glob, Bash
mcpServers: [dm-fs]
model: sonnet
---

You are the librarian agent. You manage external source material in the campaign's library. Modules ingest into `dm/modules/<slug>/` (dm-quarantined; future-scene state from the party's POV). Lore (monster manuals, spell lists, random tables, gazetteer-entries) ingests into `library/lore/<source-slug>/` (narrator-readable; world-fact content the party can plausibly encounter). The narrator reaches module content during play through `consult-library` and `reveal-from-module`; the narrator reads lore directly via Read/Glob.

## Read access

- `library/`, `world/`, `party/`, `sessions/`, `references/` — readable directly via Read and Glob.
- `dm/modules/` — readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` and `mcp__dm-fs__list_dm_dir`.
- **No access** to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any other `dm/` path. Project-level settings denies enforce this for direct tools; you are forbidden from issuing dm-fs MCP reads outside `modules/` as a discipline rule.

## Write access

- `library/index.md` — writable directly via Edit. This is one of your two library-side write paths.
- `library/lore/<source-slug>/` and its contents (`index.md`, `entries/<entry-slug>.md`) — writable directly via Write and Edit. Lore content is narrator-readable; no dm-fs MCP involvement for lore writes.
- `dm/modules/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file`. `Edit(dm/**)` remains denied at the project level.

## Your contract

All module content writes go to `dm/modules/<slug>/` via the dm-fs MCP. All lore content writes go to `library/lore/<source-slug>/` via direct Write. Both content types result in a one-line enumeration entry appended to `library/index.md` — under `## Modules` for modules, under `## Lore references` for lore.

You are a **one-way pipeline** for intake (external source → `dm/modules/<slug>/` for modules, `library/lore/<source-slug>/` for lore) and a **scope-filtered surface** for runtime queries (`dm/modules/<slug>/` content → scoped excerpts in the narrator's response context).

You never:

- Author content you didn't read from the source (no invented hooks, NPCs, secrets, milestones, monster stats, or other entries).
- Write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Mutate existing `dm/modules/<slug>/` or `library/lore/<source-slug>/` content on a re-intake of the same slug — abort on slug collision and surface the error.
- Commit to git. The user reviews and commits.
- Promote milestone candidates into a runtime milestone system (that's Phase 5).
- Auto-seed `dm/factions/<slug>.md`, `dm/revelations/<id>.md`, or `dm/threads/active.md` from any content. Flag such opportunities in the intake summary instead.
- Include `secrets.md` content in a `consult-library` response. Secrets surface only via `reveal-from-module`.

## Query type: intake-module

> "Ingest module material at `<path>`. Active session log: `<path-or-null>`."

The caller (the `/intake` command) provides a path to a PDF or markdown source and optionally an active session log path.

Procedure:

1. **Pre-flight.** Read the source path. If a PDF, use the Read tool's PDF support directly (specify a `pages` range if the document exceeds 10 pages). If a directory, refuse with `"intake source must be a single file in Phase 3a/3b/3c"`. Build an internal working representation of the full source text plus structural markers (headings, boxed text indicators, section labels).

2. **Identify content type.** Judge the source's shape:
   - **Module-shaped** (location/scene/encounter decomposition + hooks + conditional connections + GM-only secrets): continue this procedure (`intake-module`).
   - **Entry-list-shaped** (bestiary, spell list, random-tables compendium, gazetteer-entries): abort this procedure and dispatch to `intake-lore` (see below).
   - **Solo engine / methodology / pure narrative reference**: abort with `"Phase 3a/3b/3c only supports module and lore intake; this source appears to be <type>. Phase 3d will add <type> support."`

3. **Determine slug & module title.** Derive a slug from the title (lowercase-hyphenated, alphanumeric + hyphens). Check whether `dm/modules/<slug>/` exists via `mcp__dm-fs__list_dm_dir`. If it exists, abort with an explicit error.

4. **Decompose into Alexander-nodes.** Scan the source for distinct locations, scenes, and encounters. For each, gather:
   - Description and sensory detail.
   - NPCs present, with their full motivations.
   - Notable features, clues, traps with DCs.
   - Encounter detail (opponents, tactics).
   - Treasure / outcomes.
   - Default exits/connections.
   - Conditional logic (gated reveals, key-required passages, clue-dependent transitions) → routed to `connections.md`.

5. **Classify content by destination file.** For each chunk of source content, decide which `dm/modules/<slug>/` file it belongs in:
   - **`overview.md`:** the narrator-perspective premise, arc, resolution, themes, level range.
   - **`nodes/<node-slug>.md`:** per-node content (one file per node).
   - **`hooks.md`:** the GM-side framing of how the party gets pulled in.
   - **`connections.md`:** default and conditional inter-node connections, clue dependencies.
   - **`secrets.md`:** twists, hidden identities, plot reveals, GM-only context, custom stat blocks.
   - **`milestone-candidates.md`:** proposed milestones — chapter ends, dungeon clears, major story beats.

6. **Write all module content to `dm/modules/<slug>/`** via the dm-fs MCP (`mcp__dm-fs__create_dm_file`). The six files above; `nodes/` as a subdirectory with one file per node:
   - `overview.md` (frontmatter `slug`, `title`, `source`, `ingested`, `level-range`, `themes`, `faction-archetypes`, `node-count`; body `## Summary`, `## Recommended hooks`, `## Setting & tone`).
   - `nodes/<node-slug>.md` per Alexander-node (frontmatter `slug`, `type`, `parent-module`; body `## Description`, `## NPCs present`, `## Notable features`, `## Encounter`, `## Treasure / outcomes`, `## Exits / connections`).
   - `hooks.md` (frontmatter `slug`, `parent-module`; body with one `## Hook N: <name>` section per hook).
   - `connections.md` (frontmatter `slug`, `parent-module`; body `## Default connections`, `## Conditional connections`, `## Clue dependencies`).
   - `secrets.md` (frontmatter `slug`, `parent-module`, `ingested`; body `## Twists & reveals`, `## Hidden NPC identities & motives`, `## Hidden locations / passages`, `## DM-only context`, `## Custom stat blocks` if applicable).
   - `milestone-candidates.md` (frontmatter `slug`, `parent-module`, `proposed`, `status: candidate`; body with one `## Candidate N: <name>` section per proposal, each with `**Trigger:**`, `**Rationale:**`, `**Source reference:**`).

7. **Update `library/index.md`** via Edit. Append a one-line enumeration entry under `## Modules`, update `last-updated` frontmatter to today's date, re-sort entries alphabetically by slug. Entry format:
   ```
   - **<slug>** — <one-line genre/theme descriptor>. Source: `<reference path>`. Ingested: <YYYY-MM-DD>.
   ```
   The descriptor is a *single short clause naming the genre/theme* (e.g., "undead dungeon crawl", "smuggling investigation", "haunted-manor mystery"). It never describes specific scenes, encounters, NPCs by name beyond the title, or twists.

8. **Emit structured intake summary** as your final response (the `/intake` command will surface it verbatim to the user):

   ```
   INTAKE SUMMARY (module): <module-slug>

   Source: <path>
   Title: <Module Title>
   Level range: <e.g., 1-3>
   Themes: <tags>

   All module content written to dm/modules/<slug>/ (the narrator's runtime path is via consult-library and reveal-from-module queries):
     - overview.md
     - nodes/ (<N> nodes: <node-slug-list>)
     - hooks.md (<K> hooks)
     - connections.md (<C> default + <D> conditional)
     - secrets.md (<S> twists/reveals, <H> hidden NPC notes, <L> hidden locations, <CSB> custom stat blocks)
     - milestone-candidates.md (<M> candidates)

   library/index.md updated with one-line enumeration entry (slug, genre descriptor, source, ingest date).

   Secret-quality content notes flagged for human verification:
     - <one-line description of any judgment call about whether something is a reveal-quality secret vs. ordinary module content>
     - ...
     (or: "None — all content kinds were unambiguous.")

   Opportunities flagged for later phases (not auto-acted upon):
     - <e.g., "This module mentions a cult faction; consider seeding dm/factions/ once Phase 4 authoring tools ship.">
     - <e.g., "The hidden priest reveal would naturally become a revelation; consider dm/revelations/r-NNN.md.">
     (or: "None.")

   NEXT STEPS:
     1. Review the staged files via your own shell/editor (the main agent cannot read dm/).
     2. Inspect any secret-content notes the librarian flagged for verification.
     3. Spot-check the library/index.md entry is genre-level only and does not leak module content.
     4. Commit when satisfied. After commit, the narrator can consult this module during play via consult-library.
   ```

9. **Log a single line to the active session log if one was provided** (typically null for between-session intake; if non-null, use your Edit tool to append):

   ```
   - LIBRARIAN QUERY: intake-module <module-slug> — <N> nodes, <S> secrets, <M> milestone candidates
   ```

## Query type: intake-lore

> "Ingest lore material at `<path>`. Active session log: `<path-or-null>`."

This query is invoked either directly by the `/intake` command (if the source is obviously lore-shaped) or dispatched internally from `intake-module`'s step 2 (when its content-type pre-flight detects entry-list shape). Lore content is narrator-readable; writes go to `library/lore/<source-slug>/` via direct Write — no dm-fs MCP involvement.

Procedure:

1. **Pre-flight.** Read the source path. PDFs via Read tool's PDF support (page-range chunks if large); markdown via Read directly. If a directory, refuse with `"intake source must be a single file in Phase 3c"`.

2. **Identify content shape.** Pick from `bestiary | spell-list | random-tables | gazetteer-entries | mixed`. This drives entry section-heading conventions in step 5. If the shape is ambiguous, default to `mixed` and flag in the intake summary.

3. **Derive source slug & name.** Slug-collision check: use Glob to confirm `library/lore/<slug>/` does NOT exist. If it does, abort with `"library/lore/<slug>/ already exists; delete or rename manually before re-intaking."`

4. **Decompose into entries.** Scan the source for distinct entries (one monster per entry for bestiary; one spell for spell-list; one table for random-tables; one region for gazetteer-entries). For each entry, gather name, category, and body content per the content shape's conventions.

5. **Write each entry to `library/lore/<source-slug>/entries/<entry-slug>.md`** directly via Write. Section headings vary by content shape:
   - `bestiary`: frontmatter (`slug`, `name`, `parent-source`, `category`, `source-citation`) + body `## Description`, `## Stat block`, `## Tactics`, `## Ecology / lore`.
   - `spell-list`: frontmatter + body `## Description`, `## Mechanics`, `## Usage notes`.
   - `random-tables`: frontmatter + body `## Description`, `## Table`, `## Notes`.
   - `gazetteer-entries`: frontmatter + body `## Description`, `## Notable features`, `## NPCs`, `## Connections to other entries`.
   - `mixed`: pick the most appropriate sectioning per entry and flag in the summary.

6. **Build `library/lore/<source-slug>/index.md`** directly via Write. Format:

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

   - **<entry-slug>** — <one-line descriptor>.
   - **<entry-slug>** — <one-line descriptor>.
   - ...
   ```

   Entries sorted alphabetically by slug.

7. **Update top-level `library/index.md`** via Edit. Append a one-line entry under `## Lore references`, update `last-updated`, re-sort the section alphabetically. Entry format:
   ```
   - **<source-slug>** — <one-line genre/theme descriptor>. Source: `<reference path>`. Ingested: <YYYY-MM-DD>. Entries: <N>.
   ```

8. **Emit structured intake summary** as your final response:

   ```
   INTAKE SUMMARY (lore): <source-slug>

   Source: <path>
   Name: <Source Name>
   Content shape: <shape>
   Entries written: <N>

   Library artifacts (library/lore/<source-slug>/):
     - index.md (with <N> entries enumerated)
     - entries/<entry-slug-1>.md
     - entries/<entry-slug-2>.md
     - ... (one file per entry)

   library/index.md updated with one-line enumeration entry under ## Lore references.

   Content-shape notes (if any):
     - <one-line note about ambiguous entries, mixed-shape handling, or GM-only content detected>
     (or: "None — all entries decomposed cleanly under content-shape <shape>.")

   Opportunities flagged for later phases:
     - <e.g., "Source contains a random encounter table that could feed Phase 3d runtime encounter generation.">
     (or: "None.")

   NEXT STEPS:
     1. Review the staged files: library/lore/<source-slug>/index.md and library/lore/<source-slug>/entries/*.md.
     2. Spot-check that no GM-only campaign-specific content slipped in (lore is narrator-readable; pre-strip such content if found).
     3. Confirm the per-source descriptor in library/index.md is genre-level only.
     4. Commit when satisfied.
   ```

9. **Log a single line to the active session log if one was provided** (via Edit):

   ```
   - LIBRARIAN QUERY: intake-lore <source-slug> — <N> entries, content-shape: <shape>
   ```

## Query type: consult-library

> "consult-library for `<scope>`. Active session log: `<path-or-null>`."

The narrator provides a 1-6 word scope tag describing the current scene moment. You return scope-matching excerpts of public module content.

Procedure:

1. Call `mcp__dm-fs__list_dm_dir("modules")` via dm-fs MCP. If empty, return `[]` and log `- LIBRARIAN QUERY: consult-library for <scope> — 0 excerpts from 0 modules`.

2. For each module slug discovered, call `mcp__dm-fs__read_dm_file("modules/<slug>/overview.md")` and judge whether the module's themes / arc relate to the caller-supplied scope. Set aside modules with no plausible match.

3. For each surviving module, scan its content files in order of likely relevance:
   - **Node files** (`modules/<slug>/nodes/<node-slug>.md`): if the scope describes a location, scene, or encounter, read candidate node files (use `mcp__dm-fs__list_dm_dir("modules/<slug>/nodes")` to enumerate first) and match by node title / type / NPCs present.
   - **Hook file** (`modules/<slug>/hooks.md`): if the scope describes module entry or party recruitment.
   - **Connections file** (`modules/<slug>/connections.md`): if the scope describes movement between nodes or a conditional check.

4. For each matching content file, return `{module_slug, source_file, excerpt}` where `excerpt` is one or more contiguous `##` body sections from the source file (e.g., a full node's `## Description` + `## NPCs present` + `## Notable features`, or one `## Hook N: ...` block, or one or more bullet entries from `connections.md` under their parent `##` heading). Do not return frontmatter; do not return raw paragraph fragments outside their `##` parent. **Never include `secrets.md` content.** That requires `reveal-from-module`.

5. **Lean inclusive on ambiguity** — same rule as revelation: if uncertain whether a section is in scope, include it. The narrator filters when weaving.

6. Return the list (possibly empty) ordered by scope-match relevance.

7. Append a single line to the active session log via Edit:
   ```
   - LIBRARIAN QUERY: consult-library for <scope> — <K> excerpts from <M> modules
   ```

## Query type: reveal-from-module

> "reveal-from-module `<slug>` for `<reveal scope>`. Active session log: `<path>`."

The narrator provides the module slug and a reveal-scope phrase describing the in-fiction moment that earns the reveal. You return matching secret content with an explicit `[REVEAL]` tag.

The `[REVEAL]` tag in the response signals to the narrator that the content is GM-only reveal material — qualitatively distinct from `consult-library`'s untagged public excerpts. The narrator should weave revealed content into the next narrative beat (the moment that earned the reveal) and not pre-narrate it. The tag is not decorative; preserve it in any forwarded context (e.g., session-log notes).

Procedure:

1. Call `mcp__dm-fs__read_dm_file("modules/<slug>/secrets.md")`. If the file doesn't exist (or the slug is unknown), return `{error: "no such module or no secrets.md"}` and log `- LIBRARIAN QUERY: reveal-from-module <slug> for <reveal scope> — error: no such module`.

2. Match the reveal scope against secrets.md content sections (Twists & reveals, Hidden NPC identities & motives, Hidden locations / passages, DM-only context, Custom stat blocks). Use LLM judgment.

3. **Default to no match on ambiguity** — exact opposite of `consult-library`'s lean-inclusive rule. The narrator's reveal scope must unambiguously match a specific secret. If multiple secrets plausibly match, return `{reason: "scope matches multiple reveals; refine and re-query"}` and log the multi-match case.

4. If matched, return `{module_slug, reveal_section, excerpt, tag: "[REVEAL]"}`. If not matched at all, return `[]`.

5. Append session-log line:
   ```
   - LIBRARIAN QUERY: reveal-from-module <slug> for <reveal scope> — <found-or-none>
   ```

## Edge cases

- **Source path doesn't exist or isn't readable (intake).** Abort with an error before any writes. No partial mutation.
- **PDF is too large to read in one pass (intake).** Read in page-range chunks via Read's `pages` parameter; merge internal representation before classification. If still too large for your context budget, abort with `"source exceeds intake budget; pre-split into smaller modules"`.
- **Source doesn't appear module- or lore-shaped (intake-module step 2).** Route to `intake-lore` if entry-list; abort with explicit Phase 3d deferral message otherwise.
- **Slug collision (intake-module).** `dm/modules/<slug>/` already exists. Abort; user resolves manually.
- **Slug collision (intake-lore).** `library/lore/<slug>/` already exists. Abort; user resolves manually.
- **Partial intake state from prior failure (intake-module or intake-lore).** Source directory exists but is missing files. Abort with explicit error pointing at what's missing.
- **`library/index.md` already lists the slug** but the destination directory doesn't exist. Anomalous; abort.
- **Source has zero ambiguous content-kind classifications (intake-module).** Emit the secret-notes-section line "None — all content kinds were unambiguous." explicitly.
- **Source produces zero entries (intake-lore).** Abort with `"source produced no entries; check that the source is entry-list-shaped"`.
- **Source contains GM-only / "Secret" / "DM Only" markers (intake-lore).** Lore is narrator-readable by Phase 3c contract. Librarian flags in summary's content-shape notes; does NOT auto-quarantine. User pre-strips if needed.
- **Mixed-shape source (intake-lore).** Librarian uses LLM judgment to pick per-entry sectioning. Flags in summary.
- **Source overlaps existing campaign content** (intake-module) (e.g., names an NPC already in `world/home-base/npcs/`). Don't merge; flag in the summary's "Opportunities" list.
- **dm-fs MCP write fails mid-intake-module.** Surface the error; user cleans up partial state via shell.
- **Library write fails mid-intake-lore.** Surface the error; partial `library/lore/<slug>/` may exist. User reconciles via shell or via git restore.
- **`dm/modules/` is empty (consult-library).** Return `[]` and log. No error.
- **Caller supplies a malformed scope (consult-library or reveal-from-module).** Treat as best-effort. If empty, return `[]` with a session-log warning.
- **`dm/modules/<slug>/secrets.md` doesn't exist (reveal-from-module).** Error response per procedure step 1.
- **Reveal-from-module multi-match case.** Return refine-and-re-query reason; do not pick arbitrarily.

## What you don't do

- Don't author content you didn't read from the source — no invented hooks, NPCs, secrets, milestones, monster stats, or other entries.
- Don't write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Don't read `dm/` paths outside `dm/modules/` (no MCP reads against `factions/`, `revelations/`, `threads/`, `npcs/`).
- Don't include `secrets.md` content in a `consult-library` response. That content surfaces only via `reveal-from-module`.
- Don't return reveal content from `reveal-from-module` unless the scope unambiguously matches a single secret. Default to no-match on ambiguity.
- Don't mutate existing `dm/modules/<slug>/` or `library/lore/<source-slug>/` content on a re-intake — abort on slug collision.
- Don't commit. The user reviews and commits.
- Don't promote milestone candidates into a runtime milestone system — that's Phase 5.
- Don't auto-seed `dm/factions/`, `dm/revelations/`, or `dm/threads/` files. Flag opportunities in the intake summary instead.
- Don't auto-quarantine lore content to a dm-side path. Phase 3c lore is narrator-readable; if a source has GM-only campaign-specific content, flag in summary and let the user pre-strip.
- Don't use your `Edit` tool on `dm/` files — `Edit(dm/**)` is denied. All `dm/` mutations flow through `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file` via the dm-fs MCP.
END-FILE-CONTENT

- [ ] **Step 3: Verify the file matches the contract**

Read `.claude/agents/librarian.md` back and confirm:

- Frontmatter description mentions all four query types: `intake-module`, `intake-lore`, `consult-library`, `reveal-from-module`.
- `## Read access` and `## Write access` sections present. Write access has THREE bullets: `library/index.md` direct via Edit, `library/lore/<source-slug>/` direct via Write/Edit, `dm/modules/` via dm-fs MCP only.
- `## Your contract` opens with the dual positive statement covering both module and lore write paths.
- Four `## Query type:` sections present in order: `intake-module`, `intake-lore`, `consult-library`, `reveal-from-module`.
- `intake-module`'s step 2 now routes by content-shape (Module / Entry-list / Solo engine / methodology / pure narrative reference) rather than aborting on any non-module input.
- `## Edge cases` and `## What you don't do` sections present.

Run the positive-framing check (the Phase 3a discipline lesson):
```bash
grep -n "library/modules/<slug>" /Users/barriault/dnd/gygaxagain/.claude/agents/librarian.md
```
Expected: zero matches. Phase 3b's rewrite eliminated these; Phase 3c must not re-introduce them.

Run the new path check:
```bash
grep -cn "library/lore" /Users/barriault/dnd/gygaxagain/.claude/agents/librarian.md
```
Expected: at least 10 matches (frontmatter description, write access, contract, procedure step 5, step 6, step 7, intake summary, edge cases, what-you-don't-do).

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add .claude/agents/librarian.md
git commit -m "Rewrite librarian: add intake-lore query + content-type routing (Phase 3c)"
```

---

### Task 2: Seed the `library/lore/` skeleton

**Files:**
- Create: `library/lore/.gitkeep`

- [ ] **Step 1: Create the placeholder directory**

```bash
cd /Users/barriault/dnd/gygaxagain
mkdir -p library/lore
touch library/lore/.gitkeep
```

- [ ] **Step 2: Verify**

```bash
ls -la library/lore/
```

Expected: `.gitkeep` present (0 bytes), directory otherwise empty.

- [ ] **Step 3: Commit**

```bash
git add library/lore/.gitkeep
git commit -m "Seed library/lore/ skeleton (Phase 3c)"
```

---

### Task 3: Add CLAUDE.md `library/lore/` paragraph

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Locate the `## Library reference material` section**

```bash
grep -n "^## Library reference material\|^## What you must never do" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

The new paragraph belongs at the end of `## Library reference material`, immediately before `## What you must never do`.

- [ ] **Step 2: Insert the new paragraph**

Use Edit on `/Users/barriault/dnd/gygaxagain/CLAUDE.md`.

`old_string` is exactly:
```
## What you must never do
```

`new_string` is exactly:
```
`library/lore/<source-slug>/` contains narrator-readable lore content — world-fact reference material the party can plausibly encounter (monster stat blocks, spell descriptions, random tables, regional gazetteer entries). Unlike `library/modules/` (which stays empty by contract because module content is dm-quarantined), `library/lore/` IS populated and directly readable. Read `library/index.md` to see which lore sources are ingested, then read `library/lore/<source-slug>/index.md` for per-source entry triage, then read specific `library/lore/<source-slug>/entries/<entry-slug>.md` files as needed for the scene. The librarian owns intake for both modules and lore via `/intake`; runtime access to lore uses your direct Read/Glob (no librarian query needed in Phase 3c).

## What you must never do
```

This inserts a new paragraph (with a blank line above it via the trailing `\n\n## What you must never do`) before the `## What you must never do` heading.

- [ ] **Step 3: Verify**

```bash
grep -B 1 -A 1 "library/lore/<source-slug>/" /Users/barriault/dnd/gygaxagain/CLAUDE.md | head -10
```

Confirm the new paragraph reads correctly. Then re-check the section ordering:
```bash
grep -n "^## " /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

Expected: section ordering unchanged, the `## Library reference material` section now contains the new paragraph as its last content before `## What you must never do`.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Add library/lore/ paragraph to CLAUDE.md Library reference material (Phase 3c)"
```

---

### Task 4: Restart prerequisite checkpoint

**Files:**
- No file changes in this task. Procedural setup.

- [ ] **Step 1: Confirm working tree clean on phase-3c branch**

If not already on a feature branch:
```bash
cd /Users/barriault/dnd/gygaxagain
git checkout -b phase-3c
```

Verify:
```bash
git status
git log --oneline -5
```

Expected: clean working tree, branch `phase-3c` (or main) at tip including Tasks 1-3 commits.

- [ ] **Step 2: Restart prerequisite for smoke test**

The librarian's frontmatter and prompt are loaded into the Agent tool's registry at session start. After Task 1's rewrite, the running session still has the Phase 3b v3 librarian prompt cached. **For the smoke test in Task 6 to invoke the v4 librarian (with `intake-lore` available), the user must restart Claude Code.**

This is the same constraint Phase 3a/3b hit. Document this in the implementation log; signal to the user (or to the executing subagent's controller) that a restart is required before proceeding to Task 5 / Task 6.

No commit for this task — it's a procedural checkpoint.

---

### Task 5: Create the synthetic bestiary fixture

**Files:**
- Create: `references/test-bestiary.md`

This fixture is the smoke-test source AND a permanent reference for future Phase 3d testing (e.g., `consult-lore` validation).

- [ ] **Step 1: Author the synthetic bestiary**

Create `/Users/barriault/dnd/gygaxagain/references/test-bestiary.md` with the following exact content:

```markdown
# Test Bestiary (Phase 3c smoke-test fixture)

A 6-entry synthetic bestiary covering low-CR monsters across multiple categories. Created as a permanent test reference for lore-intake validation.

---

## Goblin

**Category:** humanoid
**Source citation:** Test Bestiary, entry 1

Small, scrappy, green-skinned raiders that haunt the edges of civilization. Goblins prefer ambush tactics from cover, retreating when outmatched.

### Stat block

- AC 15 (leather armor, shield) | HP 7 (2d6) | Speed 30 ft.
- STR 8 (-1) | DEX 14 (+2) | CON 10 (+0) | INT 10 (+0) | WIS 8 (-1) | CHA 8 (-1)
- Skills: Stealth +6
- Senses: Darkvision 60 ft., passive Perception 9
- Languages: Common, Goblin
- CR 1/4 (50 XP)
- Nimble Escape: The goblin can take the Disengage or Hide action as a bonus action.
- Scimitar: +4 to hit, reach 5 ft., 5 (1d6 + 2) slashing.
- Shortbow: +4 to hit, range 80/320 ft., 5 (1d6 + 2) piercing.

### Tactics

Goblins fight from cover, using Nimble Escape to relocate after each attack. They withdraw when reduced below half HP unless commanded by a leader. Often encountered in groups of 4-8.

### Ecology / lore

Goblins live in caves, ruins, or thick forests. They're scavengers and raiders, generally avoiding direct conflict with stronger foes. Tribes are led by hobgoblin or bugbear commanders.

---

## Kobold

**Category:** humanoid (dragon-blooded)
**Source citation:** Test Bestiary, entry 2

Small reptilian humanoids with draconic ancestry. Kobolds rely on traps, swarm tactics, and pack hunting to compensate for individual weakness.

### Stat block

- AC 12 | HP 5 (2d6 - 2) | Speed 30 ft.
- STR 7 (-2) | DEX 15 (+2) | CON 9 (-1) | INT 8 (-1) | WIS 7 (-2) | CHA 8 (-1)
- Senses: Darkvision 60 ft., passive Perception 8
- Languages: Common, Draconic
- CR 1/8 (25 XP)
- Sunlight Sensitivity: Disadvantage on attack rolls and Perception checks in sunlight.
- Pack Tactics: Advantage on attack rolls against a creature if at least one ally is within 5 ft. of it.
- Dagger: +4 to hit, reach 5 ft., 4 (1d4 + 2) piercing.
- Sling: +4 to hit, range 30/120 ft., 4 (1d4 + 2) bludgeoning.

### Tactics

Kobolds set elaborate traps and fight in groups to exploit Pack Tactics. They prefer subterranean tunnels where Sunlight Sensitivity isn't a factor. Frequently encountered as servants of dragons.

### Ecology / lore

Kobolds revere dragons and often inhabit caves near a dragon's lair. They're prolific trap-makers and miners. Tribes are matriarchal, led by an elder priestess or shaman.

---

## Zombie

**Category:** undead
**Source citation:** Test Bestiary, entry 3

Animated corpses driven by necromantic magic. Zombies are slow, single-minded, and surprisingly durable.

### Stat block

- AC 8 | HP 22 (3d8 + 9) | Speed 20 ft.
- STR 13 (+1) | DEX 6 (-2) | CON 16 (+3) | INT 3 (-4) | WIS 6 (-2) | CHA 5 (-3)
- Saving Throws: WIS +0
- Damage Immunities: Poison
- Condition Immunities: Poisoned
- Senses: Darkvision 60 ft., passive Perception 8
- Languages: Understands the languages it knew in life but can't speak
- CR 1/4 (50 XP)
- Undead Fortitude: If reduced to 0 HP by damage other than radiant or critical hit, roll a Constitution save (DC 5 + damage taken). On success, drop to 1 HP instead.
- Slam: +3 to hit, reach 5 ft., 4 (1d6 + 1) bludgeoning.

### Tactics

Zombies attack the nearest living creature and pursue relentlessly. They lack tactics beyond closing to melee. Undead Fortitude makes them surprisingly persistent — burn or radiant damage to finish reliably.

### Ecology / lore

Created by necromantic magic from corpses. Often found in graveyards, dungeons, or wherever a necromancer has been at work. Mindless; cannot be reasoned with.

---

## Wolf

**Category:** beast
**Source citation:** Test Bestiary, entry 4

Pack-hunting predators. Wolves are common in temperate forests and tundra regions.

### Stat block

- AC 13 (natural armor) | HP 11 (2d8 + 2) | Speed 40 ft.
- STR 12 (+1) | DEX 15 (+2) | CON 12 (+1) | INT 3 (-4) | WIS 12 (+1) | CHA 6 (-2)
- Skills: Perception +3, Stealth +4
- Senses: Passive Perception 13
- Languages: —
- CR 1/4 (50 XP)
- Keen Hearing and Smell: Advantage on Wisdom (Perception) checks relying on hearing or smell.
- Pack Tactics: Advantage on attack rolls against a creature if at least one ally is within 5 ft.
- Bite: +4 to hit, reach 5 ft., 7 (2d4 + 2) piercing. On hit, target makes a DC 11 Strength save or is knocked prone.

### Tactics

Wolves hunt in packs of 3-8, surrounding prey and using Pack Tactics. They target the weakest-looking creature first and try to knock it prone with their bite. Withdraw if pack is broken.

### Ecology / lore

Apex predators in temperate forests. Pack-bonded, intelligent for animals. Sometimes domesticated; goblin and orc tribes often keep wolves as mounts or guards.

---

## Brown Bear

**Category:** beast
**Source citation:** Test Bestiary, entry 5

Large, solitary omnivores. Brown bears defend territory and cubs ferociously.

### Stat block

- AC 11 (natural armor) | HP 34 (4d10 + 12) | Speed 40 ft., climb 30 ft.
- STR 19 (+4) | DEX 10 (+0) | CON 16 (+3) | INT 2 (-4) | WIS 13 (+1) | CHA 7 (-2)
- Skills: Perception +3
- Senses: Passive Perception 13
- Languages: —
- CR 1 (200 XP)
- Keen Smell: Advantage on Wisdom (Perception) checks relying on smell.
- Multiattack: Two attacks (one bite, one claws).
- Bite: +6 to hit, reach 5 ft., 8 (1d8 + 4) piercing.
- Claws: +6 to hit, reach 5 ft., 11 (2d6 + 4) slashing.

### Tactics

Brown bears charge and use Multiattack to maximize damage. They retreat only if severely wounded or if their cubs are no longer threatened. Encountered alone or as a mother with 1-2 cubs.

### Ecology / lore

Found in temperate and subarctic forests and mountains. Omnivorous; eat berries, fish, small mammals, carrion. Hibernate in winter.

---

## Animated Armor

**Category:** construct
**Source citation:** Test Bestiary, entry 6

A suit of armor brought to mock-life by enchantment. Animated armors guard tombs, vaults, and wizards' workshops.

### Stat block

- AC 18 (natural armor) | HP 33 (6d8 + 6) | Speed 25 ft.
- STR 14 (+2) | DEX 11 (+0) | CON 13 (+1) | INT 1 (-5) | WIS 3 (-4) | CHA 1 (-5)
- Damage Immunities: Poison, Psychic
- Condition Immunities: Blinded, Charmed, Deafened, Exhaustion, Frightened, Paralyzed, Petrified, Poisoned
- Senses: Blindsight 60 ft. (blind beyond this), passive Perception 6
- Languages: —
- CR 1 (200 XP)
- Antimagic Susceptibility: Incapacitated while in an antimagic field. If targeted by dispel magic, must succeed on a Constitution save against the caster's DC or fall unconscious for 1 minute.
- False Appearance: While motionless, indistinguishable from a normal suit of armor.
- Multiattack: Two slam attacks.
- Slam: +4 to hit, reach 5 ft., 5 (1d6 + 2) bludgeoning.

### Tactics

Animated armors are stationary guards until triggered (by approach, by touching a warded object, or by a specific phrase). Once active, they attack relentlessly until destroyed or the threat leaves. They don't pursue beyond their warded area.

### Ecology / lore

Created by transmutation magic, typically as a guardian construct. Often placed in pairs flanking doorways. Lasts until destroyed or dispelled.
```

- [ ] **Step 2: Verify the fixture**

```bash
wc -l /Users/barriault/dnd/gygaxagain/references/test-bestiary.md
```
Expected: around 130-150 lines.

```bash
grep -c "^## " /Users/barriault/dnd/gygaxagain/references/test-bestiary.md
```
Expected: 6 (one per monster entry).

- [ ] **Step 3: Commit the fixture**

```bash
cd /Users/barriault/dnd/gygaxagain
git add references/test-bestiary.md
git commit -m "Add synthetic 6-entry bestiary fixture for Phase 3c smoke testing"
```

---

### Task 6: Smoke test — intake the synthetic bestiary

**Files:**
- No new file changes by the implementer — the librarian writes them.

**Prerequisite:** the user has restarted Claude Code after Tasks 1-5 committed, so the v4 librarian prompt is loaded.

- [ ] **Step 1: Verify pre-conditions**

```bash
cd /Users/barriault/dnd/gygaxagain
ls -la library/lore/
ls -la references/test-bestiary.md
git status
```

Expected:
- `library/lore/` contains only `.gitkeep`.
- `references/test-bestiary.md` exists.
- Working tree clean (no uncommitted changes).

- [ ] **Step 2: Run /intake on the synthetic bestiary**

In the active Claude Code session (post-restart), invoke:

```
/intake references/test-bestiary.md
```

The main agent dispatches the librarian. The librarian's `intake-module` step 2 detects the source as entry-list-shaped (bestiary) and dispatches `intake-lore`. The librarian decomposes 6 entries, writes them to `library/lore/test-bestiary/entries/`, builds `library/lore/test-bestiary/index.md`, updates `library/index.md`, and returns the structured summary.

- [ ] **Step 3: Verify the artifacts**

```bash
ls -la library/lore/test-bestiary/
ls library/lore/test-bestiary/entries/
cat library/lore/test-bestiary/index.md
```

Expected:
- `library/lore/test-bestiary/index.md` exists with frontmatter (slug, name, source, ingested, content-shape: bestiary, entry-count: 6) and a body with `## Summary` + `## Entries` (6 bullets).
- `library/lore/test-bestiary/entries/` contains 6 files: `goblin.md`, `kobold.md`, `zombie.md`, `wolf.md`, `brown-bear.md`, `animated-armor.md` (slugs lowercase-hyphenated).
- Each entry file has frontmatter (slug, name, parent-source: test-bestiary, category, source-citation) + body sections (`## Description`, `## Stat block`, `## Tactics`, `## Ecology / lore`).

```bash
cat library/index.md
```

Expected: a new line under `## Lore references` matching:
```
- **test-bestiary** — <one-line genre/theme descriptor like "low-CR monsters across categories">. Source: `references/test-bestiary.md`. Ingested: 2026-05-11. Entries: 6.
```

- [ ] **Step 4: Verify narrator-readable assertion**

```bash
cat library/lore/test-bestiary/entries/goblin.md
```

Expected: file content displays directly. **No permission denial.** This is the positive confirmation of Phase 3c's narrator-readable design.

```bash
cat library/lore/test-bestiary/index.md
```

Expected: file content displays directly. No denial.

- [ ] **Step 5: Spot-check entry content**

Read one entry's stat block to confirm fidelity to the source fixture:

```bash
grep -A 5 "Stat block" library/lore/test-bestiary/entries/goblin.md
```

Expected: AC 15, HP 7 (2d6), Speed 30 ft., etc. — matches the fixture's goblin entry.

- [ ] **Step 6: Commit the smoke-test artifacts**

```bash
cd /Users/barriault/dnd/gygaxagain
git add library/index.md library/lore/test-bestiary/
git commit -m "Phase 3c smoke test: intake of test-bestiary (6 entries)"
```

---

### Task 7: Asymmetry audit + regression test run

**Files:**
- No file changes in this task. Audit only.

- [ ] **Step 1: Run the existing test suite**

```bash
cd /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q
```

Expected: `37 passed`.

- [ ] **Step 2: Phase 3c positive asymmetry test (lore IS narrator-readable)**

```bash
cat /Users/barriault/dnd/gygaxagain/library/lore/test-bestiary/entries/goblin.md | head -3
```

Expected: file content displays (frontmatter visible). No permission denial.

```bash
cat /Users/barriault/dnd/gygaxagain/library/lore/test-bestiary/index.md | head -3
```

Expected: file content displays. No denial.

- [ ] **Step 3: Phase 3a/3b boundary still holds (negative asymmetry test)**

```bash
cat /Users/barriault/dnd/gygaxagain/dm/modules/ancient-tomb-of-phandalin/secrets.md 2>&1 | head -1
```

Expected: denied (permission error). Confirms the new lore tier doesn't weaken Phase 3a/3b's dm-quarantine.

- [ ] **Step 4: Verify librarian wrote via direct Write (not dm-fs MCP)**

Check the dm-fs access log for any Phase 3c-time entries — there should be NONE for the bestiary intake, since lore writes go through direct Write, not dm-fs MCP.

```bash
grep "test-bestiary" /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log
```

Expected: empty output. Confirms lore writes did not route through the dm-fs MCP.

- [ ] **Step 5: Verify `library/modules/` stays empty**

```bash
ls /Users/barriault/dnd/gygaxagain/library/modules/
```

Expected: only `.gitkeep`. The intake-lore rewrite must not have written anything to `library/modules/` (which is the Phase 3a/3b empty-by-contract directory).

- [ ] **Step 6: No commit needed for this task**

This task is verification only. Nothing changes in the working tree.

---

### Task 8: Update CLAUDE.md `## Current phase scope` to Phase 3c

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Locate the current phase scope section**

```bash
grep -n "Current phase scope" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

The section currently reflects Phase 3b. The Phase 3c update replaces the whole long paragraph.

- [ ] **Step 2: Update the section**

Use Edit on `/Users/barriault/dnd/gygaxagain/CLAUDE.md`. Replace:

> The engine is being built incrementally. As of Phase 3b, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), module intake via `/intake` + the librarian subagent with all module content dm-quarantined (Phase 3a), and runtime librarian queries `consult-library` (scope-matched public excerpts) and `reveal-from-module` (explicit reveal access when the party has earned it) per rule 9 (Phase 3b). The Phase 2 hidden-state arc is closed; Phase 3a/3b together make module ingest and runtime consultation work end-to-end. You **do not** yet have: solo-engine/methodology/lore intake (Phase 3c), URL ingestion (Phase 3c), auto-proposals for `dm/factions/`/`dm/revelations/`/`dm/threads/` from module content (Phase 3c or 4), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or a full bookkeeper. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.

with:

> The engine is being built incrementally. As of Phase 3c, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), module intake via `/intake` + the librarian subagent with all module content dm-quarantined (Phase 3a), runtime librarian queries `consult-library` (scope-matched public excerpts) and `reveal-from-module` (explicit reveal access when the party has earned it) per rule 9 (Phase 3b), and lore-reference intake via the librarian's new `intake-lore` query — bestiary-shaped entries land in `library/lore/<source-slug>/` and are narrator-readable directly (Phase 3c). The Phase 2 hidden-state arc is closed; Phase 3a/3b/3c together make module ingest, runtime module consultation, and lore-reference intake work end-to-end. You **do not** yet have: solo-engine/methodology/gazetteer-essay intake (Phase 3d), URL ingestion (Phase 3d), auto-proposals for `dm/factions/`/`dm/revelations/`/`dm/threads/` from module content (Phase 3d or 4), curated `consult-lore` runtime query (Phase 3d if needed), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or a full bookkeeper. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.

- [ ] **Step 3: Verify**

```bash
grep -A 2 "Current phase scope" /Users/barriault/dnd/gygaxagain/CLAUDE.md | head -5
```

Confirm the new text starts with "As of Phase 3c".

- [ ] **Step 4: Commit**

```bash
cd /Users/barriault/dnd/gygaxagain
git add CLAUDE.md
git commit -m "Update CLAUDE.md current-phase-scope to Phase 3c"
```

---

### Task 9: Final integration sanity check + merge

**Goal:** Confirm Phase 3c invariants and merge phase-3c → main.

- [ ] **Step 1: Inspect git history**

```bash
cd /Users/barriault/dnd/gygaxagain
git log --oneline -10
```

Expected commits (most recent first), in this order:
1. Update CLAUDE.md current-phase-scope to Phase 3c
2. Phase 3c smoke test: intake of test-bestiary (6 entries)
3. Add synthetic 6-entry bestiary fixture for Phase 3c smoke testing
4. Add library/lore/ paragraph to CLAUDE.md Library reference material (Phase 3c)
5. Seed library/lore/ skeleton (Phase 3c)
6. Rewrite librarian: add intake-lore query + content-type routing (Phase 3c)
7. (Earlier:) Add Phase 3c implementation plan
8. (Earlier:) Add Phase 3c design: lore-reference intake

- [ ] **Step 2: Inspect working tree**

```bash
git status
```

Expected: clean working tree.

- [ ] **Step 3: Phase 3c definition-of-done checklist**

Cross-check against the spec's `## Definition of done`:

- [ ] New `intake-lore` query type on the librarian, with full procedure (pre-flight, content-shape, slug-collision, decompose, write entries, build index, update top-level index, emit summary, log).
- [ ] `intake-module`'s step 2 rewritten to route entry-list sources to `intake-lore` instead of aborting.
- [ ] `library/lore/.gitkeep` placeholder present.
- [ ] Smoke test produced `library/lore/test-bestiary/index.md` + 6 entry files under `library/lore/test-bestiary/entries/`.
- [ ] `library/index.md` `## Lore references` section lists `test-bestiary` with the prescribed format.
- [ ] Narrator-readable assertion held: `cat library/lore/test-bestiary/entries/goblin.md` succeeds.
- [ ] Phase 3a/3b boundary still holds: `cat dm/modules/ancient-tomb-of-phandalin/secrets.md` denied.
- [ ] dm-fs access log shows no entries for `test-bestiary` (lore writes went through direct Write, not MCP).
- [ ] `library/modules/` still contains only `.gitkeep` (no contamination from intake-lore).
- [ ] All 87 existing tests pass; no Python code added.
- [ ] CLAUDE.md has the new `library/lore/` paragraph + updated current-phase-scope.

- [ ] **Step 4: Merge phase-3c → main** (if working on a feature branch)

```bash
cd /Users/barriault/dnd/gygaxagain
git checkout main
git merge --no-ff phase-3c -m "Merge phase-3c: lore-reference intake (intake-lore query + library/lore/ structure)"
git branch -d phase-3c
git log --oneline -5
```

---

## Notes for executors

- **Session restart required between Task 1 and Task 6.** The librarian's prompt is loaded at session start. After Task 1's rewrite, the running session still has the Phase 3b v3 prompt cached. Tasks 2, 3, 4, 5 can run in the same session; Task 6 (smoke test) requires the user to restart Claude Code so the v4 librarian prompt loads.

- **No dm-fs MCP involvement for lore.** Phase 3c's lore writes go through the librarian's direct `Write` tool to `library/lore/`. The dm-fs MCP is unchanged (still used by `intake-module` for `dm/modules/` writes and by `consult-library`/`reveal-from-module` for reads).

- **The synthetic bestiary fixture is COMMITTED.** Unlike Phase 3a's discarded synthetic module fixture, the Phase 3c bestiary is a permanent test reference. Future Phase 3d work (e.g., `consult-lore` validation) will use this fixture.

- **Asymmetry audit is "lighter" than Phase 3a/3b.** Phase 3c's load-bearing claim is that lore IS narrator-readable (the opposite of 3a/3b's dm-quarantine). The audit confirms by positive test (`cat` succeeds) rather than negative test (`cat` denied).

- **The intake-lore prompt uses positive framing.** No "never write to X" framing for paths the librarian shouldn't write to. The contract is stated positively: "All lore content writes go to `library/lore/<source-slug>/` via direct Write."
