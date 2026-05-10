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


def write_dm_file(dm_root: Path, relative_path: str, content: str) -> None:
    """Write a UTF-8 file inside dm/, overwriting any existing content.

    Creates parent directories as needed. Raises IsADirectoryError if the
    path is an existing directory, or PathSafetyError on escape attempt.
    """
    target = resolve_dm_path(dm_root, relative_path)
    if target.exists() and target.is_dir():
        raise IsADirectoryError(f"{relative_path} is a directory")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")


def append_dm_file(dm_root: Path, relative_path: str, content: str) -> None:
    """Append UTF-8 content to an existing file inside dm/.

    Raises FileNotFoundError if the file does not exist, IsADirectoryError
    if the path is a directory, or PathSafetyError on escape attempt.
    """
    target = resolve_dm_path(dm_root, relative_path)
    if not target.exists():
        raise FileNotFoundError(f"dm file not found: {relative_path}")
    if target.is_dir():
        raise IsADirectoryError(f"{relative_path} is a directory")
    with target.open("a", encoding="utf-8") as f:
        f.write(content)


def create_dm_file(dm_root: Path, relative_path: str, content: str) -> None:
    """Create a new UTF-8 file inside dm/. Errors if the file exists.

    Creates parent directories as needed. Raises FileExistsError if the
    target already exists, or PathSafetyError on escape attempt.
    """
    target = resolve_dm_path(dm_root, relative_path)
    if target.exists():
        raise FileExistsError(f"dm file already exists: {relative_path}")
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content, encoding="utf-8")
