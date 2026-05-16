# Seeds the database with "The Ancient Tomb of Phandalin" — a 3-hour one-shot
# adventure for 1st-level characters by Michael Klamerus (DMsGuild, 2016).
#
# Idempotent: run via `bin/rails db:seed` as many times as you like. The seed
# finds-or-creates a campaign owned by the user identified by SEED_USER_EMAIL
# (defaults to jeff@barriault.net). If that user does not exist the script
# aborts with a clear message — create the user first via
# `bin/rails users:create EMAIL=... PASSWORD=...`.
#
# Designed for the Phase 9 playtest (see docs/superpowers/specs/2026-05-15-v2-
# phase-9-asymmetry-hardening-design.md). Faction + NPC + Scene admin CRUD is
# deferred to a follow-up phase; until then, this seed is the only way to
# populate non-Campaign, non-Scene admin data.

email = ENV.fetch("SEED_USER_EMAIL", "jeff@barriault.net")
user  = User.find_by(email: email) or abort(
  "Seeds need an existing user. Create one first:\n" \
  "  bin/rails users:create EMAIL=#{email} PASSWORD=<your-password>"
)

campaign_description = <<~DESC.strip
  A 3-hour one-shot dungeon crawl for 1st-level characters set in Phandalin
  on the Sword Coast. The party is hired by the captain of the city guard
  to investigate undead attacks emanating from an old cemetery outside town.
  By Michael Klamerus (DMsGuild, 2016).
DESC

campaign = Campaign.find_or_initialize_by(user: user, name: "The Ancient Tomb of Phandalin")
campaign.description  = campaign_description
campaign.save!

# Player Characters ───────────────────────────────────────────────────────────

