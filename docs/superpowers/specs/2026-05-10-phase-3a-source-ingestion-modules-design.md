# Phase 3a — Source Ingestion: Modules Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Phase 2b spec:** `docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md`.
**Phase 2c spec:** `docs/superpowers/specs/2026-05-10-phase-2c-mythic-threads-design.md`.
**Phase 2d spec:** `docs/superpowers/specs/2026-05-10-phase-2d-mythic-event-spotlight-design.md`.
**Slice of original Phase 3:** module intake only. Solo-engine intake, methodology intake, lore reference intake, runtime librarian queries, and URL ingestion all deferred to Phase 3b.

## Purpose

Phase 2 closed the hidden-state arc — factions, revelations, threads, and Mythic-event spotlight all operate against `dm/` content the assistant hand-authored at implementation time. Phase 3a displaces that pattern: external module material (One-Page One-Shots, hardcover adventure nodes, etc.) flows into the engine through `/intake`, decomposed into Alexander-style nodes, classified public-vs-secret, and committed under a strict review gate — with the narrator unable to see any of the secret content even after intake completes.

Phase 3a's load-bearing claim is that **secret-quarantine works at intake time**, because there is no second line of defense: once content lands in `library/` and gets committed, the narrator may read it in the next `/session-start`. The mandatory user-review gate (commit-gate semantics: uncommitted working tree is the staging surface) is what catches misclassifications before the narrator can encounter them.

## Definition of done

A successful Phase 3a build demonstrates all of:

- `library/` directory established with `library/index.md` and a `library/modules/` subdirectory.
- New `librarian` subagent at `.claude/agents/librarian.md` with read access to `library/`, `world/`, `party/`, `sessions/`, `references/` (direct), plus `dm/modules/` (via dm-fs MCP); write access to `library/` (direct) and `dm/modules/` (via dm-fs MCP). No access to other `dm/` paths.
- New `/intake <path>` slash command at `.claude/commands/intake.md` that dispatches the librarian and surfaces its intake summary verbatim.
- Single query type on the librarian: `intake-module`. Procedure decomposes the source into Alexander-nodes, classifies each chunk public-or-secret (ambiguous → secret default), writes public artifacts to `library/modules/<slug>/`, writes secret artifacts to `dm/modules/<slug>/` via dm-fs MCP, updates `library/index.md`, and emits a structured intake summary.
- Module ingestion produces:
  - `library/modules/<slug>/overview.md` (summary, themes, level range, recommended hook framings — never mentions twists or villain identities)
  - `library/modules/<slug>/nodes/<node-slug>.md` (one per Alexander-node — location/scene/encounter)
  - `library/modules/<slug>/hooks.md` (adventure hooks to splice into play)
  - `library/modules/<slug>/connections.md` (default + Alexander-style conditional connections between nodes, with conditions worded as player-discoverable)
  - `dm/modules/<slug>/secrets.md` (quarantined twists, hidden NPC identities & motives, hidden locations, GM-only context)
  - `dm/modules/<slug>/milestone-candidates.md` (proposed milestones for Phase 5 to promote)
  - Updated `library/index.md`
- The librarian's intake summary enumerates files created, the public/secret split counts, milestone candidates, ambiguous classifications flagged for human verification, and any opportunities for later phases (e.g., a faction archetype noticed in the source).
- Smoke test: ingest one One-Page One-Shot adventure from `references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf` end-to-end. Asymmetry audit confirms narrator-issued tool calls never touch `dm/` during or after intake; the librarian is the sole `dm/` writer.
- All 87 existing tests continue to pass; no Python code is added in this phase.
- The dm-fs MCP is wired into a fourth subagent (librarian) — no MCP tool changes; existing read/list/write/create/append cover all 3a operations.
- `CLAUDE.md` gains one informational line noting that `library/` may contain ingested module material readable to the narrator. No new routing rule, no new must-never bullet (existing `dm/` denies and the "never read dm/" prohibition already cover the asymmetry boundary for intake artifacts).

## Out of scope (deferred to Phase 3b or later)

