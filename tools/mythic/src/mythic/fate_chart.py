"""Mythic 2e Fate Chart.

FATE_CHART maps (likelihood, chaos_factor) -> (exceptional_yes_max,
yes_max, no_max, exceptional_no_max). Given a d100 roll r, the outcome
bands are inclusive ranges:

    1                    .. exceptional_yes_max -> Exceptional Yes
    exceptional_yes_max+1 .. yes_max             -> Yes
    yes_max+1            .. no_max               -> No
    no_max+1             .. exceptional_no_max   -> Exceptional No

In Mythic 2e (per the Fate Chart on page 19 and the example explanation
on page 24 of MythicGME2eV2.pdf), low rolls favor Yes and high rolls
favor No. Each cell of the chart is printed as ``L M R``:

* ``L`` is the upper bound of the Exceptional Yes range (1..L). If the
  cell shows ``X`` here, Exceptional Yes is not possible at these odds
  and we encode ``L = 0`` (empty band).
* ``M`` is the central percentage chance of a Yes answer (1..M).
* ``R`` is the lower bound of the Exceptional No range (R..100). If the
  cell shows ``X`` here, Exceptional No is not possible and we encode
  ``no_max = exceptional_no_max = 100`` (empty Exc No band).

So a cell ``10 50 91`` becomes ``(10, 50, 90, 100)`` and yields:
1-10 Exceptional Yes, 11-50 Yes, 51-90 No, 91-100 Exceptional No --
matching the worked example on page 24 of the rulebook.

Cells with ``X`` for Exceptional Yes (e.g. Very Unlikely / CF 1 = ``X 1
81``) become ``(0, 1, 80, 100)``: 1 = Yes, 2-80 = No, 81-100 = Exc No.
Cells with ``X`` for Exceptional No (e.g. Certain / CF 7 = ``20 99 X``)
become ``(20, 99, 100, 100)``: 1-20 = Exc Yes, 21-99 = Yes, 100 = No,
no Exceptional No possible.
"""

from __future__ import annotations

import secrets
from typing import Literal

LIKELIHOODS = (
    "impossible",
    "nearly_impossible",
    "very_unlikely",
    "unlikely",
    "50_50",
    "likely",
    "very_likely",
    "nearly_certain",
    "certain",
)
Likelihood = Literal[
    "impossible",
    "nearly_impossible",
    "very_unlikely",
    "unlikely",
    "50_50",
    "likely",
    "very_likely",
    "nearly_certain",
    "certain",
]