PC_SEEDS = [
  {
    name: "Aragorn", role: "pc", class_name: "Ranger", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      AC 15 (studded leather). HP 10 (1d10). Speed 30 ft.
      STR 13/+1, DEX 16/+3, CON 10/+0, INT 10/+0, WIS 16/+3, CHA 10/+0.
      Saves: STR +3, DEX +5. Proficiency +2. Passive Perception 15.
      Skills: Animal Handling +5, Insight +5, Nature +2, Perception +5,
      Stealth +5, Survival +5.
      Languages: Common, Giant, Halfling. Tools: Cartographer's Tools.
      Weapons: Longbow +5 (1d8+3 piercing, Slow), Shortsword +5 (1d6+3 piercing,
      Vex), Shortsword +5 (1d6 piercing, dual-wield, Vex), Produce Flame +5
      (1d8 fire). Unarmed +3 (2 bludgeoning).
      Features: Favored Enemy — Hunter's Mark always prepared, castable 2x/long
      rest without a slot. Savage Attacker — once per turn on a weapon hit, roll
      damage dice twice and use either. Magic Initiate (Druid).
      Spells (WIS, save DC 13, +5 attack, 2 1st-level slots):
      - Cantrips: Mending, Produce Flame.
      - 1st: Hail of Thorns, Cure Wounds (Ranger), Cure Wounds (Druid via Magic
        Initiate, 1/long rest free), Hunter's Mark (always prepared).
    NOTES
  },
  {
    name: "Caine", role: "companion", class_name: "Monk", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      AC 16 (unarmored defense). HP 10 (1d8). Speed 35 ft.
      STR 14/+2, DEX 16/+3, CON 14/+2, INT 14/+2, WIS 16/+3, CHA 16/+3.
      Saves: STR +4, DEX +5. Proficiency +2. Passive Perception 13.
      Skills: Arcana +4, Athletics +4, History +4, Stealth +5.
      Languages: Common, Giant, Orc. Tools: Calligrapher's Supplies, Flute.
      Weapons: Katana +5 (1d6+3 slashing, Nick), Shuriken +5 (1d6+3 piercing,
      thrown 20/60, Nick) ×~14 carried.
      Features: Martial Arts (Dex for unarmed/Monk weapon attack & damage; 1d6
      Martial Arts die; unarmed strike as bonus action). Unarmored Defense.
      Hill's Tumble (Hill Giant ancestry) 2/long rest — on a hit vs. Large or
      smaller, can knock prone. Large Form (Goliath) — 1/long rest, grow Large
      for 10 minutes. Powerful Build — count as one size larger for carrying;
      advantage to end Grappled. Magic Initiate (Wizard).
      Spells (no spellcasting ability shown — WIS for the feat):
      - Cantrips: Light, Message.
      - 1st: False Life (1/long rest free, or via Wizard slots — Caine has none).
    NOTES
  },
  {
    name: "Fred", role: "companion", class_name: "Cleric", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      AC 18 (chain mail + shield). HP 11 (1d8 + Dwarven Toughness). Speed 30 ft.
      STR 14/+2, DEX 8/-1, CON 14/+2, INT 10/+0, WIS 16/+3, CHA 12/+1.
      Saves: WIS +5, CHA +3. Advantage on saves vs. poison; resistance to
      poison damage. Proficiency +2. Passive Perception 13. Darkvision 120 ft.
      Skills: Insight +5, Medicine +5, Religion +2.
      Languages: Common, Dwarvish, Orc. Tools: Calligrapher's Supplies.
      Subclass: Protector Cleric (martial weapons + heavy armor proficiency).
      Weapons: Mace +4 (1d6+2 bludgeoning, Sap). Unarmed +4 (3 bludgeoning).
      Features: Stonecunning (Tremorsense 60 ft on stone, 2/long rest as bonus
      action). Magic Initiate (Cleric).
      Spells (WIS, save DC 13, +5 attack, 2 1st-level slots):
      - Cantrips: Light, Sacred Flame, Thaumaturgy, Spare the Dying (Magic
        Initiate), Word of Radiance (Magic Initiate).
      - 1st prepared: Bless, Cure Wounds, Guiding Bolt, Command, Ceremony [R],
        Bane, Protection from Evil and Good, Purify Food and Drink [R],
        Sanctuary, Shield of Faith, Create or Destroy Water, Detect Evil and
        Good, Detect Poison and Disease [R], Detect Magic [R], Healing Word,
        Inflict Wounds.
      - 1st extra (Magic Initiate, 1/long rest free): Healing Word.
    NOTES
  },
  {
    name: "Patric", role: "companion", class_name: "Wizard", level: 1, pronouns: "he/him",
    notes: <<~NOTES.strip
      AC 13 (dex only, no armor). HP 7 (1d6). Speed 30 ft.
      STR 8/-1, DEX 16/+3, CON 12/+1, INT 15/+2, WIS 9/-1, CHA 14/+2.
      Saves: INT +4, WIS +1. Proficiency +2. Passive Perception 9.
      Skills: Arcana +4, Deception +4, Investigation +4, Sleight of Hand +5,
      Stealth +5.
      Languages: Common, Nordmaarian. Tools: Disguise Kit, Forgery Kit.
      Weapons: Dagger +5 (1d4+3 piercing, finesse/thrown 20/60), Dart +5 (1d4+3
      piercing, thrown 20/60) ×12 carried, Ray of Frost +4 (1d8 cold).
      Features: Arcane Recovery (1/long rest, after short rest recover slots
      totalling level 1).
      Spells (INT, save DC 12, +4 attack, 2 1st-level slots; spellbook below):
      - Cantrips prepared: Light, Mage Hand, Ray of Frost.
      - 1st prepared (from spellbook): Burning Hands, Charm Person, Feather
        Fall, Mage Armor, Magic Missile, Sleep.
    NOTES
  }
].freeze

PC_SEEDS.each do |attrs|
  pc = campaign.player_characters.find_or_initialize_by(name: attrs[:name])
  pc.assign_attributes(attrs)
  pc.save!
end

aragorn = campaign.player_characters.find_by!(name: "Aragorn")
campaign.update!(main_character: aragorn)

# Factions ────────────────────────────────────────────────────────────────────
# Each block: find-or-create the faction, then find-or-create each secret by
# label (the natural key within a faction).

