"""File operations exposed through the dm-fs MCP server."""

from __future__ import annotations

from pathlib import Path

from dm_fs.safety import resolve_dm_path


def read_dm_file(dm_root: Path, relative_path: str) -> str:
    """Read a file inside dm/ as UTF-8. Raises FileNotFoundError or
    IsADirectoryError or PathSafetyError on failure.
    """
    target = resolve_dm_path(dm_root, relative_path)
    if not target.exists():
        raise FileNotFoundError(f"dm file not found: {relative_path}")
    if target.is_dir():
        raise IsADirectoryError(f"{relative_path} is a directory")
    return target.read_text(encoding="utf-8")


def list_dm_dir(dm_root: Path, relative_path: str) -> list[str]:
    """List entries (filenames and dirnames, no leading path) inside dm/.

    Raises FileNotFoundError if path does not exist, NotADirectoryError if
    path is a file, or PathSafetyError on escape attempt.
    """
    target = resolve_dm_path(dm_root, relative_path)
    if not target.exists():
        raise FileNotFoundError(f"dm path not found: {relative_path}")
    if not target.is_dir():
        raise NotADirectoryError(f"{relative_path} is not a directory")
    return [entry.name for entry in target.iterdir()]
