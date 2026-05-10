# Phase 1 — Minimum Viable Session: Design

**Status:** Draft for review.
**Parent spec:** `SPEC.md`.
**Phasing strategy:** Strategy A (vertical slices by playability). Phase 1 of an estimated 6–7 phases.

## Purpose

Phase 1 produces a Claude Code project where you can run a ~30-minute smoke-test play session that exercises the full architecture pattern at minimum scale. It is foundation, not first real play. Its job is to validate, against a throwaway test scenario, that the spec's information-asymmetry pattern actually works in Claude Code's runtime — before five more agents are built on top of it.

## Definition of done

A successful Phase 1 smoke test demonstrates all of:

- One playable scene runs from `/session-start` through `/session-end`.
- At least one dice roll executes through the dice subagent + Python script.
- At least one Mythic oracle call executes through the mythic subagent + Python script.
- At least one query to the world-state subagent surfaces information from `dm/` to the narrator (the asymmetry valve fires).
- The narrator demonstrably cannot read `dm/**` directly. `.claude/settings.json` denies plus the absence of the `dm-fs` MCP from its toolset enforce this mechanically.
- A session log is written and `/session-end` produces a single clean commit.

## Out of scope (deferred to later phases)

Revelation tracking and three-clue rule, librarian and `/intake`, full bookkeeper verification, milestone tracking and `/level-up`, downtime, banking, bastions, multi-character parties (companions, NPC party members), DnDB bidirectional sync (Phase 6), thread management in mythic, full random-encounter generation.

## Architecture

### Mechanism mapping

The spec describes seven agents. Phase 1 maps them to Claude Code's actual mechanisms as follows:

| Spec concept           | Phase 1 implementation                                       |
|------------------------|--------------------------------------------------------------|
| Narrator               | The user's main Claude Code session, with strict CLAUDE.md routing |
| Dice agent             | Subagent (Haiku) wrapping a Python dice/RNG script           |
| Mythic agent           | Subagent (Haiku) wrapping a Python Mythic procedure script   |
| World-state agent      | Subagent (Sonnet) — sole consumer of the `dm-fs` MCP         |
| Revelation, librarian, bookkeeper | Deferred to later phases                          |
| Slash commands         | `/session-start`, `/session-end`, `/roll`, `/ask-oracle`     |
| `dm/` access boundary  | Custom Python MCP server (`dm-fs`) + project-wide `dm/**` denies |

### Information-asymmetry enforcement

Asymmetry is enforced by three layers acting together:

1. **Project-wide deny rules in `.claude/settings.json`.** `Read`, `Write`, `Edit`, `Glob`, `Grep` against `dm/**` are denied for everyone (main agent and all subagents). A non-exhaustive set of `Bash` denies (`cat`, `grep`, `head`, `tail`, `less`, `more`, `find`, `rg` against `dm/*`) covers obvious shell paths.
2. **`dm-fs` MCP server.** A small custom Python MCP server exposes path-scoped read/list tools restricted to `dm/`. Wired into the world-state subagent's `mcpServers:` frontmatter only — the world-state subagent is the *sole* consumer in Phase 1. Main agent and all other subagents do not have it. The MCP is the *only* path to `dm/` content — denies block direct filesystem and shell access; the MCP provides controlled, audited access.
3. **Routing discipline in CLAUDE.md.** The narrator's instructions explicitly route hidden questions to the world-state subagent and forbid attempts at direct `dm/` access.

The narrator therefore has no filesystem path to `dm/` content. The world-state subagent reads `dm/` only through the MCP, which is itself a controlled, auditable interface. This realizes the spec's claim that "narrator has these paths actively blocked" as mechanical fact rather than aspiration.

### Subagent context isolation