- **Solo-engine intake.** Mythic GME 2e and similar feed via the existing mythic CLI from Phase 1; structured library extraction is Phase 3b.
- **Methodology intake.** Justin Alexander's GM book and similar — Phase 3b.
- **Lore reference intake.** Random tables, monster manuals, regional gazetteers — Phase 3b.
- **Runtime librarian queries.** Phase 3b. The narrator does not invoke the librarian during play in 3a.
- **URL ingestion.** Phase 3b. Path-only for 3a.
- **Multi-file / megabundle modules** (full hardcover adventures). Phase 3b+. One-Page One-Shots are single-file tractable.
- **Automatic milestone persistence to `dm/milestones/`.** Phase 5. 3a produces proposals only.
- **Auto-seeding `dm/factions/`, `dm/revelations/`, `dm/threads/` from module material.** Phase 3b or Phase 4. The librarian flags opportunities in the intake summary; the user decides.
- **Bookkeeper verification of intake decisions** (Phase 4).
- **`rename_dm_file` op on the dm-fs MCP.** Commit-gate is the 3a review mechanism; staging-directory promotion is deferred unless 3b workflows require it.
- **`/intake` invoked mid-session.** Discipline expectation: intake happens between sessions. The librarian's intake summary warns against running `/session-start` between `/intake` and commit. Phase 3a does not block this technically; document the discipline.
- **`--force` flag for re-ingesting an existing slug.** Phase 3b if it's a real workflow need. 3a aborts on slug collision; user resolves manually.

## Architecture

### Slice mapping

| Component                          | Phase 3a touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | One informational line in `CLAUDE.md` about `library/`. No routing rule, no must-never bullet. |
| World-state subagent               | Untouched.                                                                       |
| Revelation subagent                | Untouched.                                                                       |
| Mythic subagent                    | Untouched.                                                                       |
| Dice subagent                      | Untouched.                                                                       |
| **Librarian subagent**             | **NEW** — `.claude/agents/librarian.md`.                                         |
| `dm-fs` MCP                        | No tool changes. Wired into a fourth subagent (librarian) via the agent's frontmatter `mcpServers: [dm-fs]`. The `.mcp.json` already registers the server project-wide. |
| `.claude/settings.json`            | No deny-rule changes. Narrator's `dm/**` denies stay in place.                   |
| `/intake` command                  | **NEW** — `.claude/commands/intake.md`.                                          |
| Other slash commands               | Untouched.                                                                       |
| Repository layout                  | NEW: `library/`, `library/modules/`, `library/index.md` (initially with one entry from the smoke-test ingest). NEW: `dm/modules/` (created at first intake; not seeded). |

### Information-asymmetry preservation

The Phase 1/2 boundary holds and gets exercised more thoroughly than before.

- The narrator's `dm/**` denies in `.claude/settings.json` stay in place. There is no path from the narrator (main agent) to `dm/modules/`. The librarian writes secrets through the dm-fs MCP exactly as world-state / mythic / revelation already do — same gate, new tenant.
- `library/` is narrator-readable by design. Phase 3a's load-bearing claim is that the **librarian classifies correctly at intake time** so nothing the narrator shouldn't see ever lands in `library/`. The commit-gate is the user-visible verification step before the narrator can encounter the content: the user does not run `/session-start` between `/intake` and `git commit`.
- The dm-fs access log captures every librarian write to `dm/modules/`, so the smoke-test asymmetry audit extends naturally — grep the access log for non-subagent writes to `dm/`.
- The librarian's read scope deliberately excludes `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`. Its job is to *populate* `dm/modules/` from external sources, not to read other hidden state. The exclusion is enforced by the librarian's prompt as a discipline rule (the dm-fs MCP itself does not currently scope by subdirectory; tightening this is a future hardening concern).
- The narrator does not invoke the librarian during play in 3a. The librarian is reachable only via `/intake`, which is a between-session command. This keeps the narrator's runtime surface unchanged.

### Integration with prior phases

