# Phase 3b — Runtime Librarian Queries — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship two new runtime queries on the librarian subagent (`consult-library` for public module excerpts, `reveal-from-module` for explicit reveal access) and rewrite the existing `intake-module` query with positive-only framing to address the Phase 3a smoke-test discipline finding.

**Architecture:** Phase 3b modifies one subagent prompt (`.claude/agents/librarian.md`) and one routing file (`CLAUDE.md`). No new files, no new MCP tools, no new Python. The two new queries reuse the existing dm-fs MCP read/list ops. The intake-module rewrite preserves function but eliminates dense-negation framing that confused the LLM during Phase 3a's smoke run. Asymmetry stays structural (dm/ denied to narrator; librarian's response layer is the new audit surface).

**Tech Stack:** Markdown subagent prompts, dm-fs MCP (existing).

---

## File Structure

### Files to modify

| Path                          | Change                                                                                                              |
|-------------------------------|---------------------------------------------------------------------------------------------------------------------|
| `.claude/agents/librarian.md` | Rewrite `intake-module` procedure with positive-only framing (drop ~5 negative mentions of `library/modules/<slug>/` as a destination). Add new query type `consult-library`. Add new query type `reveal-from-module`. Update frontmatter description to mention the runtime queries. |
| `CLAUDE.md`                   | Add routing rule 9 (Runtime librarian queries). Append one new must-never bullet (no exploratory `reveal-from-module`). At end of phase, update `## Current phase scope` to Phase 3b. |

### No new files

All Phase 3b changes are confined to these two existing files. The smoke test produces no new permanent artifacts (it exercises live `consult-library` and `reveal-from-module` invocations; session-log entries get committed at `/session-end`).

### Why these boundaries

- The librarian's three query types (`intake-module`, `consult-library`, `reveal-from-module`) are tightly coupled by sharing the agent's read/write contract. Splitting them across multiple agent files would scatter concerns. The single `librarian.md` file is the right home.
- CLAUDE.md changes are minimal (one rule, one bullet, one phase-scope update) — same edit-in-place pattern as Phase 2a/2b/2c/2d/3a.

---

### Task 1: Rewrite `.claude/agents/librarian.md`

**Files:**
- Modify: `.claude/agents/librarian.md` (full rewrite, replacing the Phase 3a v2 content)

This is the load-bearing task. The new prompt has three responsibilities: existing intake (positive-framing rewrite), `consult-library`, `reveal-from-module`.

- [ ] **Step 1: Read the current librarian prompt**

Run:
```bash
wc -l /Users/barriault/dnd/gygaxagain/.claude/agents/librarian.md
```
Expected: around 154 lines (the Phase 3a v2 file).

Read the file to internalize the current structure. The Phase 3b rewrite preserves the section ordering: frontmatter → opening identity → Read access → Write access → Your contract → Query types → Edge cases → What you don't do.

- [ ] **Step 2: Write the new librarian.md**

Replace `.claude/agents/librarian.md` with the following exact content:

````markdown
---
name: librarian
description: Ingests reference source material into the campaign library and surfaces ingested module content to the narrator during play. Three query types — intake-module (ingests a module into dm/modules/), consult-library (returns scope-matching module excerpts to the narrator at runtime), and reveal-from-module (returns explicit reveal content when the in-fiction moment has earned it). The narrator has no path to module content other than this subagent's responses.
tools: Read, Write, Edit, Glob, Bash
mcpServers: [dm-fs]
model: sonnet
---

You are the librarian agent. You manage external source material in the campaign's library. Phase 3a defined the intake side: ingest modules into `dm/modules/<slug>/` and add an enumeration entry to `library/index.md`. Phase 3b adds the runtime side: surface scope-matching module excerpts to the narrator during play, and gate secret content behind a separate deliberate query.

Module content is structurally hidden from the narrator. You are the narrator's sole runtime path to that content.

## Read access

- `library/`, `world/`, `party/`, `sessions/`, `references/` — readable directly via Read and Glob.
- `dm/modules/` — readable **only** through the `dm-fs` MCP via `mcp__dm-fs__read_dm_file` and `mcp__dm-fs__list_dm_dir`.
- **No access** to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any other `dm/` path. Project-level settings denies enforce this for direct tools; you are forbidden from issuing dm-fs MCP reads outside `modules/` as a discipline rule.

## Write access

- `library/index.md` — writable directly via Edit. This is the librarian's only write path under `library/`.
- `dm/modules/` — writable **only** through the `dm-fs` MCP via `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file`. `Edit(dm/**)` remains denied at the project level.