Each subagent invocation receives a fresh context window with its own system prompt. The narrator does not see the dice subagent's modifier lookups, the mythic subagent's Fate Chart math, or the world-state subagent's raw hidden data. Subagents return only their interface-promised output. This is the structural defense against long-session narrator drift: even if the narrator's discipline degrades over a 3-hour session, it has no cached knowledge of hidden state to leak, because hidden state never enters its context in the first place.

### Per-agent model assignment

`.claude/agents/*.md` frontmatter supports a `model:` field. Phase 1 assignments:

- Narrator (main agent): user's session model (Sonnet or Opus).
- Dice subagent: Haiku — pure mechanical wrapping of a deterministic script.
- Mythic subagent: Haiku — pure mechanical wrapping with light formatting.
- World-state subagent: Sonnet (default) — real interpretation work translating hidden state to observable consequences.

## Component designs

### Repository layout (Phase 1)

```
gygaxagain/
├── CLAUDE.md
├── SPEC.md                              (existing; parent spec)
├── README.md
├── .gitignore                           (existing; references/ already excluded)
├── .mcp.json                            (registers dm-fs MCP)
├── docs/superpowers/specs/
│   └── 2026-05-09-phase-1-mvp-session-design.md  (this file)
├── .claude/
│   ├── agents/
│   │   ├── dice.md
│   │   ├── mythic.md
│   │   └── world-state.md
│   ├── commands/
│   │   ├── session-start.md
│   │   ├── session-end.md
│   │   ├── roll.md
│   │   └── ask-oracle.md
│   └── settings.json
├── tools/
│   ├── dice/                            (Python package)
│   │   ├── pyproject.toml
│   │   ├── src/dice/
│   │   │   ├── __init__.py
│   │   │   ├── parser.py
│   │   │   └── cli.py
│   │   └── tests/
│   ├── mythic/                          (Python package)
│   │   ├── pyproject.toml
│   │   ├── src/mythic/
│   │   │   ├── __init__.py
│   │   │   ├── fate_chart.py
│   │   │   ├── chaos.py
│   │   │   └── cli.py
│   │   └── tests/
│   └── dm-fs-mcp/                       (Python MCP server)
│       ├── pyproject.toml
│       ├── src/dm_fs/
│       │   ├── __init__.py
│       │   └── server.py
│       └── tests/
├── party/
│   ├── primary/
│   │   └── <character>.md               (transcribed from DnDB)
│   ├── companions/.gitkeep
│   └── npcs/.gitkeep
├── world/
│   ├── home-base/
│   │   ├── overview.md
│   │   └── npcs/
│   │       └── <public-npc>.md
│   └── regions/.gitkeep
├── dm/
│   └── npcs/
│       └── <hidden-npc>.md              (asymmetry test stub)
├── sessions/
│   └── play/.gitkeep
├── meta/
│   ├── campaign-config.md
│   ├── dice-config.md
│   └── chaos-factor.md
└── references/                          (gitignored — PDFs)
```

Spec directories not yet populated by Phase 1 (`library/`, `progression/`, `dm/factions/`, `dm/revelations/`, etc.) are not created. They land in their respective phases.

### Character sheet markdown format

Two-section structure with explicit static-vs-dynamic separation, designed so Phase 6 can later sync the static section against DnDB without untangling co-mingled fields.