- **Phase 1 (dice & mythic CLIs, world-state subagent, dm-fs MCP reads/writes):** unchanged. The librarian uses the existing dm-fs MCP tools that Phase 2a established.
- **Phase 2a (factions):** unchanged. If the librarian recognizes a faction-like entity in module content (e.g., a cult or a smuggling ring), it flags it in the intake summary's "Opportunities" list rather than auto-creating a `dm/factions/` entry. Faction file authoring stays at-implementation-time discipline until Phase 4 changes that.
- **Phase 2b (revelations):** unchanged. Same flagging discipline — the librarian may note "this module's hidden priest reveal would naturally seed a revelation," but does not autonomously write `dm/revelations/<id>.md`. The Phase 2b clue-level filter fix (landed 2026-05-10) is irrelevant to intake.
- **Phase 2c (threads):** unchanged. Newly-ingested modules do not auto-add threads.
- **Phase 2d (Mythic-event spotlight):** unchanged. The thread spotlight reads `dm/threads/active.md`; module intake does not write there.

## Component designs

### File schemas

#### `library/index.md`

Single top-level index. Sections for each content type; Phase 3a populates only `## Modules`.

```markdown
---
last-updated: <YYYY-MM-DD>
---

# Library Index

## Modules
- **<slug>** — <one-line summary>. Level <range>. Themes: <comma-separated>. Source: `<reference path>`. Ingested: <YYYY-MM-DD>.
- ...

## Solo engines
<!-- Phase 3b -->

## Methodology
<!-- Phase 3b -->

## Lore references
<!-- Phase 3b -->
```

Schema notes:

- Modules listed alphabetically by slug. The librarian re-sorts the section on each intake.
- The summary line never references twists or villain identities.

#### `library/modules/<slug>/overview.md`

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
<1-paragraph overview of premise and arc. No twists or villain identities — describes the surface situation the party encounters.>

## Recommended hooks
<1-3 sentences on how the module is most naturally entered. Detailed hook framings live in hooks.md.>

## Setting & tone
<Short description of feel, environment, NPC vibe.>
```

#### `library/modules/<slug>/nodes/<node-slug>.md`

One per Alexander-node — location, scene, or encounter.

```markdown
---
slug: <node-slug>
type: location | scene | encounter
parent-module: <module-slug>
---

# <Node Title>

## Description
<What a party encounters when they reach this node. Player-perceivable details only — no GM annotations.>

## NPCs present
- <name> — <one-line description, no hidden motives>
- ...

## Notable features
- <interactable element>
- <clue or evidence the party can find>
- ...

## Exits / connections
<Plain exits listed here. Conditional logic lives in connections.md.>
- North: <destination node-slug>
- ...
```

#### `library/modules/<slug>/hooks.md`

```markdown
# Hooks — <Module Title>

## Hook 1: <name>
<1-2 paragraphs describing how the party gets pulled in. Player-facing framing — no GM-only context.>

## Hook 2: <name>
...
```

#### `library/modules/<slug>/connections.md`

Alexander-style conditional connections between nodes.

```markdown
# Connections — <Module Title>

## Default connections
<As listed in node files; recapped here for one-stop reference.>

## Conditional connections
- **From <node-A> to <node-B>:** if <player-discoverable condition>. (e.g., "if the party found the silver key in <node-C>")
- ...

## Clue dependencies
- **Reaching <node-X> requires:** <list of clues from other nodes>
```

Schema note: condition clauses must be worded so that the *condition itself* is player-discoverable. A condition like "if the party knows the priest is the cultist" leaks the twist; the correct phrasing is "if the party finds the cult-marked dagger in <node>". The librarian's classification step enforces this — any conditional whose clause discloses a secret gets rephrased or the conditional gets routed to `dm/modules/<slug>/secrets.md`.

#### `dm/modules/<slug>/secrets.md`

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
<Any other prose the source flagged as GM-only or that the librarian classified as secret.>
```