def upsert_secret!(record, label:, content:)
  secret = record.secrets.find_or_initialize_by(label: label)
  secret.content = content
  secret.save!
end

city_guard = campaign.factions.find_or_create_by!(name: "The Phandalin City Guard") do |f|
  f.public_description = <<~DESC.strip
    The city guard of Phandalin, charged with keeping order in the rebuilt
    frontier town. Stretched thin, unwilling to risk more of their own
    against the undead, they hire outsiders for dangerous work.
  DESC
end

upsert_secret!(city_guard,
  label: "Hiring outsiders to spare guard losses",
  content: "The captain is hiring adventurers because two of his own guards " \
           "were nearly killed by a zombie at the cemetery. He cannot afford " \
           "more casualties and has been telling townsfolk that the tomb is " \
           "cursed to keep them from poking around."
)

cult_of_myrkul = campaign.factions.find_or_create_by!(name: "The Cult of Myrkul") do |f|
  f.public_description = <<~DESC.strip
    Worshippers of Myrkul, the god of the dead. Thought dormant in the region,
    their symbols still mark forgotten places.
  DESC
end

upsert_secret!(cult_of_myrkul,
  label: "Kodor Drannon was a follower",
  content: "The mage Kodor Drannon, buried in the tomb, was a devotee of " \
           "Myrkul. The dogma on the altar promises great power and eternal " \
           "life to followers who make all fear the god of the dead — which " \
           "is what now reanimates Kodor and the tomb's other dead."
)

upsert_secret!(cult_of_myrkul,
  label: "Symbol of Myrkul on the altar",
  content: "Anyone who recognizes the etchings on the altar's sarcophagus, " \
           "or reads the book sitting on the altar, will identify it as the " \
           "symbol of Myrkul."
)

grave_robbers = campaign.factions.find_or_create_by!(name: "The Grave-Robbers") do |f|
  f.public_description = <<~DESC.strip
    A small band of opportunistic thieves — Rewalt Mason and Leodak — who
    heard rumors of treasure buried with Kodor Drannon.
  DESC
end

upsert_secret!(grave_robbers,
  label: "They caused the awakening",
  content: "Rewalt and Leodak entered the tomb to loot Kodor's burial chamber. " \
           "When they opened his sarcophagus a wave of energy burst out and " \
           "woke Kodor; the rest of the dead followed. Leodak died in the " \
           "caverns below; Rewalt locked himself in the office of records."
)

upsert_secret!(grave_robbers,
  label: "Rewalt will lie to the guards after rescue",
  content: "After being rescued, Rewalt agrees to turn himself in but then " \
           "tells the guards he was dragged into the tomb by the undead — " \
           "concealing his looting. The party only learns this back in town."
)

# NPCs ────────────────────────────────────────────────────────────────────────

captain = campaign.npcs.find_or_create_by!(name: "Captain Aldridge") do |n|
  n.public_description = <<~DESC.strip
    The captain of the Phandalin city guard. Pragmatic and direct, in his
    fifties, wears worn but well-kept leather and a city badge. He meets
    the party at the cemetery gates and is the one who hired them.

    Briefing he delivers when they arrive:
    - Two citizens were attacked by a zombie in the cemetery a few nights
      ago. Two city guards drove it off and destroyed it. The captain has
      not risked sending more of his men into the tomb.
    - The tomb has existed since before Phandalin was rebuilt centuries ago.
    - He has told townspeople the tomb is cursed, to discourage them from
      going near it.
    - Records suggest it belonged to a mage named Kodor Drannon. The town
      has no detailed records from before the rebuilding.
    - 15 gp per character on return, once they've confirmed the source of
      the undead has been stopped.

    He stays at the cemetery entrance while the party explores. Two guards
    stand at the tomb door under his command.
  DESC
  n.location           = "Phandalin — cemetery entrance"
end

upsert_secret!(captain,
  label: "Knows of Kodor by reputation only",
  content: "Tells the party the tomb belonged to a mage named Kodor Drannon. " \
           "Has no records from before the town was rebuilt. The 'cursed " \
           "tomb' story is his own cover to keep townsfolk from investigating."
)

