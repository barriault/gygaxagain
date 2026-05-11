# Phase 3a — Source Ingestion: Modules — Implementation Plan (revised)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Revision note:** This plan was revised mid-implementation after a smoke-test review identified an asymmetry gap. The original plan adopted a "twist-protected" library/dm split. The revised plan implements a strict structural asymmetry: all module content lives under `dm/modules/<slug>/`. Tasks 1 and 4 are rewritten; Tasks 2 and 3 remain unchanged; Task 5 (synthetic pre-flight) is dropped (we go straight to real intake); Task 6 verification steps are updated to match dm-only artifacts; Task 9 DOD checklist is refreshed.

**Goal:** Ship `/intake` + librarian subagent + module-shaped intake under a strict structural-asymmetry model, validated by ingesting one real module end-to-end with the asymmetry boundary intact.

**Architecture:** Phase 3a adds one new subagent (librarian), one new slash command (`/intake`), one new top-level directory (`library/` — index-only for modules), and writes all ingested module content to `dm/modules/<slug>/` via the existing dm-fs MCP. The narrator (main agent) has no path to read module content during play in Phase 3a — runnability defers to Phase 3b's `consult-library` runtime query. No new MCP tools, no new Python code. All work in this plan is prompt + slash-command + content authoring + smoke-test validation against the existing test suite.

**Tech Stack:** Markdown subagent prompts, Markdown slash command, dm-fs MCP (existing — `mcp__dm-fs__read_dm_file`, `list_dm_dir`, `write_dm_file`, `create_dm_file`, `append_dm_file`), Claude Code Read tool with built-in PDF support.

---

## File Structure

### Files to create