#### `dm/modules/<slug>/milestone-candidates.md`

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
description: Ingests reference source material into the campaign library. Decomposes modules into Alexander-style nodes, quarantines secrets to dm/modules/, proposes milestone candidates, and emits a structured intake summary for user review.
tools: Read, Write, Edit, Glob, Bash
mcpServers: [dm-fs]
model: sonnet
---
```

Frontmatter notes:

- `model: sonnet` matches revelation and world-state — classification work benefits from sonnet's judgment headroom over haiku.
- `Bash` is included for future PDF-conversion helpers (e.g., `pdftotext`); the Phase 3a smoke test uses Read directly on the PDF (Claude Code's PDF support handles modest-size PDFs natively).
- The MCP wiring gives the librarian write access to `dm/modules/` exactly as world-state has access to `dm/factions/` — same gate, separate lane.

#### Read access (contract)

- `library/`, `world/`, `party/`, `sessions/`, `references/` — readable directly via Read / Glob.
- `dm/modules/` — readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` / `mcp__dm-fs__list_dm_dir`.
- **No access** to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any other `dm/` path. The settings.json denies enforce this for direct tools; the librarian's prompt forbids dm-fs MCP reads outside `modules/` as a discipline rule.

#### Write access (contract)

- `library/` — writable directly via Write / Edit.
- `dm/modules/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file` / `mcp__dm-fs__write_dm_file`. `Edit(dm/**)` remains denied at the project level.
- **No writes** to any other `dm/` path.

#### Contract

The librarian is a **one-way pipeline** from external source material into the structured `library/` + `dm/modules/` split. It classifies content as public or secret, decomposes module structure into Alexander-style nodes, and proposes milestone candidates. It never:

- Authors content it didn't read from the source (no invented hooks, NPCs, secrets, or milestones).
- Writes to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Mutates existing `library/modules/<slug>/` or `dm/modules/<slug>/` content on a re-intake of the same slug — aborts on slug collision and surfaces the error.
- Commits to git. The user reviews and commits.
- Promotes milestone candidates into a runtime milestone system (Phase 5).
- Auto-seeds `dm/factions/<slug>.md`, `dm/revelations/<id>.md`, or `dm/threads/active.md` from module content. Flags such opportunities in the summary instead.

#### Query type: `intake-module`

> "Ingest module material at `<path>`. Active session log: `<path-or-null>`."

The caller (the `/intake` command) provides a path to a PDF or markdown source and optionally an active session log path (typically null — intake is between-sessions; the session-log line is a forward-compatibility hook).

Procedure:

1. **Pre-flight.** Read the source path. If a PDF, use Read's PDF support directly (specify `pages` range if document > 10 pages). If a directory, ingest one canonical entry-point file or refuse with `"intake source must be a single file in Phase 3a"`. Build an internal working representation of the full source text plus structural markers (headings, boxed text indicators, section labels).

2. **Identify content type.** For Phase 3a, this is gated: only `module` is accepted. If the librarian judges the source is a solo engine, methodology text, or pure lore reference, return an error: `"Phase 3a only supports module ingest; this source appears to be <type>. Re-attempt after Phase 3b adds <type> support, or pre-extract module-shaped content manually."`

3. **Determine slug & module title.** Derive a slug from the title (lowercase-hyphenated, alphanumeric + hyphens). If `library/modules/<slug>/` or `dm/modules/<slug>/` already exists, abort with an explicit error naming which directory exists.

4. **Decompose into Alexander-nodes.** Scan the source for distinct locations, scenes, and encounters. For each, gather:
   - Player-perceivable description (what the party sees on arrival).
   - NPCs present, with their *public* roles only.
   - Notable features and clues.
   - Default exits/connections.
   - Any conditional logic (gated reveals, key-required passages, clue-dependent transitions) → routed to `connections.md`, not the node file.

5. **Classify each chunk public-vs-secret.** For each passage in the source, decide:
   - **Public** if the party can perceive or learn it through normal play (descriptions, surface NPC behavior, observable clues, public hooks).
   - **Secret** if the source flags it as GM-only (boxed text, `## Secret`, "in reality", "the twist is", "GM info"), or if the librarian judges the content would deflate the mystery if the narrator could read it directly (hidden motives, true identities, plot reveals, hidden locations).
   - **Ambiguous** if the call is non-obvious. **Default to secret** (safe failure mode — false positives are reviewable, false negatives leak) and flag the passage in the intake summary for explicit human review.

