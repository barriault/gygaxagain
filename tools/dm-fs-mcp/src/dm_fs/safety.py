"""Path safety for dm-fs.

Every path passed to MCP tools is resolved through resolve_dm_path, which
guarantees the result is inside the dm/ root. Absolute paths, .. escapes,
and symlinks to outside dm/ are rejected.
"""

from __future__ import annotations

from pathlib import Path


class PathSafetyError(Exception):
    """Raised when a requested path would escape dm/."""


def resolve_dm_path(dm_root: Path, relative_path: str) -> Path:
    """Resolve a relative path inside dm_root, rejecting any escape attempt.

    Returns the absolute, fully-resolved Path.
    Raises PathSafetyError if relative_path is absolute, contains .. that
    escapes the root, or resolves to a symlink target outside the root.
    """
    dm_root_resolved = dm_root.resolve(strict=False)

    if relative_path == "":
        return dm_root_resolved

    p = Path(relative_path)
    if p.is_absolute():
        raise PathSafetyError(
            f"absolute paths not permitted: {relative_path!r}"
        )

    candidate = (dm_root_resolved / p).resolve(strict=False)

    try:
        candidate.relative_to(dm_root_resolved)
    except ValueError as exc:
        raise PathSafetyError(
            f"path escapes dm/ root: {relative_path!r}"
        ) from exc

    return candidate
