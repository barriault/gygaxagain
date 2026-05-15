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

campaign = Campaign.find_or_create_by!(user: user, name: "The Ancient Tomb of Phandalin") do |c|
  c.description = <<~DESC.strip
    A 3-hour one-shot dungeon crawl for 1st-level characters set in Phandalin
    on the Sword Coast. The party is hired by the captain of the city guard
    to investigate undead attacks emanating from an old cemetery outside town.
    By Michael Klamerus (DMsGuild, 2016).
  DESC
  c.chaos_factor = 5
end

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
  n.public_description = "The captain of the Phandalin city guard. Pragmatic " \
                         "and direct. Meets the party at the cemetery, briefs " \
                         "them on the disturbance, and promises 15 gp each on " \
                         "their return."
  n.location           = "Phandalin — cemetery entrance"
end

upsert_secret!(captain,
  label: "Knows of Kodor by reputation only",
  content: "Tells the party the tomb belonged to a mage named Kodor Drannon. " \
           "Has no records from before the town was rebuilt. The 'cursed " \
           "tomb' story is his own cover to keep townsfolk from investigating."
)

rewalt = campaign.npcs.find_or_create_by!(name: "Rewalt Mason") do |n|
  n.public_description = "A grimy human in his forties, locked inside the " \
                         "tomb's Office of Records. Reeks of weeks without " \
                         "bathing. Tells the party he and a friend were " \
                         "exploring the tomb when it went wrong."
  n.location           = "Tomb Floor 1 — Office of Records (Room 2)"
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
  n.public_description = "A male halfling, found dead at the bottom of the " \
                         "staircase leading down to the second-floor caverns. " \
                         "Multiple claw and bite marks. Carries a dagger, " \
                         "3 gp, and a silver necklace worth 5 sp."
  n.location           = "Tomb Floor 2 — Caverns entrance"
end

upsert_secret!(leodak,
  label: "Rewalt's looting partner",
  content: "Leodak was Rewalt's halfling accomplice. After the dead awoke, " \
           "the two were separated on the second floor and Leodak was killed " \
           "by undead before he could escape."
)

kodor = campaign.npcs.find_or_create_by!(name: "Kodor Drannon") do |n|
  n.public_description = "An undead mage who has risen from his sarcophagus. " \
                         "Skeletal form, black hooded robe, dark blue glow " \
                         "from the eye sockets. The party will not learn his " \
                         "name until they read the office records or speak " \
                         "to Rewalt."
  n.location           = "Tomb Floor 2 — Kodor's Resting Place (Room 4)"
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
# Position is managed by acts_as_list. find_or_create_by on (campaign, title)
# is naturally unique because we never reuse titles within a campaign.

