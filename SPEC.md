# Solo Campaign Engine — Specification

A base project for solo tabletop RPG campaigns run through Claude Code, designed to be cloned per campaign. Theater of the mind. Markdown-as-database. Subagent-driven information asymmetry. Methodology rooted in Justin Alexander's *So You Want To Be A Game Master*, with Mythic Game Master Emulator as the discipline layer for genuine uncertainty. West Marches structure — fixed home base, exploratory outward expansion, persistent world state between sessions.

## Core principles

**Information asymmetry is structural, not instructional.** "DM-only" comments inside files are unreliable. The architecture instead enforces information boundaries by scoping which subagents can read which files. The main narrative agent — the one that talks to you during play — only ever sees player-knowable information. Hidden state lives behind subagents that act as one-way valves, exposing only observable consequences.

**Markdown files are the source of truth.** All persistent state lives in `.md` files in a git repository. Git diffs are the audit trail. The LLM cannot quietly rewrite history because every change is visible in the next commit. No databases for campaign state. The only structured-data exception is combat (deferred to a later spec).

**Prep situations, not plots.** Following Alexander, the system models situations with their own internal logic and lets play emerge. Faction clocks advance based on what the party did or didn't do. Locations exist independently of whether they're visited. Revelations are tracked separately from the scenarios that contain them.

**Randomness is external to the narrative agent.** Mythic rolls happen in a dedicated subagent that returns raw results. The narrative agent has to incorporate them rather than choosing convenient outcomes. This prevents the LLM from drifting toward "GM fudging dice for the favorite player" — the solo equivalent failure mode.

**Save during play; commit at session end.** Mechanical state changes constantly during play — HP, conditions, spell slots, inventory, ammo, light sources, NPC dispositions, the Chaos Factor, threads opening and closing. These are written to disk as they happen so state survives crashes, context resets, and breaks. But git commits are reserved for session end, where the bookkeeper produces a coherent reviewable changelog rather than a noisy stream of mid-play diffs. The working tree drifts during a session; at close, it commits as one or a few logical changes. Both Alexander's running-notes practice and Mythic's procedural state management assume live tracking — pretending state is read-only during play would break both methodologies.

**Smart prep, not exhaustive prep.** The world is generated lazily. Regions outside the discovered area exist only as high-level pointers until the party approaches. This keeps context windows clean and prevents committing to detail that play will never reach.

## Repository layout

```
campaign-name/
├── CLAUDE.md                    # Top-level instructions, agent routing rules
├── SPEC.md                      # This document
├── .claude/
│   ├── agents/                  # Subagent definitions
│   │   ├── narrator.md
│   │   ├── world-state.md
│   │   ├── revelation.md
│   │   ├── mythic.md
│   │   ├── dice.md
│   │   ├── librarian.md
│   │   └── bookkeeper.md
│   ├── commands/                # Slash commands
│   │   ├── intake.md
│   │   ├── session-start.md
│   │   ├── session-end.md
│   │   ├── ask-oracle.md
│   │   ├── roll.md
│   │   ├── downtime.md
│   │   ├── level-up.md
│   │   └── status.md
│   └── settings.json            # Permission scoping
├── world/                       # Player-knowable world state
│   ├── home-base/               # The keep, town, whatever the home base is
│   │   ├── overview.md
│   │   ├── npcs/
│   │   └── locations/
│   ├── regions/                 # Discovered or rumored regions
│   │   └── <region-name>/
│   │       ├── overview.md
│   │       ├── locations/
│   │       └── npcs/
│   └── factions/                # Public-facing faction info only
├── party/                       # All party-member state, organized by control type
│   ├── primary/                 # The player's primary PC
│   │   └── <name>.md
│   ├── companions/              # Player-controlled companion PCs (DM voices)
│   │   └── <name>.md
│   ├── npcs/                    # DM-controlled NPCs traveling with the party
│   │   └── <name>.md
│   ├── party-resources.md       # Shared inventory, mounts, party funds
│   ├── banking.md               # Deposits, debts, lines of credit per character
│   └── bastions/                # PHB 2024 bastion state (when applicable)
│       └── <character>/
│           ├── overview.md
│           ├── facilities.md
│           └── hirelings.md
├── progression/                 # Leveling state and milestone tracking
│   ├── milestones.md            # Player-facing: milestones reached, what's next
│   └── level-up-log.md          # Record of each level-up event
├── sessions/                    # Session logs (player-facing)
│   ├── play/                    # Adventure sessions
│   │   └── YYYY/MM/session-NNN.md
│   └── downtime/                # Downtime sessions (separate cadence)
│       └── YYYY/MM/downtime-NNN.md
├── dm/                          # DM-only — never read by narrator agent
│   ├── factions/                # Hidden faction state, clocks, agendas
│   ├── npcs/                    # Hidden NPC sheets — true motives, secrets
│   ├── revelations/             # Revelation list, clue tracker
│   ├── nodes/                   # Full node maps with secret connections
│   ├── rolls/                   # Hidden roll log
│   ├── milestones/              # Pre-committed milestone definitions
│   └── threads/                 # Mythic-style open threads
├── library/                     # Source content ingested via /intake
│   ├── modules/                 # Module summaries and node extractions
│   ├── solo-engines/            # Mythic, One Page Solo Engine, etc.
│   ├── methodology/             # Alexander's frameworks, house rules
│   └── index.md                 # Searchable index for the librarian agent
└── meta/
    ├── chaos-factor.md          # Current Mythic Chaos Factor
    ├── campaign-config.md       # System, tone, conventions, party level
    ├── dice-config.md           # Dice visibility, authority, system rules
    ├── party-config.md          # Party composition rules and authority
    └── decisions/               # Architecture decision log
```

## Agent architecture

Seven subagents, each with a tight job and scoped file access. The main DM agent (the narrator) is what you actually converse with during play. Everything else is invoked by it as needed, or by slash commands.

### Narrator (main agent)

**Role:** Voices NPCs the party has met, describes scenes, runs encounters, drives the moment-to-moment narrative.

**Read access:** Everything in `world/`, `characters/`, `sessions/`, `meta/campaign-config.md`. Never reads `dm/`.

**Write access during play:** Player-facing live state — character sheets (HP, conditions, spell slots, inventory), party resources, the active session log (append-only), NPC dispositions for NPCs the party is currently interacting with, environmental trackers (light, rations, time of day), location state for areas the party is in. All writes are to working tree only — no commits. The bookkeeper at session end verifies and commits.

