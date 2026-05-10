"""Tests for dm-fs path-safety primitive."""

from pathlib import Path

import pytest

from dm_fs.safety import resolve_dm_path, PathSafetyError


def test_resolve_relative_path(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    (dm_root / "npcs").mkdir()
    target = dm_root / "npcs" / "x.md"
    target.write_text("hello", encoding="utf-8")

    resolved = resolve_dm_path(dm_root, "npcs/x.md")
    assert resolved == target.resolve()


def test_resolve_empty_returns_root(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    resolved = resolve_dm_path(dm_root, "")
    assert resolved == dm_root.resolve()


def test_reject_absolute_path(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    with pytest.raises(PathSafetyError):
        resolve_dm_path(dm_root, "/etc/passwd")


def test_reject_dotdot_escape(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    with pytest.raises(PathSafetyError):
        resolve_dm_path(dm_root, "../outside.md")


def test_reject_symlink_to_outside(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    outside = tmp_path / "outside.md"
    outside.write_text("secret", encoding="utf-8")
    link = dm_root / "link.md"
    link.symlink_to(outside)

    with pytest.raises(PathSafetyError):
        resolve_dm_path(dm_root, "link.md")


def test_resolve_normalizes_redundant_slashes(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    (dm_root / "npcs").mkdir()
    target = dm_root / "npcs" / "x.md"
    target.write_text("hello", encoding="utf-8")
    resolved = resolve_dm_path(dm_root, "npcs//x.md")
    assert resolved == target.resolve()
