# Phase 9 shake-out playtest

Date: 2026-05-15
Environment: Heroku production (gygaxagain.com)
Device: desktop browser
Campaign: The Ancient Tomb of Phandalin (seeded — see [`db/seeds.rb`](../../../db/seeds.rb))
Party: Aragorn (Human Ranger), Caine (Goliath Monk), Fred (Dwarf Cleric), Patric (Human Wizard) — all level 1, all played by the repo owner.
Duration: ~3 hours including infrastructure-bug debugging.

## Outcome

**Playtest aborted early — system reached "unplayable" before the party left the first scene of the dungeon.** Phase 9 acceptance criterion ("start → multiple scenes → multiple events → session-end audit") not met. The narrator's prose quality is high in isolation but the play loop is broken in several structural ways simultaneously, each of which compounds the others.

The system did clear several real infrastructure problems mid-session — see "Infrastructure fixes during the playtest" below.

## Session log

Started at the cemetery gate (scene 1, "Cemetery & Tomb Approach"). Captain Aldridge briefing landed well — the narrator named the captain when Patric asked, and conveyed the captain's "tomb cursed" cover story without exposing the underlying NPC secret. Good asymmetry behavior at the public/private boundary.

Party entered the tomb. Cleared the two skeletons in the entrance hall by combat. Asked at the side chamber door; the narrator surfaced Rewalt Mason as a frightened survivor without revealing his thief secret on first contact — also good.

Then everything went sideways. The narrator began generating player dialogue (Fred and Aragorn both got lines invented for them), then ran a full multi-turn party combat sequence — choosing the spell each caster would prepare, deciding which target each character attacked, resolving the grapple, the AoO, the Sacred Flame, the Magic Missile — all inside one streamed response. The output also contained the literal `[player_action @ <timestamp>Z]` and `[narration @ <timestamp>Z]` tags from the prompt's recent-events format, rendered as visible noise. Markdown formatting in the prose (italics, em-dashes around dialogue beats, occasional headers) showed as literal `**` and `#` to the player. Every dice request from the narrator required the player to context-switch to the dice form at the bottom of the screen.

Cumulative effect: the player couldn't tell which actions had been player-declared vs. narrator-invented, the prose was unreadable in places, and the dice-roll friction made each combat a multi-screen workflow. The party never moved past scene 1 — and because the play surface has no scene-transition affordance, every event from the entire 3-hour session is attached to scene 1.

The session closed with the verdict "it's unplayable at this point."

## Findings

### Blockers (filed as sub-issues of #10)

- **[F1] #14 — Narrator can't trigger dice rolls; player must context-switch every roll.** Quoted: *"the narrator can't use the dice roller so I'm having to do all the rolls."*
- **[F2] #15 — Markdown in narration renders as plain text.** Quoted: *"the narrator renders markdown. It'd be nice if our text displayed the rich text."*
- **[F3] #13 — Prompt format tags (`[player_action @ ts]`, `[narration @ ts]`, `---`) leak into narrator output.** Caught mid-narration, rendered to the player as literal text.
- **[F4] #12 — Narrator generates player dialogue.** Quoted: *"it took action for me, "Yes, those things are gone..." Probably should have ended the narration before that and let me reply."*
- **[F5] #19 — Narrator runs entire multi-PC turn cycles in one response.** Escalation of F4: a single Narrate submission generated six separate invented player actions interleaved with narration in one streamed response.
- **[F10] #16 — No scene transition mechanism on the play surface.** All events from a multi-room playthrough were attached to scene 1; the play surface has no affordance to advance to the next scene.

### Blockers (structural, surfaced during this phase rather than during play)

- **#17 — No admin CRUD for Factions and NPCs.** Phase 0 acceptance criterion not met; only Campaigns and Scenes have admin surfaces.
- **#18 — Solid Queue not wired for production; jobs run on Async.** Acceptable for the alpha playtest but loses jobs on dyno restart.

### Polish (filed under playtest follow-up parent #11)

- **[F6] #20 — Move dice + oracle controls off the bottom dock into a side column.**
- **[F7] #21 — Chat-composer style input: anchored bottom, Enter submits, small icon button.**
- **[F8] #23 — Clickable inline dice chips embedded in narrator prose.**
- **[F9] #22 — Reset-campaign button (clear events + history; preserve setup).** Surfaced from the repeated need to "clear and start over" during iteration.
- **[F11] #24 — Add a first-class PlayerCharacter / Party model.** Currently embedded in `campaign.description` as a free-text roster.
- **[F12] #25 — Add a `scene_secrets` table (or `scene.dm_notes`) so encounter info doesn't have to live in campaign.description.**
- **[F13] #26 — Add GitHub Actions CI (Phase 1 leftover).**
- **[F14] #27 — Solid Cable TrimJob fires per-broadcast; logs are unreadable during streaming.**

## Infrastructure fixes shipped during the playtest

Listed for posterity. None of these were "Phase 9 work" per the design spec; they were latent bugs in earlier phases that surfaced when the system was first actually run end-to-end on Heroku:

| Commit | Issue fixed |
|---|---|
| `c210eeb` | Sign-in form `local: true` + 302 redirect status broken under Rails 8 Turbo defaults — caused login to "not redirect" |
| `db9b7f2` | NarrationJob swallowed non-Anthropic exceptions, leaving events stuck in `status: streaming` forever |
| `93f9121` | Cable production adapter pointed at non-existent Redis — broadcasts vanished |
| `f51824b` | Solid Cable schema never installed (`db/cable_migrate/` did not exist) — broadcasts crashed with `ArgumentError: No unique index found for id` |
| `2d9920e` | Seed data leaked DM-only encounter content into player-visible scene summaries |
| (current branch) | `Llm::ConfigError` Zeitwerk autoload workaround — properly split `app/lib/llm/error.rb` into one file per constant |

## Reflection on what this playtest revealed

Phase 9 closed prematurely (the close was reopened on 2026-05-15 with sub-issues filed). The plan's coverage-and-meta-spec milestones were genuinely shipped — `spec/asymmetry/coverage_spec.rb` is in place, all 16 components have appropriate coverage or marker comments, and the meta-spec demonstrably catches regressions. But "Phase 9 done" was never really gated on a passing playtest, only on the coverage milestones. The playtest was Acceptance Criterion #3 and it failed.

A more honest Phase 9 close criterion would have included: *the playtest produces a coherent end-to-end session, scenes advance, the narrator stops at the player's turn, dice/oracle integrate naturally, and markdown renders.* None of those were true. The asymmetry guarantees (which were the load-bearing test surface this phase added) **did** hold: no secret content appeared in any player-rendered surface during the entire session. That part shipped. The play loop did not.

Phase 9 reopens until #12–#19 close.
