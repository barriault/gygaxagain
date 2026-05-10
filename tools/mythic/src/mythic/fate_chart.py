"""Mythic 2e Fate Chart.

FATE_CHART maps (likelihood, chaos_factor) -> (exceptional_no_max, no_max,
yes_max, exceptional_yes_max). A d100 roll <= one of these thresholds
yields the corresponding outcome.

Concretely, given a roll r:
    r <= exceptional_no_max  -> Exceptional No
    r <= no_max              -> No
    r <= yes_max             -> Yes
    r <= exceptional_yes_max -> Exceptional Yes  (typically 100, so this
                                                   tier covers all remaining)

NOTE: This dictionary is populated in Task 7 from references/MythicGME2eV2.pdf.
Until then, FATE_CHART is empty and oracle() will raise.
"""

from __future__ import annotations

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

# Populated in Task 7.
FATE_CHART: dict[tuple[Likelihood, int], tuple[int, int, int, int]] = {}