**Write access for structural changes:** None. Faction clocks, hidden NPC sheets, revelation tracking, undiscovered region state — all bookkeeper-only.

**Behavior rules:**
- Never invents hidden state. When the player asks something whose answer would be hidden, queries the world-state or revelation agent.
- Never decides "yes/no" outcomes for genuinely uncertain questions. Routes those to the mythic agent.
- Voices NPCs from their public sheets. If a hidden trait would influence their behavior, the world-state agent surfaces only the observable consequence.
- Distinguishes between *narration* (what the party perceives) and *resolution* (what mechanically happens). Asks the player for declared actions before resolving them.

### World-state agent

**Role:** Owns hidden world state. Acts as a one-way information valve.

**Read access:** Everything, including `dm/factions/`, `dm/npcs/`, `dm/nodes/`.

**Write access:** None during play. The world-state agent is a pure query interface; structural changes to hidden state are the bookkeeper's job at session end.

**Interface:** The narrator queries it with structured questions. The agent returns only observable consequences, never raw hidden values.

Example queries and responses:
- *"Has anything changed with the cult faction this session?"* → "Rumors are circulating in the keep that another caravan failed to arrive from the south. The Curate seems more anxious than usual at evening services." (Never: "The cult clock is at 4/6.")
- *"What does the priest with two acolytes do when the party confronts him?"* → "He acts confused and offended, citing his standing in the chapel. He glances briefly toward the inn before recovering his composure." (Never: "He is the secret antagonist and is signaling his accomplices.")
- *"Is there anything in this region the party hasn't discovered?"* → "Yes — there is unexplored content. Should I surface a hook?" (Never the actual content until discovered.)

### Revelation agent

**Role:** Owns the revelation list and clue tracker. Following Alexander's three-clue rule, ensures every revelation has multiple delivery paths and tracks which have been delivered.