6. **Write public content to `library/modules/<slug>/`** via Write:
   - `overview.md` (summary, themes, level range, recommended hook framing — never mentions any secrets).
   - `nodes/<node-slug>.md` per Alexander-node.
   - `hooks.md` (player-facing hook framings only).
   - `connections.md` (default + conditional connections; condition clauses must be player-discoverable, not "if the player has learned the priest is the cultist").

7. **Write secret content to `dm/modules/<slug>/` via the dm-fs MCP** (`mcp__dm-fs__create_dm_file`):
   - `secrets.md` (twists, hidden NPC identities & motives, hidden locations, GM-only context).
   - `milestone-candidates.md` (proposals identified during node decomposition — chapter ends, major beats, dungeon clears, story-arc resolutions).

8. **Update `library/index.md`** via Edit — append a module entry under `## Modules`, update `last-updated`, sort module entries alphabetically by slug.

9. **Emit structured intake summary** to stdout (returned to the `/intake` command, shown verbatim to the user):

   ```
   INTAKE SUMMARY: <module-slug>

   Source: <path>
   Title: <Module Title>
   Level range: <e.g., 1-3>
   Themes: <tags>

   Public artifacts (library/modules/<slug>/):
     - overview.md
     - nodes/ (<N> nodes: <node-slug-list>)
     - hooks.md (<K> hooks)
     - connections.md (<C> default + <D> conditional)

   Secret artifacts (dm/modules/<slug>/):
     - secrets.md (<S> twists/reveals, <H> hidden NPC notes, <L> hidden locations)
     - milestone-candidates.md (<M> candidates)

   Library index updated.

   Ambiguous classifications flagged for human verification:
     - <path>:<location-in-file> — <one-line description of the ambiguity and the librarian's chosen disposition>
     - ...
     (or: "None — all classifications were unambiguous.")

   Opportunities flagged for later phases (not auto-acted upon):
     - <e.g., "This module mentions a cult faction; consider seeding dm/factions/ once Phase 4 authoring tools ship.">
     - <e.g., "The hidden priest reveal would naturally become a revelation; consider dm/revelations/r-NNN.md.">
     (or: "None.")

   NEXT STEPS:
     1. Review the staged files via `git status` and `git diff`.
     2. Inspect the ambiguous classifications above; adjust any misclassified files in place.
     3. Spot-check secrets.md does NOT contain content that's also in library/.
     4. Commit when satisfied. Do NOT run /session-start until the intake is committed.
   ```

10. **Log a single line to the active session log if one was provided** (typically null for between-session intake):

    ```
    - LIBRARIAN QUERY: intake-module <module-slug> — <N> nodes, <S> secrets, <M> milestone candidates
    ```

#### Edge cases the procedure handles

- **Source path doesn't exist or isn't readable.** Abort with an error before any writes. No partial mutation.
- **PDF is too large to read in one pass.** Read in page-range chunks; merge internal representation before classification. If still too large for sonnet context, abort with `"source exceeds intake budget; pre-split into smaller modules"`.
- **Source doesn't appear module-shaped (no nodes detectable).** Abort with `"source does not decompose into Alexander-nodes; please pre-structure or wait for Phase 3b lore-reference intake"`.
- **Slug collision** — `library/modules/<slug>/` or `dm/modules/<slug>/` already exists. Abort; user resolves manually (delete or rename). No silent overwrite.
- **Partial intake state from a prior failure.** If one directory exists and the other doesn't (e.g., a previous intake crashed between library/ writes and dm/ writes), the librarian errors with which directory exists and which doesn't. User cleans up manually.
- **Source has zero ambiguous classifications.** Summary line "None — all classifications were unambiguous." Emit explicitly so the user can trust that the absence is a result of inspection, not a missing report.
- **Source has *only* secrets** (e.g., a GM-only addendum). Public artifacts come out near-empty; flag in the summary as a discipline check ("library/modules/<slug>/overview.md has no surface content — is this source really a module?").
- **Source overlaps existing campaign content** (e.g., names an NPC already in `world/home-base/npcs/`). Don't merge; flag in the summary's "Opportunities" list. Phase 4 bookkeeper will own merge proposals.
- **dm-fs MCP write fails mid-intake.** Surface the error in the librarian's response; partial library/ writes may exist. User cleans up via `git checkout -- library/modules/<slug>/` (uncommitted) and re-runs intake after resolving the MCP issue.

