# Character Import & Rules Grounding — Design Notes

Status: exploratory. Not committed work. Captures a design conversation, not a plan.

## The question that kicked this off

CRUD forms for character creation are fine but unexciting. D&D Beyond has the best character builder UI in the hobby. Should we duplicate it, integrate with it, or use something else?

## The deeper insight

Character import is the surface case. The **load-bearing** reason to integrate with D&D Beyond is **rules grounding for the LLM-DM during play.**

- The LLM has seen SRD content in training, and probably has leaked PHB text too, but accuracy degrades on edge cases (exact wording of conditions, subclass features, spell components, post-2014 splatbook content).
- SRD 5.1 / 5.2 covers a fraction of PHB/MM/DMG — most monsters, many spells, most subclasses, most feats are NOT SRD.
- An SRD-only agent will faceplant on subclass-specific rulings, post-2014 content, and homebrew, while confidently inventing rules. In solo play there's no other human at the table to catch this.
- Giving the agent authenticated access to the books the user has purchased on DDB turns "the LLM thinks it knows Polymorph" into "the LLM quoted Polymorph from the source."

## Options surveyed

| Option | What it gives you | Catch |
|---|---|---|
| DDB import via `CobaltSession` cookie | Best UI for creation, all owned content + homebrew | Unofficial API, cookie handling, ToS gray |
| Foundry VTT actor JSON | Complete sheets, defined schema | User needs Foundry; parsing Foundry's format |
| Roll20 character JSON | Common | Pro account; sheet schema varies |
| 5e.tools / Plutonium | Open source, JSON export | Less polished UX |
| Pathbuilder-style share code | Simple paste-a-code UX | Pathbuilder is PF2e only |
| PDF / image + LLM extraction | Works for any sheet | Lossy, hallucination risk on numbers |
| Plain-text "describe your character" + LLM | Lowest friction, fits LLM-DM vibe | Optimizers will hate it |
| Owlbear Rodeo | n/a | Map/token VTT, no coherent character sheet |

**MCP question:** MCP is a protocol for exposing tools to LLM clients, not a generic API layer for a Rails app. Wrapping DDB access in MCP only makes sense if you want the in-session agent to call it as a tool (which we do, for rules lookup). For character import — a one-shot ETL job — MCP indirection adds no value. Just call the API directly.

## Decisions

### 1. DDB cookie is the primary integration path
- Store the user's `CobaltSession` cookie, hit `character-service.dndbeyond.com/character/v5/character/{id}` for imports and the monster/spell/item services for rules lookups.
- Single-user, solo-play app = the cleanest possible legal posture. No redistribution surface; the user is accessing content they personally licensed.
- ToS is still gray. Risks remain: cookie hygiene, expiration, API instability, Hasbro mood.

### 2. Our own canonical schema, not "DDB as remote read-only library"
DDB is one **source** of data flowing into our DB, not the source of truth. Why:
- Need to handle players without DDB
- DM/agent needs to override or homebrew on top of imported data
- Offline/cached access during play (DDB downtime mid-session must not break the game)
- Display in our own UI

### 3. Always have a paste fallback
When the agent doesn't know a rule, it emits a **structured request** for the user to paste the rules text. This is the only check on the agent confidently inventing rules in solo play.

- Not a chat reply — a real UI form
- On paste, store as `source: pasted_in_session`, retry the original tool call
- User can also push paste **unprompted** ("here's how Polymorph actually works, use this")
- Optional DM "promote to canonical" toggle to bless a pasted entry

### 4. Log every ungrounded ruling
After a session, surface "the agent made these N rulings without source-grounded text" so the player can canonicalize the corrections into the library. This is the feedback loop that makes the per-user library improve with use.

## Data model

### Three orthogonal concepts

1. **Content scope** — where does this NPC/location/item/spell live?
2. **Character ownership** — what does this specific PC know/carry, independent of where they're playing?
3. **Per-instance state** — same canonical NPC may have different relationships, dispositions, locations across campaigns.

### Scope hierarchy

```
Global       SRD content (built-in, CC-BY licensed, app-wide)
User-scoped  DDB-imported + reusable homebrew the user authored
             (shared across all their campaigns)
World        optional tier between user and campaign
Campaign     campaign-only content (NPCs, locations, plot, one-off items)
```

**Lookup precedence at play time:** campaign → world → user → SRD → ask-to-paste.

### Tables (sketch)

```
User
  has_many :worlds            (optional)
  has_many :characters        (PCs — portable across campaigns)
  has_many :npcs, :locations, :items, :spells, ...   (user library)

World (optional)
  belongs_to :user
  has_many :campaigns
  has_many :npcs, :locations, ...   (world-scoped)

Campaign
  belongs_to :user
  belongs_to :world, optional: true
  has_many :npcs, :locations, ...   (campaign-only)
  has_many :character_campaign_participations

Character (PC)
  belongs_to :user
  has_many :inventory_items, :known_spells, :feats   (travels with PC)
  has_many :campaign_participations
```

### Required columns on every content row

