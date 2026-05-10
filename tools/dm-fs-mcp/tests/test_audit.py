"""Tests for dm-fs access-log audit primitive."""

from pathlib import Path

from dm_fs.audit import record


def test_record_creates_log_file(tmp_path: Path):
    log_path = tmp_path / "access.log"
    record(log_path, tool="read_dm_file", relative_path="npcs/x.md", summary="42 bytes")
    assert log_path.exists()
    line = log_path.read_text(encoding="utf-8").strip()
    assert "read_dm_file" in line
    assert "npcs/x.md" in line
    assert "42 bytes" in line


def test_record_appends_to_existing_log(tmp_path: Path):
    log_path = tmp_path / "access.log"
    record(log_path, tool="read_dm_file", relative_path="a.md", summary="s1")
    record(log_path, tool="write_dm_file", relative_path="b.md", summary="s2")
    lines = log_path.read_text(encoding="utf-8").strip().split("\n")
    assert len(lines) == 2
    assert "a.md" in lines[0]
    assert "b.md" in lines[1]


def test_record_includes_iso_timestamp(tmp_path: Path):
    log_path = tmp_path / "access.log"
    record(log_path, tool="read_dm_file", relative_path="x.md", summary="")
    line = log_path.read_text(encoding="utf-8").strip()
    # ISO 8601 timestamp prefix, e.g. 2026-05-10T...
    assert line.startswith("2"), f"line should start with year digit, got: {line!r}"
    assert "T" in line.split()[0]


def test_record_creates_parent_directory(tmp_path: Path):
    log_path = tmp_path / "nested" / "dir" / "access.log"
    record(log_path, tool="read_dm_file", relative_path="x.md", summary="")
    assert log_path.exists()