**Read access:** `dm/revelations/`, `world/`, `sessions/` (to know what's been encountered).

**Write access during play:** Updates the clue-delivery log when the narrator confirms a clue has actually been delivered in play (e.g., "Sariel noticed the cult symbol on the merchant's ledger — revelation R-04 delivered via clue C-04b"). This keeps the three-clue accounting live. Working tree only.

**Write access for structural changes:** None. The revelation list itself — what revelations exist, what their available clue paths are — is bookkeeper-territory at session end.

**Interface:**
- *"What revelations are still pending?"* → Returns a structured list of what the party doesn't yet know, with available clue vectors.
- *"The party is investigating the chapel. What clues could land here?"* → Returns clue options scoped to the location.
- *"Has revelation X been delivered?"* → Yes/no with which session and which clue.

The agent never delivers a clue itself — it suggests options that the narrator can weave in. This keeps clue placement grounded in fictional opportunity rather than mechanical force.

### Mythic agent

**Role:** Executes Mythic Game Master Emulator procedures. Pure mechanism, no interpretation.

**Read access:** `meta/chaos-factor.md`, `dm/threads/`.

**Write access during play:** Updates `meta/chaos-factor.md` per Mythic rules at scene boundaries. Updates `dm/threads/` when threads open or close based on play. Appends a roll log so every oracle result is recoverable. All writes are to working tree only — the bookkeeper commits at session end. These writes are *required* for the procedure to work; Chaos Factor adjustments and thread management are mid-session mechanics in Mythic, not retrospective bookkeeping.

**Interface:**
- *"Fate Chart: likely. Current Chaos Factor: 5."* → Returns roll, result (Yes/No, with optional Exceptional or And/But modifiers), and any random event trigger.
- *"Random event check."* → Rolls and returns event focus, action, and subject from Mythic tables, raw and uninterpreted.
- *"Adjust Chaos Factor."* → Increments or decrements per the rules of the current scene outcome.

The agent does not interpret results. The narrator (or the world-state agent for thread-relevant events) interprets, with the raw roll visible in the session log so the player can see the dice were honest.

### Dice agent

**Role:** Executes dice rolls. Pure mechanism, deterministic, unfudgeable. Same discipline-mechanism logic as the mythic agent — externalizing randomness from the narrator so outcomes can't drift toward narrative convenience.

**Implementation note:** The roller itself is code, not an LLM. A dice expression parser plus a CSPRNG. The "agent" boundary exists for policy (visibility, authority, logging) and for the natural-language interface ("roll a perception check for Sariel"), but the actual rolling is procedural. This is what makes rolls genuinely unfudgeable: no model is in the loop choosing the result.

**Read access:** `characters/` (for modifier lookup), `meta/dice-config.md` (for visibility defaults and authority rules).

**Write access during play:** Appends to `sessions/YYYY/MM/session-NNN.md` for visible rolls. Appends to `dm/rolls/hidden.md` for hidden rolls. Both are working-tree-only; bookkeeper commits at session end.

**Roll visibility — three modes per roll:**

- **Open.** Result shown to the player immediately. Logged to session log. Default for player-declared actions, monster attacks, anything where transparency is part of the play experience.
- **Hidden.** Result not shown to the player. Logged to `dm/rolls/hidden.md` with full detail (expression, raw result, modifier, total, what it was for, the narrative resolution that followed). Default for perception/insight checks where knowing the roll undermines the uncertainty, for opposed checks where the player shouldn't know the opposition's number, for anything the DM would traditionally roll behind the screen. The player can review the hidden log on demand — delegation isn't forfeiture of verification.
- **Player-rolled.** No system roll. The player rolls physical or app dice and reports the result. The dice agent records the reported result in the session log with a flag noting it was player-reported. No verification is possible, but transparency is preserved through the flag.

**Roll authority — who can call for what:**

- **Player authority:** Always allowed to declare any roll for their own characters (attacks, saves, skill checks, ability checks, damage). Always allowed to choose visibility mode for their own rolls.
- **Narrator authority:** Allowed to call for any roll appropriate to the situation — perception checks, saving throws against effects, opposed checks. Visibility defaults from the config; can be overridden by player request.
- **System authority:** Monster attacks, NPC saves, environmental effects, random encounters. Visibility defaults to open per 5e convention; configurable per campaign.

The authority axis and the visibility axis are independent. The narrator can call for a player-character perception check (narrator authority) that's resolved hidden (visibility mode) — that's the classic "you don't know whether you saw something" experience.

**Interface:**
- *"Roll 1d20+5 for Sariel's perception, hidden."* → Rolls, logs to hidden, returns nothing visible to the player. Narrator gets the result for narrative resolution.
- *"Player rolled a 17 on attack against the orc."* → Records as player-reported, narrator proceeds with resolution.
- *"Roll initiative for the encounter."* → Open by default for player characters, configurable for NPCs (5e convention is open; some campaigns prefer hidden NPC initiative).
- *"Show me the hidden rolls from this session."* → Returns the hidden log, scoped to current session by default.

**Configuration via `meta/dice-config.md`:**

The per-campaign dice settings file. Defaults are sensible 5e but every roll type can be overridden. Structure:

- **Default visibility per roll type** — attacks (open), damage (open), saves (open for player, hidden for NPC), perception/insight/investigation (hidden by default), social skills (configurable), opposed checks (hidden NPC side), initiative (per preference), death saves (open).
- **Authority rules** — which rolls the narrator can call without asking, which require player consent first.
- **Critical handling** — natural 20s/1s, expanded crit ranges, system-specific rules.
- **Advantage/disadvantage** — handling for sources, stacking rules.
- **Custom roll macros** — campaign-specific shortcuts (e.g., `/roll cult-encounter` rolls on the campaign's cult encounter table).
- **Player preference** — global override letting the player request "always show me everything" or "be more aggressive about hidden rolls."

**Special integration with mythic:**

When a Mythic random event triggers an action that requires a dice roll (e.g., an event suggests an NPC attacks the party), the mythic agent's interpretation flows naturally into a dice agent call. The two agents are designed to compose: Mythic answers "what happens," dice resolves "with what mechanical outcome," narrator translates both into prose.

### Librarian agent

**Role:** Curates content from the `library/` directory. Pulls relevant material when asked, doesn't dump whole files into context.

**Read access:** `library/` and `world/` (to know what's already established).

**Write access:** Updates `library/index.md` when new material is ingested.

**Interface:**
- *"Find a level-3-appropriate hook involving the cult faction."* → Returns a curated suggestion drawn from ingested modules, formatted as a single hook with citations.
- *"What does the source material say about the road south?"* → Returns relevant excerpts and pointers, not the whole regional chapter.
- *"Suggest a waypoint for a new region the party is entering."* → Picks from available modules and solo engine procedures, considering what's already established.

The librarian is the system's defense against the LLM ignoring source material in favor of generic generation. It's also where `/intake` deposits structured summaries (see commands below).

### Bookkeeper agent

**Role:** Owns structural state changes, verifies live writes from the session, and is the sole committer to git. Runs primarily at session end.

**Read access:** Everything.

**Write access:** Everything. During play, dormant. At session end, performs three jobs in sequence:

1. **Verify live state.** Reads everything that changed in the working tree during the session and cross-checks against the session log. Does the HP on Sariel's sheet match what the narrative says happened? Did inventory changes get reflected on the right characters? Are NPC disposition changes consistent with how scenes resolved? Flags any inconsistencies for the user to resolve before commit. This is the audit step that catches mid-play errors that nobody noticed in the moment.

2. **Propose structural changes.** Reads the session log and proposes updates the live agents couldn't make: faction clock advances, hidden NPC state shifts, revelation list updates (new revelations added or paths revised), region discovery promotion (an unexplored region becoming partially known), node connection reveals, library cross-references. Presents these as a structured changelog for user review.

3. **Commit.** After the user reviews and confirms, commits the live writes plus the structural changes as one or a few logical commits with descriptive messages. Each commit is scoped to a single logical change where possible (e.g., separate commits for "session log + character state," "faction state advances," "revelations delivered"). Tags the session.

**Behavior rules:**
- Never invents new state — only reflects what happened in play.
- Never edits prior session logs. Append-only.
- Never silently fixes inconsistencies. Surfaces them and asks.
- Mid-session, can be invoked manually for major structural events (a faction openly declaring war, a region revealing itself dramatically) but the default is dormant until `/session-end`.

This agent is where most things can go wrong, so it's deliberately the most constrained: explicit invocation only, verification before structural writes, propose-before-commit, small reviewable diffs.

## Party composition and control

Solo play with a small adventuring band requires distinguishing between members the player drives, members the narrator drives, and members where authority is shared. Treating them all the same — as the spec previously did — produces friction: the narrator either over-controls the player's PC or under-controls the NPCs. The party model addresses this directly.

Three distinct member types, each with its own file directory and authority rules:

### Primary PC (`party/primary/`)

The player's main character. The player decides every action, declares every roll, and speaks every line of dialogue. The narrator describes the world this character experiences, voices the NPCs they interact with, and resolves the mechanical consequences of declared actions, but never autonomously acts on behalf of the primary PC.

If the narrator believes the primary PC would do something — react to a sudden noise, recognize a familiar smell — it surfaces that possibility ("Sariel, your years in the watch tell you that footstep cadence — what do you want to do?") rather than narrating the action directly. The line is firm: the player is the only authority over this character.

The dice agent treats player-declared rolls with `player` authority — visibility defaults to open, and the player can always override to use physical dice and report.

### Companion PCs (`party/companions/`)

Fellow adventurers the player runs but the narrator voices. The player makes the strategic and consequential decisions — what they attack, what they cast, whether they enter a room, whether they accept a deal. The narrator handles voicing, mannerisms, banter, and minor non-consequential improvisation, with the player able to override at any time.

The split that works well in practice: **the player owns the verbs, the narrator owns the voice.** "Thorne attacks the orc with his greataxe" is the player's call. *How* Thorne curses while doing it, what he says afterward when the orc falls, whether he wipes the blade on his cloak — narrator territory, with the player free to redirect anything that feels off-character.

For consequential choices, the narrator should ask before acting. "Thorne is the closest to the wounded merchant — does he stop to help, or follow the rest of you?" The default is to ask; only minor improvisation is unilateral.

Companion sheets in `party/companions/` include both the mechanical block and a **voicing brief**: speech patterns, recurring phrases, mannerisms, opinions on common topics, relationships with other party members. This lets the narrator voice them consistently across sessions without needing the player to micromanage.

The dice agent treats companion PC rolls with player authority by default (the player declares them) but allows the narrator to call for them when appropriate ("Thorne, give me a perception check") — the player can either let the system roll or take control of the roll.

### NPC party members (`party/npcs/`)

Allies, hirelings, hangers-on the DM controls. The narrator decides their actions per their stated motivations and personality. The player can request things ("ask the ranger to scout ahead," "tell the cleric to fall back") but doesn't command them — these characters have their own minds and may decline, hesitate, or counter-propose.

NPC party members carry hidden state in `dm/npcs/` like any other NPC — true motives, secret allegiances, things they haven't told the party. A "loyal" hireling might be a faction spy. A wandering ranger might have their own agenda the party hasn't yet discovered. This is what makes adding NPCs to the party narratively interesting.

The dice agent treats NPC party member rolls with system authority — the narrator calls for and resolves them, with visibility per the dice config (often open for transparency but sometimes hidden for opposed checks or hidden agendas).

NPC party members can be promoted to companion status if the player formally takes them on (in 5e terms: a sidekick rather than a hireling, or a ranger who explicitly joins the party long-term). Promotion is a deliberate act, recorded by the bookkeeper, that moves the file from `party/npcs/` to `party/companions/` and adds a voicing brief if not already present. The hidden NPC sheet in `dm/npcs/` may persist or be merged in; that's a campaign-specific call.

### Authority matrix

| Decision type           | Primary PC | Companion PC | NPC party member |
|-------------------------|------------|--------------|------------------|
| Combat actions          | Player     | Player       | Narrator         |
| Skill check declaration | Player     | Player       | Narrator         |
| Spellcasting choices    | Player     | Player       | Narrator         |
| Movement                | Player     | Player       | Narrator         |
| Dialogue (consequential)| Player     | Player       | Narrator         |
| Dialogue (flavor)       | Player     | Narrator     | Narrator         |
| Reactions to events     | Player     | Narrator (asks if consequential) | Narrator |
| Accepting/refusing deals| Player     | Player       | Narrator         |
| Equipment use           | Player     | Player       | Narrator         |
| Mannerisms / voice      | Player     | Narrator     | Narrator         |

This matrix lives in `meta/party-config.md` along with any campaign-specific overrides. A campaign where companions are more autonomous — say, with their own loyalty meters and the possibility of disagreement — would adjust the table accordingly.

### Implications across the system

The party composition model has consequences that propagate:

**Dice agent.** Authority defaults change per character type. The `/roll` command's character-name lookup must distinguish primary/companion (player authority) from NPC (narrator authority).

**Leveling.** Different rules per type — see the leveling section below. Primary and companion PCs level on milestones together; NPC party members typically don't level by milestone but by narrative event or recruitment tier.

**Bookkeeper verification.** When auditing a session for narrator overreach, the bookkeeper checks specifically: did the narrator declare actions for the primary PC? Did the narrator make consequential decisions for companions without asking? These are violations of the party model and should be flagged.

**Bastions.** Each PC gets their own bastion at the appropriate level. NPC party members do not. Companions might or might not, depending on whether the player wants to manage that complexity.

## State taxonomy: live vs. structural

Every file in the campaign falls into one of three categories. The categorization determines who can write to it during play and who's responsible for it at session end.

**Live state — writable during play by the agent that owns the relevant procedure.**

- `party/primary/<name>.md` — primary PC sheet. HP, conditions, spell slots, inventory, exhaustion, temporary effects. Player-driven; narrator updates only mechanical resolution per declared actions.
- `party/companions/<name>.md` — companion PC sheets. Same mechanical fields plus voicing brief. Updated by the narrator with player override available.
- `party/npcs/<name>.md` — NPC party member sheets. Narrator-driven updates.
- `party/party-resources.md` — shared inventory, mounts, hirelings, party funds. Written by the narrator.
- `party/banking.md` — banking state. Updated during downtime, occasionally during adventure sessions for major transactions.
- `party/bastions/<character>/` — bastion state during bastion turns and operations. Written by the narrator during downtime.
- `sessions/play/YYYY/MM/session-NNN.md` and `sessions/downtime/YYYY/MM/downtime-NNN.md` — active session logs. Append-only during play, written by the narrator. The bookkeeper appends a structured summary at session end but never edits prior content.
- `meta/chaos-factor.md` — written by the mythic agent at scene boundaries.
- `dm/threads/active.md` — written by the mythic agent when threads open or close.
- `dm/revelations/delivered.md` — written by the revelation agent when a clue is confirmed delivered in play.
- `dm/rolls/hidden.md` — written by the dice agent for hidden rolls. Player can review on demand but it's not surfaced to the narrator.
- `world/<region>/locations/<name>.md` for currently-occupied locations — environmental state (lit/unlit, doors open/closed, NPCs present), written by the narrator.
- NPC disposition trackers within `world/` for NPCs the party is interacting with — written by the narrator.

**Structural state — bookkeeper-only, modified at session end through the review process.**

- `dm/factions/*.md` — faction clocks, agendas, current operations. Advances based on what the party did or didn't do during the session.
- `dm/npcs/<name>.md` — hidden NPC sheets with true motives, secrets, allegiances. Updated when revelations or events shift them.
- `dm/revelations/list.md` — the master revelation list itself, with available clue vectors. Modified when revelations are added, retired, or have their delivery paths revised.
- `dm/nodes/<region>.md` — full node maps with secret connections. Modified when discoveries promote nodes from unknown to known, or when play creates new node relationships.
- `dm/milestones/*.md` — pre-committed milestone definitions. Added at intake or via deliberate user action. The bookkeeper checks against them but does not silently modify them.
- `progression/milestones.md` — player-facing milestone summary. Updated when milestones are confirmed hit.
- `progression/level-up-log.md` — record of each level-up event. Append-only by the bookkeeper.
- `world/<region>/overview.md` — the player-facing region summary. Modified when discovery promotes content or rumors land.
- `world/factions/<name>.md` — public-facing faction summaries. Modified when the party's perception of a faction shifts.
- `library/index.md` — when the librarian deposits new material from intake, or when a region's content gets exhausted.

**Reference state — read-only during play, modified only by `/intake` or manual editing.**

- `library/modules/`, `library/solo-engines/`, `library/methodology/` — ingested source material. Stable.
- `meta/campaign-config.md` — campaign-wide settings. Edited by the user, not by agents.
- `meta/dice-config.md` — dice visibility defaults, authority rules, and system-specific roll handling. Edited by the user.
- `meta/party-config.md` — party authority matrix and overrides. Edited by the user.
- `SPEC.md`, `CLAUDE.md`, `.claude/` — system files. Edited by the user.

This taxonomy is the practical instantiation of the save-during-play / commit-at-session-end principle. Live state changes constantly and must persist immediately. Structural state changes occasionally and benefits from review. Reference state doesn't change in the normal play loop at all.

## Leveling

This system uses **milestone leveling** exclusively. XP is not tracked. Leveling is a structural campaign event triggered when a pre-defined narrative milestone is reached, not a continuous accumulation that the narrator might trigger at convenient moments.

### Pre-committed milestones

Milestones are defined in advance — at campaign start and as new content is intaked — and stored in `dm/milestones/`. Each milestone specifies:

- **Trigger condition.** What needs to happen for the milestone to be hit. Specific enough to be unambiguous: "Party clears the Caves of Chaos and returns to the keep" rather than "Party makes significant progress."
- **Resulting level.** Which level the party advances to. Often "next level" but can specify floor/ceiling for slow or fast tracks.
- **Optional gating.** Whether other conditions must also be true (cumulative milestones, "and" relationships).
- **Source.** Module-derived, campaign-derived, or improvised. Improvised milestones added during play should be recorded explicitly so they can be reviewed.

Milestones are DM-only (in `dm/milestones/`) but a player-facing companion file `progression/milestones.md` summarizes what's known: "Major story beats reached so far. Next narrative chapter would advance the party." The player sees that progression is happening but not the exact triggers.

### How milestones are recognized

The narrator does not declare milestones. The bookkeeper, at session end, reads the session log and checks against the pre-committed milestone list. If a trigger condition appears to have been met, it surfaces this for the user to confirm: "The Caves of Chaos appear cleared based on this session — does milestone M-03 trigger?" The user decides yes/no, and on yes, the level-up procedure begins.

This is the same discipline-mechanism logic used elsewhere: the narrator could be tempted to level the party at narratively satisfying moments rather than at the pre-committed beats. Routing milestone recognition through the bookkeeper, against a pre-committed list, prevents drift.

The user can also manually trigger leveling via `/level-up` if a milestone was reached but the bookkeeper missed it, or to apply a milestone outside the normal flow.

### Per-character-type rules

**Primary PC and Companion PCs** level together on milestones. They are part of the player's adventuring band and share the same advancement track.

**NPC party members** do not level on milestones. They advance via narrative event (recruited at a higher tier, gained experience from a specific quest, leveled by a patron) or remain static, per the narrator's discretion. This keeps NPC power scaling under DM control rather than automatic. An NPC party member's level is set when they join and changes only when the bookkeeper records a deliberate advancement event.

If a campaign wants NPC party members to level with the party (a common house rule for sidekicks), this is configurable in `meta/party-config.md`.

### The level-up procedure

When `/level-up` is invoked or a milestone is confirmed:

1. Bookkeeper writes the milestone-hit record to `progression/level-up-log.md`.
2. For each leveling character, the narrator presents the available choices per the system rules: class features, ASIs/feats, spell selections, subclass choices at appropriate levels, hit point determination (rolled, averaged, or fixed per house rule).
3. Player makes choices for primary PC and companions. Narrator can suggest options but does not decide.
4. Updated character sheets are written to `party/primary/` and `party/companions/`.
5. New abilities are noted in the session log.
6. If a level threshold for bastions is crossed (level 5 in 2024 rules), the bastion creation flow triggers — see below.
7. The level-up event is committed as a separate logical commit at next `/session-end`, or immediately if invoked outside session play.

Hit point determination defaults to the system standard (PHB 2024: average rounded up after first level) but is configurable in `meta/campaign-config.md`. If rolling for HP, the dice agent handles it with `open` visibility.

## Downtime

Downtime is **a different mode of play** with its own session type, its own command, and its own resolution flow. It runs at a different time scale (days, weeks, months rather than minutes and hours) and involves transactional procedures that don't fit naturally into adventure narrative — shopping, banking, crafting, training, research, bastion turns, faction interactions over time.

### When downtime happens

Triggered explicitly by the player via `/downtime`, typically:

- After returning to a settled location with significant accumulated wealth, injuries, or projects.
- Between major chapters of the campaign.
- At level-up, when new abilities benefit from training time.
- When the player wants to advance long-running personal projects.

Downtime is not automatic — the player chooses when to enter downtime mode. Some campaigns will have lots of it; some will have very little.

### Downtime sessions

A downtime session has its own log file in `sessions/downtime/YYYY/MM/downtime-NNN.md`, distinct from adventure session logs. The two are not interleaved — when the player runs `/downtime`, the session is explicitly bracketed: it has a start ("the party returns to the keep with their winnings"), a duration ("two weeks of rest and recovery"), and an end ("when the party prepares to set out again"). World-state advances during this period via faction clocks ticking and threads progressing per Mythic procedures.

The narrator's role during downtime shifts: less moment-to-moment scene description, more transactional and bookkeeping-style narration ("Sariel spends the morning at the chapel; she finds Curate Aldous reviewing the morning's offerings"). Companion PCs and NPC party members pursue their own activities per their motivations — the player can direct or leave it to them.

### Procedures available during downtime

Configurable per campaign, but typical options include:

- **Resting and recovery.** Long-term injuries, level drains, exhaustion, restoration of expended resources beyond the long-rest cycle.
- **Shopping and crafting.** Purchasing, commissioning, or crafting equipment. Time and gold costs per system rules.
- **Banking.** Deposits and withdrawals, debt payment, lines of credit, investments. Tracked in `party/banking.md`.
- **Training.** Practicing new abilities gained from leveling, learning languages, weapon proficiencies (if the system supports cross-training).
- **Research.** Investigating clues, learning about factions, identifying magic items, library work.
- **Carousing and connections.** Building relationships in town, rumor-gathering, faction reputation.
- **Personal projects.** Long-running goals — building something, pursuing a romance, writing a book.
- **Bastion turns.** If a character has a bastion, their bastion turn resolves during downtime — see below.
- **Faction time advancement.** Mythic clocks advance per the elapsed time. The world-state agent reports observable consequences.

The narrator manages the procedures, the dice agent handles any rolls, the bookkeeper at downtime-end commits the resulting state changes.

### Banking

Maintained in `party/banking.md`. Per character (because banking is usually personal, not shared):

- Deposits at named institutions.
- Outstanding debts with terms.
- Lines of credit or ongoing accounts.
- Standing arrangements (a regular tithe, a patron's stipend, a tax obligation).

Banking is largely transactional and can be resolved with simple narration plus updates. The narrator handles routine deposits and withdrawals. Larger financial events (taking out a loan, opening a new account, currency exchange across regions) may merit more involved scene play.

### Bastions

Per the 2024 PHB rules, characters of appropriate level (default level 5) may establish a **bastion** — a personal stronghold, sanctuary, or base of operations. Each PC has their own bastion; they are not shared.

Bastion state lives in `party/bastions/<character>/`:

- `overview.md` — name, location, defenders, basic facilities.
- `facilities.md` — special facilities by type (Sanctum, Library, Workshop, etc.), with their levels and operational status.
- `hirelings.md` — bastion staff, their roles, loyalty, and recent activities.

A `bastion-events.md` file may also live in `dm/` for hidden state — secret rooms, hireling true allegiances, ongoing schemes.

### Bastion turns

Bastion turns happen at the cadence specified in the rules (typically every 7 in-game days, or per session at the DM's discretion). During downtime, accumulated bastion turns are resolved together. The narrator runs the bastion turn procedure: facility actions resolve, hireling activities produce results, bastion events trigger per the random event tables, and any defenders contend with attacks if they happened.

The dice agent handles all bastion rolls — these are typically open by default, but bastion event rolls (random encounters, hireling complications) may default to hidden.

The bookkeeper updates bastion state at `/session-end` for downtime sessions, just as for adventure sessions.

### Bastion creation

When a character first reaches the bastion-eligible level, the level-up procedure triggers a bastion creation flow:

1. Player chooses bastion location (often the home base, but can be elsewhere).
2. Player selects starting facilities per the rules.
3. Initial hirelings are determined.
4. Bastion files are created in `party/bastions/<character>/`.
5. Initial bastion overview added to `progression/level-up-log.md`.

Creation is a one-time event per character. After that, bastions evolve through bastion turns.

## Slash commands

### `/intake <path-or-url>`

Ingests source material into the campaign library. The argument can be a PDF, a markdown file, a folder, or a URL.

**Behavior:**
1. Determines material type (module, solo engine, methodology, lore reference).
2. For modules: extracts node-based summary per Alexander's framework — locations, NPCs, hooks, secrets, conditional connections — into `library/modules/<module-name>/`. Generates a one-paragraph summary, a node list with brief descriptions, and a flagged-content list of things the system shouldn't surface to the narrator agent (twists, secret villains, plot reveals). Also identifies natural milestone candidates (chapter completions, major story beats, dungeon clears) and proposes them for `dm/milestones/` — the user reviews and confirms which become committed milestones.
3. For solo engines: extracts the procedures (oracle tables, event tables, scene structure rules) into `library/solo-engines/<engine-name>/` in a format the mythic or world-state agent can call.
4. For methodology: stores the source plus a structured extraction of techniques into `library/methodology/`.
5. Updates `library/index.md` with the new material, tagged by content type, level range, themes, and faction archetypes.

**Critical guardrail:** During intake, secret/twist content is identified and stored in `dm/` rather than `library/`. The narrator agent must not be able to see "the priest is the secret villain" through the library. Intake parses for these patterns explicitly and quarantines them.

### `/session-start [optional-focus]`

Begins a play session.

**Behavior:**
1. Loads campaign config and current chaos factor.
2. Queries world-state agent for offscreen developments since last session.
3. Queries revelation agent for currently-deliverable clues.
4. Queries librarian for any region-relevant material if the party is in transit or entering new territory.
5. Generates a session-start brief: where the party is, what's changed in the world they'd plausibly hear about, what's currently pressing, what's optionally available.
6. Hands control to the narrator with this loaded context.

The optional focus argument lets the user steer: `/session-start exploration` or `/session-start cult-investigation` or `/session-start downtime`. The narrator weights setup accordingly.

### `/session-end`

Closes a session and triggers bookkeeping.

**Behavior:**
1. Bookkeeper agent surveys the working tree to identify all live writes made during the session.
2. **Verification phase.** Cross-checks live writes against the session log narrative. Flags any inconsistencies (HP that doesn't match damage taken, inventory changes without narrative cause, NPC dispositions inconsistent with how scenes resolved). Presents flags to the user for resolution.
3. **Structural phase.** Proposes structural changes the live agents couldn't make: faction clock advances, hidden NPC state shifts, revelation list updates, region promotion, node connection reveals. Presents as a structured changelog.
4. User reviews and confirms. May edit either the verification fixes or the structural proposals before proceeding.
5. Generates a session summary appended to `sessions/YYYY/MM/session-NNN.md`.
6. Updates the chaos factor based on whether the player was in or out of control of the session arc (if not already updated mid-session by the mythic agent).
7. Commits everything as one or a few logical commits with descriptive messages. Tags the session.

### `/ask-oracle <question> [likelihood]`

Direct interface to the mythic agent for ad-hoc oracle questions. Returns the roll, result, and any triggered event without interpretation. Logs the question and result to the session log so the dice trail is visible.

### `/roll <expression> [visibility] [reason]`

Direct interface to the dice agent. The expression is standard dice notation: `1d20+5`, `2d6`, `4d6kh3`, `2d20kh1+3` (advantage with +3), `2d20kl1+3` (disadvantage), and so on. Modifiers from character sheets can be referenced by name: `/roll perception sariel` looks up Sariel's perception modifier and rolls.

**Visibility argument** is optional; defaults to the configured visibility for the roll type. Explicit values: `open`, `hidden`, `player` (player will report the result instead).

**Reason** is a freeform tag for the log: `/roll 1d20+3 hidden "spotting the priest's accomplices"`. Helpful for reviewing hidden rolls later.

Examples:
- `/roll 1d20+7 attack` — rolls Sariel's attack, default visibility (open).
- `/roll perception thorne hidden` — rolls Thorne's perception, hidden from the player.
- `/roll 2d20kh1+5 stealth` — advantage stealth roll.
- `/roll player 1d20+4 save` — player will roll physically and report; agent records the reported result.

### `/show-hidden-rolls [scope]`

Player-facing command to review the hidden roll log. Default scope is current session; can be expanded to `last-N`, `all`, or filtered by reason. The log shows everything: expression, raw result, modifier, total, what it was for, and what happened narratively. The player chose to delegate the rolling, not the auditing.

### `/downtime [duration]`

Enters downtime mode. Optional duration argument — "two weeks", "until next moon", "indefinite" — frames the elapsed in-game time. If omitted, the player is prompted to specify.

**Behavior:**
1. Brackets the current adventure session (if one is active, requires `/session-end` first or auto-prompts).
2. Creates a new downtime session log at `sessions/downtime/YYYY/MM/downtime-NNN.md`.
3. Advances faction clocks and threads per Mythic procedures for the elapsed time. World-state agent reports observable consequences as the period progresses.
4. Resolves bastion turns for any character with a bastion.
5. Presents available downtime activities per the campaign config and party composition. Player chooses what each character pursues; companions and NPCs may have their own preferred activities the player can override.
6. Narrator runs the chosen procedures, with the dice agent handling rolls and the bookkeeper updating state at downtime-end.
7. `/session-end` closes the downtime session and commits.

Downtime can be paused — entering an adventure during downtime exits downtime mode cleanly, and downtime can be resumed afterward if elapsed time hasn't completed.

### `/level-up [character]`

Triggers the level-up procedure for a character (or all leveling characters if omitted). Normally invoked automatically by the bookkeeper when a milestone is confirmed, but available for manual use.

**Behavior:**
1. Confirms the milestone or advancement reason for the record.
2. For each leveling character, walks through the system's level-up choices: class features, ASIs/feats, spell selections, subclass choices, hit points (per config — average, rolled, or fixed).
3. Updates character sheets in `party/primary/` and `party/companions/`.
4. Triggers bastion creation flow if a level threshold is crossed.
5. Appends to `progression/level-up-log.md` and updates `progression/milestones.md`.
6. Logs the event in the active session log.

NPC party members are not leveled by this command unless explicitly named — their advancement is narrative.

### `/bastion <action> [character]`

Direct interface to bastion management outside of downtime — viewing current state, scheduling facility work, dispatching hirelings, reviewing recent bastion events.

**Actions:**
- `/bastion status [character]` — current state summary.
- `/bastion turn [character]` — manually run a bastion turn (normally these batch during downtime).
- `/bastion order <character> <facility> <action>` — issue an order to a facility for the next bastion turn.
- `/bastion hireling <character>` — review or update hireling assignments and morale.

If a character is omitted, the command lists all bastions in the party and prompts for which.

### `/status [scope]`

Read-only query against current state. Default scope summarizes recent activity. Optional scopes:
- `/status factions` — observable faction situation (filtered through world-state agent)
- `/status threads` — open threads from Mythic
- `/status revelations` — what's been delivered, what's pending (player-facing summary only)
- `/status region <name>` — what the party knows about a region
- `/status party` — party composition, levels, current state summary
- `/status progression` — recent milestones, what advancement is available

This is the player-facing dashboard. It never leaks DM-only information.

## CLAUDE.md routing rules

The top-level `CLAUDE.md` enforces the architecture by giving Claude Code explicit routing instructions. Key sections:

**File access boundaries.** Files matching `dm/**` are never read during normal play. They are read only by the agents authorized for them (world-state, revelation, mythic, bookkeeper) and only via explicit invocation. The narrator agent has these paths actively blocked.

**Subagent invocation patterns.** When the narrator needs hidden information, it must invoke the world-state agent rather than reading directly. The CLAUDE.md provides example prompts: "I need to know whether the merchant has heard rumors of the cult — invoke world-state agent."

**Mythic discipline.** Any genuinely uncertain yes/no question goes through `/ask-oracle` or the mythic agent. The narrator does not decide. Examples are provided so the model recognizes the pattern.

**Dice discipline.** Any mechanical roll goes through the dice agent or the `/roll` command. The narrator never invents a roll result, never narrates "you roll an 18" without a real roll behind it, and never adjusts a roll outcome for narrative reasons. If the narrator needs to know whether a character notices something, it calls for a perception check — visibility default per config — and resolves based on the actual result. Hidden rolls are still real rolls; the player just doesn't see them.

**Party authority.** The narrator never declares actions for the primary PC. For companion PCs, the narrator handles voicing and minor flavor but defers to the player on consequential choices — combat actions, spellcasting, accepting deals, deciding to stay or leave. NPC party members are narrator-controlled with player-as-suggester only. The authority matrix in `meta/party-config.md` is the reference; CLAUDE.md provides examples of where the lines fall.

**Milestone discipline.** The narrator never declares a milestone hit or initiates a level-up. Milestone recognition is the bookkeeper's job at session end, against the pre-committed list in `dm/milestones/`. The narrator can describe events that *would* trigger a milestone in narrative terms but does not announce mechanical advancement.

**Smart prep policy.** The narrator does not generate detailed content for regions the party hasn't entered. If improvisation is needed, it requests material from the librarian first; only if nothing applies does it generate, and generated content is flagged for the bookkeeper to formalize at session end.

**Session log conventions.** Every session log includes oracle rolls inline, NPC dispositions at scene boundaries, and a "loose ends" section that becomes input to the bookkeeper.

## Configuration: `meta/campaign-config.md`

The per-campaign settings file. Cloned-and-edited rather than generated. Contents:

- **System and edition** (e.g., D&D 5e 2014, 5e 2024, OSE, Shadowdark).
- **Source material connections** (D&D Beyond, Obvious Mimic library paths, etc.).
- **Tone and content guidance** — pulpy vs grim, on-screen content boundaries, comic register.
- **Home base** — what and where, faction landscape at start.
- **Starting threads** — what the campaign opens with.
- **Chaos Factor initial value** — usually 5.
- **Leveling settings** — milestone-only (default), HP determination (average/rolled/fixed), bastion-eligible level (default 5), whether NPC party members level with the party (default no).
- **Downtime settings** — available activities, default downtime cadence, banking system enabled (yes/no), bastion turn cadence.
- **House rules** — anything custom that the bookkeeper or narrator needs to respect.

## Configuration: `meta/party-config.md`

The party authority configuration. Defines the authority matrix and any campaign-specific overrides:

- **Member roster** — who is primary, who is companion, who is NPC, with file paths.
- **Authority matrix** — the table from the party composition section, with any overrides.
- **Companion voicing defaults** — global guidance for how companions are voiced when not specified per-character.
- **Promotion rules** — what triggers an NPC party member becoming a companion, and any reverse demotion rules.
- **Override conventions** — how the player signals "I'll take this one" for a companion action that would normally be narrator-handled.

## What's deliberately deferred

**Combat / spatial play.** Theater of the mind for v1. The architecture leaves room for a `combat/` directory and a tactical agent later, with state served by an external Rails app over MCP. Out of scope for this spec.

**Image generation.** NPC portraits, location sketches, faction sigils. Pluggable later via local Flux or an API.

**Voice play.** Whisper transcription of player turns. Pluggable later.

**Multi-vendor model routing.** v1 runs on Claude Code with whatever subscription tier is active. The architecture supports per-agent model assignment if migrated to direct API later, but doesn't depend on it.

**Multiplayer.** Solo only. The information asymmetry model assumes a single player whose knowledge boundary the system is enforcing. Adding multiple players changes the model significantly.

## Bootstrapping a new campaign

Workflow for cloning this base into a real campaign:

1. Clone the base repo to `<campaign-name>/`.
2. Edit `meta/campaign-config.md` for the system, tone, leveling, and downtime settings.
3. Edit `meta/party-config.md` to match the party composition for this campaign.
4. Run `/intake` on the primary module(s): the home-base material, the immediate adventure region. Intake also seeds `dm/milestones/` with module-derived milestones (e.g., "clear the Caves of Chaos") which the user reviews.
5. Run `/intake` on any solo engines being used (Mythic, One Page Solo Engine, etc.).
6. Run `/intake` on methodology references (Alexander's book, house rules documents).
7. Create the primary PC sheet in `party/primary/<name>.md` and any companion sheets in `party/companions/`. Each companion sheet must include a voicing brief.
8. If starting with NPC party members, create their public sheets in `party/npcs/` and hidden sheets in `dm/npcs/`.
9. Manually populate `world/home-base/overview.md` with the starting situation as the party would know it.
10. Review and edit `dm/milestones/` to ensure the campaign has at least the next 2-3 milestones pre-committed beyond what intake produced.
11. Run `/session-start` to begin play.

The base repo ships with empty directory structures, agent definitions, command definitions, and a templated `CLAUDE.md`. The campaign-specific content is added by intake and play.

## Failure modes to watch for

**Quiet retconning.** The bookkeeper changes a fact in an NPC file in a way that contradicts an earlier session log. Mitigation: bookkeeper diffs are reviewed before commit; session logs are append-only and prior content is never edited (only the structured summary section is added at session end).

**Live-write corruption.** A live agent writes incorrect state mid-play — wrong HP, wrong inventory, disposition update on the wrong NPC. Mitigation: the bookkeeper's verification phase at session end cross-checks live writes against the session log and flags inconsistencies. The git diff against the last session-end commit shows everything that changed.

**Uncommitted state on crash.** A session ends abruptly (crash, context loss, life interrupting) before `/session-end` runs. Mitigation: live writes are already on disk, so resumption picks up from where play left off. On the next session start, the user can either run `/session-end` retroactively against the unfinished session log, or continue play and commit at the natural close. The working tree being dirty across days is fine; what matters is that nothing is lost.

**DM-only leakage.** A hidden fact appears in narration. Mitigation: structural file scoping plus periodic audits — grep DM-only content against recent session logs.

**Library bypass.** The narrator improvises content where a module already exists. Mitigation: librarian is consulted first by convention enforced in CLAUDE.md; bookkeeper flags improvised content for later reconciliation.

**Mythic bypass.** The narrator decides yes/no on a question that should have been an oracle roll. Mitigation: explicit examples in CLAUDE.md; user can invoke `/ask-oracle` retroactively if a decision feels too convenient.

**Dice bypass.** The narrator narrates a mechanical outcome without rolling — "the orc misses you" without an attack roll, "you spot the hidden door" without a perception check. Mitigation: explicit dice-discipline rule in CLAUDE.md; the bookkeeper at session end audits the session log for mechanical outcomes that don't have a corresponding roll, and flags them. Over time, the player can also catch these in the moment and ask "what did the orc roll?"

**Hidden-roll erosion.** The player stops trusting hidden rolls because outcomes feel too convenient or inconvenient. Mitigation: `/show-hidden-rolls` is always available; the player can spot-check the hidden log periodically. The cryptographic fact that real RNG was used doesn't help if trust is gone, so transparency on demand is the safety valve.

**Primary PC overreach.** The narrator narrates an action for the player's primary PC — "Sariel draws her sword and steps forward" — instead of asking what the player does. Mitigation: explicit party authority rule in CLAUDE.md; the bookkeeper at session end audits for narration that includes primary PC actions not declared by the player, and flags them. Common at the start of scenes; gets rarer as the model recognizes the pattern.

**Companion silent override.** The narrator decides a consequential action for a companion PC without asking — "Thorne refuses to enter the cave" — when it should have been a player decision. Mitigation: companion voicing brief includes a "consequential vs flavor" guideline; bookkeeper audit catches major cases.

**Milestone drift.** The narrator advances the party at a moment that feels right rather than at a pre-committed milestone. Mitigation: milestone recognition is bookkeeper-territory; the narrator never initiates `/level-up`. If the player feels a moment deserves a level but no milestone matches, they can manually trigger advancement and add a milestone to the list — but it's a deliberate choice, not narrator drift.

**NPC autonomy collapse.** NPC party members become extensions of the player's will, doing whatever's asked without their own agendas or pushback. Mitigation: hidden NPC sheets in `dm/npcs/` carry true motivations; the world-state agent surfaces those motivations as observable behavior; the narrator is reminded by CLAUDE.md that NPC party members have their own minds.

**Context bloat.** As the campaign grows, the narrator's context fills with NPC files, location files, and session logs. Mitigation: smart prep keeps unvisited regions thin; the librarian curates rather than dumps; sessions older than a few weeks are summarized rather than included verbatim.

**Subagent confusion.** The narrator agent reads a file it shouldn't because the routing wasn't tight enough. Mitigation: `.claude/settings.json` permission scoping, plus CLAUDE.md routing rules, plus the dm/ directory naming convention as a defense in depth.

**Live-write thrashing.** Multiple agents writing to the same file in quick succession during play, producing a messy working tree. Mitigation: the state taxonomy assigns clear ownership — only one agent owns each live file. If two agents need to update related state, one of them defers to a structural change at session end rather than writing live.

## Methodology references

This system is grounded in:

- *So You Want To Be A Game Master* — Justin Alexander. Node-based scenario design, three-clue rule, prep-situations-not-plots, smart prep, revelation lists.
- *Mythic Game Master Emulator* — Tana Pigeon. Fate Chart, Chaos Factor, random events, threads list.
- *Keep on the Borderlands* and the *Into the Borderlands* compilation — Goodman Games. Reference for what a heavy-roleplay home base with faction tension looks like in classic D&D, and a worked example of West Marches outward expansion.
- The *Alexandrian* blog — extensive supplementary methodology, especially on running investigations and managing sandboxes.

Where these conflict, Alexander wins for prep structure, Mythic wins for randomness procedure, and the system architecture wins for information flow.