### `/intake` slash command (`.claude/commands/intake.md`)

```markdown
---
description: Ingest source material into the campaign library. Usage: /intake <path>
---

The user wants to ingest source material at `$1`.

Invoke the librarian subagent with: "Ingest module material at `$1`. Active session log: null."

Surface the librarian's intake summary verbatim to the user. Then remind them of the NEXT STEPS the summary describes (review via git, check ambiguities, commit when satisfied, do not start a session until committed).

Do NOT commit or push anything yourself. The user reviews and commits manually.
```

The command body is intentionally minimal — a thin dispatcher to the librarian subagent, matching the pattern of `/ask-oracle` (a thin dispatcher to mythic).

### CLAUDE.md update (Phase 3a)

One informational line is added near the bottom of the routing rules section, under `## What "smart prep" means here` or as a brief new subsection before `## What you must never do`. Suggested wording:

> **Library reference material.** `library/` may contain ingested module material — locations, hooks, NPCs from published modules — populated via `/intake`. Read it when relevant to a scene the party is in; treat it like `world/` for narrator-readability. The librarian subagent owns intake; you do not invoke the librarian during play in Phase 3a.

No new routing rule. No new must-never bullet — the existing `dm/` deny rules and the "never read dm/" prohibition already cover the secret-quarantine boundary for intake artifacts.

### Repository layout (Phase 3a additions)

```
gygaxagain/
├── .claude/
│   ├── agents/
│   │   └── librarian.md             (NEW)
│   └── commands/
│       └── intake.md                (NEW)
├── library/                          (NEW)
│   ├── index.md                     (NEW — populated by smoke-test intake)
│   └── modules/                      (populated by smoke-test intake)
│       └── <smoke-test-slug>/
├── dm/
│   └── modules/                      (created by smoke-test intake)
│       └── <smoke-test-slug>/
└── CLAUDE.md                         (one informational line added)
```

## Smoke test for Phase 3a

### Primary smoke test — real intake of one One-Page One-Shot

1. With Phase 3a's librarian subagent and `/intake` command in place, the user picks one adventure from `references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf`. (The book is a collection of one-page adventures — the user identifies a single adventure's page range, either by passing the full PDF with the librarian instructed to focus on a specific title, or by pre-extracting that adventure's page to a smaller standalone PDF or markdown.)
2. The user runs `/intake <path-to-source>`.
3. The `/intake` command invokes the librarian subagent.
4. The librarian:
   - Reads the source via the Read tool's PDF support.
   - Decomposes into Alexander-nodes.
   - Classifies each chunk public-vs-secret (ambiguous → secret default).
   - Writes `library/modules/<slug>/overview.md`, node files under `nodes/`, `hooks.md`, `connections.md` via Write.
   - Writes `dm/modules/<slug>/secrets.md` and `dm/modules/<slug>/milestone-candidates.md` via `mcp__dm-fs__create_dm_file`.
   - Updates `library/index.md` via Edit.
   - Emits the structured intake summary.
5. The user reviews:
   - `git status` shows new files in `library/modules/<slug>/`, `dm/modules/<slug>/`, and modifications to `library/index.md`.
   - `git diff` shows the index entry; new files are reviewed by reading them directly.
   - Spot-check: `library/modules/<slug>/` files contain no content the user judges secret. `dm/modules/<slug>/secrets.md` contains the expected twists/villain identities. Ambiguous classifications in the summary match the actual file placements.
   - Milestone candidates look reasonable; user neither accepts nor rejects in 3a (Phase 5 owns promotion).
6. User commits with a descriptive commit message.

**Pass criteria:**