- `source` enum: `srd_global` | `ddb_import` | `manual` | `pasted_in_session` | `homebrew`
- `source_id` — DDB ID if applicable
- `ruleset` enum: `dnd_5e_2014` | `dnd_5e_2024` | `homebrew_<id>`
- `last_synced_at` — for DDB sources
- `locked` boolean — DM said "don't overwrite this"

### Per-instance state overlays

Same canonical NPC can appear in multiple campaigns with diverging state. Don't fork the NPC every time — overlay table:

```
campaign_npc_state(campaign_id, npc_id, disposition, current_location, ...)
```

Same pattern for locations (canonical place + per-campaign state) and items (canonical item + per-character condition/charges).

### Don't go fully polymorphic

Tempting to make `content` one polymorphic table with `owner_type/owner_id`. Resist. Three concrete tables per content type (`UserNpc`, `WorldNpc`, `CampaignNpc`) sharing a Rails concern. Promote via explicit operation that copies+updates, not by mutating a foreign key.

## Specific design rules

### Provenance is load-bearing
Re-import from DDB overwrites `ddb_import` rows; never touches `manual` or `homebrew`. Without this, the second import silently wipes hand-tuned overrides.

### Ruleset versioning, not "latest wins"
2014 Polymorph and 2024 Polymorph are different spells with the same name. Create new versioned rows; let each character/campaign declare which ruleset it uses.

### Loose schema for rules text, tight for queries
Structured columns for `level`, `school`, `casting_time`, `concentration`, `components`, `damage_dice` — anything we filter or compute on. Everything else as `rules_text` (or JSONB blob) the LLM reads as prose.

### Lazy import
Don't eagerly fetch every option from every book the user owns on first import. Pull what's on the sheet now; backfill the rest when the character actually interacts with it (level-up, spell swap, browse).

### Don't cross-pollinate user libraries
Even if Polymorph from PHB-2024 is byte-identical between two users' libraries, do NOT promote to global. Strict per-user ownership is the legal safety property. Optimize for row count later with a content-hash + ownership pivot if it ever matters.

### Character ownership is its own thing
Items/spells earned by a PC belong to the PC, not the campaign. When the PC enters a new campaign, the inventory follows. Exception: campaign-bound items (McGuffins, plot devices) — add `campaign_bound: boolean` on character-owned items, settable by the DM at award time.

### Promotion as a first-class operation
"I made this NPC in Campaign A; promote them to world / promote them to user library." Explicit, auditable, reversible. Don't ask the user to pick the right scope up front; let them create-here-decide-later.

### Optional world tier
Don't force a world for a one-shot. Offer "extract a world from this campaign" later — pulls recurring NPCs/locations up a level.

## Open questions

- **Cookie expiration UX.** How frequently will users have to re-paste? What's the failure mode? Build a clean "session expired" flow on day one.
- **Bulk SRD seeding.** Open5e API? 5e.tools JSON dump (legally fraught)? SRD 5.2 official drop?
- **Monster lookups mid-session** vs character imports — different endpoints, both via cookie. Same client class with multiple methods.
- **Homebrew details on import.** DDB JSON gives name + ID for homebrew content; full text may require separate fetch. Test on the Sameagol case (Spectral Sharks / Thrash of Thresher Bowstring).
- **What does "character left a campaign" mean?** In solo play, probably nothing — but if the user retires a character and brings them back later, do we restore state from last session or treat as fresh?
- **Versioned rule changes mid-campaign.** A user buys an errata-updated book. Does the agent suddenly start ruling differently mid-campaign? Probably should pin the campaign to a ruleset snapshot.

## Test case: Sameagol

A real character we used during this conversation to surface real problems:

- DDB share URL: https://www.dndbeyond.com/characters/132889512
- DDB PDF: https://www.dndbeyond.com/sheet-pdfs/jbarriault_132889512.pdf
- Aarakocra Ranger 4, Guide background, Chaotic Good
- Backstory entirely in `Character Backstory` block; Personality/Ideals/Bonds/Flaws boxes empty
- Uses **Spectral Sharks** spell from **Thrash of Thresher Bowstring** — both homebrew
- Demonstrates: (a) HTML page is JS-rendered and useless for scraping, (b) PDF is parseable but layout-fragile, (c) homebrew rules text is not in the sheet — agent has no idea what Spectral Sharks does without separate access

This character is the canonical regression case for: aarakocra (uncommon species), 2024 ruleset, custom magic item granting a custom spell, rich freeform backstory, empty PIBF boxes, nobility background with story hooks.

## Smallest viable first cut

When work actually starts (not now):

1. `User has_one :dndb_session` with encrypted `cobalt_session`
2. `Dndb::Client` service — one method per endpoint type, `Rails.cache` per-user keyed
3. `import_character(url_or_id)` — the obvious first surface
4. One agent tool: `lookup(type:, name_or_id:)` — proves the rules-grounding pattern with cache→DDB→ask-to-paste fallback chain
5. Sameagol as the acceptance test

Schema beyond that comes later, driven by what the import actually needs to land.
