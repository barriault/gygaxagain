"""Mythic 2e random event detection and table sampling.

Tables transcribed from references/MythicGME2eV2.pdf:

* Random Event trigger rule: page 35 ("Random Events From Fate Questions")
  and page 187 (Rules Summary). Quote (p. 35): "When rolling 1d100 for the
  Fate Chart (or 2d10 for a Fate Check), if you get a double number (11,
  22, 33, etc.) whose digit (1 for 11, 2 for 22, etc.) is equal to or less
  than the Chaos Factor, then a Random Event occurs."
* Random Event Focus Table: page 37.
* Meaning Tables: Actions (Action 1 = verbs, Action 2 = nouns/concepts):
  page 47.

The plan called the two Meaning components ``ACTION_TABLE`` (verb) and
``SUBJECT_TABLE`` (noun). In Mythic 2e these are formally called "Action
1" and "Action 2" of the Meaning Tables: Actions table on page 47, and
they are paired to form an Event Meaning word pair after the Event Focus
is established. We keep the plan's names for the public API.

Note that Mythic 2e also offers Descriptions (Descriptor 1 + Descriptor
2, page 48) and various Elements meaning tables; Phase 1 implements the
core Actions pair only. The user is free to interpret the Focus and
Action+Subject pair through the lens of Context (page 36).
"""

from __future__ import annotations

import secrets

# Each entry: (upper_threshold_inclusive, value).
# Highest threshold must be 100 for each table.

# Random Event Focus Table - page 37 of MythicGME2eV2.pdf.
# Bands: 1-5, 6-10, 11-20, 21-40, 41-45, 46-50, 51-55, 56-65, 66-70,
# 71-80, 81-85, 86-100.
EVENT_FOCUS_TABLE: list[tuple[int, str]] = [
    (5, "Remote Event"),
    (10, "Ambiguous Event"),
    (20, "New NPC"),
    (40, "NPC Action"),
    (45, "NPC Negative"),
    (50, "NPC Positive"),
    (55, "Move Toward A Thread"),
    (65, "Move Away From A Thread"),
    (70, "Close A Thread"),
    (80, "PC Negative"),
    (85, "PC Positive"),
    (100, "Current Context"),
]

# Meaning Tables: Actions - Action 1 (verbs/actions) - page 47.
# 1d100 -> single-word verb. Each entry is exactly one row of the
# percentile table (threshold = the d100 face value).
ACTION_TABLE: list[tuple[int, str]] = [
    (1, "Abandon"),
    (2, "Accompany"),
    (3, "Activate"),
    (4, "Agree"),
    (5, "Ambush"),
    (6, "Arrive"),
    (7, "Assist"),
    (8, "Attack"),
    (9, "Attain"),
    (10, "Bargain"),
    (11, "Befriend"),
    (12, "Bestow"),
    (13, "Betray"),
    (14, "Block"),
    (15, "Break"),
    (16, "Carry"),
    (17, "Celebrate"),
    (18, "Change"),
    (19, "Close"),
    (20, "Combine"),
    (21, "Communicate"),
    (22, "Conceal"),
    (23, "Continue"),
    (24, "Control"),
    (25, "Create"),
    (26, "Deceive"),
    (27, "Decrease"),
    (28, "Defend"),
    (29, "Delay"),
    (30, "Deny"),
    (31, "Depart"),
    (32, "Deposit"),
    (33, "Destroy"),
    (34, "Dispute"),
    (35, "Disrupt"),
    (36, "Distrust"),
    (37, "Divide"),
    (38, "Drop"),
    (39, "Easy"),
    (40, "Energize"),
    (41, "Escape"),
    (42, "Expose"),
    (43, "Fail"),
    (44, "Fight"),
    (45, "Flee"),
    (46, "Free"),
    (47, "Guide"),
    (48, "Harm"),
    (49, "Heal"),
    (50, "Hinder"),
    (51, "Imitate"),
    (52, "Imprison"),
    (53, "Increase"),
    (54, "Indulge"),
    (55, "Inform"),
    (56, "Inquire"),
    (57, "Inspect"),
    (58, "Invade"),
    (59, "Leave"),
    (60, "Lure"),
    (61, "Misuse"),
    (62, "Move"),
    (63, "Neglect"),
    (64, "Observe"),
    (65, "Open"),
    (66, "Oppose"),
    (67, "Overthrow"),
    (68, "Praise"),
    (69, "Proceed"),
    (70, "Protect"),
    (71, "Punish"),
    (72, "Pursue"),
    (73, "Recruit"),
    (74, "Refuse"),
    (75, "Release"),
    (76, "Relinquish"),
    (77, "Repair"),
    (78, "Repulse"),
    (79, "Return"),
    (80, "Reward"),
    (81, "Ruin"),
    (82, "Separate"),
    (83, "Start"),
    (84, "Stop"),
    (85, "Strange"),
    (86, "Struggle"),
    (87, "Succeed"),
    (88, "Support"),
    (89, "Suppress"),
    (90, "Take"),
    (91, "Threaten"),
    (92, "Transform"),
    (93, "Trap"),
    (94, "Travel"),
    (95, "Triumph"),
    (96, "Truce"),
    (97, "Trust"),
    (98, "Use"),
    (99, "Usurp"),
    (100, "Waste"),
]

