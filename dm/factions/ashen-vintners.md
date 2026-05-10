---
name: Ashen Vintners
slug: ashen-vintners
status: active
discovered: false
known-as: null
clock-max: 6
---

# Ashen Vintners

## Identity

- Agenda: A southern apothecary-cult operating under cover of legitimate vintnery, supplying tailored poisons and grave-tinctures to wealthy patrons. They are pursuing a covert beachhead in the central Sword Coast trade routes by seeding operatives in roadside taverns and gathering points; an undead patron's chill marks their bloodline-bound members.
- Methods: Slow infiltration of hospitality businesses; cultivation of confidante relationships with travelers; selective dosing — never wholesale poisoning, always individual targets matched to a contract; signal-and-receive cell structure, with no operative knowing more than two others.
- Sphere of influence: South coast (origin), now extending up the High Road through Daggerford and toward Waterdeep. Amphail is a forward post.
- Linked NPCs:
  - ravenna — placed operative at The Gilded Stallion, several months in. Awaits a courier signal.

## Active operation

- Name: The Crossroads Cup
- Goal: Identify and dose a specific traveling target passing through Amphail within the season — exact target known only to the cell handler.
- Clock: 0/6
- Started: session 001, 2026-05-10

## Observable consequences ladder

- Low (1-2/6): Travelers arriving in Amphail mention the High Road feeling "thinner" lately — fewer caravans, edgier merchants, the kind of mood that comes when something is being watched without being seen.
- Mid (3-4/6): A merchant who stayed at The Gilded Stallion two weeks ago took ill on the road south and died slowly; word reaches Amphail by way of a passing courier. Locals trade theories — bad water, bad cheese, bad luck.
- High (5/6): A second traveler — a cleric, returning north — falls ill the morning after a night at the Stallion. Survives, with a recovered fever and a tongue dyed faintly black; she is convinced something was in her cup.
- Full (6/6): The contracted target arrives, takes a meal, and dies in his room before dawn. Amphail wakes to a corpse, a guarded room, and a barmaid whose alibi is too clean.

## Engagement triggers

- The party investigates Ravenna's tells in any concrete way (asks about her past, examines her hands, follows where she watches the door, asks about her herb scent): hold clock this session.
- The party watches the front door of The Gilded Stallion for who Ravenna is waiting on (a full evening of observation): hold clock this session.
- The party acquires and reads any written material from Ravenna (letter, ledger, recipe): tick -1 (the operation is set back).
- Default if no trigger fires: clock += 1.

## Discovery

- Trigger: The party either (a) acquires written or spoken evidence naming the Ashen Vintners or any of their hierarchical terms (the Cellar, the Crossroads Cup, the Vintner's Cellar Mark), or (b) confronts Ravenna directly about the herbal scent and her cold and gets a partial confession or denial that names the patron.
- On match: world-state creates `world/factions/ashen-vintners.md` populated with the public fragment composed from the Identity section, scoped to what the discovery context revealed.

## On clock filled

- Beat: A Waterdhavian factor traveling north on guild business — name to be improvised when the beat fires — is found dead in his room at The Gilded Stallion. The local guard rouses; Ravenna is questioned and her answers are clean enough to release her, but she does not return to work the following night. The Stallion's regulars trade theories until dawn.
- Post-op state: dormant — the operation completes; the Vintners pull Ravenna back to the south for reassignment. The faction stays on file but does not tick further unless reactivated by later content.

## History

- session 001, 2026-05-10: faction seeded at clock 0. Ravenna placed at The Gilded Stallion; no party engagement; clock did not advance (session-001 was pre-tick — Phase 2a's first tick fires at /session-start of session-002).