- `library/modules/<slug>/` exists with at least: `overview.md`, ≥1 file under `nodes/`, `hooks.md`, `connections.md`.
- `dm/modules/<slug>/` exists with `secrets.md` and `milestone-candidates.md`.
- `library/index.md` lists the module under `## Modules`.
- The intake summary correctly enumerates files and any ambiguous classifications.
- The dm-fs access log shows librarian-issued `create_dm_file` calls against `modules/<slug>/` paths.
- **Asymmetry audit:** grep the tool-use trace of the intake invocation for any main-agent-issued tool calls touching `dm/` — there must be none. The librarian subagent is the sole `dm/` writer. (The main agent dispatches `/intake` → librarian; the main agent itself never touches dm-fs MCP.)
- No regressions: all 87 existing tests still pass; existing Phase 1/2 smoke flows (`/session-start`, `/session-end`, oracle, dice, world-state tick, revelation could-land/confirm, thread open/close/list, Mythic event spotlight) still operate.

### Asymmetry audit specifics

Phase 3a expands what flows through the asymmetry boundary; the audit must explicitly confirm:

1. The main agent issues no `mcp__dm-fs__*` tool calls during or after intake.
2. The main agent issues no `Read`/`Glob`/`Grep` against `dm/**` (would already be denied; verify the trace contains no such attempts).
3. The librarian subagent issues no MCP reads against `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`. Grep the dm-fs access log for librarian-issued reads outside `modules/`.
4. After commit, a subsequent `/session-start` runs cleanly with the new `library/modules/<slug>/` content available to the narrator and `dm/modules/<slug>/` invisible to it. (This is a follow-up validation rather than a hard 3a pass criterion — it confirms the asymmetry holds across the session boundary.)

### Secondary smoke test — scaffolded (optional)

If the One-Page One-Shot ingestion doesn't produce content that exercises the secret-quarantine code path (e.g., the chosen adventure has no twists), the user falls back to a synthetic markdown source: a small hand-authored `references/test-module.md` with two nodes, one explicit `## Secret` block, and one unmarked-but-clearly-secret passage. Re-run `/intake references/test-module.md` and verify the librarian correctly routes the marked passage to `dm/modules/test-module/secrets.md` AND catches the unmarked passage. This validates the classification path without depending on a particular published adventure's structure.

## Failure modes Phase 3a must handle

- **Source PDF unreadable or too large.** Pre-flight error before any writes. No partial state.
- **Source isn't module-shaped.** Pre-flight error with explicit message (e.g., "this appears to be a methodology text; Phase 3b will support that").
- **Slug collision** — `library/modules/<slug>/` or `dm/modules/<slug>/` already exists. Abort; user resolves manually.
- **Partial intake state from a prior failure.** Explicit error naming which directory exists.
- **Classification misjudgment — secret content lands in `library/`.** Primary mitigation: ambiguous-default-to-secret rule + the intake summary's ambiguity list. Secondary mitigation: commit-gate (user reviews before committing). Tertiary: even after commit, the user can move content from `library/` to `dm/modules/<slug>/secrets.md` manually; the librarian's classification is a starting point, not authoritative state.
- **Classification misjudgment — public content trapped in `dm/`.** Lower impact (narrator improvises without that detail rather than spoiling a reveal). User can move content back to `library/` on review.
- **Milestone candidates are spurious or low-quality.** No harm done — they sit in `dm/modules/<slug>/milestone-candidates.md` as proposals. Phase 5 will refine promotion criteria.
- **Intake mid-session (against discipline).** Phase 3a does not block this technically. The librarian's intake-summary NEXT STEPS warn against `/session-start` between `/intake` and commit. If the user violates the discipline, the narrator may read uncommitted `library/modules/<slug>/` content in that session — content the user has not yet rejected. Document as a known discipline expectation, not a structural failure mode.
- **dm-fs MCP write fails.** Librarian surfaces the error; partial library/ writes may exist. User cleans up via `git checkout -- library/modules/<slug>/` (uncommitted) and re-runs after resolving.
- **Source contains existing campaign NPCs / locations under different names.** Librarian doesn't auto-merge; flags in summary's "Opportunities" list. User reconciles manually.
- **Conditional connection clause leaks a secret.** The librarian's classification step is responsible for catching these — if a conditional clause discloses a twist, either rephrase the clause to be player-discoverable or route the conditional to `dm/modules/<slug>/secrets.md`. Ambiguous clauses default to secret.

