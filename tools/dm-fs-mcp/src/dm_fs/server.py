"""dm-fs MCP server — exposes read/list of dm/ over stdio.

Designed for use by the world-state subagent only (wired via .mcp.json
and the subagent's mcpServers frontmatter).
"""

from __future__ import annotations

import os
from pathlib import Path

from mcp.server.fastmcp import FastMCP  # type: ignore[import-untyped]

from dm_fs.ops import list_dm_dir as _list_dm_dir
from dm_fs.ops import read_dm_file as _read_dm_file


def build_server(dm_root: Path) -> FastMCP:
    """Build an MCP server bound to a specific dm/ root.

    Tools:
        read_dm_file(relative_path: str) -> str
        list_dm_dir(relative_path: str = "") -> list[str]

    All paths are validated by dm_fs.safety.resolve_dm_path.
    """
    server = FastMCP("dm-fs")

    @server.tool()
    def read_dm_file(relative_path: str) -> str:
        """Read a markdown file inside dm/ and return its contents as text."""
        return _read_dm_file(dm_root, relative_path)

    @server.tool()
    def list_dm_dir(relative_path: str = "") -> list[str]:
        """List entries inside a dm/ subdirectory (or the dm/ root)."""
        return _list_dm_dir(dm_root, relative_path)

    return server


def main() -> None:
    """CLI entry point. Reads dm/ root from DM_ROOT env or defaults to ./dm."""
    dm_root = Path(os.environ.get("DM_ROOT", "dm")).resolve()
    if not dm_root.exists():
        raise SystemExit(f"DM_ROOT does not exist: {dm_root}")
    server = build_server(dm_root)
    server.run()


if __name__ == "__main__":
    main()
