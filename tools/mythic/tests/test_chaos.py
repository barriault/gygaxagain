"""Tests for chaos factor file read/write."""

from pathlib import Path

import pytest

from mythic.chaos import read_chaos, write_chaos, adjust_chaos


def test_read_chaos_simple_int(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("5\n", encoding="utf-8")
    assert read_chaos(f) == 5


def test_read_chaos_with_header(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("# Chaos factor\n\n7\n", encoding="utf-8")
    assert read_chaos(f) == 7


def test_read_chaos_clamps_invalid_to_default(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("nonsense\n", encoding="utf-8")
    with pytest.raises(ValueError):
        read_chaos(f)


def test_write_chaos_round_trip(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    write_chaos(f, 6)
    assert read_chaos(f) == 6


def test_adjust_chaos_increment(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("5\n", encoding="utf-8")
    new = adjust_chaos(f, +1)
    assert new == 6
    assert read_chaos(f) == 6


def test_adjust_chaos_clamps_low(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("1\n", encoding="utf-8")
    new = adjust_chaos(f, -5)
    assert new == 1


def test_adjust_chaos_clamps_high(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("9\n", encoding="utf-8")
    new = adjust_chaos(f, +5)
    assert new == 9
