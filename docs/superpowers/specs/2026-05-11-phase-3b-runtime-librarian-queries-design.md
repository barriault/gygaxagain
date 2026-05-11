# Phase 3b — Runtime Librarian Queries Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phase 1 spec:** `docs/superpowers/specs/2026-05-09-phase-1-mvp-session-design.md`.
**Phase 2a spec:** `docs/superpowers/specs/2026-05-10-phase-2a-factions-and-offscreen-developments-design.md`.
**Phase 2b spec:** `docs/superpowers/specs/2026-05-10-phase-2b-revelations-design.md`.
**Phase 2c spec:** `docs/superpowers/specs/2026-05-10-phase-2c-mythic-threads-design.md`.
**Phase 2d spec:** `docs/superpowers/specs/2026-05-10-phase-2d-mythic-event-spotlight-design.md`.
**Phase 3a spec:** `docs/superpowers/specs/2026-05-10-phase-3a-source-ingestion-modules-design.md`.
**Slice of original Phase 3:** runtime librarian queries (`consult-library` and `reveal-from-module`) plus a Phase 3a follow-up — librarian prompt hardening to address the dense-negation discipline failure surfaced by the Phase 3a smoke test. Solo-engine intake, methodology intake, lore reference intake, URL ingestion, auto-proposals for `dm/factions/` / `dm/revelations/` / `dm/threads/`, and `rename_dm_file` MCP tool all deferred to Phase 3c.

## Purpose

Phase 3a landed module intake under a strict structural-asymmetry model: all module content lives under `dm/modules/<slug>/`, denied to the narrator. The narrator's only library-side knowledge is `library/index.md`'s genre-level enumeration. That artifact is **intake-only** — the narrator has no path to *read* module content during play.

Phase 3b makes ingested modules **playable** by adding runtime queries on the librarian subagent. The narrator invokes the librarian mid-scene; the librarian reads `dm/modules/<slug>/` content via the dm-fs MCP and returns scope-matching excerpts. Secrets are gated behind a separate, deliberate query that requires the narrator to confirm the in-fiction moment has earned the reveal.

Phase 3b also addresses the Phase 3a smoke-test finding: the librarian's `intake-module` procedure was authored with dense negative framing around `library/modules/<slug>/` ("never write to," "stays empty," repeated five times), which the LLM treated as positive cues during the first smoke run and wrote 6 v1-style files to that path before correctly writing 14 v2-style files to `dm/modules/<slug>/`. Phase 3b rewrites the intake-module procedure with positive-only framing.

## Definition of done

A successful Phase 3b build demonstrates all of:

- **New query type on the librarian subagent:** `consult-library`.
  - Invocation: `"consult-library for <scope>. Active session log: <path-or-null>."` (1-6 word scope tag, same style as revelation's could-land).
  - Procedure: librarian enumerates `dm/modules/*/` via dm-fs MCP, reads each module's `overview.md` to gauge scope-relevance, then reads matching node / hook / connections files. Returns scope-matching excerpts with citation.
  - Returns a list `[{module_slug, source_file, excerpt}]`, ordered by scope-match relevance. Most calls return 0-1 items; multiple modules with overlapping scopes can return more. Each excerpt is a coherent unit (one node file's relevant sections, one hook framing, one connections entry) — not arbitrary text shreds.
  - **Never returns `secrets.md` content.** That requires `reveal-from-module`. Hard contract rule, enforced at the librarian prompt level.
  - Appends a session-log line: `- LIBRARIAN QUERY: consult-library for <scope> — <K> excerpts from <M> modules`.

- **New query type on the librarian subagent:** `reveal-from-module`.
  - Invocation: `"reveal-from-module <slug> for <reveal scope>. Active session log: <path>."`
  - Procedure: librarian reads `dm/modules/<slug>/secrets.md` via dm-fs MCP, matches the reveal scope against secret content sections (Twists & reveals, Hidden NPC identities & motives, Hidden locations / passages, DM-only context). Uses LLM judgment with **default-to-no-match on ambiguity** (opposite of `consult-library`'s lean-inclusive rule).
  - Returns `{module_slug, reveal_section, excerpt, [REVEAL] tag}` if matched, `[]` otherwise. Multiple-match case returns `reason: "scope matches multiple reveals; refine and re-query"`.
  - Appends a session-log line: `- LIBRARIAN QUERY: reveal-from-module <slug> for <reveal scope> — <found-or-none>`.

- **Existing `intake-module` query rewritten** with positive-only framing. All five negative mentions of `library/modules/<slug>/` removed from the contract section and "what you don't do" list. Replaced with a single positive contract sentence: "All module content writes go to `dm/modules/<slug>/` via the dm-fs MCP. The library side gets exactly one write: an enumeration entry appended to `library/index.md`." The procedure step-by-step content and edge-case handling stay functionally identical.

- **New CLAUDE.md routing rule 9** — runtime librarian queries.
  - Wording: when a scene moment may intersect an ingested module, invoke `consult-library` with a scope tag. When the in-fiction moment unambiguously matches a reveal the party has earned, invoke `reveal-from-module`. The narrator learns module availability from `library/index.md`; module content itself is dm-quarantined and reachable only via librarian queries.

- **New must-never bullet** added to `## What you must never do`:
  - "Never invoke `reveal-from-module` exploratory or pre-emptively — only when the in-fiction moment unambiguously matches a reveal trigger the party has earned through play."

- **Smoke test:** run a `/session-start` after the librarian rewrite is in place. Narrator detects Phandalin in `library/index.md`, invokes `consult-library` with a cemetery scope, receives the cemetery-exterior node excerpt, weaves into narration. At a moment where a reveal is earned, narrator invokes `reveal-from-module` and receives the matching reveal. Asymmetry audit confirms: no narrator-issued reads of `dm/`; the librarian's `consult-library` responses contain no `secrets.md` content; the `reveal-from-module` response is only invoked when the in-fiction moment justifies it.

- All 87 existing tests continue to pass; no Python code added.

- No new files. Repository changes are confined to `.claude/agents/librarian.md` and `CLAUDE.md`.

## Out of scope (deferred to Phase 3c or later)

- **Solo-engine intake** (`library/solo-engines/<name>/`). Phase 3c.
- **Methodology intake** (`library/methodology/<topic>/`). Phase 3c.
- **Lore reference intake** (`library/lore/<name>/`). Phase 3c.
- **URL ingestion.** Phase 3c. Path-only for 3b (and 3a).
- **Auto-proposals for `dm/factions/`, `dm/revelations/`, `dm/threads/`** from module material. Phase 3c or Phase 4.
- **`rename_dm_file` MCP tool.** Commit-gate is the review mechanism. Phase 3c if needed.
- **`consult-library` against non-module library content.** Phase 3b's runtime query only reads `dm/modules/<slug>/`. Lore reference / solo engine / methodology content will need their own query patterns once those intake types ship in 3c.
- **Cross-module composition rules.** Phase 3b returns whatever matches the scope; if two modules' scopes overlap, the narrator picks one to weave (similar to revelation's "choose at most one to weave" discipline). Cross-module discipline formalization deferred — revisit if it becomes a real problem with 3+ ingested modules.
- **Module activation slash command (`/module-activate <slug>`).** Phase 3b lets the librarian judge from scope alone; no explicit activation needed. Reconsider in 3c if 3+ ingested modules regularly overlap on scopes.
- **Reveal-trigger condition authoring at intake.** Phase 3b's `reveal-from-module` matches against `secrets.md` content as Phase 3a wrote it (freeform). Phase 3c may formalize per-reveal trigger metadata.
- **Re-validation of the Phase 3a librarian-discipline finding via a controlled re-intake.** Optional in 3b; the primary smoke test exercises both new query types and the rewritten intake-module enough that any regression should surface. If a clean re-validation is desired, do an explicit re-ingest (after first removing existing `dm/modules/ancient-tomb-of-phandalin/` via shell) and confirm `library/modules/<slug>/` stays empty.

## Architecture

### Slice mapping

| Component                          | Phase 3b touches                                                                 |
|------------------------------------|----------------------------------------------------------------------------------|
| Narrator (main agent)              | New routing rule 9 in `CLAUDE.md`. One new must-never bullet (no exploratory `reveal-from-module`). The existing Phase 3a must-never bullet ("never attempt to read `library/modules/<slug>/`...") stays; runtime access via `consult-library` is what fills its absence. |
| World-state subagent               | Untouched.                                                                       |
| Revelation subagent                | Untouched.                                                                       |
| Mythic subagent                    | Untouched.                                                                       |
| Dice subagent                      | Untouched.                                                                       |
| **Librarian subagent**             | **MODIFIED** — `.claude/agents/librarian.md`. Two new query types (`consult-library`, `reveal-from-module`). Existing `intake-module` query rewritten with positive-only framing. Read scope unchanged (already covers `dm/modules/` via dm-fs MCP). |
| `dm-fs` MCP                        | No tool changes. The existing `read_dm_file` / `list_dm_dir` already cover both new runtime queries. Edit + create paths from 3a still cover intake. |
| `.claude/settings.json`            | No deny-rule changes.                                                            |
| `/intake` command                  | Untouched.                                                                       |
| Other slash commands               | Untouched.                                                                       |
| Repository layout                  | No new files. All Phase 3b changes are to the librarian prompt and CLAUDE.md.    |

### Information-asymmetry preservation

The boundary holds. Phase 3b expands the narrator's *access pattern* (via `consult-library` / `reveal-from-module`) without expanding the narrator's *read scope*: the narrator still has no path to `dm/`. The librarian, with dm-fs MCP, reads `dm/modules/<slug>/` and returns scoped excerpts in its response. The narrator receives only what the librarian decided to surface — same one-way-valve pattern as Phase 2b's revelation subagent.

Three asymmetry layers:

1. **Filesystem layer (unchanged from Phase 1/2/3a).** `dm/**` denies in `.claude/settings.json` prevent narrator direct reads.
2. **MCP layer (unchanged).** dm-fs MCP only wired to subagents with `mcpServers: [dm-fs]` in their frontmatter. Narrator has no MCP.
3. **Response layer (new for 3b).** The librarian decides what content to return in `consult-library` and `reveal-from-module` responses. Discipline rules:
   - `consult-library` never returns content from `secrets.md`. Hard contract rule in the librarian's prompt.
   - `reveal-from-module` only returns content the narrator's scope explicitly references as a reveal moment — librarian uses LLM judgment with default-to-no-match on ambiguity.
   - Both queries return scope-matched excerpts, not full file contents (e.g., a single node's `## Description` section if the scope is "what does the cemetery look like", not the entire cemetery node file).

The narrator's `dm/**` denies cover any attempted direct-read path. Phase 3b adds no new narrator-readable files. The runtime queries route through the librarian's discretion.

### Integration with prior phases

- **Phase 1:** unchanged.
- **Phase 2a (factions), 2b (revelations), 2c (threads), 2d (Mythic-event spotlight):** unchanged. Their subagents and queries operate independently of `consult-library`. Future phases may compose (e.g., a Mythic random event with focus "Move Toward A Thread" whose thread description references an ingested module → narrator could call `consult-library` to enrich the narration), but no schema-level coupling in 3b.
- **Phase 3a (module intake):** the `intake-module` query keeps its semantics. The librarian's read access already includes `dm/modules/` via dm-fs MCP — Phase 3b's new queries reuse the existing wiring. The prompt-hardening rewrite changes the *style* of the intake-module procedure (positive-only framing) but not its function.

## Component designs

### Librarian subagent: new and revised query types

#### `consult-library`

> "consult-library for `<scope>`. Active session log: `<path-or-null>`."

The narrator provides a 1-6 word scope tag describing the current scene moment.

Procedure:

1. Call `mcp__dm-fs__list_dm_dir("modules")` via dm-fs MCP. If empty, return `[]` and log.
2. For each module slug, call `mcp__dm-fs__read_dm_file("modules/<slug>/overview.md")` and judge whether the module's themes / arc relate to the caller-supplied scope. Set aside modules with no plausible match.
3. For each surviving module, scan content files in order of relevance:
   - **Node files** (`modules/<slug>/nodes/<node-slug>.md`): if the scope describes a location, scene, or encounter, read each node file and match by node title / type / NPCs present.
   - **Hook file** (`modules/<slug>/hooks.md`): if the scope describes module entry or party recruitment.
   - **Connections file** (`modules/<slug>/connections.md`): if the scope describes movement between nodes or a conditional check.
4. For each matching content file, return `{module_slug, source_file, excerpt}` where `excerpt` is the scope-relevant section. **Never include `secrets.md` content** — that requires `reveal-from-module`.
5. **Lean inclusive on ambiguity** — same rule as revelation: if uncertain whether a section is in scope, include it. The narrator filters when weaving.
6. Return the list (possibly empty).
7. Append a single line to the active session log via Edit:
   ```
   - LIBRARIAN QUERY: consult-library for <scope> — <K> excerpts from <M> modules
   ```

#### `reveal-from-module`

> "reveal-from-module `<slug>` for `<reveal scope>`. Active session log: `<path>`."

The narrator provides the module slug and a reveal-scope phrase describing the in-fiction moment that earns the reveal.

Procedure:

1. Call `mcp__dm-fs__read_dm_file("modules/<slug>/secrets.md")`. If the file doesn't exist, return `{error: "no such module or no secrets.md"}` and log.
2. Match the reveal scope against secrets.md content sections (Twists & reveals, Hidden NPC identities & motives, Hidden locations / passages, DM-only context). Use LLM judgment.
3. **Default to no match on ambiguity** — exact opposite of `consult-library`'s lean-inclusive rule. The narrator's reveal scope must unambiguously match a specific secret. If multiple secrets plausibly match, return `{reason: "scope matches multiple reveals; refine and re-query"}`.
4. If matched, return `{module_slug, reveal_section, excerpt, tag: "[REVEAL]"}`. If not, return `[]`.
5. Append session-log line:
   ```
   - LIBRARIAN QUERY: reveal-from-module <slug> for <reveal scope> — <found-or-none>
   ```

#### `intake-module` (rewritten with positive-only framing)

The contract and procedure stay functionally identical to Phase 3a's. The rewrite removes the dense-negation framing that caused the Phase 3a smoke-test discipline failure.

Changes:

- **Drop** these negative bullets from the `## Your contract` section:
  - "Write module content to `library/modules/<slug>/` or anywhere under `library/` other than `library/index.md`. **Phase 3a's contract is that `library/modules/` remains a `.gitkeep`-only directory.**"
- **Drop** these negative bullets from `## What you don't do`:
  - "Don't write module content to `library/modules/<slug>/` or anywhere under `library/` other than `library/index.md`. Phase 3a's contract is that the `library/modules/` directory stays as `.gitkeep`-only."
- **Drop** any other inline mention of `library/modules/<slug>/` as a destination, including from the `## Write access` section's parenthetical and any procedure-step caveats.
- **Replace with** a single positive sentence at the top of `## Your contract`:
  > "All module content writes go to `dm/modules/<slug>/` via the dm-fs MCP. The library side gets exactly one write: an enumeration entry appended to `library/index.md`."
- **Replace** the `## Write access` section's library-write bullet with a positive-only form:
  > "`library/index.md` — writable directly via Edit. This is the librarian's only write path under `library/`."
- **Keep:** the read-access section, the per-file content specifications for each of the six `dm/modules/<slug>/` files, the procedure steps (procedure now flows positively: write everything to dm/modules/<slug>/, then update library/index.md), the intake summary template, edge cases, session-log logging conventions.

Anticipated effect: Phase 3a's smoke-test discipline failure (librarian wrote 6 v1-style files to `library/modules/<slug>/` before correctly writing 14 v2-style files to `dm/`) was caused by repeated negative mentions of the path acting as positive cues. Removing them eliminates the cue source. The structural enforcement (settings.json `dm/**` denies) does not change — the discipline rule is the library/ side, which has no settings-level enforcement.

### CLAUDE.md routing rule 9

Inserted after rule 8 (Random event composition), before `## Session log conventions`:

> ### 9. Runtime librarian queries
>
> When a scene moment may intersect an ingested module, invoke the librarian with "consult-library for `<scope>`. Active session log: `<path>`." The librarian returns 0+ excerpts of module content (node descriptions, hooks, connections) matching the scope. Weave the relevant excerpt into prose; do not surface content beyond what the party has perceived in-fiction. Never read `library/modules/<slug>/` directly — the directory is intentionally empty and module content lives under `dm/modules/<slug>/` which is denied to you. The librarian is your sole runtime path to module content.
>
> When the in-fiction moment unambiguously matches a reveal the party has earned — defeated the boss, solved the puzzle, the prophecy speaks — invoke "reveal-from-module `<slug>` for `<reveal scope>`. Active session log: `<path>`." Use this deliberately: a reveal is a player-facing beat, not exploratory prep.
>
> You learn what modules are available by reading `library/index.md` (genre-level enumeration only — does not pre-spoil content). The narrator-perspective premise/arc of a module is hidden from you until `consult-library` returns a relevant excerpt.

Plus one new must-never bullet (added to `## What you must never do`):

> - Never invoke `reveal-from-module` exploratory or pre-emptively — only when the in-fiction moment unambiguously matches a reveal trigger the party has earned through play.

### Repository layout (Phase 3b additions)

No new files. Modifications only:

```
gygaxagain/
├── .claude/
│   └── agents/
│       └── librarian.md             # MODIFIED — two new query types; intake-module rewritten with positive framing
└── CLAUDE.md                         # rule 9 added; one new must-never bullet
```

## Smoke test for Phase 3b

### Primary smoke test — real-session consult of Phandalin

1. With the v2 librarian prompt hardened (positive-framing rewrite landed) and the Phandalin intake from Phase 3a still in `dm/modules/ancient-tomb-of-phandalin/`, the user runs `/session-start`.
2. The narrator reads `library/index.md` and sees the Phandalin module enumerated.
3. The user, or the narrative, brings the party to the cemetery outside Phandalin.
4. The narrator invokes the librarian: `"consult-library for 'party arrives at cemetery outside phandalin'. Active session log: <path>."`
5. The librarian:
   - Lists `dm/modules/` via dm-fs MCP, finds `ancient-tomb-of-phandalin`.
   - Reads `dm/modules/ancient-tomb-of-phandalin/overview.md`, judges the scope matches the module's themes.
   - Reads `dm/modules/ancient-tomb-of-phandalin/nodes/cemetery-exterior.md`, matches.
   - Returns `[{module_slug: "ancient-tomb-of-phandalin", source_file: "nodes/cemetery-exterior.md", excerpt: <cemetery node content>}]`.
6. The narrator paraphrases the cemetery excerpt into the scene's opening prose. Player engages.
7. The party explores into the tomb. The narrator queries again: `"consult-library for 'party descends into tomb entrance hall'."` Librarian returns the tomb-entrance-f1 node excerpt.
8. Play continues. The narrator pulls each subsequent node via `consult-library` as the party enters it.
9. At a moment where the party defeats the boss or otherwise earns a major reveal, the narrator invokes `"reveal-from-module ancient-tomb-of-phandalin for 'party defeats undead mage and learns his identity'. Active session log: <path>."` Librarian returns the Kodor reveal from `secrets.md`.
10. `/session-end` commits.

**Pass criteria:**

- Session log contains `LIBRARIAN QUERY: consult-library ...` lines, one per scene transition where the librarian was queried.
- Session log contains `LIBRARIAN QUERY: reveal-from-module ...` line for the boss-defeat reveal.
- dm-fs access log shows librarian-issued reads of `modules/ancient-tomb-of-phandalin/overview.md`, `nodes/*.md` files matching the queried scenes, and `secrets.md` for the reveal query. **No reads of `secrets.md` during `consult-library` calls.**
- **Asymmetry audit:** narrator (main agent) issues zero direct reads of `dm/modules/<slug>/`. All module content flows through the librarian's responses.
- **Response-layer audit:** narration up to the boss-defeat does NOT reference Kodor's identity, Rewalt's lie, or any other content from `secrets.md`. After the reveal query, narration may reference the revealed content.
- The narrator's prose for each scene matches the corresponding `dm/modules/<slug>/nodes/<node>.md` content without leaking adjacent-node info (e.g., narrating the cemetery doesn't preview the crematorium's furnace mechanics).
- All 87 existing tests continue to pass; no Python code added.

### Secondary smoke test — scaffolded (optional)

If full session play is impractical, a scaffolded variant: dispatch the librarian directly with `consult-library for "ancient cemetery with old tomb"` and verify the response shape (one excerpt from Phandalin's overview or cemetery-exterior node, no secrets.md content). Then dispatch `reveal-from-module ancient-tomb-of-phandalin for "boss identity revealed"` and verify a Kodor-related reveal is returned. Less narrative; faster validation. Use only if real play is unavailable.

### Librarian-discipline re-validation (optional)

Phase 3a's smoke test exposed a librarian-discipline failure (dense-negation prompt → v1-style files written to `library/modules/<slug>/` before correctly writing to `dm/modules/<slug>/`). Phase 3b's prompt-hardening rewrite eliminates this. To verify, re-ingest Phandalin with the hardened librarian (after first removing the existing `dm/modules/ancient-tomb-of-phandalin/` via shell) and confirm: only `dm/modules/<slug>/` is written, `library/modules/<slug>/` stays empty. If this re-validation isn't run, the Phase 3a finding stays as "addressed by prompt rewrite, validated indirectly through 3b's primary smoke test."

## Failure modes Phase 3b must handle

- **Scope ambiguity in `consult-library` returns wrong module.** Librarian uses LLM judgment on overview-vs-scope matching. If wrong, narrator catches it on read and either refines scope (re-query) or weaves a coarser scene from what came back. Lean-inclusive rule trades over-fetch for under-fetch; user can audit in session log.
- **`secrets.md` content leaks into `consult-library` response.** Hard contract failure. If observed in the smoke test, treat as a Phase 3b blocker — re-tighten the librarian prompt's `consult-library` procedure step 4 (the "never include `secrets.md`" rule) and re-test.
- **`reveal-from-module` returns wrong reveal.** Librarian uses default-to-no-match-on-ambiguity. If wrong, narrator catches and re-queries with refined scope. Multiple-match case returns explicit `reason: "scope matches multiple reveals; refine and re-query"`.
- **Narrator pre-fetches reveals exploratory.** Caught by audit of `reveal-from-module` log lines vs. narrative state. Mitigated by the new must-never bullet. If observed in practice, treat as narrator-discipline failure — note in session log, refine CLAUDE.md rule 9 wording if recurrent.
- **Module overview spans multiple themes the narrator's scope partially matches.** Librarian returns excerpts from matching files; under-match acceptable, over-match expected (lean inclusive). Narrator filters.
- **Multiple modules ingested, scopes overlap.** `consult-library` returns excerpts from each matching module. Narrator picks one to weave (same discipline as revelation's "choose at most one"). If recurrent and causing narrative drift, defer to Phase 3c (module activation slash command, cross-module composition rules).
- **`secrets.md` matches reveal scope but the party hasn't actually earned the reveal in-fiction.** Narrator-discipline failure on the calling side, not librarian. The librarian returns content matching the scope — it doesn't validate in-fiction earned-ness. The CLAUDE.md rule 9 wording carries the discipline.
- **Librarian prompt-hardening rewrite introduces new bugs in `intake-module`.** Smoke test catches them. If `intake-module` regresses post-rewrite, fix in place and re-test before merge.
- **Empty `dm/modules/` directory at session-start.** `consult-library` returns `[]` and logs. Narrator continues without module-derived content. No error.
- **`dm/modules/<slug>/` exists but is partially populated** (missing overview.md or some nodes). Librarian reads what's there; missing files contribute no excerpts. No error.

## Open questions resolved during brainstorming

- **Query shape:** Scope-based judgment-driven (Option 1 from brainstorming). Mirrors revelation's could-land pattern. Trusts the librarian's LLM judgment for scope-vs-content matching.
- **Secret-filtering:** Two query types (`consult-library` returns public only; `reveal-from-module` returns secrets on explicit deliberate invocation). Hard separation, enforced by the librarian's prompt.
- **Excerpt granularity:** Per-content-file with section-scoped trimming. A `consult-library` response is one node's relevant sections, not the whole file. Same applies to hook and connections excerpts.
- **Module activation:** Scope-based, no explicit activation slash command. The librarian decides relevance from scope. Reconsider in Phase 3c if 3+ ingested modules regularly overlap.
- **Reveal-trigger conditions in `secrets.md`:** Not formalized in 3b. Matching uses freeform content. Phase 3c may add per-reveal trigger metadata.
- **CLAUDE.md routing:** New rule 9 (runtime librarian queries) + one new must-never bullet about exploratory reveals.
- **Librarian prompt hardening:** Positive-only framing for `intake-module`'s contract section and "what you don't do" list. Eliminate all negative bullets about `library/modules/<slug>/`. Keep the structural enforcement (settings.json denies on `dm/**`).
- **MCP changes:** None. Existing read/list/write/create/append cover all 3b operations.
- **Python code:** None.
- **New files:** None. Two existing files modified (`.claude/agents/librarian.md`, `CLAUDE.md`).

## Phase 3b → Phase 3c handoff

Phase 3b's exit unlocks Phase 3c, which composes:

- **Solo-engine intake.** `library/solo-engines/<name>/`. Phase 1's mythic CLI feeds the procedures directly; library extraction is for cataloging, optional table additions, and potential alternative-engine support (Mythic GME variants, other solo engines).
- **Methodology intake.** `library/methodology/<topic>/`. Structured extraction of GM patterns and discipline rules. May influence agent prompts directly via reference links.
- **Lore reference intake.** `library/lore/<name>/`. Random tables, monster manuals, regional gazetteers. Narrator-readable (party-fact content, not future scenes).
- **URL ingestion.** Web-fetched sources behind a host allowlist.
- **Auto-proposals for `dm/factions/`, `dm/revelations/`, `dm/threads/`** from module material. The librarian flags opportunities during intake (already done in 3a/3b); 3c lets the librarian propose seed files for user review.
- **Reveal-trigger metadata in `secrets.md`.** Formalize the trigger-condition authoring at intake so `reveal-from-module` matching becomes deterministic.
- **Optional `rename_dm_file` MCP tool** if real staging directories prove necessary.

Phase 3b's runtime-query pattern is the substrate Phase 3c's additional intake types extend (each new content type adds its own query, following the same scope-based judgment pattern).

## Roadmap context

Phase 3b sits within Strategy A (vertical slices by playability). Updated phasing:

1. **Phase 1 — Minimum viable session.** *(complete)*
2. **Phase 2a — Factions and offscreen developments.** *(complete)*
3. **Phase 2b — Revelations.** *(complete; clue-level filter fix landed 2026-05-10)*
4. **Phase 2c — Mythic threads.** *(complete)*
5. **Phase 2d — Mythic-event spotlight integration.** *(complete)*
6. **Phase 3a — Source ingestion: modules (intake-only).** *(complete)*
7. **Phase 3b — Runtime librarian queries (`consult-library` + `reveal-from-module`) + librarian prompt hardening.** *(this design)*
8. **Phase 3c — Source ingestion: solo engines, methodology, lore, URL. Plus auto-proposals for factions/revelations/threads. Plus optional rename_dm_file.**
9. **Phase 4 — Full bookkeeper.** Verification, structural-change proposals, content authoring formalization.
10. **Phase 5 — Progression.** Milestones (consumes Phase 3a's milestone-candidate proposals), `/level-up`, `/status` family.
11. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync.
12. **Phase 7 — Downtime, banking, bastions.**

Phase 3b's scope is what's locked here.