rewalt = campaign.npcs.find_or_create_by!(name: "Rewalt Mason") do |n|
  n.public_description = <<~DESC.strip
    A grimy human in his forties, currently locked inside a side chamber
    on the first floor of the tomb (the one with shelves of old records
    along its walls). Reeks of weeks without bathing. Visibly terrified.

    When the party reaches his door, he will not open it until convinced
    the skeletons in the entrance hall have been destroyed.

    Once the door is opened, the cover story he gives the party:
    - His name is Rewalt Mason.
    - He came into the tomb with a friend named Leodak (a halfling).
    - They went down to the second floor and "things started happening" —
      the dead came alive. He locked himself in here when they were
      separated.
    - He has no idea what woke the dead.
    - He claims he is just an explorer/treasure hunter; nothing organised.

    He will offer to turn himself in to the city guard once they're safely
    back at the surface.
  DESC
  n.location           = "Tomb Floor 1 — side chamber off the entrance hall"
end

upsert_secret!(rewalt,
  label: "He is a thief who looted the tomb",
  content: "Rewalt and his halfling partner Leodak broke into the tomb " \
           "specifically to loot Kodor Drannon's burial chamber, after " \
           "hearing he was buried with treasure. They opened sarcophagi on " \
           "the second floor and stole from each body. When they opened " \
           "Kodor's sarcophagus, a wave of energy woke him."
)

upsert_secret!(rewalt,
  label: "He will lie to the guards afterward",
  content: "Despite agreeing to turn himself in, Rewalt tells the guards he " \
           "was dragged into the tomb by the undead. The party only learns " \
           "this after returning to Phandalin."
)

leodak = campaign.npcs.find_or_create_by!(name: "Leodak") do |n|
  n.public_description = <<~DESC.strip
    A male halfling. The party will encounter him as a corpse at the foot
    of the stairs leading down to the second-floor caverns — multiple claw
    and bite marks, killed by undead. They will not know his name from his
    body alone; the connection to Rewalt's missing friend is made later
    when they return to Rewalt or to the captain.

    Body carries: a dagger, 3 gp, and a silver necklace worth 5 sp.
  DESC
  n.location           = "Tomb Floor 2 — at the bottom of the descent stairs"
end

upsert_secret!(leodak,
  label: "Rewalt's looting partner",
  content: "Leodak was Rewalt's halfling accomplice. After the dead awoke, " \
           "the two were separated on the second floor and Leodak was killed " \
           "by undead before he could escape."
)

kodor = campaign.npcs.find_or_create_by!(name: "Kodor Drannon") do |n|
  n.public_description = <<~DESC.strip
    The buried mage whose name the captain mentioned in his briefing.
    The party will encounter him in the deepest chamber of the tomb —
    a hexagonal stone room with an opened ornate sarcophagus (etched
    with strange symbols), an empty weapons rack, a large chest, and
    a stone altar at the back.

    His appearance now: skeletal form in a black hooded robe, a dark
    blue glow from the empty eye sockets. He stands by the altar reading
    from a book. Two skeletons flank the sarcophagus.

    Combat behaviour: he hangs back at the altar casting spells while
    the two skeletons engage in melee. He does not parley before
    attacking — he speaks only briefly before the fight begins.

    The chest in the chamber contains: 500 cp, 250 sp, 40 gp, an elegant
    robe (15 gp), a blue quartz gemstone (10 gp), a pewter crown (25 gp),
    a carved bone statuette of Myrkul (25 gp), a malachite gemstone
    (10 gp), a +1 Shield, and a Potion of Healing.
  DESC
  n.location           = "Tomb Floor 2 — deepest hexagonal chamber"
end