```markdown
---
name: <PC name>
system: dnd5e-2024
class: <class>(<level>)
race: <species>
character_id_dndb: <id>          # for future Phase 6 sync
---

# <PC name>

## Build
<!-- Static character data. DnDB will own this in Phase 6.
     Updated by /level-up (later phase) or manual edit. -->

- Race: <species, subspecies>
- Class: <class>, level <n>
- Background: <bg>
- Alignment: <align>
- Ability scores: STR <n> / DEX <n> / CON <n> / INT <n> / WIS <n> / CHA <n>
- Proficiency bonus: +<n>
- Saves (proficient): <list>
- Skills (proficient): <list>
- Class features: <list>
- Racial traits: <list>
- Feats: <list>
- Spells known/prepared: <list>
- Equipment as built: <inventory at character creation>
- AC base: <n>
- Initiative: <mod>
- Speed: <ft>

## Live
<!-- Dynamic state. MD always owns this. -->

- HP: <current>/<max> (temp: <n>)
- Conditions: <list with durations>
- Spell slots used: 1st <a/b>, 2nd <a/b>, ...
- Per-day uses: <feature> <a/b>, ...
- Inventory delta: <items consumed/found/given since creation>
- Exhaustion: <n>
- Death saves: <successes>/<failures>
- Notes: <free-form>

## Modifiers
<!-- Derived from Build. Read by dice subagent for /roll lookups.
     Can be regenerated programmatically. -->

- Perception: +<n>
- Insight: +<n>
- Stealth: +<n>
- ...
- Attack — <weapon>: +<n> to hit, <dice> damage (<type>)
- Spell save DC: <n>
- Spell attack: +<n>
```

The frontmatter exists to give scripts a stable parseable handle on identity fields. The body sections are plain markdown for human readability and narrator/agent consumption.

### Dice subagent and Python script

**Python dice package (`tools/dice/`).**

Pure parser plus CSPRNG using the standard library `secrets` module. CLI entry point invocable as `python -m dice.cli roll "<expression>"` (or via uv/pipx if preferred during implementation).

Phase 1 grammar:
- Arithmetic dice: `1d20+5`, `2d6+3`, `1d4-1`
- Multiple dice expressions: `1d8+1d6+5`
- Keep highest / keep lowest: `4d6kh3` (ability rolls), `2d20kh1` (advantage), `2d20kl1` (disadvantage)
- Critical syntax (for future expansion, not Phase 1 essential): not yet
- Modifier-by-name lookup: not in the script itself; the dice subagent handles modifier lookup before invoking the script

CLI output is structured JSON:
```json
{
  "expression": "1d20+5",
  "raw_rolls": [14],
  "modifier": 5,
  "total": 19,
  "kept": [14],
  "dropped": []
}
```

Unit tests cover parser edge cases and a statistical sanity test on distribution shape.

**Dice subagent (`.claude/agents/dice.md`).**

- Model: Haiku.
- Tools allowed: Read (on `party/`, `world/`, `meta/dice-config.md`), Bash (to invoke the dice CLI), append to active session log. **No `dm-fs` MCP access in Phase 1.**
- System prompt:
  - Receive a roll request: either a raw expression, or a named skill plus character.
  - For named-skill requests: read the character's sheet, find the modifier in the `## Modifiers` section, assemble the expression.
  - Read `meta/dice-config.md` for visibility default per roll type.
  - Apply visibility per request override or default.
  - Invoke the dice CLI; capture JSON result.
  - For open rolls: append a one-line entry to the active session log.
  - For player-rolled: skip the script; record reported result with `player-reported` flag.
  - Return to caller: result for narrative use, with explicit `visibility` field so caller knows what (if anything) to surface.

**Phase 1 dice deferrals.** Hidden rolls (`dm/rolls/hidden.md`) and the `/show-hidden-rolls` command land in Phase 2 alongside the rest of `dm/` proliferation. Phase 1's smoke test exercises dice routing with open rolls only; that's sufficient to validate the dice path. Keeping the dice subagent off the `dm-fs` MCP in Phase 1 also keeps the asymmetry boundary maximally simple: only world-state holds the MCP.

### Mythic subagent and Python script

**Python mythic package (`tools/mythic/`).**