# Meaning Tables: Actions - Action 2 (nouns/concepts/subjects) - page 47.
# 1d100 -> single-word noun. Paired with ACTION_TABLE (Action 1) to form
# an Event Meaning word pair.
SUBJECT_TABLE: list[tuple[int, str]] = [
    (1, "Advantage"),
    (2, "Adversity"),
    (3, "Agreement"),
    (4, "Animal"),
    (5, "Attention"),
    (6, "Balance"),
    (7, "Battle"),
    (8, "Benefits"),
    (9, "Building"),
    (10, "Burden"),
    (11, "Bureaucracy"),
    (12, "Business"),
    (13, "Chaos"),
    (14, "Comfort"),
    (15, "Completion"),
    (16, "Conflict"),
    (17, "Cooperation"),
    (18, "Danger"),
    (19, "Defense"),
    (20, "Depletion"),
    (21, "Disadvantage"),
    (22, "Distraction"),
    (23, "Elements"),
    (24, "Emotion"),
    (25, "Enemy"),
    (26, "Energy"),
    (27, "Environment"),
    (28, "Expectation"),
    (29, "Exterior"),
    (30, "Extravagance"),
    (31, "Failure"),
    (32, "Fame"),
    (33, "Fear"),
    (34, "Freedom"),
    (35, "Friend"),
    (36, "Goal"),
    (37, "Group"),
    (38, "Health"),
    (39, "Hindrance"),
    (40, "Home"),
    (41, "Hope"),
    (42, "Idea"),
    (43, "Illness"),
    (44, "Illusion"),
    (45, "Individual"),
    (46, "Information"),
    (47, "Innocent"),
    (48, "Intellect"),
    (49, "Interior"),
    (50, "Investment"),
    (51, "Leadership"),
    (52, "Legal"),
    (53, "Location"),
    (54, "Military"),
    (55, "Misfortune"),
    (56, "Mundane"),
    (57, "Nature"),
    (58, "Needs"),
    (59, "News"),
    (60, "Normal"),
    (61, "Object"),
    (62, "Obscurity"),
    (63, "Official"),
    (64, "Opposition"),
    (65, "Outside"),
    (66, "Pain"),
    (67, "Path"),
    (68, "Peace"),
    (69, "People"),
    (70, "Personal"),
    (71, "Physical"),
    (72, "Plot"),
    (73, "Portal"),
    (74, "Possessions"),
    (75, "Poverty"),
    (76, "Power"),
    (77, "Prison"),
    (78, "Project"),
    (79, "Protection"),
    (80, "Reassurance"),
    (81, "Representative"),
    (82, "Riches"),
    (83, "Safety"),
    (84, "Strength"),
    (85, "Success"),
    (86, "Suffering"),
    (87, "Surprise"),
    (88, "Tactic"),
    (89, "Technology"),
    (90, "Tension"),
    (91, "Time"),
    (92, "Trial"),
    (93, "Value"),
    (94, "Vehicle"),
    (95, "Victory"),
    (96, "Vulnerability"),
    (97, "Weapon"),
    (98, "Weather"),
    (99, "Work"),
    (100, "Wound"),
]


def is_random_event(roll: int, chaos_factor: int) -> bool:
    """True if a Fate Chart roll triggers a random event under Mythic 2e.

    Per page 35 of MythicGME2eV2.pdf: a Random Event occurs when the
    d100 roll is a doubles value (11, 22, 33, ..., 99) AND the matched
    digit (1, 2, 3, ..., 9) is <= the current Chaos Factor.

    A roll of 100 (double-zero on percentile dice) is not treated as a
    doubles trigger by the rulebook's "11, 22, 33, ..., 99" enumeration.
    """
    if not 1 <= roll <= 100:
        raise ValueError(f"roll must be 1..100, got {roll}")
    if roll == 100:
        return False
    tens = roll // 10
    ones = roll % 10
    if tens != ones:
        return False
    return tens <= chaos_factor


def _sample(table: list[tuple[int, str]]) -> str:
    r = secrets.randbelow(100) + 1  # 1..100
    for threshold, value in table:
        if r <= threshold:
            return value
    # Should be unreachable if table is well-formed (last threshold == 100).
    raise RuntimeError(f"table not exhaustive at roll {r}")


def sample_event() -> dict:
    """Sample a random event: focus + action + subject.

    Returns a dict with three keys:
        focus: a Random Event Focus Table category (e.g. "NPC Action")
        action: an Action 1 verb (e.g. "Attack")
        subject: an Action 2 noun (e.g. "Goal")

    Interpretation through the lens of current Context is the
    narrator's job (see page 36).
    """
    return {
        "focus": _sample(EVENT_FOCUS_TABLE),
        "action": _sample(ACTION_TABLE),
        "subject": _sample(SUBJECT_TABLE),
    }