upsert_secret!(kodor,
  label: "Stat block — 4th-level wizard",
  content: "AC 12, HP 22 (5d8). STR 9, DEX 14, CON 12, INT 17, WIS 12, CHA 12. " \
           "4th-level spellcaster (Int-based, save DC 13, +5 to hit with spell " \
           "attacks). Cantrips: ray of frost, mage hand, shocking grasp. " \
           "1st (4 slots): shield, magic missile. 2nd (3 slots): hold person, " \
           "misty step. Quarterstaff: +1 to hit, 1d8-1 bludgeoning. CR 1 " \
           "(200 XP). Vuln. bludgeoning; immune poison and poisoned condition."
)

upsert_secret!(kodor,
  label: "Defeating him ends every undead in the tomb",
  content: "Once Kodor is destroyed, every other undead creature in the tomb " \
           "collapses instantly and falls to the ground. The party's mission " \
           "is complete at this moment."
)

upsert_secret!(kodor,
  label: "Was a Myrkul devotee in life",
  content: "The altar in his chamber bears Myrkul's symbol; the book on it " \
           "promises eternal life to followers who spread fear of the god of " \
           "the dead. This is why he reanimated when his sarcophagus was " \
           "opened — and why the rest of the tomb's dead followed."
)

# Scenes ──────────────────────────────────────────────────────────────────────
# IMPORTANT: scene.title and scene.summary both render to the player surface
# (Play::Scenes::PlayComponent + Play::Campaigns::ScenePickerComponent).
# Treat them as read-aloud text — environmental description only, no names
# of beings the players have not met, no encounter composition, no trap or
# DC info. DM-side encounter content lives in scene_secrets (narrator-only).

# If we have an existing seeded campaign with scenes but no play events,
# wipe and re-seed scenes so content edits to this file always re-apply.
# This guard is safe: once any narration / dice / oracle / scene-transition
# event exists, the destroy_all is skipped and existing scenes are preserved.
if campaign.scenes.any? && !campaign.scenes.joins(:events).exists?
  destroyed = campaign.scenes.destroy_all
  puts "  Pre-play state — cleared #{destroyed.size} existing scenes to re-seed."
end

