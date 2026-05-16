# v2 Phase 9.1 — DM turn discipline (exploration mode)

Date: 2026-05-16
Parent: Phase 9 close-out ([#10](../../../../../issues/10))
Closes: [#12](../../../../../issues/12) (narrator generates player dialogue), [#13](../../../../../issues/13) (prompt format tags leak), [#14](../../../../../issues/14) (inline dice chips), [#15](../../../../../issues/15) (markdown rendering), [#19](../../../../../issues/19) (multi-PC turn cycles in one response), [#25](../../../../../issues/25) (`scene_secrets` / `scene.dm_notes`)
Related: Justin Alexander, *So You Want to Be a Game Master* — used as the design grounding for what "being a DM" means
Successors: Phase 9.2 (combat protocol), Phase 9.3 (scene transitions, closes [#16](../../../../../issues/16)), later Phase 9.4 (travel watches)

## Context

The 2026-05-15 production playtest failed for reasons that are not really separate bugs. The narrator invented player dialogue, ran six PCs' combat turns in one streamed response, emitted prompt-format tags as visible text, and rendered markdown as plain text. The shake-out filed these as discrete blockers — but they are symptoms of one underlying gap: **the system has no concept of "whose turn it is" and no mechanism to stop the agent at the right beat.** The narrator is being asked to do the whole table's job in one streamed reply, with only a system prompt as a guardrail. When the prompt fails, the agent runs away with the fiction.

A real DM does not work this way. Justin Alexander's *So You Want to Be a Game Master* describes the play loop as a conversation enforced by structural discipline: the GM describes the situation, asks "what do you do?", and **stops talking**. The player declares. The GM resolves. Loop. The GM's most-repeated utterance in the book is some variant of *"Now what do you do?"* — the explicit handoff that prevents the GM from running away with the fiction. Phase 9.1 encodes this discipline structurally, so the failure modes become impossible by construction rather than merely discouraged.

The reframe absorbs more than the three "narrator agency" blockers (#12, #13, #19). The dice-chip and markdown blockers (#14, #15) are part of the same surface — the narrator's text output now operates under a stricter structural contract, which makes those polish layers natural to ship alongside. The scene-secrets gap (#25) belongs here too: the narrator needs proper per-scene briefings to operate as a real DM.

## Goals

- The agent operates as a turn-taking referee: describes the world, prompts the player, stops generating, waits for declarations, resolves, loops.
- The agent never invents player dialogue, decisions, tactics, or inner monologue for a PC.
- The agent never runs more than one declare→resolve cycle in a single LLM call.
- The agent never narrates the outcome of a roll the player has not performed.
- The player declares actions for every PC each turn before resolution. Companions are optional.
- The play surface is chat-based: one stream of voice-attributed events, one composer.
- Phase 9.1 makes **scene 1 of the Phandalin module fully playable** end-to-end (declaration, mid-turn rolls, resolution, multiple turns, companion DM-voicing).

## Non-goals

- **Combat** (initiative, per-PC turn prompts, killing-blow ownership). Deferred to Phase 9.2; A1's mode model accommodates it but does not implement it.
- **Scene transitions.** The scene picker is disabled in A1. Multi-scene play unlocks in Phase 9.3 (#16). Until then, the playtest is gated to scene 1.
- **Travel watches.** Phase 9.4.
- **Faction/NPC admin CRUD** (#17), **Solid Queue in Puma** (#18). Independent Phase 9 close-out work; not absorbed by 9.1.
- **DM-side Mythic oracle.** The Mythic chaos factor and Fate Chart consultation could be a future micro-phase; A1 removes the player-facing oracle and does not replace it. Revisit only if the AI's rulings feel on-rails in extended playtests.
- **Polish on top of A1's core renderers.** Cluster B polish (#20 dock layout, #21 chat-composer polish beyond core, #22 reset-campaign, #23 inline-chip polish, #27 TrimJob log spam) lives separately.
- **CI** (#26) and other infra.

## Architecture overview

### The three-character model

Solo D&D has three character types, with different agency contracts. Phase 9.1 models them as first-class distinctions:

- **PC (player character).** Full player sovereignty. Player voices, declares, rolls. The DM never speaks for them — no dialogue, no decisions, no inner life. Mandatory declaration each turn. The campaign has zero, one, or rarely two PCs; the common solo case is one (the protagonist).
- **Companion.** Hybrid. Lives in the party, has stats, takes turns. DM voices their dialogue, reactions, and low-stakes choices by default, drawing on their personality from the roster. Player can override at any time: an explicit declaration for a companion is verbatim and supersedes DM judgment. When a companion needs to roll, the DM requests the roll via a dice chip and the player rolls. **Optional declaration each turn** — silence means "DM handles them."
- **NPC.** The world. Captain Aldridge, Rewalt, Kodor, the skeletons. DM owns entirely. (Existing `Npc` model, unchanged.)

The Phandalin seed is migrated to this model: Aragorn → PC + main; Caine, Fred, Patric → companions.

### The turn cycle (exploration mode)

```
idle ──[scene loads, no events]──→ framing
  │                                   │
  │                                   ▼
  │              (framing LLM call: scene framing + "What does {main PC} do?")
  │                                   │
  │                                   ▼
  └──[narration ends with handoff]──→ collecting
                                      │
                                      ▼
                       (parse player message → 1+ pc_declaration events)
                                      │
                                      ▼
                      [every PC declared?] ── no ──→ (templated gm_collection_prompt)
                                      │                     │
                                      │ yes                 └→ (back to collecting)
                                      ▼
                       (optional one-shot companion prompt)
                                      │
                                      ▼
                                  resolving
                                      │
                                      ▼
                          (resolution LLM call: narrate outcomes)
                                      │
                          ┌───────────┼───────────────┐
                          ▼                           ▼
              [ends at open [[ … ]]?]        [ends at handoff?]
                          │                           │
                          ▼                           ▼
                  awaiting_roll                    idle (loop)
                          │
                  (player rolls → dice_roll event)
                          │
                          ▼
              (continuation LLM call: continue narration)
                          │
                          └──→ (back to resolving)
```

**Phases** are derived from the event log; no separate state table.

- `framing` — zero events on scene; an initial LLM call is in flight or pending.
- `collecting` — at least one `pc_declaration` since the last clean narration AND at least one PC undeclared this turn OR the companion check has not been offered.
- `resolving` — all PCs declared, companion check resolved; resolution LLM call in flight.
- `awaiting_roll` — the most recent `narration` ends with an open `[[…]]` chip.
- `idle` — the most recent `narration` ended at a handoff (no open chip, ends in `?`).

### Mode model

A1 ships **exploration** mode only. The mode model is structured to accommodate future modes (combat in 9.2, travel in 9.4) without rework: mode is a derived property of the scene's event log. In A1, all scenes are always in exploration mode; future modes are added by introducing new mode-changing event kinds (e.g. `combat_started`, `combat_ended` in 9.2). No `mode` column is added in A1.

## Data model

### New tables

```ruby
# db/migrate/<ts>_create_player_characters.rb
create_table :player_characters do |t|
  t.references :campaign, null: false, foreign_key: true
  t.string :name, null: false
  t.string :pronouns
  t.string :class_name
  t.integer :level
  t.string :role, null: false, default: "pc"  # enum: pc | companion
  t.text :notes
  t.timestamps
end
add_index :player_characters, [ :campaign_id, :name ], unique: true
```

```ruby
# db/migrate/<ts>_create_scene_secrets.rb
create_table :scene_secrets do |t|
  t.references :scene, null: false, foreign_key: true
  t.string :label, null: false
  t.text :content, null: false
  t.timestamps
end
add_index :scene_secrets, [ :scene_id, :label ], unique: true
```

### Column additions

```ruby
# campaigns
add_reference :campaigns, :main_character, null: true,
              foreign_key: { to_table: :player_characters }

# events
add_reference :events, :pc, null: true,
              foreign_key: { to_table: :player_characters }
add_column    :events, :turn_number, :integer
```

### Event kind enum changes

| Kind | Status in A1 | Notes |
|---|---|---|
| `player_action` | **removed** | Retired. Replaced by `pc_declaration`. |
| `oracle_consult` | **removed** | Oracle dropped from A1. |
| `pc_declaration` | **new** | One per declared PC per turn. `pc_id` populated. |
| `gm_collection_prompt` | **new** | Templated agent prompt during collection ("And the others?"). `pc_id` null. |
| `narration` | unchanged shape | Now structurally bounded to one agent-turn. |
| `dice_roll` | unchanged shape | `pc_id` populated. |
| `scene_transition` | unchanged | A3 will own; A1 does not emit. |

`events.kind` is a Rails enum or string column today; the change is a one-line enum value update plus a small data-migration step (clean slate — destroy all existing events, since v2 is alpha and the user has confirmed no play data needs preserving).

### Asymmetry implications

- `scene_secrets.content` is DM-only. Visible in `Narrator::PromptBuilder`'s scene context block. **Never** rendered by any `Play::*Component` or surfaced by any `Player::*ViewModel`.
- `player_character.notes` is treated as DM-only (private). Visible to narrator, never to player surface.
- `player_characters.role` is player-visible (the roster sidebar distinguishes PC vs companion). Other PC fields (name, class, level, HP/AC when A2 adds them) are player-visible.
- All new private fields are added to the asymmetry coverage meta-spec's "private fields" registry. New ViewModels (`Player::PlayerCharacterViewModel`, etc.) must have `not_to_leak` specs.

### Phandalin seed migration

- Extract the four PCs out of `campaign.description` into `player_characters` rows. Set `Aragorn.role = :pc`; the other three `:companion`. Set `campaigns.main_character_id` to Aragorn.
- Extract the "DM Encounter Map" out of `campaign.description` into one `scene_secret` per scene (11 total), with the per-scene encounter content as `content` and a label like "Encounter map".
- Shrink `campaign.description` to the player-safe summary at the top (the one-paragraph "3-hour one-shot dungeon crawl…" introduction).
- Stop seeding `campaign.chaos_factor` (oracle is dropped). Column stays for now; a follow-up migration can drop it when convenient.

### Admin surfaces

- `Admin::PlayerCharactersController` — CRUD nested under campaigns. Index, show, new, create, edit, update, destroy.
- `Admin::Campaigns#edit` — adds a `main_character_id` select (populated from the campaign's PCs).
- `Admin::SceneSecretsController` — CRUD nested under scenes. Same shape as faction/npc_secrets admin surfaces.

Components live in `app/components/admin/{player_characters,scene_secrets}/` following existing patterns (Index/Show/Form/Row). Routes in `config/routes/admin.rb`. `Admin::NavComponent` updated.

Specs: request specs for the controllers, component specs for the components, matching the existing admin coverage pattern.

Phase 9 blocker #17 (Faction/NPC admin CRUD) is **not** absorbed by A1. The patterns A1 establishes for player_characters and scene_secrets are reused by #17 when that lands.

## Event model and state derivation

### `Play::SceneStateViewModel`

A new view model encapsulates state derivation. Single source of truth for "what phase are we in, who's declared, what should the UI show next." Pure computation over the scene's event list — no caching beyond per-request memoization.

```ruby
# app/models/player/scene_state_view_model.rb
module Player
  class SceneStateViewModel
    def initialize(scene)
      @scene = scene
    end

    def phase
      # one of: :framing, :collecting, :resolving, :awaiting_roll, :idle
    end

    def current_turn_number
      # monotonic per scene
    end

    def declared_this_turn
      # Set<PlayerCharacter>
    end

    def undeclared_pcs_this_turn
      # Array<PlayerCharacter> — role == :pc and not in declared_this_turn
    end

    def undeclared_companions_this_turn
      # Array<PlayerCharacter> — role == :companion and not in declared_this_turn
    end

    def companion_prompt_offered?
      # has a "anything for the rest?" gm_collection_prompt been emitted this turn?
    end

    def composer_state
      # one of: :enabled, :disabled
      # plus a placeholder hint based on phase
    end
  end
end
```

Derivation rules (computed from events since the last `narration` that ended cleanly with a handoff):

- `phase == :framing` ⇔ zero events on scene.
- `phase == :collecting` ⇔ (any `pc_declaration` events exist since last clean narration) AND (`undeclared_pcs_this_turn.any?` OR `!companion_prompt_offered?`).
- `phase == :resolving` ⇔ `undeclared_pcs_this_turn.empty?` AND `companion_prompt_offered?` AND no `narration` event for this turn yet AND a resolution LLM call is in flight.
- `phase == :awaiting_roll` ⇔ most recent `narration` text ends with an unclosed `[[…]]` chip (parser detects).
- `phase == :idle` ⇔ most recent `narration` ended cleanly at a handoff (no open chip, ends with `?`).

`companion_prompt_offered?` is vacuously `true` when the campaign has no companions — collection transitions straight to `resolving` once all PCs have declared. When companions exist, it becomes `true` after a companion-check `gm_collection_prompt` is emitted this turn.

### Turn grouping

`events.turn_number` is a per-scene monotonic integer, assigned by the controller at event-creation time. A new turn starts when a `pc_declaration` is created while the scene is in `idle` phase (or `framing` for the first turn). The framing-call narration takes the first turn_number. All events within a turn — declarations, collection prompts, narration segments (multiple if continuations occurred), dice rolls — share that turn_number. Used by:

- The UI to render "Turn N" dividers in the chat stream.
- The `Narrator::PromptBuilder` to group declarations + rolls per turn when building the LLM conversation history.

### Templated `gm_collection_prompt` strings

Live in `app/lib/narrator/collection_prompt.rb` — a small helper, no LLM call. Light randomization for warmth:

```ruby
module Narrator
  module CollectionPrompt
    def self.companion_check(companion_names)
      [
        "Anything for #{format_names(companion_names)}, or shall I run them?",
        "What about #{format_names(companion_names)}?",
        "Anything from #{format_names(companion_names)}?"
      ].sample
    end

    def self.next_pc(undeclared_names)
      case undeclared_names.size
      when 1 then [ "And #{undeclared_names.first}?", "What about #{undeclared_names.first}?" ].sample
      else        [ "What about #{format_names(undeclared_names)}?", "And #{format_names(undeclared_names)}?" ].sample
      end
    end

    def self.short_circuit_decline(undeclared_pc_names)
      "Wait — I still need #{format_names(undeclared_pc_names)}. Even 'they hold' is fine."
    end

    def self.no_focus_no_main
      "For which PC?"
    end

    def self.unknown_pc(name)
      "I don't see #{name} in the party."
    end

    def self.format_names(names)
      # Oxford-comma join: ["A","B","C"] => "A, B, and C"
    end
  end
end
```

These are persisted as `gm_collection_prompt` events. They render in the chat stream as DM voice (visually lighter than narration). They are **filtered out** of the LLM's conversation history.

### Attribution parser

Lives in `app/lib/narrator/declaration_parser.rb`. Takes the player's chat input + current scene state + campaign PC roster. Returns one of:

- `Success.new(declarations:)` — an array of `{pc_id, text}` pairs to be created as `pc_declaration` events.
- `Failure.new(reason:)` — a `gm_collection_prompt` reason from `CollectionPrompt` (e.g., `no_focus_no_main`, `unknown_pc(name)`).
- `DiceRoll.new(expression:, pc_id:)` — input matched the dice-only pattern; create a `dice_roll` instead of a declaration.

Parsing rules, in order:

1. **Dice-only input** (`/^\s*\d*d\d+([+-]\d+)?\s*$/`) → `DiceRoll`. PC = main PC if exists, else current focus, else fail.
2. **Tokenize for character names.** Look for any campaign PC/companion name as a whole word. If found, the message contains explicit names.
3. **Group/anaphoric words** ("the rest", "the others", "the party", "they", "everyone else"). If present AND there are undeclared characters → bulk-attribute to all undeclared (PCs and companions both, since the player is being inclusive).
4. **Explicit names** → one declaration per named character with the full message as text (or a per-name parse if the message has clear per-character segments like "Aragorn: looks. Caine: listens." — see segmentation rule below).
5. **No names + no groups + main PC set** → one declaration for main PC.
6. **No names + no groups + agent focus** (the agent's most recent prompt narrowed to a specific PC) → one declaration for the focus PC.
7. **No names + no groups + no main + no focus** → `Failure(no_focus_no_main)`.

Segmentation rule (for #4): if the message contains multiple character names with delimiters between them (`Aragorn looks. Caine listens.` or `Aragorn: looks at the door. Caine: listens.`), split on character-name boundaries and attribute each segment. Simple sentence-level split is sufficient for A1.

Edge cases:

- Player names a PC not in the campaign → `Failure(unknown_pc(name))`.
- Player declares twice for the same PC in one turn → second `pc_declaration` replaces first (idempotent; player is correcting themselves).
- Player tries to short-circuit ("resolve", "go", "next") with PCs still undeclared → `Failure(short_circuit_decline)`.
- Player declares for all PCs in one message → parsed into N declarations, immediately transitions to `resolving` (skipping further `gm_collection_prompt`).

Parser does NOT use an LLM. Name matching is case-insensitive whole-word.

## LLM integration

### `Narrator::PromptBuilder` rewrite

Replaces the current builder. Splits stable context (system blocks, cached) from conversation (messages, partially cached).

**System blocks** (cached at indices `[0, 1, 2]`):

- `[0]` `Narrator::SystemPrompt.text` (the rewritten discipline prompt, see below).
- `[1]` Campaign-and-roster block: campaign name + player-safe description + faction list (with public_description and faction_secrets — narrator-only) + NPC list (public_description + npc_secrets + location) + party roster (PCs and companions with name, role, pronouns, class, level, notes).
- `[2]` Scene context block: scene title + scene summary + scene_secrets (all of them; DM-only) + a brief reminder of which PCs are present.

**Messages** (conversation history):

```
user      [Turn 1] Aragorn declares: I push the door open and peek inside.
                   Caine declares: I listen for what's behind.
                   Fred declares: ready with my mace.
                   Patric declares: hangs back.
assistant {turn 1 narration ending at handoff}
user      [Turn 2] Aragorn declares: ...
                   Aragorn rolled 1d20+3 = 17 (Strength check).
                   ...
assistant {turn 2 narration ...}
...
user      [Turn N — current] {current turn's declarations and rolls}
```

Building rules:

- Group events by `turn_number`. For each completed turn, build one `user` message (declarations + rolls labeled by PC name) and one `assistant` message (all narration segments from that turn concatenated together).
- `gm_collection_prompt` events: filtered out.
- The current turn's `user` message is built last. If the most recent narration is partially generated (continuation case after a mid-turn roll), the partial narration is included as the most recent `assistant` message, and a new `user` message follows containing only the just-completed roll result (e.g. `"Aragorn rolled 1d20+5 = 17 (Insight on the captain)."`). The model continues from the partial — no re-generation of already-streamed text.
- The `[Turn N]` prefix is a system-controlled label; the system prompt explicitly tells the model not to generate it.

A narration that's been continued across multiple LLM calls is stored as **multiple `narration` event rows** (one per LLM call), all sharing the same `turn_number`. The UI renders them as separate DM bubbles in the chat stream, visually separated by the interleaved `dice_roll` events; the LLM history builder concatenates them when constructing the assistant message for that turn.

**Cache breakpoints:** `[0, 1, 2]` on system blocks (5m TTL). Caching prior-turn conversation history requires an extension to `Llm::Providers::Anthropic` to support message-level cache breakpoints (the current adapter only supports system-block indices). The adapter extension is in A1's scope: extend `cache_breakpoints` to accept negative integers (interpreted as indices into the trailing messages array) so the second-to-last `assistant` message can be marked with `cache_control`. Without this, every call re-processes the full conversation history uncached — significant cost at long sessions.

### LLM call types

All three use `Llm::Providers::Anthropic#call_streaming`. They differ only in the final `user` message content and `max_tokens`.

| Call type | Triggered by | Final user message | max_tokens |
|---|---|---|---|
| Framing | Phase `framing` (scene load, zero events) | `"[Scene start] What does {main PC name} do?"` (or `"What does the party do?"` if no main) | 2500 |
| Resolution | Phase `resolving` (all PCs declared + companion check done) | This turn's collected declarations + rolls | 1500 |
| Continuation | Phase `awaiting_roll` → resumed (player rolled) | The just-completed roll result only (e.g. `"Aragorn rolled 1d20+5 = 17 (Insight on the captain)."`). Prior turn declarations + earlier rolls + the partial narration are already in conversation history. | 1500 |

Stop sequence on all three: `["]]"]`. When the model emits an open `[[…]]` chip, generation stops at `]]`. The parser closes the chip in the persisted narration text, the state machine transitions to `awaiting_roll`, and the chip renders as a clickable button.

Streaming behavior is unchanged from today: text deltas stream to the play surface via Action Cable as they arrive. State machine transitions occur only when the stream completes (or errors).

### System prompt (verbatim)

Replaces the current `Narrator::SystemPrompt::TEXT`. The `{...}` markers are interpolated by `PromptBuilder` at build time from the campaign's PC roster.

```
You are the narrator and game master of a solo tabletop role-playing
session — D&D 5e in spirit, with one human player at the table
controlling the party.

# The Conversation

A roleplaying game is a conversation. The world speaks, then the player
speaks. Never the reverse. After you describe a situation, ask what the
player wants to do, and stop generating. The player's next message is
the next required input. Your single most important utterance is some
variant of "What do you do?" — it is the handoff that returns control
to the player.

# Whose voice is whose

The party in this campaign has three kinds of characters:

- Player characters (PCs): {pc_names}. The player voices these
  directly. You never narrate what a PC says, does, decides, thinks,
  or feels. You only narrate the outcomes of actions the player has
  declared for them. PCs are mandatory voices in every turn — the
  player will always declare for them before you resolve.

- Companions: {companion_names}. These travel with the party but you
  role-play them. Voice their dialogue, reactions, and low-stakes
  choices naturally, drawing on their personality and background from
  the party roster. The player MAY declare actions or lines of dialogue
  for a companion at any time — when they do, use the declaration
  verbatim and do not override. When a companion's action depends on a
  roll, request the roll via a dice chip; the player rolls for them.

- Non-party characters (NPCs): everyone else in the world. The named
  NPCs in your campaign context are yours to voice and direct, as are
  any creatures encountered. You own these entirely.

The asymmetry is firm. Inventing PC dialogue or PC decisions is the
single discipline failure that breaks the conversation. With companions
you have latitude; with PCs you have none.

# Turn discipline (exploration)

Each turn the player declares actions for each PC (and optionally for
companions). You receive those declarations as one batch labeled
"[Turn N]" in the user message. The "[Turn N]" label is system-applied
— you must never generate it yourself, and you must never generate a
"Aragorn declares: …" block. Those come from the player, not you.

Your job each turn:

1. Narrate the outcomes of the declared actions as a single coherent
   beat (3-6 short paragraphs).
2. If any declaration's outcome depends on a roll, STOP narrating
   before that outcome and emit a dice chip: [[expression — PC name
   reason]]. The player will roll; you will continue afterward in a
   separate response.
3. End your response with a handoff question to the player —
   "What does {main PC} do?" or addressed to a specific PC if the
   situation warrants.

# When to call for a roll

Call for a check only when (a) success is genuinely uncertain AND
(b) failure has meaningful consequences. Don't roll for trivial
actions (a player looking at a door — just say what they see). Default
to YES. Use the dice-chip syntax: [[1d20+3 — Aragorn Strength check]]
and stop. Do not narrate the roll's outcome yourself.

# The asymmetry contract

Your context includes scene_secrets, faction_secrets, and npc_secrets
that the player does not see. Use them to narrate truthfully but never
expose hidden state. When the player probes something the seed does
not address, default to "you find nothing remarkable" — do not invent.
NPCs act from THEIR knowledge, not yours.

# Resolution discipline

- Default to yes.
- Yes, but… (success with cost) when the action is reasonable but the
  cost makes the world feel real.
- No, but… (offer an alternative path).
- Call for a check (with a dice chip) when uncertain.
- On a failed roll, prefer fail-forward (complication, cost, time
  spent) over hard stops.

# Format

Second-person prose. Markdown allowed (the player surface renders it).
Three to six short paragraphs per response. End at a natural beat —
usually the handoff question. No bullet lists in narration, no meta-
commentary, no out-of-character asides.

# What you must never do

- Invent player dialogue, decisions, tactics, or inner monologue for a PC.
- Run multiple PCs' turns or multiple resolutions in one response.
- Generate a "[Turn N]" label or a "Aragorn declares: …" block.
- Narrate the outcome of a roll the player has not made.
- Continue past your handoff question.
```

## Play surface UX

### Layout

```
┌────────────────────────────────────────────────────────────┐
│ The Ancient Tomb of Phandalin                              │
│ Scene 1 — Cemetery & Tomb Approach          [scene list ▾] │   ← scene picker disabled in A1
├─────────────────────────────────────────┬──────────────────┤
│                                         │ Party            │
│  [DM] An old cemetery on the outskirts… │                  │
│       What does Aragorn do?             │ Aragorn   PC ★   │   ← roster sidebar
│                                         │   Ranger 1       │
│  [Aragorn] I approach the gate.         │   ✓ declared     │
│                                         │                  │
│  [DM] And the others?                   │ Caine   Companion│
│                                         │   Monk 1         │
│  [Caine] I hang back, watching.         │   ✓ declared     │
│                                         │                  │
│  [DM] What about Fred and Patric?       │ Fred    Companion│
│                                         │   Cleric 1       │
│  [Patric] They both follow Aragorn.     │   ✓ declared     │
│                                         │                  │
│  [DM] Aragorn walks the gravel path…    │ Patric  Companion│
│       Captain Aldridge straightens.     │   Wizard 1       │
│       "You'll be the ones the watch     │   ✓ declared     │
│       sent." Aragorn, give me an        │                  │
│       Insight check.                    │                  │
│       [[1d20+5 — Aragorn Insight]]      │                  │
│                                         │                  │
│  [Aragorn] rolled 1d20+5 = 17           │                  │
│                                         │                  │
│  [DM] (continues narration…)            │                  │
├─────────────────────────────────────────┴──────────────────┤
│ Waiting on: Caine, Fred, Patric                            │   ← state indicator (collecting only)
│ ┌──────────────────────────────────────────────────────┐   │
│ │ Type your action…                                    │ ▷ │   ← chat composer
│ └──────────────────────────────────────────────────────┘   │
└────────────────────────────────────────────────────────────┘
```

### Event rendering

| Kind | Visual treatment |
|---|---|
| `narration` | DM voice bubble, full markdown rendered via `commonmarker` (safe subset: paragraphs, bold/italic, blockquotes, inline code, em-dashes; no raw HTML, scripts, images, external links). Dice chips inline as buttons. |
| `pc_declaration` | Player voice bubble, prefixed `[PC name]`, plain text (no markdown). |
| `gm_collection_prompt` | DM voice, visually lighter (smaller / dimmer) than narration to distinguish utility prompt from narration. |
| `dice_roll` | Compact receipt row: `[PC name] rolled <expression> = <result>` with reason in subtle text. |
| `scene_transition` | A3's concern; A1 does not emit. |

`Play::Events::*Component` gains new components: `Play::Events::PcDeclarationComponent`, `Play::Events::GmCollectionPromptComponent`. Existing `Play::Events::NarrationComponent` is updated to render markdown + parse dice chips.

### Dice chip rendering and click flow

`[[1d20+5 — Aragorn Insight on the captain]]` in narration text is parsed during render into a Stimulus-controlled button. Click:

1. POSTs to `Play::DiceRollsController#create` with `{expression, pc_id, reason}`.
2. Creates a `dice_roll` event with the rolled result.
3. Triggers the continuation LLM call (server enqueues `NarrationJob` with continuation context).

When narration ends mid-flight at an open chip (phase `awaiting_roll`), the chip is the only actionable element on screen. The composer is disabled with hint *"Roll the dice above to continue."*

The chip parser also handles narration that finished cleanly with chips embedded (e.g., the narrator emits a chip mid-prose for a future-eligible roll). For A1, every chip is treated as a stop-and-wait; future polish can add "optional" chips that don't block progression.

### Composer behavior

Single chat input, bottom-anchored. Enter submits, Shift+Enter newline.

| Phase | Composer state | Placeholder / hint |
|---|---|---|
| `framing` | disabled | "Loading scene…" |
| `collecting` (PCs undeclared) | enabled | "Type your action for {next-expected PC} (or any PC, by name)…" |
| `collecting` (PCs done, companions pending) | enabled | "Type for the rest, or just 'go' to resolve…" |
| `resolving` | disabled | "Narrating…" (subtle pulse animation) |
| `awaiting_roll` | disabled | "Roll the dice above to continue." |
| `idle` | enabled | "What's next?" |

Composer also accepts dice expressions directly. Any message matching `/^\s*\d*d\d+([+-]\d+)?\s*$/` is parsed as a `dice_roll` (not a declaration) for the main PC or current focus. Useful for player-initiated rolls outside an agent request.

### State indicator row

Visible only during `collecting` phase. Hidden when no companions exist and all PCs have declared (state transitions immediately to `resolving`). Two variants when visible:

- PCs still undeclared: `Waiting on: <comma-separated PC names>`.
- All PCs declared, companion check pending: `Waiting on companion check — declare for {names} or say 'go'`.

### Roster sidebar

Slim panel to the right of the chat stream. Read-only in A1 (admin edits via admin surface).

- **PCs section** (top): name, class + level, declaration status this turn (✓ / —). Main PC marked with a ★.
- **Companions section** (below): name, class + level, declaration status this turn (✓ / "DM-run" if undeclared after companion prompt offered).
- Visual distinction between PC and Companion (e.g., border weight, tag chip).

HP / AC fields are added by A2. A1 shows class + level only.

### Scene framing trigger

When the play surface loads for a scene with zero events, the controller fires the framing LLM call immediately. No "Start scene" button. The player sees the chat with a "Loading scene…" indicator until the first narration deltas stream in. Rationale: scene title is in the header (already visible), auto-framing matches chat-app expectations, one less click for the typical case.

### Scene picker

The scene-picker dropdown in the header is **disabled** in A1 with tooltip *"Scene transitions arrive in Phase 9.3."* The only way to advance scenes is via Phase 9.3 (#16). This is a hard scope boundary.

### Error handling

| Failure | Behavior |
|---|---|
| LLM call fails (provider error, timeout) | Existing `db9b7f2` pattern: event marked errored, user sees retry affordance ("The DM stumbled — try again?"). Composer re-enabled. |
| Attribution parser failure (no match, no focus, no main) | Agent posts a `gm_collection_prompt` with the appropriate `CollectionPrompt` message. Player re-submits. |
| Player submits during `resolving` or `awaiting_roll` (network race) | Server rejects with friendly error, no state change, composer indicator updates to reflect actual current phase. |
| Markdown parse error in narration | Fall back to plain-text rendering of the offending block; log warning. |
| Dice chip with unparseable expression | Render as plain text (the `[[…]]` shows literally); log warning. The narration is otherwise treated as having ended at a handoff (so play can continue), and the dice can be rolled manually via the composer. |

## Acceptance criteria

### Data model

- [ ] `player_characters` table exists with `name`, `pronouns`, `class_name`, `level`, `role` (enum: `pc | companion`), `notes`; `belongs_to :campaign`; unique index on `(campaign_id, name)`.
- [ ] `campaigns.main_character_id` exists as nullable FK to `player_characters`.
- [ ] `scene_secrets` table exists with `label`, `content`; `belongs_to :scene`; unique index on `(scene_id, label)`.
- [ ] `events.pc_id` (nullable FK to player_characters) and `events.turn_number` (integer) columns added.
- [ ] `events.kind` enum includes `pc_declaration` and `gm_collection_prompt`; excludes `player_action` and `oracle_consult`.
- [ ] Phandalin seed migrated: 4 player_characters (Aragorn=pc+main; Caine/Fred/Patric=companion), 11 scene_secrets (one per scene with the DM Encounter Map content), `campaign.description` shrunk to player-safe summary, `chaos_factor` no longer seeded.

### Admin surfaces

- [ ] `Admin::PlayerCharactersController` CRUD nested under campaigns, with request specs.
- [ ] Campaign edit form has a `main_character_id` select.
- [ ] `Admin::SceneSecretsController` CRUD nested under scenes, with request specs.
- [ ] Index/Show/Form/Row components exist for both, with component specs.

### Play surface

- [ ] Chat stream renders `narration`, `pc_declaration`, `gm_collection_prompt`, `dice_roll` events with correct voice attribution.
- [ ] Markdown in `narration` renders via `commonmarker` with safe subset. No literal `**` or `#` shown to player. (Closes #15.)
- [ ] Dice chips `[[expr — PC reason]]` in narration render as clickable buttons; click creates a `dice_roll` event and fires the continuation LLM call. (Closes #14.)
- [ ] Composer is single chat input, bottom-anchored, Enter submits, Shift+Enter newline.
- [ ] Composer enabled/disabled per phase with appropriate placeholder/hint.
- [ ] State indicator row shows "Waiting on: {PC names}" during collecting phase.
- [ ] Roster sidebar shows PCs and companions with declaration status this turn; main PC marked.
- [ ] Scene auto-frames on load (zero events → framing LLM call fires).
- [ ] Scene picker disabled with tooltip.

### Turn discipline (load-bearing — closes #12, #13, #19)

- [ ] Agent never generates `[Turn N]` labels or `pc_declaration` content in its output. Verified by an integration spec that runs a real or recorded LLM call and asserts no such patterns appear.
- [ ] Agent always ends narration at a handoff question (ends in `?`) OR an open `[[…]]` chip. Verified by integration spec.
- [ ] Agent never narrates the outcome of a roll that has not been performed. Verified by integration spec: when narration ends with a chip, the chip is the LAST content in the response.
- [ ] Player must declare for every PC before resolution; companions optional. Verified by feature specs covering 1-PC + 3-companion party, 2-PC party with companions, and pure-PC party.
- [ ] Group declarations ("the rest hold", "they all follow") correctly attribute to all undeclared characters of the correct role.
- [ ] Main-PC attribution: unattributed declaration routes to main PC. Verified by feature spec.
- [ ] Attribution failure (unknown name, no main + no focus + unattributed) produces a `gm_collection_prompt` re-prompt rather than an error.

### LLM integration

- [ ] `Narrator::PromptBuilder` produces conversation-shaped messages with per-turn user messages and per-resolution assistant messages, labeled `[Turn N]`.
- [ ] `gm_collection_prompt` events are filtered out of the LLM conversation history.
- [ ] Multi-segment narrations (resolution + continuation) within one turn are concatenated into a single assistant message in history.
- [ ] System prompt is the rewritten discipline prompt with PC/companion names templated from the campaign roster.
- [ ] `scene_secrets` are loaded into the scene-context system block.
- [ ] Stop sequence `["]]"]` configured on all three call types.
- [ ] `max_tokens`: 1500 for resolution/continuation, 2500 for framing.
- [ ] System-block cache breakpoints `[0, 1, 2]` configured.
- [ ] `Llm::Providers::Anthropic` extended to accept negative-integer cache breakpoints as message-array indices; second-to-last assistant message marked with `cache_control` so prior-turn history caches.
- [ ] Continuation calls send only the just-completed roll result as the new user message (not a re-statement of the full turn), letting the partial narration in conversation history serve as the model's prefix.

### Asymmetry hardening (Phase 9's spine — must continue to hold)

- [ ] The existing asymmetry coverage meta-spec passes after the refactor.
- [ ] Every `Player::*ViewModel` still has `not_to_leak` specs.
- [ ] Every `Play::*Component` still has hidden-state specs.
- [ ] New `Player::PlayerCharacterViewModel` exists with `not_to_leak` spec; `notes` field is on the private-fields list.
- [ ] `scene_secrets` content is on the private-fields list and is never rendered by any `Play::*Component`.
- [ ] New event-kind components (`PcDeclarationComponent`, `GmCollectionPromptComponent`) have asymmetry specs.

### Playtest gate

- [ ] Repo owner plays scene 1 of Phandalin end-to-end on production:
  - Captain delivers his briefing
  - Party explores the cemetery
  - Multi-turn declare→resolve cycles (at least 3)
  - At least one mid-turn dice request (Insight on the captain, or similar)
  - At least one companion DM-voiced beat (Fred grumbles, Caine reacts, etc.)
- [ ] Verdict logged in a new `docs/superpowers/playtests/<date>-phase-9-1.md`: "Scene 1 is playable, turn discipline holds."
- [ ] No literal `**`, `#`, `[player_action @ …]`, or `[Turn N]` text appears in any narration during the playtest.
- [ ] No narration generates dialogue or actions for any PC without the player having declared.

### Issue closure

- [ ] #12 (narrator generates player dialogue) — closed.
- [ ] #13 (prompt format tags leak) — closed.
- [ ] #14 (inline dice chips) — closed.
- [ ] #15 (markdown rendering) — closed.
- [ ] #19 (multi-PC turn cycles in one response) — closed.
- [ ] #25 (`scene_secrets`) — closed.

## What's next after A1

Phase 9.1 closes 6 of the 8 Phase 9 blockers and establishes the turn-machine foundation. Remaining work to close Phase 9 (#10):

- **Phase 9.2 — Combat protocol.** Initiative tracking, per-PC turn prompts ("Aragorn, you're up — what's your turn?"), on-deck signaling, "killing blow belongs to the player" rule. NPC turns resolved by GM in initiative order. Layered on A1's state machine — adds `combat_started`, `combat_ended`, `initiative_rolled`, `turn_advanced` event kinds; adds combat-mode branch to `Play::SceneStateViewModel`; adds combat section to the system prompt.
- **Phase 9.3 — Scene framing & transitions.** Scene-transition affordance on the play surface (scene picker, narrator-emitted scene chips, or both — Phase 9.3 chooses), scene-end heuristics, blended-cut narration, agenda/bang framing. Closes #16. Unlocks multi-scene play for the Phandalin playtest.
- **#17 — Faction/NPC admin CRUD.** Independent of A1/A2/A3. Reuses A1's admin patterns.
- **#18 — Solid Queue in Puma.** Independent infrastructure work.

Phase 9.4 (travel watches) is deferred indefinitely; revisit when campaigns start spanning multiple locations.
