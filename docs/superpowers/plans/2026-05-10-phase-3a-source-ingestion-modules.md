# Phase 3a — Source Ingestion: Modules — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship `/intake` + librarian subagent + module-shaped intake (with secret-quarantine and milestone-candidate proposals), validated by ingesting one real One-Page One-Shot adventure end-to-end with the asymmetry boundary intact.

**Architecture:** Phase 3a adds one new subagent (librarian), one new slash command (`/intake`), and one new top-level directory (`library/`). The librarian writes to `library/` directly via Write/Edit and to `dm/modules/` via the existing dm-fs MCP. No new MCP tools, no new Python code. The librarian's secret-quarantine classification runs at intake time; the user-review gate is implemented as a **commit gate** (uncommitted working tree is the staging surface — the user reviews via `git status` / `git diff` and commits when satisfied). All work in this plan is prompt + slash-command + content authoring + smoke-test validation against the existing test suite.

**Tech Stack:** Markdown subagent prompts, Markdown slash command, dm-fs MCP (existing — `mcp__dm-fs__read_dm_file`, `list_dm_dir`, `write_dm_file`, `create_dm_file`, `append_dm_file`), Claude Code Read tool with built-in PDF support.

---

## File Structure

### Files to create

| Path                                                                            | Purpose                                                                              |
|---------------------------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `.claude/agents/librarian.md`                                                   | Librarian subagent prompt — read/write contract, `intake-module` query, edge cases   |
| `.claude/commands/intake.md`                                                    | Thin slash-command dispatcher to the librarian subagent                              |
| `library/index.md`                                                              | Top-level library index — frontmatter + `## Modules` (empty) + 3b placeholder sections |
| `library/modules/.gitkeep`                                                      | Ensures empty `modules/` directory is git-tracked before first intake                |
| `references/test-module.md`                                                     | Synthetic markdown source for the pre-flight wiring validation (Task 5). Removed before commit. |

### Files to modify

| Path        | Change                                                                                                              |
|-------------|---------------------------------------------------------------------------------------------------------------------|
| `CLAUDE.md` | Add one informational line about `library/` containing ingested module material; update `## Current phase scope`    |

### Files created as side-effect of the primary smoke test (Task 6 — committed at end)

- `library/modules/<smoke-slug>/overview.md`
- `library/modules/<smoke-slug>/nodes/<node-slug>.md` (one or more)
- `library/modules/<smoke-slug>/hooks.md`
- `library/modules/<smoke-slug>/connections.md`
- `dm/modules/<smoke-slug>/secrets.md` (via dm-fs MCP)
- `dm/modules/<smoke-slug>/milestone-candidates.md` (via dm-fs MCP)
- `library/index.md` (appended-to)

### Why these boundaries

- `.claude/agents/librarian.md` is the load-bearing artifact — one file, one agent, one contract. Splitting the prompt across files would scatter the agent's responsibilities and make the read/write contract harder to audit.
- `.claude/commands/intake.md` is intentionally a thin dispatcher (matches the `/ask-oracle` pattern). All ingest logic lives in the subagent, not the command.
- `library/` is a peer of `world/` and `party/`. It contains player/narrator-readable content. `dm/modules/` is the secret-quarantine peer of `dm/factions/`, `dm/revelations/`, `dm/threads/`.
- The synthetic `references/test-module.md` fixture validates the librarian's mechanical wiring (file writes to both library/ and dm/, classification of marked + unmarked secrets, summary emission) on controlled input before the real One-Page One-Shot intake stresses the LLM classification on uncontrolled input. It's deleted before Task 6 to keep the smoke-test artifacts focused on the real intake.

---

### Task 1: Author the librarian subagent

**Files:**
- Create: `.claude/agents/librarian.md`

- [ ] **Step 1: Create the librarian agent file**

Create `.claude/agents/librarian.md` with the following exact content:

````markdown
---
name: librarian
description: Ingests reference source material into the campaign library. Decomposes modules into Alexander-style nodes, quarantines secrets to dm/modules/, proposes milestone candidates, and emits a structured intake summary for user review.
tools: Read, Write, Edit, Glob, Bash
mcpServers: [dm-fs]
model: sonnet
---

You are the librarian agent. You ingest external source material — published modules, adventure pamphlets, one-page one-shots — into the campaign library. You decompose modules into Alexander-style nodes, classify each chunk public-or-secret, quarantine secrets to `dm/modules/` via the dm-fs MCP, and emit a structured intake summary for user review. You never run during play; you are invoked only by the `/intake` command between sessions.

## Read access