scenes = [
  {
    title:   "Cemetery & Tomb Approach",
    summary: "An old cemetery on the outskirts of Phandalin. Weathered " \
             "headstones lean among long grass; vines cover the back wall " \
             "of the yard. Set into the hillside at the back of the " \
             "cemetery is a low stone tomb — its iron door dull with age, " \
             "the rune-work above the lintel softened to illegibility."
  },
  {
    title:   "The Tomb — Entrance Hall",
    summary: "A wide circular chamber, well-lit by guttering torches in " \
             "iron sconces along the stone walls. The floor is dusty flagstone. " \
             "Three heavy wooden doors lead away — one on the left, one to the " \
             "right, and one directly across the room. The air smells of cold " \
             "stone and old smoke."
  },
  {
    title:   "The Tomb — West Side Chamber",
    summary: "Behind the leftmost door of the entrance hall. A narrow stone " \
             "room lined with collapsing wooden shelves; loose parchments " \
             "lie scattered across the floor. A single heavy door stands at " \
             "the back, currently barred from the inside."
  },
  {
    title:   "The Tomb — North Chamber",
    summary: "Behind the door directly across the entrance hall. A large " \
             "stone room, every surface covered in a layer of grey dust. " \
             "Four wooden body-prep tables stand along the left wall. At " \
             "the far end of the room is a great furnace, cold and dark, " \
             "with a stone slab in front of it. To the right is a smaller " \
             "table piled with personal effects — arrows in a bundle, two " \
             "short swords, a copper ring. The air carries a pungent, sour " \
             "odour."
  },
  {
    title:   "The Tomb — East Hallway",
    summary: "Behind the rightmost door of the entrance hall. A narrow " \
             "passage stretching far into the dark, perhaps ninety feet long " \
             "and only wide enough for three abreast. Short side hallways " \
             "branch left and right every thirty feet or so. The walls on " \
             "both sides are honeycombed from floor to ceiling with shallow " \
             "alcoves, and in each alcove rests a body. The bones are dry " \
             "and old."
  },
  {
    title:   "The Tomb — Far Chamber",
    summary: "At the end of the east hallway. A second circular chamber, " \
             "similar to the entrance hall but colder. Doors on the left " \
             "and ahead open onto small rooms holding sarcophagi whose " \
             "stone lids have already been shoved aside. To the right, a " \
             "stone staircase descends into deeper darkness."
  },
  {
    title:   "The Caverns — Entrance",
    summary: "The stairs end in a cavern. Rough-hewn stone replaces the " \
             "worked-tomb masonry of the floor above. The tunnel ahead " \
             "splits in two — one branch curls away to the left, the other " \
             "leads right. The walls of each tunnel are lined with shallow " \
             "alcoves, each holding the dry remains of someone long " \
             "interred."
  },
  {
    title:   "The Caverns — West Tunnel",
    summary: "The left branch is a short tunnel, roughly twenty feet long, " \
             "ending in a small alcove. A stone sarcophagus stands open at " \
             "the back, its lid askew. A wooden chest, banded with iron, " \
             "sits in front of the sarcophagus."
  },
  {
    title:   "The Caverns — East Tunnel",
    summary: "The right branch opens into a round chamber. An open " \
             "sarcophagus lies along the left wall, its lid cracked on the " \
             "floor. A narrow tunnel leaves the chamber on the far side, " \
             "twisting onward into the deeper dark."
  },
  {
    title:   "The Caverns — Deepest Chamber",
    summary: "The far tunnel opens into a large hexagonal chamber. The " \
             "walls and floor are smooth worked stone again, ancient and " \
             "cold. At the centre of the room stands an ornate, opened " \
             "sarcophagus, its lid carved with strange etchings. To the " \
             "left, an empty wooden weapons rack leans against the wall; " \
             "to the right, a great iron-bound chest. At the back of the " \
             "chamber, a low stone altar."
  },
  {
    title:   "Return to Phandalin",
    summary: "The party climbs back to the surface and out through the " \
             "cemetery gate. The captain is waiting. The horizon is just " \
             "starting to lighten. Time to make a report."
  }
]

scenes.each do |attrs|
  campaign.scenes.find_or_create_by!(title: attrs[:title]) do |s|
    s.summary = attrs[:summary]
  end
end

# Scene Secrets ───────────────────────────────────────────────────────────────
# DM-only encounter map content, one secret per scene. These replace the
# # DM Encounter Map section that previously lived in campaign.description.