| Path                                                                            | Purpose                                                                              |
|---------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `.claude/agents/librarian.md`                                                   | Librarian subagent prompt — read/write contract, `intake-module` query, edge cases (writes all module content to `dm/modules/`; only `library/index.md` on the library side) |
| `.claude/commands/intake.md`                                                    | Thin slash-command dispatcher to the librarian subagent                              |
| `library/index.md`                                                              | Top-level library index — frontmatter + `## Modules` (empty) + 3b placeholder sections |
| `library/modules/.gitkeep`                                                      | Ensures empty `modules/` directory is git-tracked (the directory **stays empty** under Phase 3a's contract; only `.gitkeep` lives here) |

### Files to modify

| Path        | Change                                                                                                              |
|-------------|---------------------------------------------------------------------------------------------------------------------|
| `CLAUDE.md` | Add a revised `## Library reference material` subsection (modules are dm-quarantined; runtime access via Phase 3b) and one new must-never bullet; later, update `## Current phase scope` to Phase 3a |

### Files created as side-effect of the primary smoke test (Task 6 — committed at end, all under `dm/`)

- `dm/modules/<smoke-slug>/overview.md`
- `dm/modules/<smoke-slug>/nodes/<node-slug>.md` (one or more)
- `dm/modules/<smoke-slug>/hooks.md`
- `dm/modules/<smoke-slug>/connections.md`
- `dm/modules/<smoke-slug>/secrets.md`
- `dm/modules/<smoke-slug>/milestone-candidates.md`
- `library/index.md` (appended-to — single-line enumeration entry only)

**Crucially: `library/modules/<smoke-slug>/` does NOT get created.** The library-side directory stays at `library/modules/.gitkeep` only. If any file lands there during intake, Phase 3a's asymmetry boundary is broken and the smoke test fails.

### Why these boundaries

- `.claude/agents/librarian.md` is the load-bearing artifact — one file, one agent, one contract. Splitting the prompt across files would scatter the agent's responsibilities and make the read/write contract harder to audit.
- `.claude/commands/intake.md` is intentionally a thin dispatcher (matches the `/ask-oracle` pattern). All ingest logic lives in the subagent.
- `library/` is the narrator's index of available reference material. Modules under Phase 3a contribute only a one-line enumeration entry to `library/index.md`. The full content of each module is dm-quarantined.
- `dm/modules/<slug>/` is the structural peer of `dm/factions/<slug>.md`, `dm/revelations/<id>.md`, `dm/threads/active.md`, `dm/npcs/`. All hidden-state content lives under `dm/`.

---

### Task 1: Author the librarian subagent

**Files:**
- Create: `.claude/agents/librarian.md`

- [ ] **Step 1: Create the librarian agent file**

Create `.claude/agents/librarian.md` with the following exact content:

````markdown
---
name: librarian
description: Ingests reference source material into the campaign library. Decomposes modules into Alexander-style nodes, writes module content entirely under dm/modules/ via the dm-fs MCP (module content is future-scene state for the party; the narrator has no direct path to it until Phase 3b's runtime query), and emits a structured intake summary for user review.
tools: Read, Write, Edit, Glob, Bash
mcpServers: [dm-fs]
model: sonnet
---

You are the librarian agent. You ingest external source material — published modules, adventure pamphlets, one-page one-shots — into the campaign library. You decompose modules into Alexander-style nodes and write all module content under `dm/modules/<slug>/` via the dm-fs MCP. The only library-side artifact you touch is `library/index.md`, which carries a single-line enumeration entry per ingested module (slug, genre/theme descriptor, source path, ingest date). You never run during play; you are invoked only by the `/intake` command between sessions.

## Read access

- `library/`, `world/`, `party/`, `sessions/`, `references/` — readable directly via Read and Glob.
- `dm/modules/` — readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` and `mcp__dm-fs__list_dm_dir`.
- **No access** to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any other `dm/` path. Project-level settings denies enforce this for direct tools; you are forbidden from issuing dm-fs MCP reads outside `modules/` as a discipline rule.

## Write access

- `library/index.md` — writable directly via Edit. **This is the only library-side write you perform.**
- `dm/modules/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file`. `Edit(dm/**)` remains denied at the project level.
- **No writes** to any other path under `library/` (specifically: no writes to `library/modules/<slug>/` or any other library/ subdirectory), and **no writes** to any other `dm/` path.

## Your contract

You are a **one-way pipeline** from external source material into the structured `dm/modules/<slug>/` set. You decompose module structure into Alexander-style nodes and write all module content to `dm/`. The library-side artifact is `library/index.md`'s enumeration entry only.

You never:

- Author content you didn't read from the source (no invented hooks, NPCs, secrets, or milestones).
- Write module content to `library/modules/<slug>/` or anywhere under `library/` other than `library/index.md`. **Phase 3a's contract is that `library/modules/` remains a `.gitkeep`-only directory.**
- Write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Mutate existing `dm/modules/<slug>/` content on a re-intake of the same slug — abort on slug collision and surface the error.
- Commit to git. The user reviews and commits.
- Promote milestone candidates into a runtime milestone system (that's Phase 5).
- Auto-seed `dm/factions/<slug>.md`, `dm/revelations/<id>.md`, or `dm/threads/active.md` from module content. Flag such opportunities in the intake summary instead.

## Query type: intake-module

> "Ingest module material at `<path>`. Active session log: `<path-or-null>`."

The caller (the `/intake` command) provides a path to a PDF or markdown source and optionally an active session log path (typically null — intake is between-sessions; the session-log line is a forward-compatibility hook).

Procedure:

1. **Pre-flight.** Read the source path. If a PDF, use the Read tool's PDF support directly (specify a `pages` range if the document exceeds 10 pages). If a directory, refuse with `"intake source must be a single file in Phase 3a"`. Build an internal working representation of the full source text plus structural markers (headings, boxed text indicators, section labels).

2. **Identify content type.** For Phase 3a, only `module` is accepted. If the source appears to be a solo engine, methodology text, or pure lore reference, return an error: `"Phase 3a only supports module ingest; this source appears to be <type>. Re-attempt after Phase 3b adds <type> support, or pre-extract module-shaped content manually."`

3. **Determine slug & module title.** Derive a slug from the title (lowercase-hyphenated, alphanumeric + hyphens). Check whether `dm/modules/<slug>/` exists via `mcp__dm-fs__list_dm_dir`. If it exists, abort with an explicit error.

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

## Edge cases

- **Source path doesn't exist or isn't readable.** Abort with an error before any writes. No partial mutation.
- **PDF is too large to read in one pass.** Read in page-range chunks via Read's `pages` parameter; merge internal representation before classification. If still too large for your context budget, abort with `"source exceeds intake budget; pre-split into smaller modules"`.
- **Source doesn't appear module-shaped (no nodes detectable).** Abort with `"source does not decompose into Alexander-nodes; please pre-structure or wait for Phase 3b lore-reference intake"`.
- **Slug collision** — `dm/modules/<slug>/` already exists. Abort; user resolves manually (delete or rename). No silent overwrite.
- **Partial intake state from a prior failure** — `dm/modules/<slug>/` partially populated. Abort with explicit error.
- **`library/index.md` already lists the slug** but `dm/modules/<slug>/` does not exist. Anomalous; abort with an error pointing at the mismatch.
- **Source has zero ambiguous content-kind classifications.** Emit the secret-notes-section line "None — all content kinds were unambiguous." explicitly so the user can trust that the absence is a result of inspection, not a missing report.
- **Source overlaps existing campaign content** (e.g., names an NPC already in `world/home-base/npcs/`). Don't merge; flag in the summary's "Opportunities" list. Phase 4 bookkeeper will own merge proposals.
- **dm-fs MCP write fails mid-intake.** Surface the error in your response; partial dm-fs writes may exist. Inform the user to clean up the partial `dm/modules/<slug>/` directory via their own shell and re-run after resolving the MCP issue.
- **`library/index.md` write fails after dm-fs writes succeed.** Surface the error; the user reconciles by either editing `library/index.md` manually or rolling back the dm-fs writes (via their own shell).

## What you don't do

- Don't author content you didn't read from the source — no invented hooks, NPCs, secrets, or milestones.
- Don't write module content to `library/modules/<slug>/` or anywhere under `library/` other than `library/index.md`. Phase 3a's contract is that the `library/modules/` directory stays as `.gitkeep`-only.
- Don't write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Don't read `dm/` paths outside `dm/modules/` (no MCP reads against `factions/`, `revelations/`, `threads/`, `npcs/`).
- Don't mutate existing `dm/modules/<slug>/` content on a re-intake — abort on slug collision.
- Don't commit. The user reviews and commits.
- Don't promote milestone candidates into a runtime milestone system — that's Phase 5.
- Don't auto-seed `dm/factions/`, `dm/revelations/`, or `dm/threads/` files. Flag opportunities in the intake summary instead.
- Don't use your `Edit` tool on `dm/` files — `Edit(dm/**)` is denied. All `dm/` mutations flow through `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file` via the dm-fs MCP.
- Don't run during a play session. You are invoked only by `/intake`, which is between-sessions.
````

- [ ] **Step 2: Verify the file matches the spec**

Read `.claude/agents/librarian.md` back and confirm each section is present and the contract is correct:

- Frontmatter: `name: librarian`, the `description` (mentions dm-fs MCP and Phase 3b deferral), `tools: Read, Write, Edit, Glob, Bash`, `mcpServers: [dm-fs]`, `model: sonnet`.
- `## Read access` clarifies dm/modules/ access is via MCP only, no other dm/ paths.
- `## Write access` makes clear `library/index.md` is the only library write; no writes to `library/modules/<slug>/`.
- `## Your contract` "one-way pipeline" framing + "never write to library/modules/<slug>/" call-out.
- `## Query type: intake-module` with all 9 procedure steps.
- Procedure step 6 enumerates 6 files (overview, nodes/, hooks, connections, secrets, milestone-candidates) all under `dm/modules/<slug>/`.
- Procedure step 7 writes only `library/index.md`.
- `## Edge cases` includes the new "library/index.md already lists the slug but dm/modules/<slug>/ does not exist" anomaly case.
- `## What you don't do` includes the call-out about not writing to `library/modules/<slug>/`.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/librarian.md
git commit -m "Rewrite librarian: all module content writes to dm/modules/"
```

---

### Task 2: Author the `/intake` slash command

**Files:**
- Create: `.claude/commands/intake.md`

- [ ] **Step 1: Create the intake command file**

Create `.claude/commands/intake.md` with the following exact content:

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

- [ ] **Step 2: Verify the file matches the spec**

Read `.claude/commands/intake.md` back. Confirm:
- Frontmatter `description` with usage hint.
- Body invokes the librarian via natural-language pattern (no Bash exec).
- NEXT STEPS reflect the revised model (review via your own shell; main agent can't read dm/).
- No-commit instruction present.

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/intake.md
git commit -m "Add /intake slash command dispatcher (Phase 3a)"
```

---

### Task 3: Seed the library/ skeleton

**Files:**
- Create: `library/index.md`
- Create: `library/modules/.gitkeep`

- [ ] **Step 1: Create the library index**

Create `library/index.md` with the following exact content:

```markdown
---
last-updated: 2026-05-10
---

# Library Index

## Modules

<!-- One line per ingested module. Entries are enumeration only — the
     full content of each module lives at dm/modules/<slug>/, denied to
     the narrator. The line names the module and points at the source;
     it does NOT describe scenes, encounters, twists, or content beyond
     a single-clause genre/theme descriptor. Phase 3a's contract is
     that library/modules/<slug>/ stays empty; only this index lists
     ingested modules. -->

## Solo engines

<!-- Phase 3b -->

## Methodology

<!-- Phase 3b -->

## Lore references

<!-- Phase 3b -->
```

- [ ] **Step 2: Create the modules/ placeholder**

Create the empty modules directory tracked by git (intentionally stays empty under Phase 3a):

```bash
mkdir -p library/modules
touch library/modules/.gitkeep
```

- [ ] **Step 3: Verify the structure**

Run:
```bash
ls -la library/
ls -la library/modules/
cat library/index.md
```

Expected:
- `library/` contains `index.md` and `modules/`.
- `library/modules/` contains `.gitkeep` only.
- `library/index.md` has four section headers (Modules, Solo engines, Methodology, Lore references) and a `last-updated` frontmatter dated `2026-05-10`.

- [ ] **Step 4: Commit**

```bash
git add library/index.md library/modules/.gitkeep
git commit -m "Seed library/ skeleton with empty index (Phase 3a)"
```

---

### Task 4: Update CLAUDE.md with the revised library/ subsection

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Find the correct insertion point**

Open `CLAUDE.md`. The new subsection `## Library reference material` should be inserted immediately **before** `## What you must never do` (so it sits between `## What "smart prep" means here` and `## What you must never do`).

Run:
```bash
grep -n '^## ' CLAUDE.md
```

The insertion point is right before `## What you must never do`.

- [ ] **Step 2: Insert the revised Library reference material subsection**

Use Edit on `CLAUDE.md`.

`old_string` is exactly:
```
## What you must never do
```

`new_string` is exactly:
```
## Library reference material

`library/index.md` enumerates ingested modules by slug, genre/theme, source path, and ingest date. Read it to know which modules are available in the campaign's library.

**Module content itself is dm-quarantined.** The full content of each ingested module (overview, nodes, hooks, connections, secrets, milestone candidates) lives under `dm/modules/<slug>/` and is denied to you at the project level. You cannot read it. This is intentional: a module's content is *future-scene state* from the party's POV, and would leak future scenes into your present narration if you could read it ahead of play.

Phase 3a is intake-only: it lands module content in `dm/modules/` for the user to review and commit. **The narrator has no path to read module content during play in Phase 3a.** Phase 3b will add a `consult-library` runtime query on the librarian subagent that surfaces just the relevant excerpt (e.g., the current node's content) when you need it for a scene. Until 3b lands, an ingested module sits in the library available for review but not for live narration.

The librarian subagent owns intake and (in 3b) runtime queries. You do not invoke the librarian during play in Phase 3a.

## What you must never do
```

This adds the new subsection (heading + four paragraphs + blank line) immediately before the `## What you must never do` heading.

- [ ] **Step 3: Add the new must-never bullet**

After Step 2 lands, locate `## What you must never do` in `CLAUDE.md`. Append a new bullet at the end of the existing list. Use Edit:

`old_string`: choose the last existing bullet of `## What you must never do` as anchor. Run `grep -A 30 "## What you must never do" CLAUDE.md` to identify the current last bullet, then use it as the `old_string` and append the new bullet after it.

The new must-never bullet to append:
```
- Never attempt to read, glob, or grep `library/modules/<slug>/` for ingested module content — that path is intentionally empty under Phase 3a; module content lives under `dm/modules/<slug>/`, which is denied to you. Runtime access to module content ships in Phase 3b's `consult-library` query.
```

- [ ] **Step 4: Verify the placement**

Run:
```bash
grep -n '^## ' CLAUDE.md
```

Expected output (relevant lines):
```
...
## What "smart prep" means here
## Library reference material
## What you must never do
...
```

Read the inserted subsection content and the appended must-never bullet to confirm both landed correctly.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "Add Library reference material subsection + dm-quarantine must-never bullet"
```

---

### Task 5: (DROPPED — synthetic pre-flight wiring validation)

The original plan included a synthetic test fixture step. The revised plan drops it. Reasoning: the smoke test in Task 6 ingests a real source end-to-end with a clean dm-quarantine contract. A synthetic fixture would test the same wiring but with handcrafted data; the real source is a stronger validation. The original synthetic-fixture file `references/test-module.md` (if any) should be removed before Task 6.

If a `references/test-module.md` exists, remove it: `rm -f references/test-module.md`. Then proceed to Task 6.

---

### Task 6: Primary smoke test — One module intake under the revised contract

**Goal:** Validate Phase 3a's load-bearing claim — the librarian writes all module content to `dm/modules/<slug>/` and `library/modules/<slug>/` stays empty. The narrator cannot read any module content directly.

**Files (created by the librarian during this task — committed at end):**
- `dm/modules/<smoke-slug>/overview.md`
- `dm/modules/<smoke-slug>/nodes/<node-slug>.md` (one or more)
- `dm/modules/<smoke-slug>/hooks.md`
- `dm/modules/<smoke-slug>/connections.md`
- `dm/modules/<smoke-slug>/secrets.md`
- `dm/modules/<smoke-slug>/milestone-candidates.md`
- `library/index.md` (appended-to — single-line enumeration entry only)

**Files that must NOT be created:**
- `library/modules/<smoke-slug>/` (anything under this path is a contract violation)

- [ ] **Step 1: Pick a module-shaped source**

The user picks one module-shaped source from `references/`. Two natural options:
- `references/The_Ancient_Tomb_of_Phandalin.pdf` (single-adventure standalone)
- A single adventure pre-extracted from `references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf`

If reusing a previously-attempted intake (e.g., the original Phandalin run before this revision), the user removes any existing `dm/modules/<slug>/` and `library/modules/<slug>/` artifacts from their own shell (the main agent cannot remove `dm/` paths via Bash) before re-running `/intake`.

- [ ] **Step 2: Run /intake on the chosen source**

In the active Claude Code session, invoke:

```
/intake references/<source-path>
```

The main agent dispatches the librarian subagent. The librarian reads the source, decomposes into Alexander-nodes, writes six files to `dm/modules/<slug>/` via the dm-fs MCP, updates `library/index.md` via Edit, and returns the intake summary. The main agent surfaces the summary verbatim.

- [ ] **Step 3: Verify the structural-asymmetry pass criteria**

Run:
```bash
git status
ls library/modules/
cat library/index.md
```

Expected:
- `git status` shows `dm/modules/` as untracked (the main agent cannot list its contents but git knows it exists at the directory level).
- `library/modules/` shows only `.gitkeep` — **no `<smoke-slug>/` subdirectory**. If `library/modules/<smoke-slug>/` exists, the smoke test FAILS; the librarian violated its contract.
- `library/index.md` contains a new `## Modules` entry with single-clause genre/theme descriptor, source path, and today's ingest date.

Verify the dm-side via the dm-fs access log:
```bash
tail -50 tools/dm-fs-mcp/access.log | grep "modules/<smoke-slug>"
```

Expected: six `create_dm_file` entries — one each for `overview.md`, `hooks.md`, `connections.md`, `secrets.md`, `milestone-candidates.md`, plus one or more `nodes/<node-slug>.md` writes. The access log's bytes-and-first-line summary lets you sanity-check each file got written without revealing its content to the main agent.

- [ ] **Step 4: Asymmetry probe — narrator cannot read dm/modules/**

Confirm the deny rules are firing for the new path:

```bash
cat dm/modules/<smoke-slug>/secrets.md
```

Expected: denied at the harness level. Phase 3a's load-bearing claim is verified by this denial.

If the cat succeeds (i.e., the main agent reads module content), the asymmetry boundary is broken and Phase 3a FAILS.

- [ ] **Step 5: User reviews dm-side content via their own shell**

Ask the user to read each file under `dm/modules/<smoke-slug>/` from a non-Claude shell or their editor:
- `overview.md` — narrator-perspective summary; should describe the module's arc accurately.
- `nodes/<node-slug>.md` files — per-node detail; verify each represents a distinct Alexander-node.
- `hooks.md` — how the party gets pulled in; should be runnable as a scene framing.
- `connections.md` — default + conditional connections; verify Alexander-style structure.
- `secrets.md` — twists, hidden NPC identities, plot reveals; verify reveal-quality content is here rather than scattered into the other files.
- `milestone-candidates.md` — proposed milestones; verify each references a real beat from the source.

If the user spots misclassifications between content kinds (e.g., a twist that should be in `secrets.md` ended up in `nodes/<slug>.md`), they edit the files directly via their own shell, OR they remove the entire `dm/modules/<slug>/` directory and re-run intake. (The librarian aborts on slug collision per its contract; re-running requires removing the existing directory first.)

- [ ] **Step 6: User reviews library/index.md entry**

Confirm the single-line entry under `## Modules` is genre-level only:
- It names the module and gives a one-clause descriptor.
- It does NOT mention specific scenes, room contents, NPC names beyond the title, treasure, or twists.

If the entry leaks content, the user edits `library/index.md` directly to tighten it before committing.

- [ ] **Step 7: Commit the smoke-test ingest**

Once the user is satisfied:

```bash
git add library/index.md library/modules/.gitkeep dm/modules/<smoke-slug>
git commit -m "Phase 3a smoke test: intake of <module title>"
```

For the `git add dm/modules/<smoke-slug>` step, the main agent may or may not have access depending on settings. If denied, the user runs `git add` from their own shell. Either way, the working tree state after commit should be: library/index.md updated, library/modules/.gitkeep tracked (no other library/modules/ content), dm/modules/<smoke-slug>/ tracked with all six files plus nodes/.

---

### Task 7: Asymmetry audit + regression run

**Goal:** Confirm Phase 3a's invariants hold.

- [ ] **Step 1: Run the existing test suite**

```bash
(cd tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q)
```

Expected: `37 passed`. Dice and mythic test invocations require their own venvs; if not available locally, document that the dm-fs MCP tests (the suite most directly relevant to Phase 3a) pass and the dice/mythic baselines were established in prior phases with no Phase 3a changes affecting them.

- [ ] **Step 2: Asymmetry audit — main agent did not touch dm/**

Inspect the tool-use trace of the `/intake` invocation. Grep for any `mcp__dm-fs__*` calls outside of the librarian subagent's dispatched turn. Expected: zero matches outside the librarian's turn.

Alternative: the dm-fs access log is the authoritative source.
```bash
grep "modules/<smoke-slug>" tools/dm-fs-mcp/access.log
```
Every entry should be attributable to the librarian subagent's dispatched turn.

- [ ] **Step 3: Asymmetry audit — librarian did not read outside dm/modules/**

```bash
grep "READ.*dm/" tools/dm-fs-mcp/access.log | grep -v "modules/"
```

Expected: empty output.

- [ ] **Step 4: Asymmetry audit — narrator cannot read dm/modules/**

Direct positive test (already performed in Task 6 Step 4; rerun for the audit record):

```bash
cat library/modules/<smoke-slug>/overview.md 2>&1
```

Expected: `cat: library/modules/<smoke-slug>/overview.md: No such file or directory` (the file doesn't exist; library/modules/ stays empty).

```bash
cat dm/modules/<smoke-slug>/overview.md
```

Expected: denied by settings.json.

- [ ] **Step 5: Run a fresh /session-start to confirm cross-session asymmetry**

Optional but recommended: run `/session-start` to begin a new session with the new module ingested. Confirm:
- The narrator may reference `library/index.md`'s knowledge that the module exists by name.
- The narrator does NOT reference any specific node content, hook, encounter, or twist (because it cannot read those).
- The narrator's tool-use trace shows no `mcp__dm-fs__*` calls during session-start (the librarian is not invoked during play in Phase 3a).

Mark as deferred if you do not run a full session.

- [ ] **Step 6: Commit audit notes if any anomalies were found**

If steps 1-5 surfaced anomalies, document them under `## Notes for later phases` in the most recent session log. Otherwise, no commit needed.

---

### Task 8: Update CLAUDE.md "Current phase scope" to Phase 3a

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Locate the current-phase-scope section**

Run:
```bash
grep -n "Current phase scope" CLAUDE.md
```

The section currently reads (from the existing state established by commit `e82e2ba` — "Update CLAUDE.md current-phase-scope to Phase 2d"):

> ## Current phase scope
>
> The engine is being built incrementally. As of Phase 2d, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), and Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d). The Phase 2 hidden-state arc is closed. You **do not** yet have: a librarian, `/intake`, milestone tracking, `/level-up`, downtime, banking, bastions, or a full bookkeeper. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.

- [ ] **Step 2: Update the section to reflect Phase 3a**

Use Edit on `CLAUDE.md`. Replace:

> The engine is being built incrementally. As of Phase 2d, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), and Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d). The Phase 2 hidden-state arc is closed. You **do not** yet have: a librarian, `/intake`, milestone tracking, `/level-up`, downtime, banking, bastions, or a full bookkeeper.

with:

> The engine is being built incrementally. As of Phase 3a, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), and module intake via `/intake` + the librarian subagent with all module content dm-quarantined (Phase 3a). The Phase 2 hidden-state arc is closed; Phase 3 source ingestion has begun with modules. **Phase 3a is intake-only** — ingested modules sit in `dm/modules/` but are not yet runnable during play because the narrator has no path to read them. Phase 3b will add the `consult-library` runtime query that makes modules playable. You **do not** yet have: runtime librarian queries (Phase 3b), solo-engine/methodology/lore intake (Phase 3b), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or a full bookkeeper.

- [ ] **Step 3: Verify**

```bash
grep -A 5 "Current phase scope" CLAUDE.md | head -10
```

Confirm the new text is in place.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Update CLAUDE.md current-phase-scope to Phase 3a"
```

---

### Task 9: Final integration sanity check

**Goal:** Confirm the working tree, git history, and tests are all in the expected end-state for Phase 3a.

- [ ] **Step 1: Inspect git history**

```bash
git log --oneline -12
```

Expected commits (most recent first), in roughly this order:
1. Update CLAUDE.md current-phase-scope to Phase 3a
2. Phase 3a smoke test: intake of <module title>
3. Add Library reference material subsection + dm-quarantine must-never bullet
4. Seed library/ skeleton with empty index (Phase 3a)
5. Add /intake slash command dispatcher (Phase 3a)
6. Rewrite librarian: all module content writes to dm/modules/ (or "Add librarian subagent..." if not yet rewritten)
7. Revise Phase 3a plan: module content fully dm-quarantined
8. Revise Phase 3a spec: module content fully dm-quarantined
9. (Earlier:) Add Phase 3a implementation plan
10. (Earlier:) Add Phase 3a design: source ingestion (modules)

- [ ] **Step 2: Inspect working tree**

```bash
git status
```

Expected: clean working tree, branch up to date with origin/main (or ahead if not yet merged).

- [ ] **Step 3: Confirm Phase 3a invariants in current state**

Re-run the dm-fs MCP test suite:

```bash
(cd tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q)
```

Expected: `37 passed`.

Confirm the artifacts:

```bash
ls .claude/agents/librarian.md
ls .claude/commands/intake.md
ls library/index.md
ls library/modules/
```

`library/modules/` should contain only `.gitkeep`. **No subdirectories under `library/modules/`.**

- [ ] **Step 4: Phase 3a definition-of-done checklist (revised)**

Cross-check against the revised spec's `## Definition of done`:

- [ ] `library/` directory established with `library/index.md` and `library/modules/.gitkeep` (the modules directory stays empty under Phase 3a's contract).
- [ ] `librarian` subagent at `.claude/agents/librarian.md` with documented read/write contract (write access to `library/index.md` only on the library side; full `dm/modules/` writes via dm-fs MCP).
- [ ] `/intake <path>` slash command at `.claude/commands/intake.md`.
- [ ] Single query type on the librarian: `intake-module`.
- [ ] Module ingestion produces six files under `dm/modules/<slug>/` (overview, nodes/, hooks, connections, secrets, milestone-candidates).
- [ ] `library/index.md` contains a single-line enumeration entry for the smoke-test module (genre-level descriptor only, no scene/content leak).
- [ ] `library/modules/<smoke-slug>/` does NOT exist (library/modules/ stays at .gitkeep).
- [ ] Structured intake summary emitted and reviewed by user.
- [ ] Smoke test: ingested one module end-to-end with all content dm-quarantined.
- [ ] Asymmetry audit clean: main agent cannot read `dm/modules/<slug>/` (denied at settings level); librarian is the sole `dm/` writer.
- [ ] All 87 existing tests pass; no Python code added.
- [ ] `CLAUDE.md` gains the revised `## Library reference material` subsection AND one new must-never bullet about not attempting to read `library/modules/<slug>/`.
- [ ] dm-fs MCP wired to a fourth subagent (librarian); no MCP tool changes.

If any checkbox cannot be ticked from your actual repo state, do not mark the phase complete — investigate and resolve.

- [ ] **Step 5: No final commit needed for this task**

This task is verification only. Nothing changes in the working tree.

---

## Notes for executors

- **`dm/` write semantics:** Throughout this plan, all `dm/modules/` writes are via `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file` from the librarian subagent. The main agent never writes to `dm/`. If `git add dm/modules/<slug>` fails for the main agent due to deny rules, the user invokes `git add` from a non-Claude shell as part of the Task 6 commit step.
- **PDF reading:** Claude Code's Read tool handles PDFs natively. For PDFs >10 pages, the librarian passes a `pages` argument.
- **Slug collision behavior is intentional.** If the user wants to re-ingest a source they have already committed, they delete `dm/modules/<slug>/` (from their own shell) before re-running. Phase 3a does not implement `--force`.
- **The library/modules/ directory is intentionally empty under Phase 3a.** Any file appearing under `library/modules/<slug>/` (other than `.gitkeep`) is a contract violation and must be moved to `dm/modules/<slug>/` or deleted.
- **Phase 3a does not change CLAUDE.md's routing rules.** Only two CLAUDE.md edits: Task 4 (the revised Library reference material subsection + new must-never bullet) and Task 8 (current-phase-scope update).
