# Phase 3a — Source Ingestion: Modules Design

**Status:** Revised after smoke-test review identified an asymmetry gap. Locked.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Phase 2b spec:** `docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md`.
**Phase 2c spec:** `docs/superpowers/specs/2026-05-10-phase-2c-mythic-threads-design.md`.
**Phase 2d spec:** `docs/superpowers/specs/2026-05-10-phase-2d-mythic-event-spotlight-design.md`.
**Slice of original Phase 3:** module **intake** only. **Runnability** (narrator access to ingested module content during play) is deferred to Phase 3b, which adds the `consult-library` runtime query.

## Revision note (mid-implementation pivot)

The first draft of this spec adopted a "twist-protected" classification model: the librarian extracted GM-only twists/villain identities to `dm/modules/<slug>/secrets.md` and wrote the rest of the module (overview, nodes, hooks, connections) to `library/modules/<slug>/` for direct narrator reading. A first smoke-test intake (The Ancient Tomb of Phandalin) revealed the gap: a module's "non-twist" content — dungeon layout, encounter contents, trap locations, room descriptions, treasure placement — is *future-scene state from the party's POV*. Putting it in narrator-readable territory required relying on **narrator discipline** ("only consult the current node") to prevent leakage of future scenes into present narration. That's behavioral, not structural — exactly the property Phase 2 explicitly avoided.

This revision corrects to a **structural-asymmetry** model: module content lives **entirely** under `dm/modules/<slug>/`. The narrator has no path to read module content during play in Phase 3a. The only library-side artifact is `library/index.md`'s enumeration entry (slug → source path → ingest date), used to know a module exists *by name*. The narrator gains access to specific module content through Phase 3b's `consult-library` runtime query, which scopes responses to the current scene's relevant excerpt.

## Purpose

Phase 2 closed the hidden-state arc — factions, revelations, threads, and Mythic-event spotlight all operate against `dm/` content the assistant hand-authored at implementation time. Phase 3a displaces that pattern for module material: external sources (One-Page One-Shots, hardcover adventure nodes, etc.) flow into the engine through `/intake`, decomposed into Alexander-style nodes, and committed entirely under `dm/modules/<slug>/`. The librarian writes; the narrator does not read.

Phase 3a's load-bearing claim is that **module content is structurally invisible to the narrator after intake**, by virtue of living wholly under `dm/` (denied at the project level for the narrator's direct tools, accessible only to subagents with the dm-fs MCP wired in). The user reviews the intake artifacts via their own shell/editor (outside Claude Code) and commits when satisfied — the commit-gate is the mandatory review checkpoint before the module enters the campaign's hidden-state set.

## Definition of done

A successful Phase 3a build demonstrates all of:

- `library/` directory established with `library/index.md` (the only narrator-readable artifact related to ingested modules) and a `library/modules/` placeholder directory that **remains empty under the Phase 3a contract**. The librarian never writes module content under `library/modules/`.
- New `librarian` subagent at `.claude/agents/librarian.md` with read access to `library/`, `world/`, `party/`, `sessions/`, `references/` (direct), plus `dm/modules/` (via dm-fs MCP); write access to `library/index.md` (direct, the only library/ write) and `dm/modules/` (via dm-fs MCP). No access to other `dm/` paths.
- New `/intake <path>` slash command at `.claude/commands/intake.md` that dispatches the librarian and surfaces its intake summary verbatim.
- Single query type on the librarian: `intake-module`. Procedure decomposes the source into Alexander-nodes, classifies each chunk by *content kind* (overview / hook / node-description / connection / secret-reveal / milestone-candidate), writes **all** module content to `dm/modules/<slug>/` via dm-fs MCP, updates `library/index.md` with the module's enumeration entry, and emits a structured intake summary.
- Module ingestion produces (all under `dm/modules/<slug>/`, all written via the dm-fs MCP):
  - `overview.md` (summary, themes, level range, recommended hook framings — the librarian's narrator-perspective summary of the module's arc)
  - `nodes/<node-slug>.md` per Alexander-node (location/scene/encounter — full content, including NPCs present, notable features, encounter mechanics, treasure)
  - `hooks.md` (adventure hooks framed from the module's perspective — what brings the party in)
  - `connections.md` (default + Alexander-style conditional connections; all conditions and clue dependencies)
  - `secrets.md` (twists, hidden NPC identities & motives, hidden locations, GM-only context — content the librarian flagged as "would deflate the beat if revealed mid-scene")
  - `milestone-candidates.md` (proposed milestones for Phase 5 to promote)
- `library/index.md` is updated with one entry per ingested module: `- **<slug>** — <one-line public-facing description>. Source: \`<reference path>\`. Ingested: <YYYY-MM-DD>.` The description is the *minimum public signal* — it names the genre/theme (e.g., "undead dungeon crawl outside Phandalin") but does **not** describe what happens in any specific node or reveal the dungeon's contents. The narrator may learn from this entry that a module *exists by name*; nothing more.
- The librarian's intake summary enumerates files created (all under `dm/modules/<slug>/`), the breakdown by content kind, milestone candidates, secret-content notes flagged for human verification, and any opportunities for later phases (e.g., a faction archetype noticed in the source).
- Smoke test: ingest one module end-to-end (a One-Page One-Shot or the previously-attempted Phandalin source). Asymmetry audit confirms the narrator (main agent) cannot read any file under `dm/modules/<slug>/`; only the librarian (with dm-fs MCP) can. `library/modules/<slug>/` does not exist after intake — only `library/index.md` is modified on the library side.
- All 87 existing tests continue to pass; no Python code is added in this phase.
- The dm-fs MCP is wired into a fourth subagent (librarian) — no MCP tool changes; existing read/list/write/create/append cover all 3a operations.
- `CLAUDE.md` is updated:
  - The Phase 3a-original "library/ may contain ingested module material" informational line is replaced with a corrected subsection that explicitly states module content is dm-quarantined and unreadable to the narrator until Phase 3b's runtime query.
  - One new must-never bullet: "Never attempt to read or grep `library/modules/<slug>/` for ingested module content — that path is intentionally empty; module content lives under `dm/modules/<slug>/`, which is denied to you. Runtime access to module content ships in Phase 3b."

## Out of scope (deferred to Phase 3b or later)

- **Module runnability during play.** Phase 3a ingests but does not play. The narrator has no path to read ingested module content. Phase 3b's `consult-library` runtime query unblocks runnability — it accepts a scene scope from the narrator and returns just the relevant excerpt (e.g., the current node's `nodes/<slug>.md` content, scoped). Until 3b ships, an ingested module sits in `dm/modules/` available for review but not for live narration.
- **Solo-engine intake.** Mythic GME 2e and similar feed via the existing mythic CLI from Phase 1; structured library extraction is Phase 3b.
- **Methodology intake.** Justin Alexander's GM book and similar — Phase 3b.
- **Lore reference intake.** Random tables, monster manuals, regional gazetteers — Phase 3b. (Lore references may legitimately be narrator-readable since they describe *world* facts the party can plausibly know, not future scenes. Phase 3b will design lore-reference shape distinct from modules.)
- **URL ingestion.** Phase 3b. Path-only for 3a.
- **Multi-file / megabundle modules** (full hardcover adventures). Phase 3b+. One-Page One-Shots and small standalone dungeons are single-file tractable.
- **Automatic milestone persistence to `dm/milestones/`.** Phase 5. 3a produces proposals only at `dm/modules/<slug>/milestone-candidates.md`.
- **Auto-seeding `dm/factions/`, `dm/revelations/`, `dm/threads/` from module material.** Phase 3b or Phase 4. The librarian flags opportunities in the intake summary; the user decides.
- **Bookkeeper verification of intake decisions** (Phase 4).
- **`rename_dm_file` op on the dm-fs MCP.** Commit-gate is the 3a review mechanism; staging-directory promotion is deferred unless 3b workflows require it.
- **`/intake` invoked mid-session.** Discipline expectation: intake happens between sessions. The librarian's intake summary warns against running `/session-start` between `/intake` and commit. Phase 3a does not block this technically; document the discipline.
- **`--force` flag for re-ingesting an existing slug.** Phase 3b if it's a real workflow need. 3a aborts on slug collision; user resolves manually.

## Architecture

### Slice mapping

| Component                          | Phase 3a touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | One revised `## Library reference material` subsection in `CLAUDE.md` (replaces the original Phase 3a informational line; new content says module content is dm-quarantined). One new must-never bullet. |
| World-state subagent               | Untouched.                                                                       |
| Revelation subagent                | Untouched.                                                                       |
| Mythic subagent                    | Untouched.                                                                       |
| Dice subagent                      | Untouched.                                                                       |
| **Librarian subagent**             | **NEW** — `.claude/agents/librarian.md`. Writes all module content to `dm/modules/<slug>/` via dm-fs MCP; updates `library/index.md` directly. |
| `dm-fs` MCP                        | No tool changes. Wired into a fourth subagent (librarian) via the agent's frontmatter `mcpServers: [dm-fs]`. The `.mcp.json` already registers the server project-wide. |
| `.claude/settings.json`            | No deny-rule changes. Narrator's `dm/**` denies stay in place — that's the structural enforcement of the asymmetry boundary. |
| `/intake` command                  | **NEW** — `.claude/commands/intake.md`. Thin dispatcher to the librarian subagent. |
| Other slash commands               | Untouched.                                                                       |
| Repository layout                  | NEW: `library/`, `library/modules/` (empty, .gitkeep), `library/index.md` (initially empty Modules section, populated by intake). NEW: `dm/modules/` (created at first intake; not seeded). |

### Information-asymmetry preservation — load-bearing claim

The Phase 1/2 boundary holds *structurally*, not behaviorally. Phase 3a's claim:

- **`dm/**` is denied to the narrator's direct tools** (`Read`, `Write`, `Edit`, `Glob`, `Grep`, plus the inspection-style Bash commands `cat`, `grep`, `head`, `tail`, `find`, `less`, `more`, `rg`). This is enforced by `.claude/settings.json` and is the same enforcement Phase 2 relied on.
- **The librarian's writes to `dm/modules/` flow through the dm-fs MCP**, which only subagents with `mcpServers: [dm-fs]` in their frontmatter can use. The narrator has no MCP; the librarian is the only Phase 3a-relevant tenant.
- **The library-side artifact `library/index.md` deliberately carries no module content** — only an enumeration entry per module (slug, one-line genre-level descriptor, source path, ingest date). The narrator reading `library/index.md` learns that a module *exists by name and source*; it does not learn what happens in any room, encounter, or NPC interaction.
- **`library/modules/<slug>/` does not exist as a populated directory under Phase 3a.** It stays as `library/modules/.gitkeep` only. If the narrator attempts to `Glob` or `Read` content under `library/modules/<slug>/`, they will find nothing — the intentional absence is the discipline gap-closer.

The narrator-vs-librarian asymmetry is thus *symmetric to* world-state vs. dm/factions in Phase 2a, revelation vs. dm/revelations in Phase 2b, and mythic vs. dm/threads in Phase 2c: the subagent writes via MCP, the narrator reads nothing directly. Module content is the next tenant of the same pattern, not an exception to it.

The dm-fs access log captures every librarian write to `dm/modules/`, so the smoke-test asymmetry audit extends naturally — grep the access log for librarian-issued writes to `modules/<slug>/` and confirm no main-agent-issued reads anywhere under `dm/`.

### Integration with prior phases

- **Phase 1 (dice & mythic CLIs, world-state subagent, dm-fs MCP reads/writes):** unchanged. The librarian uses the existing dm-fs MCP tools that Phase 2a established.
- **Phase 2a (factions):** unchanged. If the librarian recognizes a faction-like entity in module content (e.g., a cult or a smuggling ring), it flags it in the intake summary's "Opportunities" list rather than auto-creating a `dm/factions/` entry. Faction file authoring stays at-implementation-time discipline until Phase 4 changes that.
- **Phase 2b (revelations):** unchanged. Same flagging discipline — the librarian may note "this module's hidden priest reveal would naturally seed a revelation," but does not autonomously write `dm/revelations/<id>.md`. The Phase 2b clue-level filter fix (landed 2026-05-10) is irrelevant to intake.
- **Phase 2c (threads):** unchanged. Newly-ingested modules do not auto-add threads.
- **Phase 2d (Mythic-event spotlight):** unchanged. The thread spotlight reads `dm/threads/active.md`; module intake does not write there.

## Component designs

### File schemas

#### `library/index.md`

Top-level index. The **only** library-side artifact that names ingested modules.

```markdown
---
last-updated: <YYYY-MM-DD>
---

# Library Index

## Modules

<!-- One line per ingested module. Entries are enumeration only — the
     full content of each module lives at dm/modules/<slug>/, denied to
     the narrator. The line below names the module and points at the
     source; it does NOT describe scenes, encounters, twists, or content
     beyond a single-clause genre/theme descriptor. -->

- **<slug>** — <one-line genre/theme descriptor>. Source: `<reference path>`. Ingested: <YYYY-MM-DD>.
- ...

## Solo engines

<!-- Phase 3b -->

## Methodology

<!-- Phase 3b -->

## Lore references

<!-- Phase 3b -->
```

Schema notes:

- Module entries are alphabetical by slug. The librarian re-sorts on each intake.
- The descriptor is a single short clause (e.g., "undead dungeon crawl", "smuggling investigation", "haunted-manor mystery"). It identifies what kind of module exists; it does not pre-reveal arc or content.
- Source and ingest date are bookkeeping, useful for de-duplication and freshness checks at Phase 3b+ time.

#### `dm/modules/<slug>/overview.md`

The librarian's narrator-perspective summary of the module's arc. **Lives under `dm/`; not narrator-readable.**

```markdown
---
slug: <slug>
title: <Module Title>
source: references/<file>
ingested: <YYYY-MM-DD>
level-range: <e.g., "1-3">
themes: [<comma-separated tags>]
faction-archetypes: [<e.g., "cult", "smugglers">]
node-count: <N>
---

# <Module Title>

## Summary

<1-paragraph narrator-perspective summary of the module's premise, arc, and resolution. Includes the major beats — what kicks it off, what the party encounters, where it ends. Written for the librarian's runtime callers (Phase 3b consumers); not for player consumption.>

## Recommended hooks

<1-3 sentences on how the module is most naturally entered. Detailed hook framings live in hooks.md.>

## Setting & tone

<Short description of feel, environment, NPC vibe.>
```

#### `dm/modules/<slug>/nodes/<node-slug>.md`

One per Alexander-node — location, scene, or encounter. **Lives under `dm/`; not narrator-readable.**

```markdown
---
slug: <node-slug>
type: location | scene | encounter
parent-module: <module-slug>
---

# <Node Title>

## Description

<What a party encounters when they reach this node. Includes everything the narrator needs to run the node: physical description, ambient sensory detail, any boxed-text-equivalent prose.>

## NPCs present

- <name> — <one-line description including role and any immediate behavior>
- ...

## Notable features

- <interactable element, with the librarian's note about what investigation reveals>
- <clue or evidence>
- <trap, with DC and trigger>
- ...

## Encounter

<If the node has an encounter: opponents, their tactics, mechanical block references (which live in secrets.md if they're custom stat blocks).>

## Treasure / outcomes

<Any treasure, item, or resolution-state changes from this node.>

## Exits / connections

<Plain exits listed here. Conditional and clue-gated logic lives in connections.md.>
- North: <destination node-slug>
- ...
```