scenes = [
  {
    title:   "Cemetery & Tomb Entrance",
    summary: "The captain meets the party at the cemetery gates, briefs them " \
             "on the undead disturbance, and promises 15 gp each on return. " \
             "Two soldiers guard the tomb door at the back of the cemetery; " \
             "vines cover the walls and the headstones are unreadable."
  },
  {
    title:   "Tomb Entrance Chamber",
    summary: "Floor 1, Room 1. A circular, torch-lit room with three wooden " \
             "doors (left, right, ahead). Two skeletons are banging on the " \
             "left door, trying to break through to whatever lies beyond. " \
             "Hostile: 2 Skeletons (100 XP)."
  },
  {
    title:   "Office of Records",
    summary: "Floor 1, Room 2 (behind the door the skeletons were attacking). " \
             "Rewalt Mason is locked inside, hesitant to open the door. " \
             "Roleplay: he conceals that he is a thief; reveals it under " \
             "questioning or after the party clears Floor 2. Says his friend " \
             "Leodak is somewhere below."
  },
  {
    title:   "The Crematorium",
    summary: "Floor 1, Room 3 (north door from the entrance). Pungent " \
             "odor, dust-covered surfaces, four wooden body-prep tables, a " \
             "furnace at the back, a side table with 20 arrows, two short " \
             "swords, and a copper ring (15 cp). Three zombies wander the " \
             "room. Lighting the furnace and pushing zombies in destroys " \
             "them instantly. Hostile: 3 Zombies (150 XP)."
  },
  {
    title:   "Narrow Skeletal Passage",
    summary: "Floor 1, Room 4 (right door from the entrance). A 90-foot " \
             "hallway with short side passages every 30 feet. Alcoves filled " \
             "with resting skeletons line the walls. Four skeletons ambush " \
             "the party between the first two hallways unless a character " \
             "passes a DC 15 Wisdom (Perception) check. Hostile: 4 Skeletons " \
             "(200 XP)."
  },
  {
    title:   "Skeleton Captain Chamber",
    summary: "Floor 1, Room 5. A second circular chamber. Doors lead to " \
             "side rooms with already-opened sarcophagi. A staircase leads " \
             "down to Floor 2. Two skeleton captains stand at the center. " \
             "Hostile: 2 Skeleton Captains (Appendix, 200 XP)."
  },
  {
    title:   "Caverns Entrance (Floor 2)",
    summary: "Floor 2, Room 1. The stairs open onto a cavern that splits " \
             "into two tunnels (left and right). Leodak's body lies at the " \
             "foot of the stairs, killed by claws and bites. Searching " \
             "yields a dagger, 3 gp, and a silver necklace (5 sp). No " \
             "encounters here."
  },
  {
    title:   "Left Tunnel — Sarcophagus and Trapped Chest",
    summary: "Floor 2, Room 2. 20-foot tunnel to an open sarcophagus. A " \
             "trap-impaled skeleton lies beside it (silver ring, 5 sp). A " \
             "wooden chest in front of the tomb contains 100 sp and bears a " \
             "hidden crossbow trap (DC 15 Perception to spot, DC 10 Dex to " \
             "disarm; 1d10 arrow damage on failure). No creatures."
  },
  {
    title:   "Right Tunnel — The Ghoul",
    summary: "Floor 2, Room 3. The tunnel opens onto a round room with an " \
             "open sarcophagus on the left and another tunnel right toward " \
             "the cavern exit. A ghoul waits in the center. Search after " \
             "defeat yields a gold ring (5 gp). The 60-foot exit tunnel has " \
             "a skull-statue magic-missile trap halfway down — DC 10 " \
             "Perception to spot, DC 10 Dex to disable, 1d10 force damage " \
             "to the lead character on failure. Hostile: Ghoul (200 XP)."
  },
  {
    title:   "Kodor's Resting Place",
    summary: "Floor 2, Room 4. The final chamber. A hexagon-shaped room with " \
             "an opened ornate sarcophagus (etched with Myrkul's symbol), an " \
             "empty weapons rack, a large chest, and a stone altar at the " \
             "back. Kodor Drannon stands by the altar reading from a book. " \
             "Two skeletons flank the sarcophagus. Kodor hangs back casting " \
             "spells while the skeletons engage. Chest treasure: 500 cp, " \
             "250 sp, 40 gp, elegant robe (15 gp), blue quartz (10 gp), " \
             "pewter crown (25 gp), carved bone statuette of Myrkul (25 gp), " \
             "malachite gem (10 gp), +1 Shield, Potion of Healing. Hostile: " \
             "Kodor Drannon (200 XP), 2 Skeletons (100 XP)."
  },
  {
    title:   "Return to Phandalin",
    summary: "Climbing back to the surface, the party reports to the city " \
             "guard. The captain confirms the source of the undead is " \
             "destroyed and pays 15 gp each. The party also learns that " \
             "Rewalt did not turn himself in — he told the guards he was " \
             "dragged in by the undead, concealing his looting. Award 200 " \
             "XP per character plus 15 XP per trap successfully disarmed or " \
             "avoided."
  }
]

scenes.each do |attrs|
  campaign.scenes.find_or_create_by!(title: attrs[:title]) do |s|
    s.summary = attrs[:summary]
  end
end

puts "Seeded campaign '#{campaign.name}' for #{user.email}:"
puts "  #{campaign.factions.count} factions, " \
     "#{campaign.factions.flat_map(&:secrets).count} faction secrets"
puts "  #{campaign.npcs.count} NPCs, " \
     "#{campaign.npcs.flat_map(&:secrets).count} NPC secrets"
puts "  #{campaign.scenes.count} scenes"