## Your contract

All module content writes go to `dm/modules/<slug>/` via the dm-fs MCP. The library side gets exactly one write: an enumeration entry appended to `library/index.md`.

You are a **one-way pipeline** for intake (external source → `dm/modules/<slug>/`) and a **scope-filtered surface** for runtime queries (`dm/modules/<slug>/` content → scoped excerpts in the narrator's response context).

You never:

- Author content you didn't read from the source (no invented hooks, NPCs, secrets, or milestones).
- Write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Mutate existing `dm/modules/<slug>/` content on a re-intake of the same slug — abort on slug collision and surface the error.
- Commit to git. The user reviews and commits.
- Promote milestone candidates into a runtime milestone system (that's Phase 5).
- Auto-seed `dm/factions/<slug>.md`, `dm/revelations/<id>.md`, or `dm/threads/active.md` from module content. Flag such opportunities in the intake summary instead.
- Include `secrets.md` content in a `consult-library` response. Secrets surface only via `reveal-from-module`.

## Query type: intake-module

> "Ingest module material at `<path>`. Active session log: `<path-or-null>`."

The caller (the `/intake` command) provides a path to a PDF or markdown source and optionally an active session log path (typically null — intake is between-sessions; the session-log line is a forward-compatibility hook).

Procedure:

1. **Pre-flight.** Read the source path. If a PDF, use the Read tool's PDF support directly (specify a `pages` range if the document exceeds 10 pages). If a directory, refuse with `"intake source must be a single file in Phase 3a"`. Build an internal working representation of the full source text plus structural markers (headings, boxed text indicators, section labels).

2. **Identify content type.** For Phase 3a/3b, only `module` is accepted. If the source appears to be a solo engine, methodology text, or pure lore reference, return an error: `"Phase 3a/3b only supports module ingest; this source appears to be <type>. Re-attempt after Phase 3c adds <type> support, or pre-extract module-shaped content manually."`

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
   INTAKE SUMMARY: <module-slug>

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

## Query type: consult-library

> "consult-library for `<scope>`. Active session log: `<path-or-null>`."

The narrator provides a 1-6 word scope tag describing the current scene moment (e.g., "party arrives at cemetery", "tomb entrance hall", "investigating the chapel cellar"). You return scope-matching excerpts of public module content.

Procedure:

1. Call `mcp__dm-fs__list_dm_dir("modules")` via dm-fs MCP. If empty, return `[]` and log `- LIBRARIAN QUERY: consult-library for <scope> — 0 excerpts from 0 modules`.

2. For each module slug discovered, call `mcp__dm-fs__read_dm_file("modules/<slug>/overview.md")` and judge whether the module's themes / arc relate to the caller-supplied scope. Set aside modules with no plausible match.

3. For each surviving module, scan its content files in order of likely relevance:
   - **Node files** (`modules/<slug>/nodes/<node-slug>.md`): if the scope describes a location, scene, or encounter, read candidate node files (use `mcp__dm-fs__list_dm_dir("modules/<slug>/nodes")` to enumerate first) and match by node title / type / NPCs present.
   - **Hook file** (`modules/<slug>/hooks.md`): if the scope describes module entry or party recruitment.
   - **Connections file** (`modules/<slug>/connections.md`): if the scope describes movement between nodes or a conditional check.

4. For each matching content file, return `{module_slug, source_file, excerpt}` where `excerpt` is the scope-relevant section of that file (typically one node's relevant body sections, or one hook's framing, or specific connections entries — not arbitrary text shreds). **Never include `secrets.md` content.** That requires `reveal-from-module`.

5. **Lean inclusive on ambiguity** — same rule as revelation: if uncertain whether a section is in scope, include it. The narrator filters when weaving.

6. Return the list (possibly empty) ordered by scope-match relevance.

7. Append a single line to the active session log via Edit:
   ```
   - LIBRARIAN QUERY: consult-library for <scope> — <K> excerpts from <M> modules
   ```

## Query type: reveal-from-module

> "reveal-from-module `<slug>` for `<reveal scope>`. Active session log: `<path>`."

The narrator provides the module slug and a reveal-scope phrase describing the in-fiction moment that earns the reveal (e.g., "party defeats undead mage and learns his identity", "party reads the dying NPC's letter and sees the cult sigil"). You return matching secret content with an explicit `[REVEAL]` tag.

Procedure:

1. Call `mcp__dm-fs__read_dm_file("modules/<slug>/secrets.md")`. If the file doesn't exist (or the slug is unknown), return `{error: "no such module or no secrets.md"}` and log `- LIBRARIAN QUERY: reveal-from-module <slug> for <reveal scope> — error: no such module`.

2. Match the reveal scope against secrets.md content sections (Twists & reveals, Hidden NPC identities & motives, Hidden locations / passages, DM-only context, Custom stat blocks). Use LLM judgment.

3. **Default to no match on ambiguity** — exact opposite of `consult-library`'s lean-inclusive rule. The narrator's reveal scope must unambiguously match a specific secret. If multiple secrets plausibly match, return `{reason: "scope matches multiple reveals; refine and re-query"}` and log the multi-match case.

4. If matched, return `{module_slug, reveal_section, excerpt, tag: "[REVEAL]"}`. If not matched at all, return `[]`.

5. Append session-log line:
   ```
   - LIBRARIAN QUERY: reveal-from-module <slug> for <reveal scope> — <found-or-none>
   ```

   Where `<found-or-none>` is one of:
   - `found <reveal_section>` — single match, content returned.
   - `none` — no match.
   - `multi-match; refine` — multiple matches, narrator asked to refine.

## Edge cases

- **Source path doesn't exist or isn't readable (intake).** Abort with an error before any writes. No partial mutation.
- **PDF is too large to read in one pass (intake).** Read in page-range chunks via Read's `pages` parameter; merge internal representation before classification. If still too large for your context budget, abort with `"source exceeds intake budget; pre-split into smaller modules"`.
- **Source doesn't appear module-shaped — no nodes detectable (intake).** Abort with `"source does not decompose into Alexander-nodes; please pre-structure or wait for Phase 3c lore-reference intake"`.
- **Slug collision (intake)** — `dm/modules/<slug>/` already exists. Abort; user resolves manually (delete or rename). No silent overwrite.
- **Partial intake state from a prior failure (intake)** — `dm/modules/<slug>/` partially populated. Abort with explicit error.
- **`library/index.md` already lists the slug** but `dm/modules/<slug>/` does not exist (intake). Anomalous; abort with an error pointing at the mismatch.
- **Source has zero ambiguous content-kind classifications (intake).** Emit the secret-notes-section line "None — all content kinds were unambiguous." explicitly so the user can trust that the absence is a result of inspection, not a missing report.
- **Source overlaps existing campaign content** (intake) (e.g., names an NPC already in `world/home-base/npcs/`). Don't merge; flag in the summary's "Opportunities" list. Phase 4 bookkeeper will own merge proposals.
- **dm-fs MCP write fails mid-intake.** Surface the error in your response; partial dm-fs writes may exist. Inform the user to clean up the partial `dm/modules/<slug>/` directory via their own shell and re-run after resolving the MCP issue.
- **`library/index.md` write fails after dm-fs writes succeed (intake).** Surface the error; the user reconciles by either editing `library/index.md` manually or rolling back the dm-fs writes (via their own shell).
- **`dm/modules/` is empty (consult-library).** Return `[]` and log. No error.
- **`dm/modules/<slug>/` exists but is partially populated (consult-library).** Read what's there; missing files contribute no excerpts. No error.
- **Caller supplies a malformed scope (consult-library or reveal-from-module)** — empty string, paragraph-length blob, etc. Treat as best-effort. If empty, return `[]` with a session-log warning.
- **`dm/modules/<slug>/secrets.md` doesn't exist (reveal-from-module).** Error response per procedure step 1.
- **Reveal-from-module multi-match case.** Return `reason: "scope matches multiple reveals; refine and re-query"` and log explicitly. Do not pick arbitrarily.
- **Scope is "give me everything for <module>"-style (consult-library).** The librarian's contract is scope-matching, not full-module dumping. Return content matching the scope (probably overview content) and a one-line note advising the caller to query per-scene-moment instead.

## What you don't do

- Don't author content you didn't read from the source — no invented hooks, NPCs, secrets, or milestones.
- Don't write to `dm/factions/`, `dm/revelations/`, `dm/threads/`, `dm/npcs/`, or any `dm/` path outside `dm/modules/`.
- Don't read `dm/` paths outside `dm/modules/` (no MCP reads against `factions/`, `revelations/`, `threads/`, `npcs/`).
- Don't include `secrets.md` content in a `consult-library` response. That content surfaces only via `reveal-from-module`.
- Don't return reveal content from `reveal-from-module` unless the scope unambiguously matches a single secret. Default to no-match on ambiguity.
- Don't mutate existing `dm/modules/<slug>/` content on a re-intake — abort on slug collision.
- Don't commit. The user reviews and commits.
- Don't promote milestone candidates into a runtime milestone system — that's Phase 5.
- Don't auto-seed `dm/factions/`, `dm/revelations/`, or `dm/threads/` files. Flag opportunities in the intake summary instead.
- Don't use your `Edit` tool on `dm/` files — `Edit(dm/**)` is denied. All `dm/` mutations flow through `mcp__dm-fs__create_dm_file` and `mcp__dm-fs__write_dm_file` via the dm-fs MCP.
````

- [ ] **Step 3: Verify the file matches the contract**

Read `.claude/agents/librarian.md` back and confirm:

- Frontmatter mentions all three query types in the description.
- `## Read access`, `## Write access`, `## Your contract` sections present.
- Three `## Query type:` sections present: `intake-module`, `consult-library`, `reveal-from-module`.
- `## Edge cases` and `## What you don't do` sections present.
- **No mentions of `library/modules/<slug>/` as a destination.** Grep for it:
  ```bash
  grep -n "library/modules/<slug>/" .claude/agents/librarian.md
  ```
  Expected: zero matches except in passing context (e.g., "never read `library/modules/<slug>/` directly" wording carried from prior CLAUDE.md style — but ideally even those are absent from the librarian's own prompt; check carefully). The contract section's positive framing is the goal.

- [ ] **Step 4: Commit**

```bash
git add .claude/agents/librarian.md
git commit -m "Rewrite librarian: add consult-library + reveal-from-module; positive-frame intake-module"
```

---

### Task 2: Add CLAUDE.md routing rule 9 + must-never bullet

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Locate the insertion point for routing rule 9**

Run:
```bash
grep -n "^### " /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

Expected sections include rules 1-8 numbered. Rule 9 belongs after rule 8 (Random event composition) and before `## Session log conventions`.

Then locate `## Session log conventions`:
```bash
grep -n "^## Session log conventions" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

The insertion point for rule 9 is immediately before `## Session log conventions`.

- [ ] **Step 2: Insert routing rule 9**

Use Edit on `CLAUDE.md`.

`old_string` is exactly:
```
## Session log conventions
```

`new_string` is exactly:
```
### 9. Runtime librarian queries

When a scene moment may intersect an ingested module, invoke the librarian with "consult-library for `<scope>`. Active session log: `<path>`." The librarian returns 0+ excerpts of module content (node descriptions, hooks, connections) matching the scope. Weave the relevant excerpt into prose; do not surface content beyond what the party has perceived in-fiction. Never read `library/modules/<slug>/` directly — the directory is intentionally empty and module content lives under `dm/modules/<slug>/` which is denied to you. The librarian is your sole runtime path to module content.

When the in-fiction moment unambiguously matches a reveal the party has earned — defeated the boss, solved the puzzle, the prophecy speaks — invoke "reveal-from-module `<slug>` for `<reveal scope>`. Active session log: `<path>`." Use this deliberately: a reveal is a player-facing beat, not exploratory prep.

You learn what modules are available by reading `library/index.md` (genre-level enumeration only — does not pre-spoil content). The narrator-perspective premise/arc of a module is hidden from you until `consult-library` returns a relevant excerpt.

## Session log conventions
```

- [ ] **Step 3: Add the new must-never bullet**

Locate the end of `## What you must never do`. The existing list (post-Phase 3a) ends with the bullet about `library/modules/<slug>/` being intentionally empty. The new bullet appends after that one.

Use Edit. Find the last existing must-never bullet:

```bash
grep -A 30 "## What you must never do" /Users/barriault/dnd/gygaxagain/CLAUDE.md | tail -15
```

Identify the last `- Never ...` bullet and use it as the anchor.

`old_string` (anchor — the existing last bullet from Phase 3a):
```
- Never attempt to read, glob, or grep `library/modules/<slug>/` for ingested module content — that path is intentionally empty under Phase 3a; module content lives under `dm/modules/<slug>/`, which is denied to you. Runtime access to module content ships in Phase 3b's `consult-library` query.
```

`new_string`:
```
- Never attempt to read, glob, or grep `library/modules/<slug>/` for ingested module content — that path is intentionally empty; module content lives under `dm/modules/<slug>/`, which is denied to you. Runtime access to module content is via the librarian's `consult-library` query (Phase 3b).
- Never invoke `reveal-from-module` exploratory or pre-emptively — only when the in-fiction moment unambiguously matches a reveal trigger the party has earned through play.
```

Note: the rewrite of the first bullet drops the "Phase 3a / ships in Phase 3b" framing since runtime access exists now; the bullet is content-equivalent but tense-corrected. The second bullet is the new Phase 3b addition.

- [ ] **Step 4: Verify placement and content**

Run:
```bash
grep -n "^### \|^## " /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

Expected output includes (in order):
```
### 1. Dice routing
### 2. Oracle routing
### 3. Hidden-info routing
### 4. Primary PC authority
### 5. Offscreen developments
### 6. Revelation routing
### 7. Thread management
### 8. Random event composition
### 9. Runtime librarian queries
## Session log conventions
```

Then:
```bash
grep -c "^- Never " /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 10 (was 9 after Phase 3a; +1 for the new exploratory-reveal bullet).

Read the inserted rule 9 and the appended must-never bullet to confirm both landed correctly.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "Add CLAUDE.md routing rule 9 + exploratory-reveal must-never bullet (Phase 3b)"
```

---

### Task 3: Prepare for smoke test — branch + restart prerequisite

**Files:**
- No file changes in this task. Procedural setup.

- [ ] **Step 1: Confirm working tree clean and on phase-3b branch**

If not already on a feature branch:
```bash
git checkout -b phase-3b
```

(Optional: the user may prefer to land Phase 3b directly on main if Tasks 1-2 are simple enough — match the Phase 2 / 3a pattern with `phase-3b` branch + merge at end.)

Verify:
```bash
git status
git log --oneline -5
```

Expected: clean working tree, branch `phase-3b` (or main) at tip including Tasks 1 and 2 commits.

- [ ] **Step 2: Restart prerequisite for smoke test**

The librarian's frontmatter and prompt are loaded into the Agent tool's registry at session start. After Task 1's rewrite, the running session still has the Phase 3a v2 librarian prompt cached. **For the smoke test in Task 4 to invoke the v3 librarian, the user must restart Claude Code.**

This is the same constraint Phase 3a hit: agent definitions don't refresh mid-session. Document this in the implementation log; signal to the user (or to the executing subagent's controller) that a restart is required before proceeding to Task 4.

No commit for this task — it's a procedural checkpoint.

---

### Task 4: Smoke test execution

**Files:**
- No file changes during the smoke test itself, but the test produces a session log entry that gets committed at `/session-end` (or via an ad-hoc commit if running scaffolded).

**Two smoke-test modes — pick one per Task 3 outcome:**

#### Mode A (preferred): Real session smoke test

- [ ] **Step A1: Start a new session**

After session restart, run `/session-start`. The narrator initializes per Phase 1's procedure.

- [ ] **Step A2: Drive the narrator to a scene that intersects Phandalin**

Either narratively (the party travels to Phandalin region) or explicitly ("the party arrives at the cemetery outside Phandalin where they were sent by the guard captain"). The narrator reads `library/index.md` and notes the Phandalin module is enumerated.

- [ ] **Step A3: Verify the narrator invokes `consult-library`**

After the scene setup, the narrator should — per CLAUDE.md rule 9 — invoke:
```
consult-library for "party arrives at cemetery outside phandalin". Active session log: sessions/play/2026/05/session-006.md
```

(Or similar scope wording. The session number depends on which session-NNN this is.)

Confirm in the session log:
```bash
grep "LIBRARIAN QUERY: consult-library" sessions/play/2026/05/session-NNN.md
```

Expected: one line of the form `- LIBRARIAN QUERY: consult-library for <scope> — <K> excerpts from <M> modules`.

- [ ] **Step A4: Verify the librarian returned cemetery-exterior content**

Inspect the dm-fs access log:
```bash
tail -20 tools/dm-fs-mcp/access.log | grep -E "list_dm_dir modules$|read_dm_file modules/ancient-tomb-of-phandalin/(overview\.md|nodes/cemetery-exterior\.md)"
```

Expected at least:
- `list_dm_dir modules` (the librarian's slug enumeration step)
- `read_dm_file modules/ancient-tomb-of-phandalin/overview.md` (scope-relevance check)
- `read_dm_file modules/ancient-tomb-of-phandalin/nodes/cemetery-exterior.md` (the matching node)

Crucially, **no read of `modules/ancient-tomb-of-phandalin/secrets.md`** during this query.

- [ ] **Step A5: Verify the narrator's prose matches the cemetery node**

Read the narrator's scene-opening prose for the cemetery scene from the session log. Compare against `dm/modules/ancient-tomb-of-phandalin/nodes/cemetery-exterior.md` (from your own shell, not via Claude Code — the main agent cannot read it). Confirm:

- Prose describes what's in `cemetery-exterior.md`'s `## Description` section.
- Prose does NOT reference content from adjacent nodes (e.g., does not mention the crematorium's furnace or the right-tunnel trap unless the party has reached those nodes).
- Prose does NOT reference Kodor by name, Rewalt's identity, or any twist from `secrets.md`.

- [ ] **Step A6: Drive party deeper, repeat consult-library**

Continue play. As the party enters subsequent nodes (tomb entrance, narrow passage, etc.), the narrator should invoke `consult-library` per scene transition. Each invocation produces a session-log line and corresponding dm-fs access log entries.

- [ ] **Step A7: Trigger a reveal**

When the in-fiction moment unambiguously earns a reveal (e.g., the party defeats Kodor), the narrator should invoke:
```
reveal-from-module ancient-tomb-of-phandalin for "party defeats undead mage and learns his identity". Active session log: ...
```

Confirm in the session log:
```bash
grep "LIBRARIAN QUERY: reveal-from-module" sessions/play/2026/05/session-NNN.md
```

Expected: one line of the form `- LIBRARIAN QUERY: reveal-from-module ancient-tomb-of-phandalin for <scope> — found <reveal_section>`.

Inspect the access log:
```bash
tail -10 tools/dm-fs-mcp/access.log | grep "secrets.md"
```

Expected: one `read_dm_file modules/ancient-tomb-of-phandalin/secrets.md` entry, AT the moment of the reveal — not before.

- [ ] **Step A8: Verify the reveal landed correctly in narration**

Read the post-reveal prose in the session log. Confirm:
- Prose now references content from `secrets.md` (e.g., Kodor's history, his connection to Myrkul cultists, etc.).
- The prose does NOT reference other reveals not earned (e.g., Rewalt's lie is only revealed if the in-fiction moment earned that specific reveal too).

- [ ] **Step A9: `/session-end`**

Run `/session-end`. The bookkeeper commits the session.

#### Mode B (fallback): Scaffolded smoke test

If real session play is impractical (e.g., user wants to validate mechanics fast without full play):

- [ ] **Step B1: Dispatch consult-library directly**

In the active session (post-restart), dispatch the librarian via the Agent tool:

```
Agent(subagent_type="librarian", prompt="consult-library for 'cemetery outside phandalin'. Active session log: null.")
```

- [ ] **Step B2: Verify response shape**

The librarian's response should include:
- One excerpt with `module_slug: "ancient-tomb-of-phandalin"`.
- `source_file` referencing `nodes/cemetery-exterior.md` (or `overview.md` if no node clearly matches the scope).
- Excerpt content matches the actual file content.
- **No secret content from `secrets.md`.**

Check dm-fs access log to confirm no read of `secrets.md` during this query:
```bash
tail -10 tools/dm-fs-mcp/access.log
```

- [ ] **Step B3: Dispatch reveal-from-module directly**

```
Agent(subagent_type="librarian", prompt="reveal-from-module ancient-tomb-of-phandalin for 'party defeats undead mage and learns his identity'. Active session log: null.")
```

- [ ] **Step B4: Verify the reveal response**

The librarian's response should include:
- `module_slug: "ancient-tomb-of-phandalin"`.
- `reveal_section` matching content about Kodor (e.g., "Twists & reveals" or "Hidden NPC identities & motives").
- `tag: "[REVEAL]"`.
- Excerpt content from `secrets.md`.

Check dm-fs access log for the secrets.md read:
```bash
tail -10 tools/dm-fs-mcp/access.log
```

Expected: `read_dm_file modules/ancient-tomb-of-phandalin/secrets.md`.

- [ ] **Step B5: Test the ambiguity-rejection path**

Dispatch with a deliberately ambiguous reveal scope:

```
Agent(subagent_type="librarian", prompt="reveal-from-module ancient-tomb-of-phandalin for 'something surprising happens'. Active session log: null.")
```

Expected response: `{reason: "scope matches multiple reveals; refine and re-query"}` or `[]` (default-no-match-on-ambiguity).

- [ ] **Step B6: No commit needed for scaffolded test**

The scaffolded test produces no permanent artifacts beyond access-log entries. Document results inline in the user's review.

---

### Task 5: Asymmetry audit + regression test run

**Files:**
- No file changes in this task. Audit only.

- [ ] **Step 1: Run the existing test suite**

```bash
cd /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q
```

Expected: `37 passed`.

- [ ] **Step 2: Asymmetry audit — narrator did not touch dm/ during the smoke test**

If the smoke test ran via Mode A (real session), inspect the session's tool-use trace (if available) for any `mcp__dm-fs__*` calls outside the librarian's dispatched turns. Expected: zero matches outside the librarian's turns.

For Mode B (scaffolded), the dispatched librarian turns are the only relevant context.

Authoritative check via access log:
```bash
grep "modules/ancient-tomb-of-phandalin" /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log | tail -20
```

Every entry from the Phase 3b smoke run should be attributable to the librarian's `consult-library` or `reveal-from-module` invocations.

- [ ] **Step 3: Asymmetry audit — secrets.md only read during reveal-from-module**

```bash
grep "modules/ancient-tomb-of-phandalin/secrets.md" /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp/access.log
```

Inspect timestamps. Pre-Phase-3b entries are intake writes (`create_dm_file` from Phase 3a). Phase 3b entries should be `read_dm_file` only, and only during `reveal-from-module` invocations (correlate with session log `LIBRARIAN QUERY: reveal-from-module` lines).

Expected: NO `read_dm_file ... secrets.md` entries during `consult-library` calls. If you see secrets.md reads correlated with `consult-library` log lines, the asymmetry contract is broken.

- [ ] **Step 4: Asymmetry audit — narrator cannot directly read dm/modules/**

```bash
cat /Users/barriault/dnd/gygaxagain/dm/modules/ancient-tomb-of-phandalin/secrets.md 2>&1 | head -3
```

Expected: denied by settings.json deny rules. (Same positive verification as Phase 3a.)

- [ ] **Step 5: library/modules/ stays empty**

```bash
ls -la /Users/barriault/dnd/gygaxagain/library/modules/
```

Expected: only `.gitkeep`. **No `<slug>/` subdirectory.** The intake-module rewrite's positive framing should prevent the Phase 3a discipline failure from recurring. If a subdirectory appeared during Phase 3b smoke (e.g., the user re-ingested Phandalin as part of the librarian-rewrite re-validation), that's a Phase 3b regression — investigate.

- [ ] **Step 6: Commit audit notes if anomalies were found**

If steps 1-5 surfaced anomalies, document them under `## Notes for later phases` in the most recent session log (Mode A) or as a comment in the implementation log (Mode B). Otherwise, no commit needed.

---

### Task 6: Update CLAUDE.md `## Current phase scope` to Phase 3b

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Locate the section**

```bash
grep -n "Current phase scope" /Users/barriault/dnd/gygaxagain/CLAUDE.md
```

The section currently reads (from Phase 3a):

> The engine is being built incrementally. As of Phase 3a, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), and module intake via `/intake` + the librarian subagent with all module content dm-quarantined (Phase 3a). The Phase 2 hidden-state arc is closed; Phase 3 source ingestion has begun with modules. **Phase 3a is intake-only** — ingested modules sit in `dm/modules/` but are not yet runnable during play because the narrator has no path to read them. Phase 3b will add the `consult-library` runtime query that makes modules playable. You **do not** yet have: runtime librarian queries (Phase 3b), solo-engine/methodology/lore intake (Phase 3b), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or a full bookkeeper. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.

- [ ] **Step 2: Update the section to reflect Phase 3b**

Use Edit on `CLAUDE.md`. Replace the long paragraph above with:

> The engine is being built incrementally. As of Phase 3b, you have: dice routing, oracle routing, hidden-info routing via the world-state subagent, factions with offscreen-developments at session-start (Phase 2a), revelations with three-clue tracking via the revelation subagent (Phase 2b), Mythic threads with open/close/list via the mythic subagent (Phase 2c), Mythic random-event composition — thread spotlight in the mythic subagent plus narrator-routed faction/revelation composition per rule 8 (Phase 2d), module intake via `/intake` + the librarian subagent with all module content dm-quarantined (Phase 3a), and runtime librarian queries `consult-library` (scope-matched public excerpts) and `reveal-from-module` (explicit reveal access when the party has earned it) per rule 9 (Phase 3b). The Phase 2 hidden-state arc is closed; Phase 3a/3b together make module ingest and runtime consultation work end-to-end. You **do not** yet have: solo-engine/methodology/lore intake (Phase 3c), URL ingestion (Phase 3c), auto-proposals for `dm/factions/`/`dm/revelations/`/`dm/threads/` from module content (Phase 3c or 4), milestone promotion to `dm/milestones/` or `/level-up` (Phase 5), downtime, banking, bastions, or a full bookkeeper. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.

- [ ] **Step 3: Verify**

```bash
grep -A 2 "Current phase scope" /Users/barriault/dnd/gygaxagain/CLAUDE.md | head -5
```

Confirm new text is in place.

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "Update CLAUDE.md current-phase-scope to Phase 3b"
```

---

### Task 7: Final integration sanity check

**Goal:** Confirm the working tree, git history, and tests are all in the expected end-state for Phase 3b.

- [ ] **Step 1: Inspect git history**

```bash
git log --oneline -10
```

Expected commits (most recent first), in roughly this order:
1. Update CLAUDE.md current-phase-scope to Phase 3b
2. (smoke-test commit, if Mode A) — `/session-end` for the Phase 3b smoke test session
3. Add CLAUDE.md routing rule 9 + exploratory-reveal must-never bullet (Phase 3b)
4. Rewrite librarian: add consult-library + reveal-from-module; positive-frame intake-module
5. (Earlier:) Add Phase 3b design: runtime librarian queries + prompt hardening

- [ ] **Step 2: Inspect working tree**

```bash
git status
```

Expected: clean working tree.

- [ ] **Step 3: Confirm Phase 3b invariants**

Re-run the dm-fs MCP test suite:

```bash
cd /Users/barriault/dnd/gygaxagain/tools/dm-fs-mcp && source .venv/bin/activate && python -m pytest -q
```

Expected: `37 passed`.

Confirm artifacts:

```bash
grep -c "^## Query type" /Users/barriault/dnd/gygaxagain/.claude/agents/librarian.md
```
Expected: 3 (intake-module, consult-library, reveal-from-module).

```bash
grep -c "^### " /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 9 (rules 1-9).

```bash
grep -c "^- Never " /Users/barriault/dnd/gygaxagain/CLAUDE.md
```
Expected: 10 (the post-Phase-3a count of 9 plus 1 for Phase 3b's exploratory-reveal bullet).

- [ ] **Step 4: Phase 3b definition-of-done checklist**

Cross-check against the spec's `## Definition of done`:

- [ ] New `consult-library` query type on the librarian. Returns scope-matched excerpts, never includes `secrets.md` content. Session-log line emitted.
- [ ] New `reveal-from-module` query type on the librarian. Default-to-no-match-on-ambiguity. Multi-match returns `reason: "scope matches multiple reveals..."`. Session-log line emitted.
- [ ] `intake-module` rewritten with positive-only framing. Function unchanged. Smoke-test re-validation (if run) confirms `library/modules/<slug>/` stays empty after re-intake.
- [ ] CLAUDE.md rule 9 added; one new must-never bullet about exploratory `reveal-from-module`; `## Current phase scope` updated to Phase 3b.
- [ ] Smoke test exercised both new queries against the existing Phandalin module. Asymmetry held — narrator never read `dm/`; `secrets.md` only read during `reveal-from-module`.
- [ ] All 87 existing tests pass; no Python code added.
- [ ] No new files. Repository changes are confined to `.claude/agents/librarian.md` and `CLAUDE.md`.

If any checkbox cannot be ticked, investigate before merging.

- [ ] **Step 5: Merge phase-3b → main** (if working on a feature branch)

```bash
git checkout main
git merge --no-ff phase-3b -m "Merge phase-3b: runtime librarian queries (consult-library + reveal-from-module)"
git branch -d phase-3b
git log --oneline -5
```

---

## Notes for executors

- **Session restart required between Task 1 and Task 4.** The librarian's prompt is loaded at session start. After Task 1's rewrite, the running session still has the Phase 3a prompt cached. Tasks 2 and 3 can run in the same session; Task 4 (smoke test) requires the user to restart Claude Code so the v3 librarian prompt loads.
- **Mode A vs Mode B for Task 4.** Mode A (real session) validates the full narrator-librarian interaction including CLAUDE.md routing rule 9's effect on narrator behavior. Mode B (scaffolded) validates only the librarian's response shape. Mode A is preferred; Mode B is a fallback if real play isn't practical.
- **The intake-module rewrite is positive-framing only.** Do not change the procedure's semantics. The Phase 3a smoke-test discovered that `library/modules/<slug>/` mentions in negative form acted as positive cues for the LLM. The rewrite removes those mentions; the structural enforcement (settings.json `dm/**` denies, `library/` not denied) is unchanged.
- **No new MCP tools.** Phase 3b's runtime queries reuse `mcp__dm-fs__read_dm_file` and `mcp__dm-fs__list_dm_dir` from Phase 1/2a.
- **The librarian prompt is the longest single artifact in this plan.** Task 1 step 2's exact content runs ~180 lines. Write it carefully; the smoke test in Task 4 is the validation surface.
