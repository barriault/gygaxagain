"""Tests for the Fate Chart oracle."""

import pytest

from mythic.fate_chart import FATE_CHART, oracle


def test_fate_chart_table_complete():
    """Every (likelihood, chaos_factor) pair has an entry."""
    likelihoods = (
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
    for cf in range(1, 10):
        for lik in likelihoods:
            assert (lik, cf) in FATE_CHART, f"missing ({lik!r}, {cf})"


def test_oracle_returns_yes_no_value():
    result = oracle(likelihood="50_50", chaos_factor=5)
    assert result["outcome"] in ("yes", "no", "exceptional_yes", "exceptional_no")
    assert isinstance(result["roll"], int)
    assert 1 <= result["roll"] <= 100
    assert result["likelihood"] == "50_50"
    assert result["chaos_factor"] == 5


def test_oracle_invalid_likelihood():
    with pytest.raises(ValueError):
        oracle(likelihood="totally_made_up", chaos_factor=5)


def test_oracle_invalid_chaos_factor():
    with pytest.raises(ValueError):
        oracle(likelihood="50_50", chaos_factor=0)
    with pytest.raises(ValueError):
        oracle(likelihood="50_50", chaos_factor=10)


def test_oracle_distribution_50_50_at_cf5_roughly_balanced():
    # Statistical sanity: 50/50 at CF 5 should be near 50% yes.
    yes_count = 0
    for _ in range(2000):
        r = oracle(likelihood="50_50", chaos_factor=5)
        if r["outcome"] in ("yes", "exceptional_yes"):
            yes_count += 1
    # Allow generous bounds; this is a smoke test, not a precision test.
    assert 800 < yes_count < 1200, f"got {yes_count}/2000 yes outcomes"
