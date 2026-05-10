"""Tests that the MCP server registers expected tools."""

from pathlib import Path

import pytest

from dm_fs.server import build_server


def test_server_builds(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    server = build_server(dm_root)
    assert server is not None


def test_server_registers_read_and_list_tools(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    server = build_server(dm_root)
    # Inspect the registered tools list. The exact accessor depends on the
    # MCP SDK version; this test asserts that the tool names appear.
    tool_names = _list_tool_names(server)
    assert "read_dm_file" in tool_names
    assert "list_dm_dir" in tool_names


def _list_tool_names(server) -> list[str]:
    """Best-effort tool-name extraction. Adapt as needed for current SDK."""
    if hasattr(server, "_tools"):
        return list(server._tools.keys())
    if hasattr(server, "_tool_manager"):
        # Newer FastMCP versions
        tm = server._tool_manager
        if hasattr(tm, "_tools"):
            return list(tm._tools.keys())
        if hasattr(tm, "list_tools"):
            return [t.name for t in tm.list_tools()]
    if hasattr(server, "tools"):
        try:
            return list(server.tools.keys())
        except Exception:
            return [t.name for t in server.tools]
    raise RuntimeError(
        "Could not introspect server tools — adapt _list_tool_names "
        "for your installed MCP SDK version."
    )
