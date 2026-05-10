"""dm-fs access-log audit primitive.

Records every read/write call to a log file outside dm/. The log path
defaults to tools/dm-fs-mcp/access.log (overridable via DM_FS_AUDIT_LOG).

The log records timestamp, tool, path, and a short summary — never full
file content. Used by the Phase 2a asymmetry audit to verify which agent
accessed dm/ during a session.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path


def record(
    log_path: Path,
    *,
    tool: str,
    relative_path: str,
    summary: str,
) -> None:
    """Append one line to the access log."""
    log_path.parent.mkdir(parents=True, exist_ok=True)
    timestamp = datetime.now(timezone.utc).isoformat(timespec="seconds")
    line = f"{timestamp}\t{tool}\t{relative_path}\t{summary}\n"
    with log_path.open("a", encoding="utf-8") as f:
        f.write(line)
