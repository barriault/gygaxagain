"""Tests for dice CLI invocation and JSON output."""

import json
import subprocess
import sys


def _run_cli(*args: str) -> tuple[int, str, str]:
    """Run the dice CLI as a subprocess. Returns (returncode, stdout, stderr)."""
    result = subprocess.run(
        [sys.executable, "-m", "dice.cli", *args],
        capture_output=True,
        text=True,
    )
    return result.returncode, result.stdout, result.stderr


def test_cli_roll_constant_outputs_json():
    rc, out, err = _run_cli("roll", "5")
    assert rc == 0, err
    payload = json.loads(out)
    assert payload["total"] == 5
    assert payload["expression"] == "5"


def test_cli_roll_d1_total_predictable():
    rc, out, err = _run_cli("roll", "3d1+2")
    assert rc == 0, err
    payload = json.loads(out)
    assert payload["total"] == 5


def test_cli_roll_d20_in_range():
    rc, out, err = _run_cli("roll", "1d20")
    assert rc == 0, err
    payload = json.loads(out)
    assert 1 <= payload["total"] <= 20


def test_cli_roll_invalid_expression_returns_nonzero():
    rc, out, err = _run_cli("roll", "not-a-roll")
    assert rc != 0
    assert "error" in (out + err).lower() or err.strip() != ""


def test_cli_no_subcommand_returns_nonzero():
    rc, out, err = _run_cli()
    assert rc != 0
