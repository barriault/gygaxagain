"""Tests for dm-fs file operations (read, list)."""

from pathlib import Path

import pytest

from dm_fs.ops import read_dm_file
from dm_fs.safety import PathSafetyError


def test_read_existing_file(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    target = dm / "npcs" / "merchant.md"
    target.write_text("# Merchant\n\nHidden agenda: cult.\n", encoding="utf-8")

    content = read_dm_file(dm, "npcs/merchant.md")
    assert "Hidden agenda" in content


def test_read_missing_file_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(FileNotFoundError):
        read_dm_file(dm, "npcs/missing.md")


def test_read_unsafe_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(PathSafetyError):
        read_dm_file(dm, "../escape.md")


def test_read_directory_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    with pytest.raises(IsADirectoryError):
        read_dm_file(dm, "npcs")
