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
