# Session 001 — 2026-05-10

**Focus:** Phase 1 smoke test — opening scene at The Gilded Stallion in Amphail.

**Party state at session start:**
- Dagnal (Hill Dwarf Life Cleric 3) — HP 30/30, no conditions, all spell slots full (4× 1st, 2× 2nd), Channel Divinity 1/1 available, Heroic Inspiration 0/1.

---

## Log

- WORLD-STATE QUERY: offscreen changes — Phase 1 baseline; no factions, clocks, or queued events. Opening world is at its initial state.
- WORLD-STATE QUERY: NPC behavior (ambient/opening) — Ravenna: five observable tells surfaced for opening scene at The Gilded Stallion; Sir Godfrey absent; Spirit presence rendered as atmosphere only.
- ROLL: 1d20+4 = 20 (Dagnal — Insight on Ravenna's demeanor/tells while greeting her at the bar)
- WORLD-STATE QUERY: NPC behavior (Insight 20 on Ravenna) — five concrete tells surfaced: hand calluses/chemical stains, laugh-eyes mismatch, door-watching, environmental cold/candle gutter near her, faint medicinal herb smell.
- ORACLE (unlikely, CF=5): no [roll 51]

---

## Session-end summary

Smoke-test session for the Phase 1 architecture. Dagnal arrived at The Gilded Stallion in Amphail at dusk and greeted Ravenna, the barmaid, with deliberate attention. A nat-equivalent Insight 20 surfaced five concrete tells about Ravenna — blade-grip calluses, chemical staining on her hand, a practiced-but-incomplete smile, a vigil for the front door, faint medicinal herb scent, and a small unnatural cold travelling with her. The oracle confirmed Ravenna will not volunteer information unprompted; the conversation paused with her asking Dagnal "Travelling far?" and waiting on a reply.

**Loose ends:**
- Dagnal has not yet answered Ravenna's question about her destination, nor pressed any of the tells she observed.
- Whatever Ravenna is waiting for at the front door has not arrived.
- The unnatural cold and the herbal scent are surfaced but unexplained — open threads for the next session.
- Dagnal still needs a meal, a drink, and a bed for the night; none have been resolved on screen.

**Chaos factor decision:**
- CF unchanged at 5. Session was observational in nature — Dagnal initiated all interactions, no complications or NPC actions advanced the world state, no random events triggered. Per Phase 1 spec, default is no adjustment for low-event sessions.

**Architecture notes for later phases:**
- Subagent flagged a false-positive security warning when the narrator appended a one-line WORLD-STATE QUERY summary to the log (which is the documented Phase 1 protocol). Worth refining the subagent's check so it doesn't fire on protocol-compliant logging.
