"""Tests for dice expression parsing (no rolling yet)."""

import pytest

from dice.parser import parse_expression, Term, DiceTerm, ConstantTerm, roll


def test_parse_constant():
    terms = parse_expression("5")
    assert terms == [ConstantTerm(value=5, sign=1)]


def test_parse_simple_die():
    terms = parse_expression("1d20")
    assert terms == [DiceTerm(count=1, sides=20, sign=1, keep=None)]


def test_parse_die_with_modifier():
    terms = parse_expression("1d20+5")
    assert terms == [
        DiceTerm(count=1, sides=20, sign=1, keep=None),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_die_with_negative_modifier():
    terms = parse_expression("1d4-1")
    assert terms == [
        DiceTerm(count=1, sides=4, sign=1, keep=None),
        ConstantTerm(value=1, sign=-1),
    ]


def test_parse_multiple_dice_terms():
    terms = parse_expression("1d8+1d6+5")
    assert terms == [
        DiceTerm(count=1, sides=8, sign=1, keep=None),
        DiceTerm(count=1, sides=6, sign=1, keep=None),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_multiplied_dice():
    terms = parse_expression("2d6")
    assert terms == [DiceTerm(count=2, sides=6, sign=1, keep=None)]


def test_parse_whitespace_tolerated():
    terms = parse_expression("1d20 + 5")
    assert terms == [
        DiceTerm(count=1, sides=20, sign=1, keep=None),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_empty_raises():
    with pytest.raises(ValueError):
        parse_expression("")


def test_parse_garbage_raises():
    with pytest.raises(ValueError):
        parse_expression("not-a-roll")


# Rolling tests

def test_roll_constant_only():
    result = roll("5")
    assert result["total"] == 5
    assert result["expression"] == "5"


def test_roll_d1_is_deterministic():
    # d1 always rolls 1, so the result is fully determined.
    result = roll("3d1+2")
    assert result["total"] == 5
    assert result["terms"][0]["rolls"] == [1, 1, 1]
    assert result["terms"][0]["value"] == 3
    assert result["terms"][1]["value"] == 2


def test_roll_returns_per_term_breakdown():
    result = roll("1d1+1d1")
    assert len(result["terms"]) == 2
    assert all(t["type"] == "dice" for t in result["terms"])
    assert result["total"] == 2


def test_roll_negative_term_subtracts():
    result = roll("3d1-1")
    assert result["total"] == 2


def test_roll_d20_within_range():
    for _ in range(50):
        result = roll("1d20+5")
        die_value = result["terms"][0]["value"]
        assert 1 <= die_value <= 20
        assert result["total"] == die_value + 5


def test_parse_keep_highest():
    terms = parse_expression("4d6kh3")
    assert terms == [DiceTerm(count=4, sides=6, sign=1, keep=("h", 3))]


def test_parse_advantage_syntax():
    terms = parse_expression("2d20kh1+5")
    assert terms == [
        DiceTerm(count=2, sides=20, sign=1, keep=("h", 1)),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_disadvantage_syntax():
    terms = parse_expression("2d20kl1+5")
    assert terms == [
        DiceTerm(count=2, sides=20, sign=1, keep=("l", 1)),
        ConstantTerm(value=5, sign=1),
    ]


def test_roll_keep_highest_drops_lowest():
    # 4d1kh3 → all rolls are 1, but "kept" should be 3 of them, "dropped" 1.
    result = roll("4d1kh3")
    term = result["terms"][0]
    assert len(term["kept"]) == 3
    assert len(term["dropped"]) == 1
    assert term["value"] == 3


def test_roll_advantage_picks_higher_of_two_d20():
    # Repeatedly roll 2d20kh1 and verify the kept roll is always >= dropped.
    for _ in range(50):
        result = roll("2d20kh1")
        term = result["terms"][0]
        assert len(term["kept"]) == 1
        assert len(term["dropped"]) == 1
        assert term["kept"][0] >= term["dropped"][0]


def test_roll_disadvantage_picks_lower_of_two_d20():
    for _ in range(50):
        result = roll("2d20kl1")
        term = result["terms"][0]
        assert len(term["kept"]) == 1
        assert len(term["dropped"]) == 1
        assert term["kept"][0] <= term["dropped"][0]