#### `dm/modules/<slug>/hooks.md`

Adventure hooks framed from the module's GM-side perspective. **Lives under `dm/`; not narrator-readable.**

```markdown
---
slug: <slug>
parent-module: <module-slug>
---

# Hooks — <Module Title>

## Hook 1: <name>

<1-2 paragraphs describing how the party gets pulled in. Includes the framing the narrator would use to present the hook to the party. Player-perceivable framing.>

## Hook 2: <name>
...
```

Schema note: hooks live in `dm/` (not `library/`) because their *use* is module-specific — a hook is a transition into running this module. The librarian (Phase 3b) returns the hook on request when the narrator wants to surface this module to the party.

#### `dm/modules/<slug>/connections.md`

Alexander-style conditional connections between nodes. **Lives under `dm/`; not narrator-readable.**

```markdown
---
slug: <slug>
parent-module: <module-slug>
---

# Connections — <Module Title>

## Default connections

<As listed in node files; recapped here for one-stop reference.>

## Conditional connections

- **From <node-A> to <node-B>:** if <condition, in narrator-perspective full clarity>. (Phase 3b's runtime query will scope-filter conditionals when surfacing to the narrator if needed.)
- ...

## Clue dependencies

- **Reaching <node-X> requires:** <list of clues from other nodes>
```

#### `dm/modules/<slug>/secrets.md`

Twists, hidden identities, and reveal content the librarian identified as content that would deflate a beat if seen mid-scene. **Lives under `dm/`; not narrator-readable. Phase 3b's runtime query treats this content with extra care — it's surfaced only when the narrator's scope explicitly matches a reveal.**

```markdown
---
slug: <slug>
parent-module: <module-slug>
ingested: <YYYY-MM-DD>
---

# <Module Title> — Secrets

## Twists & reveals

- **<Twist name>:** <The hidden fact. What actually drives the situation.>
- ...

## Hidden NPC identities & motives

- **<NPC name>:** publicly <surface role>; actually <hidden role/motive>.
- ...

## Hidden locations / passages

- **<location>:** revealed by <condition>.
- ...

## DM-only context

<Any other prose the source flagged as GM-only, or that the librarian classified as a reveal-quality secret.>

## Custom stat blocks

<If the module defines custom stat blocks (e.g., a unique undead variant), they live here.>
```

Schema note: under Phase 3a's revised model, the secret-vs-rest distinction is *not* an asymmetry boundary — both kinds of content live under `dm/` and are equally invisible to the narrator. The distinction matters for Phase 3b's runtime query, which will more aggressively filter `secrets.md` content even from the librarian's responses (returning a twist only when the scope explicitly matches a reveal moment).

#### `dm/modules/<slug>/milestone-candidates.md`

Proposed milestones for Phase 5 to promote.

```markdown
---
slug: <slug>
parent-module: <module-slug>
proposed: <YYYY-MM-DD>
status: candidate
---

# Milestone Candidates — <Module Title>

<!-- Phase 3a produces these as proposals. Phase 5 will define the milestone schema and promote accepted candidates to dm/milestones/. -->

## Candidate 1: <name>

- **Trigger:** <chapter completion / major story beat / dungeon clear>
- **Rationale:** <why the librarian thinks this is a natural progression beat>
- **Source reference:** <node-slug or section of source>

## Candidate 2: <name>
...
```

### Librarian subagent (`.claude/agents/librarian.md`)

Frontmatter:

```yaml
---
name: librarian
description: Ingests reference source material into the campaign library. Decomposes modules into Alexander-style nodes, writes module content entirely under dm/modules/ via the dm-fs MCP (module content is future-scene state for the party; the narrator has no direct path to it until Phase 3b's runtime query), and emits a structured intake summary for user review.
tools: Read, Write, Edit, Glob, Bash
mcpServers: [dm-fs]
model: sonnet
---
```

Frontmatter notes:

- `model: sonnet` matches revelation and world-state — classification work benefits from sonnet's judgment headroom over haiku.
- `Bash` is included for future PDF-conversion helpers; the Phase 3a smoke test uses Read directly on the PDF (Claude Code's PDF support handles modest-size PDFs natively).
- The MCP wiring gives the librarian write access to `dm/modules/` exactly as world-state has access to `dm/factions/` — same gate, separate lane.
- `Write` and `Edit` are in the tools list specifically for `library/index.md`. The librarian never writes any other file under `library/`.

#### Read access (contract)

- `library/`, `world/`, `party/`, `sessions/`, `references/` — readable directly via Read / Glob.
- `dm/modules/` — readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` / `mcp__dm-fs__list_dm_dir`.
- **No access** to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any other `dm/` path. The settings.json denies enforce this for direct tools; the librarian's prompt forbids dm-fs MCP reads outside `modules/` as a discipline rule.

#### Write access (contract)

- `library/index.md` — writable directly via Edit. **This is the only library-side write.**
- `dm/modules/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file`.
- **No writes** to any other path under `library/` (no `library/modules/<slug>/`, no other library/ subdirs), and **no writes** to any other `dm/` path. `Edit(dm/**)` remains denied at the project level.

#### Contract

The librarian is a **one-way pipeline** from external source material into the structured `dm/modules/<slug>/` set. It decomposes module structure into Alexander-style nodes and writes module content entirely to `dm/`. The library-side artifact is `library/index.md`'s enumeration entry only.

The librarian never:

- Authors content it didn't read from the source (no invented hooks, NPCs, secrets, or milestones).
- Writes module content to `library/modules/<slug>/` or anywhere under `library/` other than `library/index.md`.
- Writes to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Mutates existing `dm/modules/<slug>/` content on a re-intake of the same slug — aborts on slug collision and surfaces the error.
- Commits to git. The user reviews and commits.
- Promotes milestone candidates into a runtime milestone system (Phase 5).
- Auto-seeds `dm/factions/<slug>.md`, `dm/revelations/<id>.md`, or `dm/threads/active.md` from module content. Flags such opportunities in the intake summary instead.

#### Query type: `intake-module`

> "Ingest module material at `<path>`. Active session log: `<path-or-null>`."

The caller (the `/intake` command) provides a path to a PDF or markdown source and optionally an active session log path (typically null — intake is between-sessions; the session-log line is a forward-compatibility hook).

Procedure:

1. **Pre-flight.** Read the source path. If a PDF, use Read's PDF support directly (specify a `pages` range if the document exceeds 10 pages). If a directory, refuse with `"intake source must be a single file in Phase 3a"`. Build an internal working representation of the full source text plus structural markers (headings, boxed text indicators, section labels).

2. **Identify content type.** For Phase 3a, only `module` is accepted. If the source appears to be a solo engine, methodology text, or pure lore reference, return an error: `"Phase 3a only supports module ingest; this source appears to be <type>. Re-attempt after Phase 3b adds <type> support, or pre-extract module-shaped content manually."`

3. **Determine slug & module title.** Derive a slug from the title (lowercase-hyphenated, alphanumeric + hyphens). Check whether `dm/modules/<slug>/` exists via `mcp__dm-fs__list_dm_dir`. If it exists, abort. (The librarian no longer checks `library/modules/<slug>/` because module content does not live there in Phase 3a.)

4. **Decompose into Alexander-nodes.** Scan the source for distinct locations, scenes, and encounters. For each, gather:
   - Description and sensory detail.
   - NPCs present, with their full motivations.
   - Notable features, clues, traps with DCs.
   - Encounter detail (opponents, tactics).
   - Treasure / outcomes.
   - Default exits/connections.
   - Conditional logic (gated reveals, key-required passages, clue-dependent transitions) → routed to `connections.md`.

5. **Classify content by kind.** For each chunk of source content, decide which `dm/modules/<slug>/` file it belongs in:
   - **`overview.md`:** the narrator-perspective premise, arc, resolution, themes, level range.
   - **`nodes/<node-slug>.md`:** per-node content (one file per node).
   - **`hooks.md`:** the GM-side framing of how the party gets pulled in.
   - **`connections.md`:** default and conditional inter-node connections, clue dependencies.
   - **`secrets.md`:** twists, hidden identities, plot reveals, GM-only context, custom stat blocks.
   - **`milestone-candidates.md`:** proposed milestones — chapter ends, dungeon clears, major story beats.

   No content lands under `library/`. The asymmetry boundary at intake is structural (everything to dm/), not classification-driven.

6. **Write all module content to `dm/modules/<slug>/`** via the dm-fs MCP (`mcp__dm-fs__create_dm_file`). The 6 files above; nodes/ as a subdirectory with one file per node.

7. **Update `library/index.md`** via Edit. Append a one-line enumeration entry under `## Modules`, update `last-updated` frontmatter to today's date, re-sort entries alphabetically by slug. The entry follows the format: `- **<slug>** — <one-line genre/theme descriptor>. Source: \`<reference path>\`. Ingested: <YYYY-MM-DD>.` The descriptor is a *single short clause naming the genre/theme*; it never describes specific scenes, encounters, or twists.

8. **Emit structured intake summary** as your final response (the `/intake` command will surface it verbatim to the user):

   ```
   INTAKE SUMMARY: <module-slug>

   Source: <path>
   Title: <Module Title>
   Level range: <e.g., 1-3>
   Themes: <tags>

   All module content written to dm/modules/<slug>/ (invisible to the narrator until Phase 3b's runtime query):
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
     1. Review the staged files via your own shell/editor (NOT via Claude Code's main agent — dm/ is denied).
        - dm/modules/<slug>/overview.md, nodes/*, hooks.md, connections.md, secrets.md, milestone-candidates.md
        - library/index.md (the only narrator-visible change)
     2. Confirm the library/index.md entry's descriptor is genre-level only and does not leak module content.
     3. Confirm that no file landed under library/modules/<slug>/ — Phase 3a's contract is that the directory stays empty.
     4. Commit when satisfied. Do NOT run /session-start until the intake is committed.
        Phase 3a does not yet provide narrator runtime access to the ingested module; that ships in Phase 3b.
   ```

9. **Log a single line to the active session log if one was provided** (typically null for between-session intake; if non-null, use your Edit tool to append):

   ```
   - LIBRARIAN QUERY: intake-module <module-slug> — <N> nodes, <S> secrets, <M> milestone candidates
   ```

#### Edge cases

- **Source path doesn't exist or isn't readable.** Abort with an error before any writes. No partial mutation.
- **PDF is too large to read in one pass.** Read in page-range chunks via Read's `pages` parameter; merge internal representation before classification. If still too large for your context budget, abort with `"source exceeds intake budget; pre-split into smaller modules"`.
- **Source doesn't appear module-shaped (no nodes detectable).** Abort with `"source does not decompose into Alexander-nodes; please pre-structure or wait for Phase 3b lore-reference intake"`.
- **Slug collision** — `dm/modules/<slug>/` already exists. Abort; user resolves manually (delete or rename). No silent overwrite.
- **Partial intake state from a prior failure** — `dm/modules/<slug>/` exists with some files but not all. Abort with explicit error. User cleans up manually.
- **`library/index.md` already lists the slug** but `dm/modules/<slug>/` does not exist. Anomalous; abort with an error pointing at the mismatch.
- **Source has zero ambiguous content-kind classifications.** Emit the secret-notes-section line "None — all content kinds were unambiguous." explicitly so the user can trust that the absence is a result of inspection, not a missing report.
- **Source overlaps existing campaign content** (e.g., names an NPC already in `world/home-base/npcs/`). Don't merge; flag in the summary's "Opportunities" list. Phase 4 bookkeeper will own merge proposals.
- **dm-fs MCP write fails mid-intake.** Surface the error in your response; partial dm-fs writes may exist. Inform the user to clean up the partial `dm/modules/<slug>/` directory via their own shell and re-run after resolving the MCP issue.
- **`library/index.md` write fails after dm-fs writes succeed.** Surface the error; the user reconciles by either editing `library/index.md` manually or rolling back the dm-fs writes (via their own shell).

### `/intake` slash command (`.claude/commands/intake.md`)

Unchanged from the initial Phase 3a draft — a thin dispatcher.

```markdown
---
description: Ingest source material into the campaign library. Usage: /intake <path>
---

The user wants to ingest source material at `$1`.

Invoke the librarian subagent with: "Ingest module material at `$1`. Active session log: null."

Surface the librarian's intake summary verbatim to the user. Then remind them of the NEXT STEPS the summary describes:

1. Review the staged files via your own shell/editor (the main agent cannot read `dm/`).
2. Inspect any secret-content notes the librarian flagged for verification.
3. Spot-check the `library/index.md` entry is genre-level only and does not leak module content.
4. Commit when satisfied. Do NOT run `/session-start` until the intake is committed.

Do NOT commit or push anything yourself. The user reviews and commits manually.
```

The dispatcher is unchanged in shape from the initial Phase 3a draft; what changes is the librarian's behavior it dispatches to. The intake-summary structure surfaced to the user reflects the revised contract (all content under `dm/`, library-side is index-only).

### CLAUDE.md update (Phase 3a — revised)

The original Phase 3a draft added a single informational subsection saying `library/` may contain ingested module material readable to the narrator. **That subsection is replaced.** The revised version:

> ## Library reference material
>
> `library/index.md` enumerates ingested modules by slug, genre/theme, source path, and ingest date. Read it to know which modules are available in the campaign's library.
>
> **Module content itself is dm-quarantined.** The full content of each ingested module (overview, nodes, hooks, connections, secrets, milestone candidates) lives under `dm/modules/<slug>/` and is denied to you at the project level. You cannot read it. This is intentional: a module's content is *future-scene state* from the party's POV, and would leak future scenes into your present narration if you could read it ahead of play.
>
> Phase 3a is intake-only: it lands module content in `dm/modules/` for the user to review and commit. **The narrator has no path to read module content during play in Phase 3a.** Phase 3b will add a `consult-library` runtime query on the librarian subagent that surfaces just the relevant excerpt (e.g., the current node's content) when you need it for a scene. Until 3b lands, an ingested module sits in the library available for review but not for live narration.
>
> The librarian subagent owns intake and (in 3b) runtime queries. You do not invoke the librarian during play in Phase 3a.

Plus one new must-never bullet (added to `## What you must never do`):

> - Never attempt to read, glob, or grep `library/modules/<slug>/` for ingested module content — that path is intentionally empty under Phase 3a; module content lives under `dm/modules/<slug>/`, which is denied to you. Runtime access to module content ships in Phase 3b's `consult-library` query.

### Repository layout (Phase 3a additions)

```
gygaxagain/
├── .claude/
│   ├── agents/
│   │   └── librarian.md             (NEW)
│   └── commands/
│       └── intake.md                (NEW)
├── library/                          (NEW)
│   ├── index.md                     (NEW — populated by intake with one-line entries)
│   └── modules/                      (intentionally empty under Phase 3a; .gitkeep)
├── dm/
│   └── modules/                      (created by first intake; all module content lives here)
│       └── <smoke-test-slug>/        (smoke-test artifact)
└── CLAUDE.md                         (Library reference material subsection revised; one new must-never bullet)
```

## Smoke test for Phase 3a

### Primary smoke test — real intake of one One-Page One-Shot or equivalent

1. With Phase 3a's librarian subagent and `/intake` command in place, the user picks one module-shaped source from `references/` (e.g., `references/The_Ancient_Tomb_of_Phandalin.pdf` or a single adventure pre-extracted from `references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf`).
2. The user runs `/intake <path-to-source>`.
3. The `/intake` command invokes the librarian subagent.
4. The librarian:
   - Reads the source via the Read tool's PDF support.
   - Decomposes into Alexander-nodes.
   - Classifies each chunk by content kind (overview / nodes / hooks / connections / secrets / milestone-candidates).
   - Writes all six file types to `dm/modules/<slug>/` via `mcp__dm-fs__create_dm_file`.
   - Updates `library/index.md` with the new enumeration entry via Edit.
   - Emits the structured intake summary.
5. The user reviews:
   - `git status` shows `dm/modules/<slug>/` as untracked and `library/index.md` as modified.
   - The user reads each file under `dm/modules/<slug>/` directly via their own shell/editor (outside Claude Code — the main agent cannot read `dm/`).
   - `library/index.md` entry is genre-level only (e.g., "undead dungeon crawl"); not a scene-by-scene tease.
   - `library/modules/<slug>/` does **not** exist (only `library/modules/.gitkeep` is present).
6. User commits with a descriptive commit message.

**Pass criteria:**

- `dm/modules/<slug>/` exists (per dm-fs access log and per user inspection in their own shell) with: `overview.md`, ≥1 file under `nodes/`, `hooks.md`, `connections.md`, `secrets.md`, `milestone-candidates.md`.
- `library/index.md` lists the module under `## Modules` with a single-clause genre/theme descriptor.
- **`library/modules/<slug>/` does not exist.** Only `library/modules/.gitkeep` remains in `library/modules/`.
- The intake summary correctly enumerates files and any secret-content notes.
- The dm-fs access log shows librarian-issued `create_dm_file` calls against `modules/<slug>/` paths (six writes: overview + nodes/<N>/ + hooks + connections + secrets + milestone-candidates).
- **Asymmetry audit (load-bearing):** the main agent attempts `cat dm/modules/<slug>/secrets.md` (or any file under `dm/modules/<slug>/`) and is denied. The narrator can confirm via `cat library/index.md` that the index entry exists, but cannot read any module content.
- No regressions: all 87 existing tests still pass; existing Phase 1/2 smoke flows (`/session-start`, `/session-end`, oracle, dice, world-state tick, revelation could-land/confirm, thread open/close/list, Mythic event spotlight) still operate.

### Asymmetry audit specifics

Phase 3a's revised model makes the asymmetry audit simpler than the original draft's:

1. The main agent issues no `mcp__dm-fs__*` tool calls during or after intake. (The main agent has no MCP wiring; this is structurally enforced.)
2. The main agent issues no `Read`/`Glob`/`Grep` against `dm/**` (denied by settings.json; verify the trace contains no such attempts).
3. The main agent attempts a direct `cat`/`ls` against any file under `dm/modules/<slug>/` and is denied (positive verification that the deny rules are firing).
4. The librarian subagent issues no MCP reads against `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`. Grep the dm-fs access log for librarian-issued reads outside `modules/`.
5. After commit, a subsequent `/session-start` runs cleanly. The narrator may read `library/index.md` and learn that the module exists by name, but cannot access any module content. (Follow-up validation; not a hard 3a pass criterion.)

## Failure modes Phase 3a must handle

- **Source PDF unreadable or too large.** Pre-flight error before any writes. No partial state.
- **Source isn't module-shaped.** Pre-flight error with explicit message (e.g., "this appears to be a methodology text; Phase 3b will support that").
- **Slug collision** — `dm/modules/<slug>/` already exists. Abort; user resolves manually.
- **Partial intake state from a prior failure** — `dm/modules/<slug>/` partially populated. Abort with explicit error.
- **`library/index.md` is out of sync** with `dm/modules/<slug>/` (one knows about the module, the other doesn't). Anomalous; surface to the user.
- **Classification misjudgment.** Under the revised model, classification misjudgments are between *content kinds within dm/* (e.g., a passage that should be in `nodes/cellar.md` ends up in `secrets.md`). The asymmetry is preserved regardless — the user reviews via their own shell and re-files content if needed. No risk of the narrator pre-reading a misclassified passage.
- **Milestone candidates are spurious or low-quality.** No harm done — they sit in `dm/modules/<slug>/milestone-candidates.md` as proposals. Phase 5 will refine promotion criteria.
- **Intake mid-session (against discipline).** Phase 3a does not block this technically. The librarian's intake-summary NEXT STEPS warn against `/session-start` between `/intake` and commit. If the user violates the discipline, only `library/index.md` is in the main agent's narrator-readable scope, and the index entry is genre-level only. The asymmetry holds even under discipline violation, because the dm-side content is structurally inaccessible.
- **dm-fs MCP write fails.** Librarian surfaces the error; partial dm-side state may exist. User cleans up via their own shell and re-runs after resolving.
- **Source contains existing campaign NPCs / locations under different names.** Librarian doesn't auto-merge; flags in summary's "Opportunities" list. User reconciles manually.
- **Library index entry leaks content.** The librarian's discipline rule is that the descriptor is a single-clause genre/theme tag. If the librarian over-describes (e.g., names the boss, names the twist), the user catches it on review of `library/index.md` and edits before commit. The commit-gate catches this case.

## Open questions resolved during brainstorming (revised)

- **Slicing of original Phase 3:** Phase 3a = `/intake` plumbing + librarian + module intake **only**. Runnability (narrator reading module content during play) defers to Phase 3b's `consult-library` runtime query. Solo-engine intake, methodology intake, lore reference intake, URL ingestion, and auto-seeding of factions/revelations/threads all defer to Phase 3b+.
- **Asymmetry model:** Structural, not behavioral. Module content lives entirely under `dm/modules/<slug>/`. `library/modules/<slug>/` does not exist as a populated directory. The narrator has no path to read module content directly until Phase 3b's runtime query.
- **Secret-content distinction:** Inside `dm/modules/<slug>/`, the librarian still separates twist/reveal content (`secrets.md`) from regular module content (`overview.md`, `nodes/`, `hooks.md`, `connections.md`). This distinction is for *Phase 3b's runtime query*, which will more aggressively filter `secrets.md` when surfacing module content to the narrator. In Phase 3a, both kinds are equally invisible to the narrator.
- **PDF reading:** Direct via Claude Code's Read tool (PDF support). No pdftotext shim in 3a.
- **Module representation:** Per-node files in `dm/modules/<slug>/nodes/<node-slug>.md`. Hooks, connections, secrets, milestone-candidates each in their own file under `dm/modules/<slug>/`.
- **Milestone candidates location:** `dm/modules/<slug>/milestone-candidates.md`. `dm/milestones/` skeleton not created in 3a; Phase 5 owns it.
- **Runtime librarian queries:** Deferred to Phase 3b. Phase 3a's deliverable is intake-only.
- **CLAUDE.md routing:** No new routing rule. One revised subsection (`## Library reference material`) and one new must-never bullet.
- **dm-fs MCP changes:** None. Existing read/list/write/create/append cover all 3a operations.
- **Auto-seeding hidden state:** Librarian flags opportunities in the summary; doesn't act. Faction/revelation/thread file authoring stays implementation-time discipline until Phase 4.
- **Python code added:** None. All 3a work is prompt + slash command + content writes via existing MCP.
- **`library/modules/` directory:** Stays as `library/modules/.gitkeep` only. The directory exists in git; no module subdirs are populated under Phase 3a.

## Phase 3a → Phase 3b handoff

Phase 3a's exit unlocks Phase 3b, which adds:

- **`consult-library` runtime query** on the librarian. The narrator invokes this mid-scene when a moment plausibly intersects an ingested module: "What does the library say about the party entering <location>?" or "What hook does <module-slug> use?" The librarian returns scoped excerpts — typically just the relevant `nodes/<slug>.md` content or just the hook text — never the full module. This is what makes ingested modules *playable* in Phase 3b.
- **Scope-filtered `secrets.md` surfacing.** When the narrator's scope explicitly matches a reveal moment, the librarian's response may include the relevant secret content; otherwise `secrets.md` content stays absent from the response.
- **Solo-engine intake.** Mythic GME 2e-style table extraction into `library/solo-engines/<name>/` (lore-quality content that *is* narrator-readable, distinct from modules).
- **Methodology intake.** Justin Alexander's GM book and similar — structured extraction of techniques and discipline patterns into `library/methodology/<topic>/`.
- **Lore reference intake.** Random tables, monster manuals, regional gazetteers into `library/lore/<name>/` — also narrator-readable, since they describe world facts rather than future scenes.
- **URL ingestion.** Web-fetched source material, behind a host-allowlist if needed.
- **Auto-proposals for `dm/factions/`, `dm/revelations/`, `dm/threads/`.** When module intake identifies a faction archetype or a clear revelation candidate, the librarian can propose a seed file (still user-reviewed before commit).
- **Optional `rename_dm_file` MCP tool** if real staging directories prove necessary.

Phase 3a's commit-gate review pattern is the substrate Phase 3b extends.

## Roadmap context

Phase 3a sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete; clue-level filter fix landed 2026-05-10)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(complete; closes Phase 2 hidden-state arc)*
6. **Phase 3a — Source ingestion: modules (intake-only; dm-quarantined).** *(this design, revised)*
7. **Phase 3b — Source ingestion: solo engines, methodology, lore, runtime librarian `consult-library` query. Phase 3b is what makes Phase 3a's ingested modules playable.**
8. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals, content authoring formalization.
9. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
10. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
11. **Phase 7 — Downtime, banking, bastions.**

Phase 3a's scope is what's locked here.