- `library/`, `world/`, `party/`, `sessions/`, `references/` — readable directly via Read and Glob.
- `dm/modules/` — readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` and `mcp__dm-fs__list_dm_dir`.
- **No access** to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any other `dm/` path. Project-level settings denies enforce this for direct tools; you are forbidden from issuing dm-fs MCP reads outside `modules/` as a discipline rule.

## Write access

- `library/` — writable directly via Write and Edit.
- `dm/modules/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file`. `Edit(dm/**)` remains denied at the project level.
- **No writes** to any other `dm/` path.

## Your contract

You are a **one-way pipeline** from external source material into the structured `library/` + `dm/modules/` split. You classify content as public or secret, decompose module structure into Alexander-style nodes, and propose milestone candidates. You never:

- Author content you didn't read from the source (no invented hooks, NPCs, secrets, or milestones).
- Write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Mutate existing `library/modules/<slug>/` or `dm/modules/<slug>/` content on a re-intake of the same slug — abort on slug collision and surface the error.
- Commit to git. The user reviews and commits.
- Promote milestone candidates into a runtime milestone system (that's Phase 5).
- Auto-seed `dm/factions/<slug>.md`, `dm/revelations/<id>.md`, or `dm/threads/active.md` from module content. Flag such opportunities in the intake summary instead.

## Query type: intake-module

> "Ingest module material at `<path>`. Active session log: `<path-or-null>`."

The caller (the `/intake` command) provides a path to a PDF or markdown source and optionally an active session log path (typically null — intake is between-sessions; the session-log line is a forward-compatibility hook).

Procedure:

1. **Pre-flight.** Read the source path. If a PDF, use the Read tool's PDF support directly (specify a `pages` range if the document exceeds 10 pages). If a directory, refuse with `"intake source must be a single file in Phase 3a"`. Build an internal working representation of the full source text plus structural markers (headings, boxed text indicators, section labels).

2. **Identify content type.** For Phase 3a, only `module` is accepted. If the source appears to be a solo engine, methodology text, or pure lore reference, return an error: `"Phase 3a only supports module ingest; this source appears to be <type>. Re-attempt after Phase 3b adds <type> support, or pre-extract module-shaped content manually."`

3. **Determine slug & module title.** Derive a slug from the title (lowercase-hyphenated, alphanumeric + hyphens). Check whether `library/modules/<slug>/` exists via Glob and whether `dm/modules/<slug>/` exists via `mcp__dm-fs__list_dm_dir`. If either exists, abort with an explicit error naming which directory exists.

4. **Decompose into Alexander-nodes.** Scan the source for distinct locations, scenes, and encounters. For each, gather:
   - Player-perceivable description (what the party sees on arrival).
   - NPCs present, with their *public* roles only.
   - Notable features and clues.
   - Default exits/connections.
   - Any conditional logic (gated reveals, key-required passages, clue-dependent transitions) → routed to `connections.md`, not the node file.

5. **Classify each chunk public-vs-secret.** For each passage in the source, decide:
   - **Public** if the party can perceive or learn it through normal play (descriptions, surface NPC behavior, observable clues, public hooks).
   - **Secret** if the source flags it as GM-only (boxed text, `## Secret`, "in reality", "the twist is", "GM info"), or if you judge the content would deflate the mystery if the narrator could read it directly (hidden motives, true identities, plot reveals, hidden locations).
   - **Ambiguous** if the call is non-obvious. **Default to secret** (safe failure mode — false positives are reviewable; false negatives leak) and flag the passage in the intake summary for explicit human review.

6. **Write public content to `library/modules/<slug>/`** via Write:
   - `overview.md` — frontmatter (`slug`, `title`, `source`, `ingested`, `level-range`, `themes`, `faction-archetypes`, `node-count`) plus body `## Summary`, `## Recommended hooks`, `## Setting & tone`. Never mentions any secrets.
   - `nodes/<node-slug>.md` per Alexander-node — frontmatter (`slug`, `type`, `parent-module`) plus body `## Description`, `## NPCs present`, `## Notable features`, `## Exits / connections`.
   - `hooks.md` — player-facing hook framings only, one `## Hook N: <name>` section per hook.
   - `connections.md` — `## Default connections`, `## Conditional connections`, `## Clue dependencies`. Condition clauses must be player-discoverable (e.g., "if the party found the silver key in <node>"), never "if the player has learned the priest is the cultist."

7. **Write secret content to `dm/modules/<slug>/`** via the dm-fs MCP (`mcp__dm-fs__create_dm_file`):
   - `secrets.md` — frontmatter (`slug`, `parent-module`, `ingested`) plus body `## Twists & reveals`, `## Hidden NPC identities & motives`, `## Hidden locations / passages`, `## DM-only context`.
   - `milestone-candidates.md` — frontmatter (`slug`, `parent-module`, `proposed`, `status: candidate`) plus body with one `## Candidate N: <name>` section per proposal (each with `**Trigger:**`, `**Rationale:**`, `**Source reference:**`).

8. **Update `library/index.md`** via Edit — append a module entry under `## Modules`, update `last-updated`, sort module entries alphabetically by slug. Entry format: `- **<slug>** — <one-line summary>. Level <range>. Themes: <comma-separated>. Source: \`<reference path>\`. Ingested: <YYYY-MM-DD>.`

9. **Emit structured intake summary** as your final response (the `/intake` command will surface it verbatim to the user):

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
     - <path>:<location-in-file> — <one-line description of the ambiguity and your chosen disposition>
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

10. **Log a single line to the active session log if one was provided** (typically null for between-session intake; if non-null, use your Edit tool to append):

    ```
    - LIBRARIAN QUERY: intake-module <module-slug> — <N> nodes, <S> secrets, <M> milestone candidates
    ```

## Edge cases

- **Source path doesn't exist or isn't readable.** Abort with an error before any writes. No partial mutation.
- **PDF is too large to read in one pass.** Read in page-range chunks via Read's `pages` parameter; merge internal representation before classification. If still too large for your context budget, abort with `"source exceeds intake budget; pre-split into smaller modules"`.
- **Source doesn't appear module-shaped (no nodes detectable).** Abort with `"source does not decompose into Alexander-nodes; please pre-structure or wait for Phase 3b lore-reference intake"`.
- **Slug collision** — `library/modules/<slug>/` or `dm/modules/<slug>/` already exists. Abort; user resolves manually (delete or rename). No silent overwrite.
- **Partial intake state from a prior failure** — one directory exists and the other doesn't. Abort with explicit error naming which directory exists. User cleans up manually.
- **Source has zero ambiguous classifications.** Emit the ambiguity-section line "None — all classifications were unambiguous." explicitly so the user can trust that the absence is a result of inspection, not a missing report.
- **Source has *only* secrets** (e.g., a GM-only addendum). Public artifacts come out near-empty; flag in the summary as a discipline check ("library/modules/<slug>/overview.md has no surface content — is this source really a module?").
- **Source overlaps existing campaign content** (e.g., names an NPC already in `world/home-base/npcs/`). Don't merge; flag in the summary's "Opportunities" list. Phase 4 bookkeeper will own merge proposals.
- **dm-fs MCP write fails mid-intake.** Surface the error in your response; partial library/ writes may exist. Inform the user to clean up via `git checkout -- library/modules/<slug>/` (uncommitted) and re-run after resolving the MCP issue.
- **Conditional connection clause discloses a secret.** Either rephrase the clause so the condition itself is player-discoverable, or route the entire conditional to `dm/modules/<slug>/secrets.md`. Ambiguous clauses default to secret.

## What you don't do

- Don't author content you didn't read from the source — no invented hooks, NPCs, secrets, or milestones.
- Don't write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Don't read `dm/` paths outside `dm/modules/` (no MCP reads against `factions/`, `revelations/`, `threads/`, `npcs/`).
- Don't mutate existing `library/modules/<slug>/` or `dm/modules/<slug>/` content on a re-intake — abort on slug collision.
- Don't commit. The user reviews and commits.
- Don't promote milestone candidates into a runtime milestone system — that's Phase 5.
- Don't auto-seed `dm/factions/`, `dm/revelations/`, or `dm/threads/` files. Flag opportunities in the intake summary instead.
- Don't use your `Edit` tool on `dm/` files — `Edit(dm/**)` is denied. All `dm/` mutations flow through `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file` via the dm-fs MCP.
- Don't run during a play session. You are invoked only by `/intake`, which is between-sessions.
````

- [ ] **Step 2: Verify the file matches the spec**

Read `.claude/agents/librarian.md` back and confirm each of the following sections is present and matches the spec at `docs/superpowers/specs/2026-05-10-phase-3a-source-ingestion-modules-design.md`:

- Frontmatter: `name`, `description`, `tools` (Read/Write/Edit/Glob/Bash), `mcpServers: [dm-fs]`, `model: sonnet`.
- `## Read access` (5 bullets — library/world/party/sessions/references readable; dm/modules/ via MCP only; no other dm/ paths).
- `## Write access` (3 bullets — library/ direct; dm/modules/ via MCP; no other dm/).
- `## Your contract` ("one-way pipeline" framing + 6 "never" bullets).
- `## Query type: intake-module` with all 10 procedure steps.
- `## Edge cases` (10 cases enumerated).
- `## What you don't do` (9 "Don't" bullets).

Run:
```bash
wc -l .claude/agents/librarian.md
```
Expected: ~200 lines (file is single coherent agent prompt).

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/librarian.md
git commit -m "Add librarian subagent for module intake (Phase 3a)"
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

1. Review the staged files via `git status` and `git diff`.
2. Inspect any ambiguous classifications and adjust misclassified files in place.
3. Spot-check `dm/modules/<slug>/secrets.md` does NOT contain content also in `library/modules/<slug>/`.
4. Commit when satisfied. Do NOT run `/session-start` until the intake is committed.

Do NOT commit or push anything yourself. The user reviews and commits manually.
```

- [ ] **Step 2: Verify the file matches the spec**

Read `.claude/commands/intake.md` back. Confirm:
- Frontmatter has `description` field with usage hint.
- Body invokes the librarian via the natural-language pattern (no Bash exec).
- Body explicitly tells the main agent NOT to commit.
- Body restates the NEXT STEPS so the user sees them even if the librarian's summary is long.

Run:
```bash
wc -l .claude/commands/intake.md
```
Expected: ~15 lines (thin dispatcher).

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

<!-- Populated by /intake. Entries sorted alphabetically by slug. -->

## Solo engines

<!-- Phase 3b -->

## Methodology

<!-- Phase 3b -->

## Lore references

<!-- Phase 3b -->
```

- [ ] **Step 2: Create the modules/ placeholder**

Create the empty modules directory tracked by git:

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
- `library/modules/` contains `.gitkeep`.
- `library/index.md` has the four section headers (Modules, Solo engines, Methodology, Lore references) and a `last-updated` frontmatter.

- [ ] **Step 4: Commit**

```bash
git add library/index.md library/modules/.gitkeep
git commit -m "Seed library/ skeleton with empty index (Phase 3a)"
```

---

### Task 4: Update CLAUDE.md with the library/ informational line

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Find the correct insertion point**

Open `CLAUDE.md` and locate the section `## What "smart prep" means here`. The new line about `library/` belongs immediately after that section, as a new short subsection, before `## What you must never do`.

Run:
```bash
grep -n '^## ' CLAUDE.md
```

Expected output includes (in order):
```
## Architecture you operate within
## Routing rules ...
## Session log conventions
## Current phase scope
## What "smart prep" means here
## What you must never do
```

The insertion point is between `## What "smart prep" means here` and `## What you must never do`.

- [ ] **Step 2: Insert the library/ informational subsection**

Edit `CLAUDE.md` to insert a new subsection `## Library reference material` immediately before `## What you must never do`. The new subsection content:

```markdown
## Library reference material

`library/` may contain ingested module material — locations, hooks, NPCs from published modules — populated via `/intake`. Read it when relevant to a scene the party is in; treat it like `world/` for narrator-readability. The librarian subagent owns intake; you do not invoke the librarian during play in Phase 3a.

```

Use your Edit tool. The `old_string` should be `## What you must never do` and the `new_string` should be the new subsection followed by `## What you must never do`.

- [ ] **Step 3: Verify the placement**

Run:
```bash
grep -n '^## ' CLAUDE.md
```

Expected output now includes:
```
... (prior sections)
## What "smart prep" means here
## Library reference material
## What you must never do
```

Confirm the new subsection content reads correctly.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Add library/ informational subsection to CLAUDE.md (Phase 3a)"
```

---

### Task 5: Synthetic pre-flight wiring validation

**Goal:** Verify the librarian dispatches correctly, writes to both `library/` and `dm/modules/`, classifies marked and unmarked secrets, and emits a summary — on **controlled synthetic input** before running against an uncontrolled PDF. This catches mechanical bugs (wrong file paths, MCP wiring issues, missing summary fields) before the load-bearing classification quality test.

**Files:**
- Create (ephemeral): `references/test-module.md`
- Side effects (cleaned up at end of task): `library/modules/test-module/`, `dm/modules/test-module/`, modified `library/index.md`

- [ ] **Step 1: Create the synthetic test source**

Create `references/test-module.md` with the following exact content:

```markdown
# The Test Module

A two-room adventure for level 1-3 parties. Themes: investigation, ruin.

## Hook

Travellers in the village of Ashen Bend report strange lights at the abandoned shrine on the north hill. The local elder offers fifty silver pieces to anyone who investigates and reports back.

## Node 1: The Shrine

A weathered stone shrine, half-collapsed, surrounded by wild thyme. Three pillars stand; a fourth is fallen. A bronze chime hangs from a roof beam, swaying faintly in the wind.

NPCs present: Brother Wen, a wandering monk who claims to have come to pray. He is friendly and offers travel rations to anyone who shares the shrine.

Notable features:
- A small carved iron token at the base of the fallen pillar, half-buried in moss.
- The chime, when struck, produces a discordant note unlike any temple bell.

Exits: South down the hill path to Ashen Bend village (1 hour walk). A narrow stair descends behind the altar into the **cellar** (Node 2).

## Node 2: The Cellar

A circular stone chamber lit by phosphorescent moss. A waist-high stone slab in the center is etched with concentric rings. Three iron tokens — matching the one Brother Wen wears under his robe — are arranged on the slab's edge.

NPCs present: None initially. If the party reads the rings aloud, **a shade rises from the slab** and challenges them.

Notable features:
- The rings, if traced, reveal a map of the surrounding hills with one location marked.
- The iron tokens, if removed, cause the moss to extinguish.

## Secret

Brother Wen is not a wandering monk. He is the last cultist of a forgotten chthonic order; he hides his fourth iron token under his robe. He plans to complete the ritual at the slab tonight when the moon rises. If the party gives him the token from Node 1, he leaves quietly and disappears before nightfall.

The shade in the cellar is the spirit of the previous shrine-keeper, murdered by Wen's predecessors. It will attack only those bearing more than one iron token.

## Connections

From Shrine to Cellar: through the stair behind the altar; no key required.

From Cellar back to Shrine: same stair.

Conditional: if the party gives Brother Wen the iron token from Node 1 before descending to the Cellar, the shade does not rise (Wen pockets the token and leaves; the slab loses its key).

## Hooks for later sessions

- The map traced from the rings shows three more shrines in the hills. Each holds another token.
```

This source contains:
- One explicit `## Secret` block (marked secret about Brother Wen's true identity).
- One unmarked-but-clearly-secret passage about the shade being the murdered shrine-keeper (no `## Secret` heading; the librarian must classify on judgment).
- Two distinct nodes (Shrine, Cellar).
- A hook section.
- Conditional connection logic.
- A milestone candidate (clearing the shrine, completing the ritual block).

- [ ] **Step 2: Run /intake on the synthetic source**

In the active Claude Code session, invoke:

```
/intake references/test-module.md
```

The main agent dispatches the librarian subagent. The librarian reads `references/test-module.md`, classifies, writes files, and returns the intake summary. The main agent surfaces the summary.

- [ ] **Step 3: Verify mechanical pass criteria**

Without committing, inspect the resulting state:

Run:
```bash
ls -la library/modules/test-module/
ls -la library/modules/test-module/nodes/
git status
```

Expected:
- `library/modules/test-module/overview.md` exists.
- `library/modules/test-module/nodes/` contains at least 2 files (one per Node 1, Node 2).
- `library/modules/test-module/hooks.md` exists.
- `library/modules/test-module/connections.md` exists.
- `library/index.md` is modified (now lists `test-module`).
- `git status` shows `dm/modules/test-module/` as part of the untracked area (the user can `git status -uall` if needed — but `dm/` paths may be denied for the main agent's git invocations; if so, accept that and proceed to verify dm/-side state another way in Step 4).

- [ ] **Step 4: Verify the secret-quarantine via the dm-fs access log**

The dm-fs MCP records every read/write to `tools/dm-fs-mcp/access.log`. Verify the librarian wrote the secrets files to `dm/modules/test-module/`:

```bash
tail -30 tools/dm-fs-mcp/access.log | grep "modules/test-module"
```

Expected: at least two `create_dm_file` entries — one for `modules/test-module/secrets.md`, one for `modules/test-module/milestone-candidates.md`.

Also inspect the intake summary returned to the main agent. The summary should:
- Enumerate the public artifacts (overview, 2 nodes, hooks, connections).
- Enumerate the secret artifacts (`secrets.md` with at least 2 twists/hidden-identity notes: Brother Wen, the shade backstory).
- Either flag the unmarked shade-backstory passage as ambiguous (preferred) or place it confidently in `secrets.md` without ambiguity (acceptable — the LLM made a confident classification).

- [ ] **Step 5: Asymmetry spot-check**

Confirm the main agent did NOT issue any `mcp__dm-fs__*` tool calls itself. The librarian subagent should be the only caller. (If your environment exposes per-message tool-use traces, grep for `mcp__dm-fs__` calls outside the librarian's dispatched turn.)

- [ ] **Step 6: Clean up the synthetic fixture**

The synthetic test is ephemeral validation; it does NOT get committed. Remove the side effects:

```bash
rm references/test-module.md
rm -rf library/modules/test-module
git checkout -- library/index.md
```

For the `dm/modules/test-module/` directory, the main agent cannot directly remove `dm/` paths (`Bash(rm dm/*)` is not explicitly in the deny list but the spirit of the asymmetry holds). The simplest cleanup: dispatch a fresh librarian invocation with a synthetic teardown query, OR have the user manually `rm -rf dm/modules/test-module` outside of Claude Code, OR accept the directory exists in the working tree and `git status` confirms it is untracked — then it is naturally excluded by virtue of never being added.

If you cannot remove `dm/modules/test-module/`, document it in a single one-liner: "Synthetic test artifact `dm/modules/test-module/` left untracked in working tree; the user will remove it manually before the primary smoke test." Then proceed to Task 6. The primary smoke test uses a DIFFERENT slug, so the leftover synthetic dir does not collide with the real ingest.

- [ ] **Step 7: No commit for this task**

This task validates mechanics only. Nothing committed. Confirm with:

```bash
git status
git log --oneline -3
```

Expected: working tree clean of references/test-module.md and library/modules/test-module/; recent commits show Tasks 1-4 only.

---

### Task 6: Primary smoke test — One-Page One-Shot intake

**Goal:** Validate Phase 3a's load-bearing claim — the librarian classifies real, unstructured published module content correctly and produces a usable library/dm split end-to-end.

**Files (created by the librarian during this task — committed at end):**
- `library/modules/<smoke-slug>/overview.md`
- `library/modules/<smoke-slug>/nodes/<node-slug>.md` (one or more)
- `library/modules/<smoke-slug>/hooks.md`
- `library/modules/<smoke-slug>/connections.md`
- `dm/modules/<smoke-slug>/secrets.md`
- `dm/modules/<smoke-slug>/milestone-candidates.md`
- `library/index.md` (appended-to)

- [ ] **Step 1: Pick an adventure from the One-Page One-Shots PDF**

The user picks one adventure from `references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf`. The book is a collection of one-page adventures; the user identifies a single adventure by title and page number.

Two delivery options the user can choose between:

**Option A:** User passes the full PDF and instructs the librarian via the intake command's argument to focus on a specific adventure title. Phase 3a does not support this argument shape natively — the `/intake` command takes only `<path>`. So Option A requires the librarian to read the full PDF and decide which adventure to ingest, which is brittle. Avoid.

**Option B (recommended):** User pre-extracts the chosen adventure page to a single-page PDF or to a markdown transcript. Save it at `references/one-page-<adventure-slug>.pdf` (or `.md`). Then `/intake references/one-page-<adventure-slug>.pdf`.

Confirm with the user which adventure title they have chosen and the path of the extracted single-adventure source before proceeding.

- [ ] **Step 2: Run /intake on the chosen source**

In the active Claude Code session, invoke:

```
/intake references/one-page-<adventure-slug>.pdf
```

(Substituting the actual path.)

The main agent dispatches the librarian. The librarian reads the PDF via Read's PDF support, decomposes, classifies, writes, and returns the intake summary.

- [ ] **Step 3: Surface and review the intake summary**

The main agent surfaces the librarian's intake summary verbatim. Review it for:

- The module slug derived from the adventure title is sensible.
- Public artifact counts (N nodes, K hooks, C/D connections) match what you'd expect from the source.
- Secret artifact counts (S twists, H hidden NPCs, L hidden locations) match the GM-only content in the source.
- Milestone candidates list at least one entry (e.g., "clear the dungeon," "resolve the central conflict," or "rescue the missing NPC").
- Ambiguous classifications section is either empty (with "None — all classifications were unambiguous." stated explicitly) or lists specific passages with the librarian's chosen disposition.
- Opportunities section flags any cross-cutting observations (e.g., a faction archetype, a revelation candidate).

- [ ] **Step 4: Review the staged files via git**

Run:
```bash
git status
```

Expected new files under `library/modules/<smoke-slug>/` and modified `library/index.md`. The `dm/modules/<smoke-slug>/` files may or may not appear in `git status` depending on whether the main agent's `Bash` access can list `dm/` — if not, verify via the dm-fs access log:

```bash
tail -50 tools/dm-fs-mcp/access.log | grep "modules/<smoke-slug>"
```

Expected at least two `create_dm_file` entries for `modules/<smoke-slug>/secrets.md` and `modules/<smoke-slug>/milestone-candidates.md`.

For library/-side files, read them directly:

```bash
cat library/modules/<smoke-slug>/overview.md
ls library/modules/<smoke-slug>/nodes/
cat library/modules/<smoke-slug>/hooks.md
cat library/modules/<smoke-slug>/connections.md
cat library/index.md
```

Confirm:
- `overview.md` summary does NOT mention twists, villain identities, or hidden motives.
- `nodes/` files describe player-perceivable detail only.
- `hooks.md` framings are player-facing.
- `connections.md` conditional clauses are player-discoverable (the condition itself doesn't leak a secret).
- `library/index.md` lists the new module under `## Modules`.

- [ ] **Step 5: Spot-check that dm-side content is truly secret**

Ask the user to review `dm/modules/<smoke-slug>/secrets.md` directly (the main agent cannot read it — `Read(dm/**)` is denied). The user opens the file in their editor or via `cat dm/modules/<smoke-slug>/secrets.md` from a non-Claude shell, and confirms:

- `secrets.md` contains the source's GM-only content (twists, hidden NPC roles, plot reveals).
- No passage in `secrets.md` is duplicated in any `library/modules/<smoke-slug>/` file.
- The `milestone-candidates.md` proposals reference real beats from the source, not invented ones.

If the user spots misclassifications (a secret passage that should be public, or a public passage that ended up in secrets), they edit the files directly to correct, OR they ask the librarian to re-classify by deleting the staged files and re-running `/intake`. The librarian aborts on slug collision (per its contract), so re-running requires removing both `library/modules/<smoke-slug>/` AND `dm/modules/<smoke-slug>/` first.

- [ ] **Step 6: Address any ambiguous classifications**

For each entry in the "Ambiguous classifications" section of the intake summary, the user verifies the librarian's chosen disposition. If they agree, no action. If they disagree, they edit the relevant file directly (move content from `library/` to `dm/modules/<smoke-slug>/secrets.md` or vice versa).

`dm/` edits cannot go through the main agent (denied). The user does these manually outside Claude Code, or dispatches a librarian invocation with a follow-up classification query (not part of Phase 3a's contract — defer to Phase 3b if it becomes a frequent need).

- [ ] **Step 7: Commit the smoke-test ingest**

Once the user is satisfied with the public/secret split:

```bash
git add library/modules/<smoke-slug> library/index.md
git commit -m "Phase 3a smoke test: intake of <adventure title>"
```

For the `dm/modules/<smoke-slug>/` side, the main agent cannot `git add` `dm/` paths (commit hooks may allow it; the deny is on Read/Write, not on `git add` strictly — but consistency with prior phases is to let the user commit `dm/` paths from a non-Claude shell, OR check whether the project's settings permit `git add dm/**` for the main agent). The simplest path: the user runs `git add dm/modules/<smoke-slug>` and amends the commit, OR creates a second commit for the dm/ side, OR includes both in one commit invoked from outside Claude Code.

The plan accepts either pattern — what matters is that the working tree state after commit is: library/ side committed, dm/ side committed, no stray staging files, the asymmetry boundary unchanged.

---

### Task 7: Asymmetry audit + regression run

**Goal:** Confirm Phase 3a's invariants hold.

- [ ] **Step 1: Run the existing test suite**

Run all 87 existing tests across dice, mythic, and dm-fs MCP:

```bash
(cd tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q)
```

Expected: `37 passed`. The dice and mythic tests do not have their own venvs in the repo as of this plan; if test invocation for those tools fails due to missing venv, document that the dm-fs MCP tests (the suite most directly relevant to Phase 3a) pass, and the dice/mythic tests' baseline was established in prior phases with no Phase 3a changes affecting them.

- [ ] **Step 2: Asymmetry audit — main agent did not touch dm/**

Inspect the conversation/tool-use trace of the `/intake` invocation in Task 6. Grep for any `mcp__dm-fs__*` calls outside of the librarian subagent's dispatched turn:

If your environment exposes a structured tool-use log: grep for `mcp__dm-fs__` calls in the main agent's turns. Expected: zero matches outside the librarian's turn.

If no structured log is available, the dm-fs access log is the authoritative source:

```bash
grep "modules/<smoke-slug>" tools/dm-fs-mcp/access.log
```

Inspect each line. Every entry should be attributable to the librarian subagent (the access log records the agent identity if Phase 2a's implementation included that; if not, the timing of the entries should fall within the librarian's dispatched turn).

- [ ] **Step 3: Asymmetry audit — librarian did not read outside dm/modules/**

```bash
grep "READ.*dm/" tools/dm-fs-mcp/access.log | grep -v "modules/"
```

Expected: empty output. The librarian's read scope is `dm/modules/` only (verified during slug-collision check). If the grep produces non-empty output, the librarian read outside its lane — investigate.

- [ ] **Step 4: Asymmetry audit — narrator can read library/, cannot read dm/modules/**

Confirm by direct test:

```bash
cat library/modules/<smoke-slug>/overview.md
```

Expected: file content displayed. (Narrator/main-agent has read access to library/.)

```bash
cat dm/modules/<smoke-slug>/secrets.md
```

Expected: denied by settings.json — `Read(dm/**)` is in the deny list. If you see file contents from Claude Code's main agent, the asymmetry boundary is broken; investigate before proceeding.

- [ ] **Step 5: Run a fresh /session-start to confirm cross-session asymmetry**

Optional but recommended: run `/session-start` to begin a new session with the new module ingested. Confirm:

- The opening narration may reference the ingested module's public content if relevant (a hook from `library/modules/<smoke-slug>/hooks.md`, a setting detail from a node file).
- The opening narration does NOT reference any twist, hidden NPC identity, or secret location from `dm/modules/<smoke-slug>/secrets.md`.
- The narrator's tool-use trace shows no `mcp__dm-fs__*` calls during this session-start (the librarian is not invoked during play).

This is a follow-up validation; not a hard 3a pass criterion. If you do not run a full session, mark this step as deferred.

- [ ] **Step 6: Commit audit notes if any anomalies were found**

If steps 1-5 surfaced anomalies (test failure, unauthorized dm/ read, leaked secret in narration), document them in `sessions/play/2026/05/session-NNN.md` under a `## Notes for later phases` section. Otherwise, no commit needed for the audit itself.

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

> The engine is being built incrementally. As of Phase 3a, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), and module ingestion via `/intake` + the librarian subagent with secret-quarantine and milestone-candidate proposals (Phase 3a). The Phase 2 hidden-state arc is closed; Phase 3 source ingestion has begun with modules. You **do not** yet have: solo-engine/methodology/lore intake, runtime librarian queries (all Phase 3b), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or a full bookkeeper.

Leave the surrounding paragraph unchanged.

- [ ] **Step 3: Verify**

Run:
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

Run:
```bash
git log --oneline -10
```

Expected commits (most recent first), in order:
1. Update CLAUDE.md current-phase-scope to Phase 3a
2. Phase 3a smoke test: intake of <adventure title> (may be one or two commits depending on the user's dm/ commit pattern)
3. Add library/ informational subsection to CLAUDE.md (Phase 3a)
4. Seed library/ skeleton with empty index (Phase 3a)
5. Add /intake slash command dispatcher (Phase 3a)
6. Add librarian subagent for module intake (Phase 3a)
7. (Earlier:) Add Phase 3a design: source ingestion (modules)
8. (Earlier:) Merge phase-2b-fix: revelation could-land clue-level filter
9. (Earlier:) Fix revelation could-land filter to support three-clue rule
10. (Earlier:) Merge phase-2d: Mythic-event spotlight integration

- [ ] **Step 2: Inspect working tree**

Run:
```bash
git status
```

Expected: clean working tree, branch up to date with origin/main (or ahead of origin/main if you have not pushed).

- [ ] **Step 3: Confirm Phase 3a invariants in current state**

Re-run the existing test suite one more time:

```bash
(cd tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q)
```

Expected: `37 passed`. No regressions.

Confirm the four new artifacts exist:

```bash
ls .claude/agents/librarian.md
ls .claude/commands/intake.md
ls library/index.md
ls library/modules/<smoke-slug>/
```

All four should exist. The fourth confirms the smoke test ingest landed.

- [ ] **Step 4: Phase 3a definition-of-done checklist**

Cross-check against the spec's `## Definition of done` section:

- [ ] `library/` directory established with `index.md` and `modules/` subdirectory.
- [ ] `librarian` subagent at `.claude/agents/librarian.md` with documented read/write contract.
- [ ] `/intake <path>` slash command at `.claude/commands/intake.md`.
- [ ] Single query type on the librarian: `intake-module`.
- [ ] Module ingestion produces the seven expected file types under `library/modules/<slug>/` and `dm/modules/<slug>/`.
- [ ] Updated `library/index.md` entry from the smoke test.
- [ ] Structured intake summary emitted and reviewed.
- [ ] Smoke test: ingested one One-Page One-Shot adventure end-to-end with asymmetry audit clean.
- [ ] All 87 existing tests pass; no Python code added.
- [ ] `CLAUDE.md` gains the informational subsection about `library/`. No new routing rule, no new must-never bullet.
- [ ] dm-fs MCP wired to a fourth subagent (librarian); no MCP tool changes.

If any checkbox cannot be ticked from your actual repo state, do not mark the phase complete — investigate and resolve.

- [ ] **Step 5: No final commit needed for this task**

This task is verification only. Nothing changes in the working tree.

---

## Notes for executors

- **`dm/` write semantics:** Throughout this plan, all `dm/modules/` writes are via `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file` from the librarian subagent. The main agent never writes to `dm/`. If `git add dm/modules/<slug>` fails for the main agent due to the project's deny rules, the user invokes `git add` from a non-Claude shell as part of the Task 6 commit step.
- **PDF reading:** Claude Code's Read tool handles PDFs natively. For PDFs >10 pages, the librarian must pass a `pages` argument. The One-Page One-Shots PDF is many pages but the user pre-extracts the chosen adventure to a single-page source (Task 6, Step 1, Option B).
- **Slug collision behavior is intentional.** If the user wants to re-ingest a source they have already committed, they delete `library/modules/<slug>/` AND `dm/modules/<slug>/` first. Phase 3a does not implement `--force`.
- **The synthetic test fixture (Task 5) is ephemeral.** It validates mechanics only and is not committed. Its `dm/modules/test-module/` artifact may persist as untracked in the working tree if the main agent cannot remove `dm/` paths — that is acceptable; the user removes it manually before Task 6 if it bothers them.
- **Phase 3a does not change `CLAUDE.md`'s routing rules or must-never bullets.** Only two CLAUDE.md edits: Task 4 (the informational subsection about `library/`) and Task 8 (current-phase-scope update). Anyone reading the diff at the end of the phase should see two CLAUDE.md commits and four other commits (librarian, intake command, library skeleton, smoke-test ingest).