Implements the subset of Mythic Game Master Emulator needed for Phase 1:
- Fate Chart percentage lookup: 2D-table indexed by likelihood × current Chaos Factor, producing roll thresholds.
- Yes/No oracle resolution with Exceptional Yes / Exceptional No bands and Random Event detection (Mythic's "doubles within Chaos range" trigger).
- Random event resolution from Mythic's Event Focus, Action, Subject tables.
- Chaos Factor adjustment (increment/decrement) per scene outcome.

Exact percentages and tables are sourced from the Mythic GME PDF in `references/`; verified against the source during implementation.

CLI:
```
mythic oracle --likelihood likely --cf 5
mythic event
mythic chaos --adjust +1
```

Output is structured JSON; CLI itself does not interpret events into narrative — that's the narrator's job per spec.

**Mythic subagent (`.claude/agents/mythic.md`).**

- Model: Haiku.
- Tools allowed: Read and Write on `meta/chaos-factor.md`, Read on `meta/campaign-config.md` (for initial CF if uninitialized), Bash to invoke the mythic CLI, append to active session log.
- No `dm-fs` MCP access in Phase 1 (threads deferred).
- System prompt:
  - Receive an oracle question with optional likelihood (default `50/50`).
  - Read current Chaos Factor.
  - Invoke fate chart CLI; if event triggered, invoke event CLI.
  - Format result for narrator: `Oracle: Yes (Exceptional). Random event: NPC Action — focus on Curate Aldous.`
  - Append raw roll and result to active session log inline.
  - Update Chaos Factor when explicitly asked (typically at scene end, called by `/session-end` in Phase 1).
  - Return formatted result.

Phase 1 deferrals: no `dm/threads/` writes; thread management lands in Phase 2.

### World-state subagent

**Subagent (`.claude/agents/world-state.md`).**

- Model: Sonnet (default).
- Tools allowed: Read on `world/`, `party/` (to know what's been established and what the party knows); access to `dm-fs` MCP for read/list of `dm/`. Append to active session log allowed for query records.
- System prompt:
  - Receive a structured query from the narrator.
  - Phase 1 supports three query types:
    - "What does NPC X do when [situation]?" — read public sheet from `world/`, hidden sheet from `dm/npcs/<x>.md` via MCP, surface only observable behavior consistent with hidden state.
    - "Has anything changed with [topic] this session?" — Phase 1 stub: no factions running; returns minimal "nothing observable from offscreen" answer.
    - "Is there hidden content the party hasn't discovered in [scope]?" — Phase 1 stub: yes/no with optional one-line tease, no concrete reveal.
  - Never returns raw hidden values, faction clock numbers, or unrevealed plot content.
  - Returns prose suitable for narrator to weave into description.

Phase 1's stub world-state agent meaningfully implements the first query type. The second and third types are scaffolded for Phase 2 expansion.

### `dm-fs` MCP server

**Python MCP (`tools/dm-fs-mcp/`).**

Implements the MCP protocol over stdio using the official Python MCP SDK. Exposes a small, read-only interface to `dm/`:

- `read_dm_file(relative_path: str) -> str` — returns file contents.
- `list_dm_dir(relative_path: str = "") -> list[str]` — returns directory listing relative to `dm/`.

Phase 1's `dm-fs` MCP is read-only. Write operations (e.g., `append_dm_file` for hidden roll log, `write_dm_file` for thread state) land in Phase 2 when more `dm/` content needs live updates.

Path safety:
- All inputs resolved relative to project's `dm/`.
- Reject paths containing `..` or absolute paths.
- Reject symlinks that point outside `dm/`.
- Reject paths that resolve outside `dm/` after canonicalization.

Audit log: every call writes a line to a project-local log file (location TBD during implementation — likely `tools/dm-fs-mcp/access.log`, *outside* `dm/` so it's not subject to its own deny rules) recording timestamp, tool, path, and calling agent if available from MCP context. Nice-to-have; deferrable if it complicates initial implementation.

`.mcp.json` at project root registers the server with stdio transport. Only the world-state subagent definition lists it under its `mcpServers:` frontmatter; no other agent has access.

### Slash commands

**`/session-start [optional-focus]`** (`.claude/commands/session-start.md`).

Phase 1 lite. Prompt template instructs the main agent to:
1. Determine next session number; create `sessions/play/YYYY/MM/session-NNN.md` with header (date, focus, party state snapshot).
2. Read `meta/campaign-config.md` for system, tone, party.
3. Read `party/primary/<name>.md` for current PC state.
4. Invoke world-state subagent: "Has anything changed offscreen since last session?" (Phase 1: returns minimal answer.)
5. Greet narrator with loaded context and hand off control.

**`/session-end`** (`.claude/commands/session-end.md`).

Phase 1 lite. Prompt template instructs the main agent to:
1. Append a session-end summary section to the active session log.
2. Invoke mythic subagent to update chaos factor based on scene-in-control assessment.
3. `git add -A && git commit -m "session NNN: <summary>"` — single commit.

Phase 1 explicitly does **not** include the bookkeeper's verification phase. Live writes during Phase 1 are trusted; Phase 4 introduces verification.

**`/roll <expression-or-skill> [character] [visibility] [reason]`** (`.claude/commands/roll.md`).

Prompt template parses arguments and invokes the dice subagent with structured input.

**`/ask-oracle <question> [likelihood]`** (`.claude/commands/ask-oracle.md`).

Prompt template invokes the mythic subagent with question and likelihood. Default likelihood is `50/50` if omitted.

### `.claude/settings.json` (Phase 1)

```json
{
  "permissions": {
    "deny": [
      "Read(dm/**)",
      "Write(dm/**)",
      "Edit(dm/**)",
      "Glob(dm/**)",
      "Grep(dm/**)",
      "Bash(cat dm/*)",
      "Bash(cat dm/**/*)",
      "Bash(grep dm/*)",
      "Bash(grep -r dm/)",
      "Bash(rg dm/*)",
      "Bash(less dm/*)",
      "Bash(more dm/*)",
      "Bash(head dm/*)",
      "Bash(tail dm/*)",
      "Bash(find dm/*)"
    ]
  }
}
```

The Bash deny list is best-effort — shell escapes are creative — but combined with the absence of any tool-level read path through the MCP for non-world-state agents, accidental main-agent access to `dm/` is mechanically prevented. Determined adversarial bypass is not a Phase 1 threat model; the threat model is *narrator drift*, which the layered defenses address.

### CLAUDE.md routing rules (Phase 1)

A focused subset of the spec's full routing rules. The Phase 1 CLAUDE.md establishes:

1. **Narrator role.** Voices NPCs from public sheets, describes scenes, never invents hidden state, never decides yes/no on uncertain questions. Narration ≠ resolution; ask the player for declared actions before resolving.
2. **Dice routing.** Any mechanical roll → invoke the dice subagent (or the user invokes `/roll`). Never narrate a mechanical outcome without a real roll behind it.
3. **Oracle routing.** Any genuinely uncertain yes/no question → invoke the mythic subagent (or the user invokes `/ask-oracle`). Never decide.
4. **Hidden-info routing.** Any question whose answer would require reading `dm/` content → invoke the world-state subagent. Never attempt to read `dm/` directly.
5. **Primary PC authority.** Never declare actions for the player's PC; surface possibilities for the player to react to.
6. **Session log conventions.** Append to active session log; record dice rolls inline; mark scene boundaries.

Routing rules deferred to later phases: revelation tracking, milestone discipline, library consultation, full party-authority matrix.

## Test content

- **PC.** A real character pulled from the user's DnDB library via the `dndbeyond` MCP, transcribed manually into the markdown format above. The user names the character at the start of implementation.
- **Scene.** One scene/encounter selected from `references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf`. The scene is chosen during implementation by skimming the PDF — preferring a scene with a single named NPC whose surface presentation can plausibly hide an ulterior motive (good fit for the asymmetry test).
- **Hidden NPC stub.** The chosen scene's NPC is split: a public-facing sheet at `world/home-base/npcs/<name>.md` (what the party initially knows) and a hidden sheet at `dm/npcs/<name>.md` (true motivation, secret allegiance, observable tells the world-state agent should surface).
- **System.** D&D 5e (2024 edition). Configurable in `meta/campaign-config.md`.

## Smoke test scenario

The success criterion is that all four routing patterns fire without breaking, and the narrator never reads `dm/` directly.

1. User runs `/session-start` → main agent loads context, queries world-state for offscreen developments (returns minimal in Phase 1), greets player.
2. Narrator presents the scene; PC enters the situation.
3. User declares an action requiring a roll → narrator invokes dice subagent → roll executes via Python script → narrator narrates result. (*Dice routing exercised.*)
4. User asks an uncertain yes/no question → user invokes `/ask-oracle` (or narrator routes via mythic subagent) → mythic returns formatted result → narrator weaves it in. (*Oracle routing exercised.*)
5. PC interacts with the hidden-stub NPC → narrator queries world-state subagent: "What does <NPC> do when <situation>?" → world-state reads both public sheet and hidden sheet (latter via MCP), returns observable behavior → narrator narrates. Verify via inspection that no hidden detail leaked into narration. (*Asymmetry valve exercised.*)
6. User runs `/session-end` → mythic subagent updates Chaos Factor → main agent commits working tree.

Successful smoke test: all four steps complete, all four routing flows demonstrably exercise their subagents, and a manual inspection confirms narrator never read `dm/` files (verifiable by grepping the session's tool-use log).

## Failure modes Phase 1 must handle

- **MCP server fails to start.** World-state subagent surfaces a clear error to the narrator; narrator informs the player rather than silently fabricating. The player can then invoke `/session-end` to capture state and debug offline.
- **Dice script error or unparseable expression.** Subagent reports parse error to caller; narrator informs the player and asks for clarification rather than fabricating a result.
- **Permission deny fires when it shouldn't.** Initial bring-up tests all four routing flows end-to-end; bring-up is not "done" until each fires cleanly without spurious denials.
- **Subagent invocation latency.** Acceptable per architectural intent; worth measuring during smoke test to baseline Phase 2 expectations.

## Open questions resolved during brainstorming

- *Per-subagent permission scoping in Claude Code:* not supported natively. Resolved via `dm-fs` MCP server as the enforcement boundary, paired with project-wide `dm/**` denies.
- *D&D Beyond as character source of truth:* deferred to Phase 6 (Character Integration). Phase 1 uses a one-time manual transcription from DnDB into the markdown format. Markdown remains canonical during play, per spec principle.
- *Scope of Phase 1 vs. real first session:* Phase 1 is a smoke test against throwaway content. First real campaign session begins after Phase 1's exit criteria are met.

## Phase 1 → Phase 2 handoff

Phase 1's exit unlocks Phase 2 (Hidden-state machinery): full world-state agent with faction clocks and offscreen developments, revelation agent and three-clue tracking, expanded `dm/` population, mythic threads, and broader CLAUDE.md routing rules. The `dm-fs` MCP built in Phase 1 is the foundation Phase 2 builds on, not throwaway scaffolding.

## Roadmap context

Phase 1 sits within Strategy A (vertical slices by playability). Approximate phasing:

1. **Phase 1 — Minimum viable session.** *(this design)*
2. **Phase 2 — Hidden-state machinery.** World-state full implementation, revelation agent, expanded `dm/`, mythic threads.
3. **Phase 3 — Source ingestion.** `/intake`, librarian, secret-quarantine logic.
4. **Phase 4 — Full bookkeeper.** Verification phase, structural-change proposals, commit discipline.
5. **Phase 5 — Progression.** Milestones, `/level-up`, leveling per character type.
6. **Phase 6 — Character integration.** Bidirectional MD↔DnDB sync; static/dynamic field separation enforced.
7. **Phase 7 — Downtime, banking, bastions.** Long-cadence mode and supporting systems.

Boundaries between phases are guidance; specific deliverables can shift. Phase 1's scope is what's locked.