SCENE_SECRETS = {
  "Cemetery & Tomb Approach"      => <<~TEXT,
    Captain Aldridge is here, waiting at the gate. Two unnamed city soldiers
    stand at the tomb door. No combat. The captain delivers his briefing
    (see his NPC entry) and unbars the tomb door at the party's request.
  TEXT
  "The Tomb — Entrance Hall"      => <<~TEXT,
    2 Skeletons (MM 272) are at the left door, trying to break through to
    the side chamber. They do not notice the party at first; will notice
    if anyone fails a Stealth check or stands too long in the open. CR 1/4
    each, 100 XP for the pair.
  TEXT
  "The Tomb — West Side Chamber"  => <<~TEXT,
    Rewalt Mason (see his NPC entry) is locked inside, alone. He will not
    open the door until told the skeletons are destroyed. After opening,
    roleplay per his NPC entry — he conceals he's a thief and his halfling
    partner is named Leodak, until questioned hard or until the party
    returns from Floor 2 having found Leodak's body. No combat in this room.
  TEXT
  "The Tomb — North Chamber"      => <<~TEXT,
    3 Zombies (MM 316) wander the room, awakened before they were cremated.
    CR 1/4 each, 150 XP for the three. The furnace can be lit (wood already
    underneath); any zombie pushed in is destroyed instantly. The side table
    holds 20 arrows, two shortswords, and a copper ring (15 cp).
  TEXT
  "The Tomb — East Hallway"       => <<~TEXT,
    4 Skeletons (MM 272) ambush the party as they pass the first set of side
    passages, crawling out of the alcoves (two from each end of the hallway).
    Characters get a DC 15 Wisdom (Perception) check before triggering the
    trap to notice two skeletons moving near the first side passage; success
    avoids the ambush surprise round. CR 1/4 each, 200 XP for the four.
  TEXT
  "The Tomb — Far Chamber"        => <<~TEXT,
    2 Skeleton Captains (custom — see stat-block summary in their npc_secret
    on Kodor; they're CR 1/2 each, 100 XP, AC 14 studded leather, HP 16,
    Multiattack: two shortsword attacks at +4 for 1d6+2 piercing) stand at
    the centre of the room. Side rooms left and ahead hold already-opened
    sarcophagi (looted by Rewalt and Leodak earlier — no treasure left). The
    staircase right descends to the second floor / caverns.
  TEXT
  "The Caverns — Entrance"        => <<~TEXT,
    No encounter here. Leodak's body lies at the foot of the stairs — see
    his NPC entry. The body has a dagger, 3 gp, and a silver necklace (5 sp).
  TEXT
  "The Caverns — West Tunnel"     => <<~TEXT,
    No creatures. The wall trap that killed the previous victim is already
    sprung (a rusted spear projecting from the side wall, with the impaled
    skeleton). The skeleton has a silver ring (5 sp). The wooden chest in
    front of the sarcophagus has a hidden crossbow trap on the lid — DC 15
    Wisdom (Perception) to spot, DC 10 Dexterity (sleight of hand) to disarm,
    1d10 piercing damage to whoever opens it untrained. Chest contains 100 sp.
  TEXT
  "The Caverns — East Tunnel"     => <<~TEXT,
    Ghoul (MM 148) in the centre of the chamber. CR 1, 200 XP. The opened
    sarcophagus along the left wall is empty (looted). After defeating it,
    searching the ghoul yields a gold ring (5 gp). The 60-foot exit tunnel
    has a magic-missile trap halfway down — a skull statue at the far end
    fires at the lead character. DC 10 Wisdom (Perception) to spot, DC 10
    Dexterity to disable, 1d10 force damage on a miss to the lead character
    only.
  TEXT
  "The Caverns — Deepest Chamber" => <<~TEXT,
    Kodor Drannon (see his NPC entry — full stat block in his npc_secrets)
    stands by the altar. 2 Skeletons (MM 272) flank the open sarcophagus.
    Kodor opens the encounter with a brief threatening line and then casts
    Magic Missile or Shocking Grasp; he hangs back near the altar while the
    skeletons engage in melee. Once Kodor drops, every other undead in the
    tomb instantly collapses. The chest at the right contains the treasure
    detailed in Kodor's NPC entry. The book on the altar contains Myrkul's
    dogma (see Cult of Myrkul faction entry).
  TEXT
  "Return to Phandalin"           => <<~TEXT,
    No combat. The captain confirms the source is destroyed and pays 15 gp
    per character. After the party leaves, narrate that Rewalt did not turn
    himself in — see Rewalt's npc_secrets. Award 200 XP per character plus
    15 XP per trap they successfully disarmed or avoided.
  TEXT
}.freeze

campaign.scenes.each do |scene|
  content = SCENE_SECRETS[scene.title]
  next unless content
  secret = scene.scene_secrets.find_or_initialize_by(label: "Encounter map")
  secret.content = content.strip
  secret.save!
end

puts "Seeded campaign '#{campaign.name}' for #{user.email}:"
puts "  #{campaign.factions.count} factions, " \
     "#{campaign.factions.flat_map(&:secrets).count} faction secrets"
puts "  #{campaign.npcs.count} NPCs, " \
     "#{campaign.npcs.flat_map(&:secrets).count} NPC secrets"
puts "  #{campaign.scenes.count} scenes"
puts "  #{campaign.player_characters.count} player characters " \
     "(#{campaign.player_characters.pcs.count} PCs, " \
     "#{campaign.player_characters.companions.count} companions)"
puts "  #{campaign.scenes.flat_map(&:scene_secrets).count} scene secrets"
