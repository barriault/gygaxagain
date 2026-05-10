"""Tests for dm-fs file operations (read, list)."""

from pathlib import Path

import pytest

from dm_fs.ops import read_dm_file, list_dm_dir
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


def test_list_empty_root(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    assert list_dm_dir(dm, "") == []


def test_list_returns_relative_entries(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    (dm / "npcs" / "alpha.md").write_text("a", encoding="utf-8")
    (dm / "npcs" / "beta.md").write_text("b", encoding="utf-8")

    entries = sorted(list_dm_dir(dm, "npcs"))
    assert entries == ["alpha.md", "beta.md"]


def test_list_root_lists_subdirs(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    (dm / "factions").mkdir()
    entries = sorted(list_dm_dir(dm, ""))
    assert entries == ["factions", "npcs"]


def test_list_missing_dir_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(FileNotFoundError):
        list_dm_dir(dm, "missing")


def test_list_file_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    f = dm / "npcs.md"
    f.write_text("hi", encoding="utf-8")
    with pytest.raises(NotADirectoryError):
        list_dm_dir(dm, "npcs.md")


def test_list_unsafe_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(PathSafetyError):
        list_dm_dir(dm, "../escape")


def test_write_creates_file(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "factions").mkdir()
    from dm_fs.ops import write_dm_file
    write_dm_file(dm, "factions/cult.md", "# Cult\n\nclock: 1/6\n")
    assert (dm / "factions" / "cult.md").read_text(encoding="utf-8") == "# Cult\n\nclock: 1/6\n"


def test_write_overwrites_existing(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "factions").mkdir()
    target = dm / "factions" / "cult.md"
    target.write_text("old", encoding="utf-8")
    from dm_fs.ops import write_dm_file
    write_dm_file(dm, "factions/cult.md", "new")
    assert target.read_text(encoding="utf-8") == "new"


def test_write_unsafe_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    from dm_fs.ops import write_dm_file
    with pytest.raises(PathSafetyError):
        write_dm_file(dm, "../escape.md", "content")


def test_write_to_directory_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "factions").mkdir()
    from dm_fs.ops import write_dm_file
    with pytest.raises(IsADirectoryError):
        write_dm_file(dm, "factions", "content")


def test_write_creates_parent_directories(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    from dm_fs.ops import write_dm_file
    write_dm_file(dm, "factions/new/sub/cult.md", "content")
    assert (dm / "factions" / "new" / "sub" / "cult.md").read_text(encoding="utf-8") == "content"


def test_append_to_existing_file(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "factions").mkdir()
    target = dm / "factions" / "cult.md"
    target.write_text("# Cult\n\n## History\n", encoding="utf-8")
    from dm_fs.ops import append_dm_file
    append_dm_file(dm, "factions/cult.md", "- session 002: clock 0 → 1\n")
    assert target.read_text(encoding="utf-8") == "# Cult\n\n## History\n- session 002: clock 0 → 1\n"


def test_append_missing_file_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    from dm_fs.ops import append_dm_file
    with pytest.raises(FileNotFoundError):
        append_dm_file(dm, "factions/missing.md", "content")


def test_append_to_directory_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "factions").mkdir()
    from dm_fs.ops import append_dm_file
    with pytest.raises(IsADirectoryError):
        append_dm_file(dm, "factions", "content")


def test_append_unsafe_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    from dm_fs.ops import append_dm_file
    with pytest.raises(PathSafetyError):
        append_dm_file(dm, "../escape.md", "content")


def test_create_new_file(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "factions").mkdir()
    from dm_fs.ops import create_dm_file
    create_dm_file(dm, "factions/new-cult.md", "# New Cult\n")
    assert (dm / "factions" / "new-cult.md").read_text(encoding="utf-8") == "# New Cult\n"


def test_create_existing_file_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "factions").mkdir()
    target = dm / "factions" / "cult.md"
    target.write_text("existing", encoding="utf-8")
    from dm_fs.ops import create_dm_file
    with pytest.raises(FileExistsError):
        create_dm_file(dm, "factions/cult.md", "new")
    assert target.read_text(encoding="utf-8") == "existing"  # unchanged


def test_create_unsafe_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    from dm_fs.ops import create_dm_file
    with pytest.raises(PathSafetyError):
        create_dm_file(dm, "../escape.md", "content")


def test_create_creates_parent_directories(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    from dm_fs.ops import create_dm_file
    create_dm_file(dm, "factions/new/sub/cult.md", "content")
    assert (dm / "factions" / "new" / "sub" / "cult.md").read_text(encoding="utf-8") == "content"