## Open questions resolved during brainstorming

- **Slicing of original Phase 3:** Phase 3a = `/intake` plumbing + librarian + module intake (with secret-quarantine + milestone proposals). Solo-engine intake, methodology intake, lore reference intake, runtime librarian queries, URL ingestion, and auto-seeding of factions/revelations/threads from module material all defer to Phase 3b+.
- **Secret-quarantine mechanism:** LLM classification by the librarian with mandatory review gate. Review gate implemented as commit-gate (uncommitted working tree is the staging surface). Default-to-secret on ambiguity. Staging-directory plumbing deferred unless Phase 3b workflows require it.
- **PDF reading:** Direct via Claude Code's Read tool (PDF support). No pdftotext shim in 3a.
- **Module representation:** Per-node files in `library/modules/<slug>/nodes/<node-slug>.md`. Hooks and connections in separate files. Matches Alexander's node-based design.
- **Milestone candidates location:** `dm/modules/<slug>/milestone-candidates.md` — co-located with module secrets. `dm/milestones/` skeleton not created in 3a; Phase 5 owns it.
- **Runtime librarian queries:** Deferred to Phase 3b.
- **CLAUDE.md routing:** No new rule. One informational line about `library/`.
- **dm-fs MCP changes:** None. Existing read/list/write/create/append cover all 3a operations.
- **Auto-seeding hidden state:** Librarian flags opportunities in the summary; doesn't act. Faction/revelation/thread file authoring stays implementation-time discipline until Phase 4.
- **Python code added:** None expected. All 3a work is prompt + slash command + content writes. The smoke test validates behavior; no unit tests against the librarian's classification (that's the user-review-gate's job).
- **Librarian read scope discipline beyond `dm/modules/`:** The dm-fs MCP does not currently scope by subdirectory. The librarian's prompt forbids reads outside `modules/` as a discipline rule, enforced by inspection of the dm-fs access log during the asymmetry audit. Hardening the MCP with per-agent subdirectory scoping is a future concern.

## Phase 3a → Phase 3b handoff

Phase 3a's exit unlocks Phase 3b, which composes:

- **Solo-engine intake.** Mythic GME 2e-style table extraction into `library/solo-engines/<name>/` in a structured form the mythic subagent can call (e.g., callable JSON or markdown table format the agent loads on demand).
- **Methodology intake.** Justin Alexander's GM book and similar — structured extraction of techniques and discipline patterns into `library/methodology/<topic>/`. May influence agent prompts directly (e.g., a "three-clue rule" reference linked from the revelation agent's prompt).
- **Lore reference intake.** Random tables, monster manuals, regional gazetteers into `library/lore/<name>/`.
- **Runtime librarian queries.** A second query type on the librarian (`consult-library`) that the narrator can invoke mid-scene to pull curated excerpts without dumping whole module files into context.
- **URL ingestion.** Web-fetched source material, behind a host-allowlist if needed.
- **Auto-proposals for `dm/factions/`, `dm/revelations/`, `dm/threads/`.** When module intake identifies a faction archetype or a clear revelation candidate, the librarian can propose a seed file (still user-reviewed before commit).
- **Optional `rename_dm_file` MCP tool** if real staging directories prove necessary (e.g., for intake-mid-session safety).

Phase 3a's commit-gate review pattern and ambiguity-flagging discipline are the substrate Phase 3b extends.

## Roadmap context

Phase 3a sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete; clue-level filter fix landed 2026-05-10)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(complete; closes Phase 2 hidden-state arc)*
6. **Phase 3a — Source ingestion: modules.** *(this design)*
7. **Phase 3b — Source ingestion: solo engines, methodology, lore, runtime librarian queries.**
8. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals, content authoring formalization.
9. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
10. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
11. **Phase 7 — Downtime, banking, bastions.**

Phase 3a's scope is what's locked here.
