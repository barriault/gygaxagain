"""Tests for mythic CLI."""

import json
import subprocess
import sys
from pathlib import Path


def _run_cli(*args: str) -> tuple[int, str, str]:
    result = subprocess.run(
        [sys.executable, "-m", "mythic.cli", *args],
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout, result.stderr


def test_cli_oracle_default_likelihood():
    rc, out, err = _run_cli("oracle", "--likelihood", "50_50", "--cf", "5")
    assert rc == 0, err
    payload = json.loads(out)
    assert payload["outcome"] in ("yes", "no", "exceptional_yes", "exceptional_no")
    assert "random_event" in payload  # may be None or an event dict


def test_cli_event_returns_event():
    rc, out, err = _run_cli("event")
    assert rc == 0, err
    payload = json.loads(out)
    assert "focus" in payload and "action" in payload and "subject" in payload


def test_cli_chaos_read(tmp_path: Path):
    chaos_file = tmp_path / "chaos.md"
    chaos_file.write_text("# Chaos factor\n\n5\n", encoding="utf-8")
    rc, out, err = _run_cli("chaos", "--file", str(chaos_file), "--read")
    assert rc == 0, err
    payload = json.loads(out)
    assert payload["chaos_factor"] == 5


def test_cli_chaos_adjust(tmp_path: Path):
    chaos_file = tmp_path / "chaos.md"
    chaos_file.write_text("# Chaos factor\n\n5\n", encoding="utf-8")
    rc, out, err = _run_cli(
        "chaos", "--file", str(chaos_file), "--adjust", "+1"
    )
    assert rc == 0, err
    payload = json.loads(out)
    assert payload["chaos_factor"] == 6


def test_cli_unknown_command_returns_nonzero():
    rc, out, err = _run_cli("does-not-exist")
    assert rc != 0