# All 81 cells transcribed from the Fate Chart on page 19 of
# references/MythicGME2eV2.pdf. Tuple is
# (exceptional_yes_max, yes_max, no_max, exceptional_no_max).
FATE_CHART: dict[tuple[Likelihood, int], tuple[int, int, int, int]] = {
    # Certain: 10 50 91 | 13 65 94 | 15 75 96 | 17 85 98 | 18 90 99 |
    #          19 95 100 | 20 99 X | 20 99 X | 20 99 X
    ("certain", 1): (10, 50, 90, 100),
    ("certain", 2): (13, 65, 93, 100),
    ("certain", 3): (15, 75, 95, 100),
    ("certain", 4): (17, 85, 97, 100),
    ("certain", 5): (18, 90, 98, 100),
    ("certain", 6): (19, 95, 99, 100),
    ("certain", 7): (20, 99, 100, 100),
    ("certain", 8): (20, 99, 100, 100),
    ("certain", 9): (20, 99, 100, 100),
    # Nearly Certain: 7 35 88 | 10 50 91 | 13 65 94 | 15 75 96 |
    #                 17 85 98 | 18 90 99 | 19 95 100 | 20 99 X | 20 99 X
    ("nearly_certain", 1): (7, 35, 87, 100),
    ("nearly_certain", 2): (10, 50, 90, 100),
    ("nearly_certain", 3): (13, 65, 93, 100),
    ("nearly_certain", 4): (15, 75, 95, 100),
    ("nearly_certain", 5): (17, 85, 97, 100),
    ("nearly_certain", 6): (18, 90, 98, 100),
    ("nearly_certain", 7): (19, 95, 99, 100),
    ("nearly_certain", 8): (20, 99, 100, 100),
    ("nearly_certain", 9): (20, 99, 100, 100),
    # Very Likely: 5 25 86 | 7 35 88 | 10 50 91 | 13 65 94 | 15 75 96 |
    #              17 85 98 | 18 90 99 | 19 95 100 | 20 99 X
    ("very_likely", 1): (5, 25, 85, 100),
    ("very_likely", 2): (7, 35, 87, 100),
    ("very_likely", 3): (10, 50, 90, 100),
    ("very_likely", 4): (13, 65, 93, 100),
    ("very_likely", 5): (15, 75, 95, 100),
    ("very_likely", 6): (17, 85, 97, 100),
    ("very_likely", 7): (18, 90, 98, 100),
    ("very_likely", 8): (19, 95, 99, 100),
    ("very_likely", 9): (20, 99, 100, 100),
    # Likely: 3 15 84 | 5 25 86 | 7 35 88 | 10 50 91 | 13 65 94 |
    #         15 75 96 | 17 85 98 | 18 90 99 | 19 95 100
    ("likely", 1): (3, 15, 83, 100),
    ("likely", 2): (5, 25, 85, 100),
    ("likely", 3): (7, 35, 87, 100),
    ("likely", 4): (10, 50, 90, 100),
    ("likely", 5): (13, 65, 93, 100),
    ("likely", 6): (15, 75, 95, 100),
    ("likely", 7): (17, 85, 97, 100),
    ("likely", 8): (18, 90, 98, 100),
    ("likely", 9): (19, 95, 99, 100),
    # 50/50: 2 10 83 | 3 15 84 | 5 25 86 | 7 35 88 | 10 50 91 |
    #        13 65 94 | 15 75 96 | 17 85 98 | 18 90 99
    ("50_50", 1): (2, 10, 82, 100),
    ("50_50", 2): (3, 15, 83, 100),
    ("50_50", 3): (5, 25, 85, 100),
    ("50_50", 4): (7, 35, 87, 100),
    ("50_50", 5): (10, 50, 90, 100),
    ("50_50", 6): (13, 65, 93, 100),
    ("50_50", 7): (15, 75, 95, 100),
    ("50_50", 8): (17, 85, 97, 100),
    ("50_50", 9): (18, 90, 98, 100),
    # Unlikely: 1 5 82 | 2 10 83 | 3 15 84 | 5 25 86 | 7 35 88 |
    #           10 50 91 | 13 65 94 | 15 75 96 | 17 85 98
    ("unlikely", 1): (1, 5, 81, 100),
    ("unlikely", 2): (2, 10, 82, 100),
    ("unlikely", 3): (3, 15, 83, 100),
    ("unlikely", 4): (5, 25, 85, 100),
    ("unlikely", 5): (7, 35, 87, 100),
    ("unlikely", 6): (10, 50, 90, 100),
    ("unlikely", 7): (13, 65, 93, 100),
    ("unlikely", 8): (15, 75, 95, 100),
    ("unlikely", 9): (17, 85, 97, 100),
    # Very Unlikely: X 1 81 | 1 5 82 | 2 10 83 | 3 15 84 | 5 25 86 |
    #                7 35 88 | 10 50 91 | 13 65 94 | 15 75 96
    ("very_unlikely", 1): (0, 1, 80, 100),
    ("very_unlikely", 2): (1, 5, 81, 100),
    ("very_unlikely", 3): (2, 10, 82, 100),
    ("very_unlikely", 4): (3, 15, 83, 100),
    ("very_unlikely", 5): (5, 25, 85, 100),
    ("very_unlikely", 6): (7, 35, 87, 100),
    ("very_unlikely", 7): (10, 50, 90, 100),
    ("very_unlikely", 8): (13, 65, 93, 100),
    ("very_unlikely", 9): (15, 75, 95, 100),
    # Nearly Impossible: X 1 81 | X 1 81 | 1 5 82 | 2 10 83 | 3 15 84 |
    #                    5 25 86 | 7 35 88 | 10 50 91 | 13 65 94
    ("nearly_impossible", 1): (0, 1, 80, 100),
    ("nearly_impossible", 2): (0, 1, 80, 100),
    ("nearly_impossible", 3): (1, 5, 81, 100),
    ("nearly_impossible", 4): (2, 10, 82, 100),
    ("nearly_impossible", 5): (3, 15, 83, 100),
    ("nearly_impossible", 6): (5, 25, 85, 100),
    ("nearly_impossible", 7): (7, 35, 87, 100),
    ("nearly_impossible", 8): (10, 50, 90, 100),
    ("nearly_impossible", 9): (13, 65, 93, 100),
    # Impossible: X 1 81 | X 1 81 | X 1 81 | 1 5 82 | 2 10 83 |
    #             3 15 84 | 5 25 86 | 7 35 88 | 10 50 91
    ("impossible", 1): (0, 1, 80, 100),
    ("impossible", 2): (0, 1, 80, 100),
    ("impossible", 3): (0, 1, 80, 100),
    ("impossible", 4): (1, 5, 81, 100),
    ("impossible", 5): (2, 10, 82, 100),
    ("impossible", 6): (3, 15, 83, 100),
    ("impossible", 7): (5, 25, 85, 100),
    ("impossible", 8): (7, 35, 87, 100),
    ("impossible", 9): (10, 50, 90, 100),
}


def oracle(likelihood: Likelihood, chaos_factor: int) -> dict:
    """Resolve a yes/no question via the Mythic 2e Fate Chart.

    Returns a dict with 'outcome', 'roll', 'likelihood', 'chaos_factor',
    and 'thresholds' (the 4-tuple that determined the bands).

    Outcome semantics follow Mythic 2e: low rolls favor Yes, high rolls
    favor No. The four bands are Exceptional Yes / Yes / No / Exceptional
    No, defined by the cell's thresholds.
    """
    if likelihood not in LIKELIHOODS:
        raise ValueError(f"unknown likelihood {likelihood!r}")
    if not 1 <= chaos_factor <= 9:
        raise ValueError(f"chaos_factor must be 1..9, got {chaos_factor}")

    thresholds = FATE_CHART[(likelihood, chaos_factor)]
    exc_yes, yes, no, exc_no = thresholds
    r = secrets.randbelow(100) + 1  # 1..100

    if r <= exc_yes:
        outcome = "exceptional_yes"
    elif r <= yes:
        outcome = "yes"
    elif r <= no:
        outcome = "no"
    else:
        outcome = "exceptional_no"

    return {
        "outcome": outcome,
        "roll": r,
        "likelihood": likelihood,
        "chaos_factor": chaos_factor,
        "thresholds": list(thresholds),
    }
