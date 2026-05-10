# Dice config

Phase 1 uses open-roll defaults across the board. Hidden rolls are
deferred to Phase 2.

## Default visibility per roll type (Phase 1)

- attacks: open
- damage: open
- saves: open
- skill checks: open
- ability checks: open
- initiative: open
- death saves: open

## Authority

- player: may declare any roll for own character; may always override visibility
- narrator: may call for any roll appropriate to the situation
- system: monster attacks, NPC saves, environmental effects roll open by default

## Critical handling

- D&D 5e 2024 standard:
  - attack rolls: natural 20 = critical hit (double damage dice)
  - attack rolls: natural 1 = automatic miss
  - skill/ability/saves: no critical band
- Override per-campaign as needed.

## Advantage / disadvantage

- expressed as `2d20kh1` (advantage) and `2d20kl1` (disadvantage)
- advantage and disadvantage cancel one-for-one; net result expressed as
  one of: straight `1d20`, advantage `2d20kh1`, or disadvantage `2d20kl1`
