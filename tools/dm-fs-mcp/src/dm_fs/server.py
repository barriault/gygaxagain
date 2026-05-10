"""dm-fs MCP server — exposes read/list/write/append/create of dm/ over stdio.

Designed for use by the world-state subagent only (wired via .mcp.json
and the subagent's mcpServers frontmatter). Every call is recorded to
an access log outside dm/.
"""

from __future__ import annotations

import os
from pathlib import Path

from mcp.server.fastmcp import FastMCP  # type: ignore[import-untyped]

from dm_fs.audit import record as audit_record
from dm_fs.ops import append_dm_file as _append_dm_file
from dm_fs.ops import create_dm_file as _create_dm_file
from dm_fs.ops import list_dm_dir as _list_dm_dir
from dm_fs.ops import read_dm_file as _read_dm_file
from dm_fs.ops import write_dm_file as _write_dm_file


def build_server(dm_root: Path, *, audit_log: Path | None = None) -> FastMCP:
    """Build an MCP server bound to a specific dm/ root.

    Tools:
        read_dm_file(relative_path: str) -> str
        list_dm_dir(relative_path: str = "") -> list[str]
        write_dm_file(relative_path: str, content: str) -> None
        append_dm_file(relative_path: str, content: str) -> None
        create_dm_file(relative_path: str, content: str) -> None

    All paths are validated by dm_fs.safety.resolve_dm_path. Every call
    is recorded to audit_log (if provided) via dm_fs.audit.record.
    """
    server = FastMCP("dm-fs")

    def _audit(tool: str, relative_path: str, summary: str) -> None:
        if audit_log is not None:
            audit_record(audit_log, tool=tool, relative_path=relative_path, summary=summary)

    @server.tool()
    def read_dm_file(relative_path: str) -> str:
        """Read a markdown file inside dm/ and return its contents as text."""
        content = _read_dm_file(dm_root, relative_path)
        _audit("read_dm_file", relative_path, f"{len(content)} bytes")
        return content

    @server.tool()
    def list_dm_dir(relative_path: str = "") -> list[str]:
        """List entries inside a dm/ subdirectory (or the dm/ root)."""
        entries = _list_dm_dir(dm_root, relative_path)
        _audit("list_dm_dir", relative_path, f"{len(entries)} entries")
        return entries

    @server.tool()
    def write_dm_file(relative_path: str, content: str) -> None:
        """Write a UTF-8 file inside dm/, overwriting any existing content."""
        _write_dm_file(dm_root, relative_path, content)
        first_line = content.split("\n", 1)[0][:80]
        _audit("write_dm_file", relative_path, f"{len(content)} bytes; first: {first_line!r}")

    @server.tool()
    def append_dm_file(relative_path: str, content: str) -> None:
        """Append UTF-8 content to an existing file inside dm/."""
        _append_dm_file(dm_root, relative_path, content)
        first_line = content.split("\n", 1)[0][:80]
        _audit("append_dm_file", relative_path, f"appended {len(content)} bytes; first: {first_line!r}")

    @server.tool()
    def create_dm_file(relative_path: str, content: str) -> None:
        """Create a new UTF-8 file inside dm/. Errors if the file exists."""
        _create_dm_file(dm_root, relative_path, content)
        first_line = content.split("\n", 1)[0][:80]
        _audit("create_dm_file", relative_path, f"{len(content)} bytes; first: {first_line!r}")

    return server


def main() -> None:
    """CLI entry point. Reads dm/ root from DM_ROOT env or defaults to ./dm.

    Audit log path comes from DM_FS_AUDIT_LOG env var, defaulting to
    <package-dir>/../../access.log (i.e., tools/dm-fs-mcp/access.log).
    """
    dm_root = Path(os.environ.get("DM_ROOT", "dm")).resolve()
    if not dm_root.exists():
        raise SystemExit(f"DM_ROOT does not exist: {dm_root}")

    audit_log_default = Path(__file__).resolve().parent.parent.parent / "access.log"
    audit_log = Path(os.environ.get("DM_FS_AUDIT_LOG", str(audit_log_default)))

    server = build_server(dm_root, audit_log=audit_log)
    server.run()


if __name__ == "__main__":
    main()
