# Phase 1 MVP Session Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a Claude Code project that can run a smoke-test play session exercising the spec's information-asymmetry pattern at minimum scale — narrator main agent + Haiku dice/mythic subagents wrapping Python scripts + Sonnet world-state subagent as the sole consumer of a custom `dm-fs` MCP server.

**Architecture:** Three Python packages (`dice`, `mythic`, `dm-fs-mcp`) under `tools/`, three Claude Code subagents under `.claude/agents/`, four slash commands under `.claude/commands/`, project-wide `dm/**` deny rules in `.claude/settings.json`, and a custom MCP server registered via `.mcp.json` that only the world-state subagent has access to. Markdown files are the source of truth for all campaign state.

**Tech Stack:** Python 3.14 (stdlib only for `dice` and `mythic`; official `mcp` Python SDK for `dm-fs-mcp`); pytest for unit tests; Claude Code subagents and slash commands; markdown for all content and configuration; git for state audit trail.

---

## Conventions used in this plan

- **Project root:** `/Users/barriault/dnd/gygaxagain`. All paths in this plan are relative to this root unless absolute.
- **Python venv:** A single project-level virtual environment at `.venv/` is used for all three Python packages and pytest. Activate with `source .venv/bin/activate` before running test or CLI commands. Package installs are editable (`pip install -e .`).
- **Commit cadence:** every task ends with one commit. Tests, source, and any related config changes go in the same commit.
- **TDD discipline:** Python work follows red-green-refactor. Write the failing test first, run it to confirm failure, write minimal code to pass, run to confirm pass, then commit. Each "Step" in a task is one atomic action.
- **Markdown content (subagents, commands, configs):** no traditional unit tests, but a manual verification step is included where practical (e.g., "open the file in `cat` and confirm frontmatter parses").
- **Smoke test:** the final task is the integrated end-to-end smoke test against the test content. It is the empirical Definition of Done for Phase 1.

---

## Task 1: Bootstrap project venv and repo skeleton

**Files:**
- Create: `.venv/` (Python virtual environment, gitignored)
- Modify: `.gitignore` (add `.venv/` and Python artifacts)
- Create: `party/companions/.gitkeep`, `party/npcs/.gitkeep`, `world/regions/.gitkeep`, `sessions/play/.gitkeep`, `dm/npcs/.gitkeep`, `tools/.gitkeep`
- Create: `meta/campaign-config.md` (placeholder header only — filled in Task 15)
- Create: `meta/dice-config.md` (placeholder header only — filled in Task 15)
- Create: `meta/chaos-factor.md` (placeholder header only — filled in Task 15)

- [ ] **Step 1: Create the venv and ensure pip is current**

```bash
cd /Users/barriault/dnd/gygaxagain
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
python -m pip install pytest
```

Expected: `pip --version` reports a recent pip; `pytest --version` reports a version (recent pytest, 8.x or later).

- [ ] **Step 2: Update .gitignore**

Append to `.gitignore`:

```
# Python
.venv/
__pycache__/
*.pyc
*.pyo
*.egg-info/
build/
dist/
.pytest_cache/
```

- [ ] **Step 3: Create the directory skeleton with .gitkeep markers**

```bash
mkdir -p party/companions party/npcs world/home-base/npcs world/regions sessions/play dm/npcs tools meta
touch party/companions/.gitkeep party/npcs/.gitkeep world/regions/.gitkeep sessions/play/.gitkeep dm/npcs/.gitkeep tools/.gitkeep
```

- [ ] **Step 4: Create stub meta/ files (filled in Task 15)**

`meta/campaign-config.md`:
```markdown
# Campaign config

(Phase 1: filled in by Task 15.)
```

`meta/dice-config.md`:
```markdown
# Dice config

(Phase 1: filled in by Task 15.)
```

`meta/chaos-factor.md`:
```markdown
# Chaos factor

5
```

(The chaos-factor file is consumed by the mythic subagent and must be a parseable single-integer file. We start at the Mythic 2e default of 5.)

- [ ] **Step 5: Verify and commit**

```bash
git status
git add .gitignore party/ world/ sessions/ dm/ tools/.gitkeep meta/
git commit -m "Bootstrap repo skeleton and project venv conventions

Adds the directory tree Phase 1 will populate, .gitkeep markers for
empty directories, stub meta/ files, and Python venv/build artifacts
to .gitignore."
```

Expected: `git status` clean afterward; `ls dm/npcs` shows `.gitkeep`.

---

## Task 2: Dice tool — package bootstrap

**Files:**
- Create: `tools/dice/pyproject.toml`
- Create: `tools/dice/src/dice/__init__.py`
- Create: `tools/dice/tests/__init__.py`
- Create: `tools/dice/tests/test_smoke.py`

- [ ] **Step 1: Write the failing smoke test**

`tools/dice/tests/test_smoke.py`:
```python
"""Smoke test that the dice package imports."""

def test_dice_imports():
    import dice
    assert dice is not None
```

- [ ] **Step 2: Run test to verify it fails**

```bash
cd /Users/barriault/dnd/gygaxagain
source .venv/bin/activate
pytest tools/dice/tests/test_smoke.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'dice'`.

- [ ] **Step 3: Create the package structure**

`tools/dice/pyproject.toml`:
```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "dice"
version = "0.1.0"
description = "Dice expression parser and CSPRNG roller for the solo campaign engine"
requires-python = ">=3.11"
dependencies = []

[project.scripts]
dice = "dice.cli:main"

[tool.setuptools.packages.find]
where = ["src"]
```

`tools/dice/src/dice/__init__.py`:
```python
"""Dice parser and roller."""
__version__ = "0.1.0"
```

`tools/dice/tests/__init__.py`:
```python
```

(empty file to mark tests as a package)

- [ ] **Step 4: Install editable and rerun the test**

```bash
cd /Users/barriault/dnd/gygaxagain
source .venv/bin/activate
pip install -e tools/dice
pytest tools/dice/tests/test_smoke.py -v
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/dice/
git commit -m "Bootstrap dice package with smoke test

Editable install of tools/dice. Package importable and pyproject.toml
declares the dice CLI entry point that later tasks will populate."
```

---

## Task 3: Dice tool — simple expression parsing and rolling

**Files:**
- Create: `tools/dice/src/dice/parser.py`
- Create: `tools/dice/tests/test_parser.py`

This task implements the basic dice grammar: integer constants, single dice terms (`1d20`, `2d6`), modifier arithmetic (`1d20+5`, `2d6-1`), and multi-term sums (`1d8+1d6+5`).

- [ ] **Step 1: Write failing tests for parsing into structured form**

`tools/dice/tests/test_parser.py`:
```python
"""Tests for dice expression parsing (no rolling yet)."""

import pytest

from dice.parser import parse_expression, Term, DiceTerm, ConstantTerm


def test_parse_constant():
    terms = parse_expression("5")
    assert terms == [ConstantTerm(value=5, sign=1)]


def test_parse_simple_die():
    terms = parse_expression("1d20")
    assert terms == [DiceTerm(count=1, sides=20, sign=1, keep=None)]


def test_parse_die_with_modifier():
    terms = parse_expression("1d20+5")
    assert terms == [
        DiceTerm(count=1, sides=20, sign=1, keep=None),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_die_with_negative_modifier():
    terms = parse_expression("1d4-1")
    assert terms == [
        DiceTerm(count=1, sides=4, sign=1, keep=None),
        ConstantTerm(value=1, sign=-1),
    ]


def test_parse_multiple_dice_terms():
    terms = parse_expression("1d8+1d6+5")
    assert terms == [
        DiceTerm(count=1, sides=8, sign=1, keep=None),
        DiceTerm(count=1, sides=6, sign=1, keep=None),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_multiplied_dice():
    terms = parse_expression("2d6")
    assert terms == [DiceTerm(count=2, sides=6, sign=1, keep=None)]


def test_parse_whitespace_tolerated():
    terms = parse_expression("1d20 + 5")
    assert terms == [
        DiceTerm(count=1, sides=20, sign=1, keep=None),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_empty_raises():
    with pytest.raises(ValueError):
        parse_expression("")


def test_parse_garbage_raises():
    with pytest.raises(ValueError):
        parse_expression("not-a-roll")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tools/dice/tests/test_parser.py -v
```

Expected: FAIL — `cannot import name 'parse_expression' from 'dice.parser'`.

- [ ] **Step 3: Implement parser**

`tools/dice/src/dice/parser.py`:
```python
"""Dice expression parser.

Grammar (Phase 1):
    expression := term ( ('+' | '-') term )*
    term       := dice | constant
    dice       := <count>d<sides>[k(h|l)<n>]
    constant   := <integer>
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Literal, Optional, Union


@dataclass(frozen=True)
class DiceTerm:
    count: int
    sides: int
    sign: int  # +1 or -1
    keep: Optional[tuple[Literal["h", "l"], int]]


@dataclass(frozen=True)
class ConstantTerm:
    value: int
    sign: int  # +1 or -1


Term = Union[DiceTerm, ConstantTerm]


# Captures a signed term: optional leading +/-, then a dice or constant body.
_TERM_RE = re.compile(
    r"""
    \s*
    (?P<sign>[+-])?\s*
    (?:
        (?P<count>\d+)d(?P<sides>\d+)
        (?:k(?P<keep>[hl])(?P<keep_n>\d+))?
        |
        (?P<const>\d+)
    )
    """,
    re.VERBOSE,
)


def parse_expression(expression: str) -> list[Term]:
    """Parse a dice expression into a list of signed Terms.

    Raises ValueError on empty or unparseable input.
    """
    if not expression or not expression.strip():
        raise ValueError("empty dice expression")

    pos = 0
    terms: list[Term] = []
    first = True
    s = expression.strip()

    while pos < len(s):
        m = _TERM_RE.match(s, pos)
        if m is None or m.end() == pos:
            raise ValueError(f"unparseable at position {pos}: {s[pos:]!r}")

        sign_str = m.group("sign")
        if first and sign_str is None:
            sign = 1
        elif sign_str is None:
            # No sign between terms is invalid (e.g., "1d6 1d8")
            raise ValueError(f"missing operator at position {pos}: {s[pos:]!r}")
        else:
            sign = 1 if sign_str == "+" else -1

        if m.group("const") is not None:
            terms.append(ConstantTerm(value=int(m.group("const")), sign=sign))
        else:
            count = int(m.group("count"))
            sides = int(m.group("sides"))
            keep = None
            if m.group("keep") is not None:
                keep = (m.group("keep"), int(m.group("keep_n")))
            terms.append(
                DiceTerm(count=count, sides=sides, sign=sign, keep=keep)
            )

        pos = m.end()
        first = False
        # Skip whitespace before the next operator
        while pos < len(s) and s[pos].isspace():
            pos += 1

    if not terms:
        raise ValueError(f"no terms parsed from {expression!r}")
    return terms
```

- [ ] **Step 4: Run tests to verify pass**

```bash
pytest tools/dice/tests/test_parser.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Add roll() function with tests**

Append to `tools/dice/tests/test_parser.py`:
```python
from dice.parser import roll


def test_roll_constant_only():
    result = roll("5")
    assert result["total"] == 5
    assert result["expression"] == "5"


def test_roll_d1_is_deterministic():
    # d1 always rolls 1, so the result is fully determined.
    result = roll("3d1+2")
    assert result["total"] == 5
    assert result["terms"][0]["rolls"] == [1, 1, 1]
    assert result["terms"][0]["value"] == 3
    assert result["terms"][1]["value"] == 2


def test_roll_returns_per_term_breakdown():
    result = roll("1d1+1d1")
    assert len(result["terms"]) == 2
    assert all(t["type"] == "dice" for t in result["terms"])
    assert result["total"] == 2


def test_roll_negative_term_subtracts():
    result = roll("3d1-1")
    assert result["total"] == 2


def test_roll_d20_within_range():
    for _ in range(50):
        result = roll("1d20+5")
        die_value = result["terms"][0]["value"]
        assert 1 <= die_value <= 20
        assert result["total"] == die_value + 5
```

Append to `tools/dice/src/dice/parser.py`:
```python
import secrets


def _roll_die(sides: int) -> int:
    return secrets.randbelow(sides) + 1


def roll(expression: str) -> dict:
    """Roll a parsed dice expression. Returns a structured result."""
    terms = parse_expression(expression)
    out_terms: list[dict] = []
    total = 0

    for term in terms:
        if isinstance(term, ConstantTerm):
            value = term.sign * term.value
            total += value
            out_terms.append(
                {
                    "type": "constant",
                    "value": value,
                    "sign": term.sign,
                }
            )
        else:
            rolls = [_roll_die(term.sides) for _ in range(term.count)]
            kept, dropped = _apply_keep(rolls, term.keep)
            term_value = term.sign * sum(kept)
            total += term_value
            out_terms.append(
                {
                    "type": "dice",
                    "expr": _format_dice_term(term),
                    "rolls": rolls,
                    "kept": kept,
                    "dropped": dropped,
                    "value": term_value,
                    "sign": term.sign,
                }
            )

    return {
        "expression": expression,
        "terms": out_terms,
        "total": total,
    }


def _apply_keep(
    rolls: list[int], keep: Optional[tuple[Literal["h", "l"], int]]
) -> tuple[list[int], list[int]]:
    """Return (kept, dropped) lists. If keep is None, all rolls kept."""
    if keep is None:
        return list(rolls), []
    direction, n = keep
    if n >= len(rolls):
        return list(rolls), []
    sorted_indexed = sorted(enumerate(rolls), key=lambda p: p[1])
    if direction == "h":
        kept_indices = {i for i, _ in sorted_indexed[-n:]}
    else:
        kept_indices = {i for i, _ in sorted_indexed[:n]}
    kept = [r for i, r in enumerate(rolls) if i in kept_indices]
    dropped = [r for i, r in enumerate(rolls) if i not in kept_indices]
    return kept, dropped


def _format_dice_term(term: DiceTerm) -> str:
    base = f"{term.count}d{term.sides}"
    if term.keep is not None:
        direction, n = term.keep
        base += f"k{direction}{n}"
    return base
```

- [ ] **Step 6: Run all parser tests to verify pass**

```bash
pytest tools/dice/tests/test_parser.py -v
```

Expected: all tests PASS (parsing + rolling).

- [ ] **Step 7: Commit**

```bash
git add tools/dice/src/dice/parser.py tools/dice/tests/test_parser.py
git commit -m "Implement dice parser and roller for simple expressions

Supports integer constants, dice terms (NdS), and signed addition.
Roller uses secrets.randbelow for CSPRNG. Returns per-term breakdown
with kept/dropped rolls (foundation for keep-highest/lowest in next
task)."
```

---

## Task 4: Dice tool — keep highest / lowest (advantage / disadvantage)

**Files:**
- Modify: `tools/dice/tests/test_parser.py` (add tests for `kh`/`kl`)
- (Implementation already in `parser.py` from Task 3, but tested here.)

- [ ] **Step 1: Write failing tests for keep semantics**

Append to `tools/dice/tests/test_parser.py`:
```python
def test_parse_keep_highest():
    terms = parse_expression("4d6kh3")
    assert terms == [DiceTerm(count=4, sides=6, sign=1, keep=("h", 3))]


def test_parse_advantage_syntax():
    terms = parse_expression("2d20kh1+5")
    assert terms == [
        DiceTerm(count=2, sides=20, sign=1, keep=("h", 1)),
        ConstantTerm(value=5, sign=1),
    ]


def test_parse_disadvantage_syntax():
    terms = parse_expression("2d20kl1+5")
    assert terms == [
        DiceTerm(count=2, sides=20, sign=1, keep=("l", 1)),
        ConstantTerm(value=5, sign=1),
    ]


def test_roll_keep_highest_drops_lowest():
    # 4d1kh3 → all rolls are 1, but "kept" should be 3 of them, "dropped" 1.
    result = roll("4d1kh3")
    term = result["terms"][0]
    assert len(term["kept"]) == 3
    assert len(term["dropped"]) == 1
    assert term["value"] == 3


def test_roll_advantage_picks_higher_of_two_d20():
    # Repeatedly roll 2d20kh1 and verify the kept roll is always >= dropped.
    for _ in range(50):
        result = roll("2d20kh1")
        term = result["terms"][0]
        assert len(term["kept"]) == 1
        assert len(term["dropped"]) == 1
        assert term["kept"][0] >= term["dropped"][0]


def test_roll_disadvantage_picks_lower_of_two_d20():
    for _ in range(50):
        result = roll("2d20kl1")
        term = result["terms"][0]
        assert len(term["kept"]) == 1
        assert len(term["dropped"]) == 1
        assert term["kept"][0] <= term["dropped"][0]
```

- [ ] **Step 2: Run tests to verify pass**

```bash
pytest tools/dice/tests/test_parser.py -v
```

Expected: all tests PASS (Task 3's implementation already supports `keep`).

- [ ] **Step 3: Commit**

```bash
git add tools/dice/tests/test_parser.py
git commit -m "Test dice keep-highest/lowest (advantage/disadvantage)

Coverage for kh and kl modifiers. Implementation was already in place
from Task 3; this task is the test-driven validation that 4d6kh3 and
2d20kh1/2d20kl1 produce correct kept/dropped/value outputs."
```

---

## Task 5: Dice tool — CLI

**Files:**
- Create: `tools/dice/src/dice/cli.py`
- Create: `tools/dice/tests/test_cli.py`

- [ ] **Step 1: Write failing CLI tests**

`tools/dice/tests/test_cli.py`:
```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tools/dice/tests/test_cli.py -v
```

Expected: FAIL — `dice.cli` does not exist.

- [ ] **Step 3: Implement CLI**

`tools/dice/src/dice/cli.py`:
```python
"""Dice CLI: `python -m dice.cli roll '<expression>'` -> JSON to stdout."""

from __future__ import annotations

import argparse
import json
import sys

from dice.parser import roll


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="dice")
    sub = parser.add_subparsers(dest="command", required=True)

    roll_p = sub.add_parser("roll", help="Roll a dice expression")
    roll_p.add_argument("expression", help="Dice expression, e.g. '1d20+5'")

    args = parser.parse_args(argv)

    if args.command == "roll":
        try:
            result = roll(args.expression)
        except ValueError as exc:
            json.dump(
                {"error": str(exc), "expression": args.expression}, sys.stdout
            )
            sys.stdout.write("\n")
            return 2
        json.dump(result, sys.stdout)
        sys.stdout.write("\n")
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run tests to verify pass**

```bash
pytest tools/dice/tests/test_cli.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Run all dice tests to confirm full suite green**

```bash
pytest tools/dice/ -v
```

Expected: all dice tests pass.

- [ ] **Step 6: Commit**

```bash
git add tools/dice/src/dice/cli.py tools/dice/tests/test_cli.py
git commit -m "Add dice CLI with JSON output

python -m dice.cli roll '1d20+5' returns JSON to stdout. Returns
non-zero exit on invalid expressions with an error JSON payload."
```

---

## Task 6: Mythic tool — package bootstrap and Fate Chart data extraction

**Files:**
- Create: `tools/mythic/pyproject.toml`
- Create: `tools/mythic/src/mythic/__init__.py`
- Create: `tools/mythic/src/mythic/fate_chart.py` (with empty FATE_CHART)
- Create: `tools/mythic/tests/__init__.py`
- Create: `tools/mythic/tests/test_smoke.py`

- [ ] **Step 1: Read the Mythic 2e PDF Fate Chart pages**

```bash
# Skim the PDF to find the Fate Chart and exceptional thresholds.
# Use the Read tool on references/MythicGME2eV2.pdf with pages parameter.
# Locate: the Fate Chart table (likelihood × Chaos Factor → percentile thresholds)
# and the Random Event trigger rules.
```

The implementer should read pages of `references/MythicGME2eV2.pdf` until they find:
- The Fate Chart: a 9-column × 9-row table where rows are likelihoods (Impossible, Nearly Impossible, Very Unlikely, Unlikely, 50/50, Likely, Very Likely, Nearly Certain, Certain) and columns are Chaos Factors 1–9. Each cell has three numbers: the Exceptional No threshold, the standard No-vs-Yes threshold, and the Exceptional Yes threshold (Mythic 2e variant uses bands; encode whichever form the PDF presents).
- The Random Event trigger rule for Mythic 2e: in 2e, the trigger is when the d100 roll's tens and ones digits match (doubles) AND the tens digit is ≤ the current Chaos Factor.
- The Event Focus, Action, and Subject tables.

These values become the constants in `fate_chart.py` (Task 7) and the event tables in `events.py` (Task 9).

- [ ] **Step 2: Write the failing smoke test**

`tools/mythic/tests/test_smoke.py`:
```python
def test_mythic_imports():
    import mythic
    assert mythic is not None


def test_fate_chart_module_exists():
    from mythic import fate_chart
    assert hasattr(fate_chart, "FATE_CHART")
```

- [ ] **Step 3: Run test to verify it fails**

```bash
pytest tools/mythic/tests/test_smoke.py -v
```

Expected: FAIL — `ModuleNotFoundError: No module named 'mythic'`.

- [ ] **Step 4: Create the package**

`tools/mythic/pyproject.toml`:
```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "mythic"
version = "0.1.0"
description = "Mythic GME 2e procedures for the solo campaign engine"
requires-python = ">=3.11"
dependencies = []

[project.scripts]
mythic = "mythic.cli:main"

[tool.setuptools.packages.find]
where = ["src"]
```

`tools/mythic/src/mythic/__init__.py`:
```python
"""Mythic GME 2e procedures."""
__version__ = "0.1.0"
```

`tools/mythic/src/mythic/fate_chart.py`:
```python
"""Mythic 2e Fate Chart.

FATE_CHART maps (likelihood, chaos_factor) -> (exceptional_no_max, no_max,
yes_max, exceptional_yes_max). A d100 roll <= one of these thresholds
yields the corresponding outcome.

Concretely, given a roll r:
    r <= exceptional_no_max  -> Exceptional No
    r <= no_max              -> No
    r <= yes_max             -> Yes
    r <= exceptional_yes_max -> Exceptional Yes  (typically 100, so this
                                                   tier covers all remaining)

NOTE: This dictionary is populated in Task 7 from references/MythicGME2eV2.pdf.
Until then, FATE_CHART is empty and oracle() will raise.
"""

from __future__ import annotations

from typing import Literal

LIKELIHOODS = (
    "impossible",
    "nearly_impossible",
    "very_unlikely",
    "unlikely",
    "50_50",
    "likely",
    "very_likely",
    "nearly_certain",
    "certain",
)
Likelihood = Literal[
    "impossible",
    "nearly_impossible",
    "very_unlikely",
    "unlikely",
    "50_50",
    "likely",
    "very_likely",
    "nearly_certain",
    "certain",
]

# Populated in Task 7.
FATE_CHART: dict[tuple[Likelihood, int], tuple[int, int, int, int]] = {}
```

`tools/mythic/tests/__init__.py`:
```python
```

- [ ] **Step 5: Install editable and run tests**

```bash
pip install -e tools/mythic
pytest tools/mythic/tests/test_smoke.py -v
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add tools/mythic/
git commit -m "Bootstrap mythic package

Package skeleton with FATE_CHART placeholder; oracle implementation and
table population land in next task once Mythic 2e PDF is consulted."
```

---

## Task 7: Mythic tool — Fate Chart oracle

**Files:**
- Modify: `tools/mythic/src/mythic/fate_chart.py` (populate `FATE_CHART`, add `oracle()`)
- Create: `tools/mythic/tests/test_fate_chart.py`

- [ ] **Step 1: Populate the FATE_CHART dictionary from the Mythic 2e PDF**

Open `references/MythicGME2eV2.pdf` with the Read tool, find the Fate Chart, and transcribe each cell as a `(likelihood, chaos_factor)` -> `(exceptional_no_max, no_max, yes_max, exceptional_yes_max)` entry into `FATE_CHART`.

Encoding rule:
- For each cell, the PDF lists thresholds for Exceptional No / No / Yes / Exceptional Yes.
- A d100 roll of 1–`exceptional_no_max` is Exceptional No.
- `exceptional_no_max+1` to `no_max` is No.
- `no_max+1` to `yes_max` is Yes.
- `yes_max+1` to `exceptional_yes_max` is Exceptional Yes.
- `exceptional_yes_max` is typically 100 (every cell sums to all 100 outcomes).

The full table contains 9 likelihoods × 9 Chaos Factors = 81 entries.

Replace the empty assignment with the populated dict. Example shape (one entry only — the implementer fills all 81 from the PDF):
```python
FATE_CHART: dict[tuple[Likelihood, int], tuple[int, int, int, int]] = {
    ("50_50", 5): (5, 50, 95, 100),
    # ... 80 more entries from references/MythicGME2eV2.pdf
}
```

- [ ] **Step 2: Write failing tests for oracle()**

`tools/mythic/tests/test_fate_chart.py`:
```python
"""Tests for the Fate Chart oracle."""

import pytest

from mythic.fate_chart import FATE_CHART, oracle


def test_fate_chart_table_complete():
    """Every (likelihood, chaos_factor) pair has an entry."""
    likelihoods = (
        "impossible",
        "nearly_impossible",
        "very_unlikely",
        "unlikely",
        "50_50",
        "likely",
        "very_likely",
        "nearly_certain",
        "certain",
    )
    for cf in range(1, 10):
        for lik in likelihoods:
            assert (lik, cf) in FATE_CHART, f"missing ({lik!r}, {cf})"


def test_oracle_returns_yes_no_value():
    result = oracle(likelihood="50_50", chaos_factor=5)
    assert result["outcome"] in ("yes", "no", "exceptional_yes", "exceptional_no")
    assert isinstance(result["roll"], int)
    assert 1 <= result["roll"] <= 100
    assert result["likelihood"] == "50_50"
    assert result["chaos_factor"] == 5


def test_oracle_invalid_likelihood():
    with pytest.raises(ValueError):
        oracle(likelihood="totally_made_up", chaos_factor=5)


def test_oracle_invalid_chaos_factor():
    with pytest.raises(ValueError):
        oracle(likelihood="50_50", chaos_factor=0)
    with pytest.raises(ValueError):
        oracle(likelihood="50_50", chaos_factor=10)


def test_oracle_distribution_50_50_at_cf5_roughly_balanced():
    # Statistical sanity: 50/50 at CF 5 should be near 50% yes.
    yes_count = 0
    for _ in range(2000):
        r = oracle(likelihood="50_50", chaos_factor=5)
        if r["outcome"] in ("yes", "exceptional_yes"):
            yes_count += 1
    # Allow generous bounds; this is a smoke test, not a precision test.
    assert 800 < yes_count < 1200, f"got {yes_count}/2000 yes outcomes"
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
pytest tools/mythic/tests/test_fate_chart.py -v
```

Expected: FAIL — `oracle` not defined yet.

- [ ] **Step 4: Implement oracle()**

Append to `tools/mythic/src/mythic/fate_chart.py`:
```python
import secrets


def oracle(likelihood: Likelihood, chaos_factor: int) -> dict:
    """Resolve a yes/no question via the Mythic 2e Fate Chart.

    Returns a dict with 'outcome', 'roll', 'likelihood', 'chaos_factor', and
    'thresholds' (the 4-tuple that determined the bands).
    """
    if likelihood not in LIKELIHOODS:
        raise ValueError(f"unknown likelihood {likelihood!r}")
    if not 1 <= chaos_factor <= 9:
        raise ValueError(f"chaos_factor must be 1..9, got {chaos_factor}")

    thresholds = FATE_CHART[(likelihood, chaos_factor)]
    exc_no, no, yes, exc_yes = thresholds
    r = secrets.randbelow(100) + 1  # 1..100

    if r <= exc_no:
        outcome = "exceptional_no"
    elif r <= no:
        outcome = "no"
    elif r <= yes:
        outcome = "yes"
    else:
        outcome = "exceptional_yes"

    return {
        "outcome": outcome,
        "roll": r,
        "likelihood": likelihood,
        "chaos_factor": chaos_factor,
        "thresholds": list(thresholds),
    }
```

- [ ] **Step 5: Run tests to verify pass**

```bash
pytest tools/mythic/tests/test_fate_chart.py -v
```

Expected: all tests PASS. The completeness test verifies all 81 cells are populated; the distribution test verifies oracle() produces sensible random outcomes.

- [ ] **Step 6: Commit**

```bash
git add tools/mythic/src/mythic/fate_chart.py tools/mythic/tests/test_fate_chart.py
git commit -m "Implement Mythic 2e Fate Chart oracle

FATE_CHART populated from references/MythicGME2eV2.pdf with all 81
likelihood × chaos-factor cells. oracle() rolls d100 (CSPRNG) and
classifies into exceptional_no / no / yes / exceptional_yes per the
cell's thresholds."
```

---

## Task 8: Mythic tool — Chaos Factor read/write

**Files:**
- Create: `tools/mythic/src/mythic/chaos.py`
- Create: `tools/mythic/tests/test_chaos.py`

The chaos factor lives in `meta/chaos-factor.md` as a single integer (no header parsing in Phase 1; the file may have a leading `# Chaos factor` line and a blank line). The mythic tool parses it leniently.

- [ ] **Step 1: Write failing tests**

`tools/mythic/tests/test_chaos.py`:
```python
"""Tests for chaos factor file read/write."""

from pathlib import Path

import pytest

from mythic.chaos import read_chaos, write_chaos, adjust_chaos


def test_read_chaos_simple_int(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("5\n", encoding="utf-8")
    assert read_chaos(f) == 5


def test_read_chaos_with_header(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("# Chaos factor\n\n7\n", encoding="utf-8")
    assert read_chaos(f) == 7


def test_read_chaos_clamps_invalid_to_default(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("nonsense\n", encoding="utf-8")
    with pytest.raises(ValueError):
        read_chaos(f)


def test_write_chaos_round_trip(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    write_chaos(f, 6)
    assert read_chaos(f) == 6


def test_adjust_chaos_increment(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("5\n", encoding="utf-8")
    new = adjust_chaos(f, +1)
    assert new == 6
    assert read_chaos(f) == 6


def test_adjust_chaos_clamps_low(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("1\n", encoding="utf-8")
    new = adjust_chaos(f, -5)
    assert new == 1


def test_adjust_chaos_clamps_high(tmp_path: Path):
    f = tmp_path / "chaos-factor.md"
    f.write_text("9\n", encoding="utf-8")
    new = adjust_chaos(f, +5)
    assert new == 9
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tools/mythic/tests/test_chaos.py -v
```

Expected: FAIL — module does not exist.

- [ ] **Step 3: Implement chaos.py**

`tools/mythic/src/mythic/chaos.py`:
```python
"""Read, write, and adjust the Mythic Chaos Factor in meta/chaos-factor.md.

The file format is lenient: any leading markdown header and blank lines are
ignored; the first standalone integer 1..9 is the chaos factor. write_chaos
overwrites with a clean header + integer.
"""

from __future__ import annotations

import re
from pathlib import Path

CHAOS_MIN = 1
CHAOS_MAX = 9
_INT_LINE = re.compile(r"^\s*(\d+)\s*$")


def read_chaos(path: Path) -> int:
    text = Path(path).read_text(encoding="utf-8")
    for line in text.splitlines():
        m = _INT_LINE.match(line)
        if m:
            value = int(m.group(1))
            if CHAOS_MIN <= value <= CHAOS_MAX:
                return value
            raise ValueError(
                f"chaos factor {value} out of range {CHAOS_MIN}..{CHAOS_MAX}"
            )
    raise ValueError(f"no chaos factor found in {path}")


def write_chaos(path: Path, value: int) -> None:
    if not CHAOS_MIN <= value <= CHAOS_MAX:
        raise ValueError(
            f"chaos factor {value} out of range {CHAOS_MIN}..{CHAOS_MAX}"
        )
    Path(path).write_text(
        f"# Chaos factor\n\n{value}\n", encoding="utf-8"
    )


def adjust_chaos(path: Path, delta: int) -> int:
    current = read_chaos(path)
    new = max(CHAOS_MIN, min(CHAOS_MAX, current + delta))
    write_chaos(path, new)
    return new
```

- [ ] **Step 4: Run tests to verify pass**

```bash
pytest tools/mythic/tests/test_chaos.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/mythic/src/mythic/chaos.py tools/mythic/tests/test_chaos.py
git commit -m "Implement chaos factor read/write/adjust

Lenient parser accepts a leading markdown header; writer normalizes the
file. adjust_chaos clamps to 1..9."
```

---

## Task 9: Mythic tool — Random event detection and event tables

**Files:**
- Create: `tools/mythic/src/mythic/events.py`
- Create: `tools/mythic/tests/test_events.py`

Mythic 2e random event trigger: a Fate Chart roll triggers a random event when the tens and ones digits match (doubles like 11, 22, 33, ...) AND the tens digit is ≤ the current Chaos Factor. (Implementer: confirm exact Mythic 2e trigger by reading PDF page; the rule is summarized here based on common 2e formulation.)

The event itself is composed of an Event Focus (sampled from a percentile table), an Event Action (verb), and an Event Subject (noun). Each table comes from the PDF.

- [ ] **Step 1: Read Random Event tables from the PDF**

Open `references/MythicGME2eV2.pdf` and locate:
- The "Event Focus" table: percentile bands → focus categories like "Remote Event", "NPC Action", "PC Negative", etc.
- The "Action" table: 1d100 → verb.
- The "Subject" table: 1d100 → noun.

Transcribe each into module-level constants `EVENT_FOCUS_TABLE`, `ACTION_TABLE`, `SUBJECT_TABLE` as lists of `(threshold, value)` tuples sorted ascending by threshold. (E.g., `[(7, "Remote Event"), (28, "NPC Action"), (35, "Introduce a New NPC"), ...]`.)

- [ ] **Step 2: Write failing tests**

`tools/mythic/tests/test_events.py`:
```python
"""Tests for random event detection and table sampling."""

from mythic.events import (
    is_random_event,
    EVENT_FOCUS_TABLE,
    ACTION_TABLE,
    SUBJECT_TABLE,
    sample_event,
)


def test_doubles_below_cf_triggers():
    assert is_random_event(roll=11, chaos_factor=5) is True
    assert is_random_event(roll=33, chaos_factor=5) is True
    assert is_random_event(roll=55, chaos_factor=5) is True


def test_doubles_above_cf_does_not_trigger():
    assert is_random_event(roll=66, chaos_factor=5) is False
    assert is_random_event(roll=99, chaos_factor=5) is False


def test_non_doubles_does_not_trigger():
    assert is_random_event(roll=12, chaos_factor=5) is False
    assert is_random_event(roll=43, chaos_factor=5) is False


def test_event_tables_populated():
    assert len(EVENT_FOCUS_TABLE) > 0
    assert len(ACTION_TABLE) > 0
    assert len(SUBJECT_TABLE) > 0
    # Highest threshold of each table should be 100.
    assert EVENT_FOCUS_TABLE[-1][0] == 100
    assert ACTION_TABLE[-1][0] == 100
    assert SUBJECT_TABLE[-1][0] == 100


def test_sample_event_returns_focus_action_subject():
    event = sample_event()
    assert "focus" in event
    assert "action" in event
    assert "subject" in event
    # Each component should be a non-empty string.
    assert event["focus"] and isinstance(event["focus"], str)
    assert event["action"] and isinstance(event["action"], str)
    assert event["subject"] and isinstance(event["subject"], str)
```

- [ ] **Step 3: Run tests to verify they fail**

```bash
pytest tools/mythic/tests/test_events.py -v
```

Expected: FAIL — module does not exist.

- [ ] **Step 4: Implement events.py**

`tools/mythic/src/mythic/events.py`:
```python
"""Mythic 2e random event detection and table sampling.

Tables transcribed from references/MythicGME2eV2.pdf.
"""

from __future__ import annotations

import secrets

# Each entry: (upper_threshold_inclusive, value).
# Implementer: populate from PDF. Highest threshold must be 100.

EVENT_FOCUS_TABLE: list[tuple[int, str]] = [
    # (7, "Remote Event"),
    # (28, "NPC Action"),
    # ...
]

ACTION_TABLE: list[tuple[int, str]] = [
    # (4, "Attainment"),
    # (8, "Starting"),
    # ...
]

SUBJECT_TABLE: list[tuple[int, str]] = [
    # (4, "Goals"),
    # (8, "Dreams"),
    # ...
]


def is_random_event(roll: int, chaos_factor: int) -> bool:
    """True if a Fate Chart roll triggers a random event under Mythic 2e."""
    if not 1 <= roll <= 100:
        raise ValueError(f"roll must be 1..100, got {roll}")
    tens = roll // 10
    ones = roll % 10
    # Doubles: 11, 22, 33, ..., 99. (00 is roll=100 in d100; treat as no.)
    if roll == 100:
        return False
    if tens != ones:
        return False
    return tens <= chaos_factor


def _sample(table: list[tuple[int, str]]) -> str:
    r = secrets.randbelow(100) + 1  # 1..100
    for threshold, value in table:
        if r <= threshold:
            return value
    # Should be unreachable if table is well-formed (last threshold == 100).
    raise RuntimeError(f"table not exhaustive at roll {r}")


def sample_event() -> dict:
    """Sample a random event: focus + action + subject."""
    return {
        "focus": _sample(EVENT_FOCUS_TABLE),
        "action": _sample(ACTION_TABLE),
        "subject": _sample(SUBJECT_TABLE),
    }
```

The implementer must populate the three tables from the PDF before tests will pass — `test_event_tables_populated` and `test_sample_event_returns_focus_action_subject` verify the tables are real.

- [ ] **Step 5: Run tests to verify pass**

```bash
pytest tools/mythic/tests/test_events.py -v
```

Expected: all tests PASS once tables are populated.

- [ ] **Step 6: Commit**

```bash
git add tools/mythic/src/mythic/events.py tools/mythic/tests/test_events.py
git commit -m "Implement Mythic 2e random event detection and tables

is_random_event applies Mythic 2e doubles-within-chaos-range trigger.
Event Focus, Action, and Subject tables transcribed from
references/MythicGME2eV2.pdf and sampled with CSPRNG."
```

---

## Task 10: Mythic tool — CLI

**Files:**
- Create: `tools/mythic/src/mythic/cli.py`
- Create: `tools/mythic/tests/test_cli.py`

- [ ] **Step 1: Write failing CLI tests**

`tools/mythic/tests/test_cli.py`:
```python
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
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tools/mythic/tests/test_cli.py -v
```

Expected: FAIL — `mythic.cli` does not exist.

- [ ] **Step 3: Implement CLI**

`tools/mythic/src/mythic/cli.py`:
```python
"""Mythic CLI."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from mythic.fate_chart import oracle as fate_oracle
from mythic.events import is_random_event, sample_event
from mythic.chaos import read_chaos, adjust_chaos


def _cmd_oracle(args: argparse.Namespace) -> int:
    result = fate_oracle(likelihood=args.likelihood, chaos_factor=args.cf)
    event = None
    if is_random_event(roll=result["roll"], chaos_factor=args.cf):
        event = sample_event()
    payload = {**result, "random_event": event}
    json.dump(payload, sys.stdout)
    sys.stdout.write("\n")
    return 0


def _cmd_event(args: argparse.Namespace) -> int:
    json.dump(sample_event(), sys.stdout)
    sys.stdout.write("\n")
    return 0


def _cmd_chaos(args: argparse.Namespace) -> int:
    path = Path(args.file)
    if args.read:
        cf = read_chaos(path)
    elif args.adjust is not None:
        delta = int(args.adjust)
        cf = adjust_chaos(path, delta)
    else:
        json.dump({"error": "specify --read or --adjust"}, sys.stdout)
        sys.stdout.write("\n")
        return 2
    json.dump({"chaos_factor": cf, "file": str(path)}, sys.stdout)
    sys.stdout.write("\n")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="mythic")
    sub = parser.add_subparsers(dest="command", required=True)

    p_oracle = sub.add_parser("oracle", help="Resolve a yes/no question")
    p_oracle.add_argument("--likelihood", required=True)
    p_oracle.add_argument("--cf", type=int, required=True)
    p_oracle.set_defaults(func=_cmd_oracle)

    p_event = sub.add_parser("event", help="Sample a random event")
    p_event.set_defaults(func=_cmd_event)

    p_chaos = sub.add_parser("chaos", help="Read or adjust the chaos factor")
    p_chaos.add_argument("--file", required=True)
    g = p_chaos.add_mutually_exclusive_group(required=True)
    g.add_argument("--read", action="store_true")
    g.add_argument("--adjust", help="Delta like +1 or -1")
    p_chaos.set_defaults(func=_cmd_chaos)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 4: Run tests to verify pass**

```bash
pytest tools/mythic/tests/test_cli.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Run full mythic test suite**

```bash
pytest tools/mythic/ -v
```

Expected: all mythic tests PASS.

- [ ] **Step 6: Commit**

```bash
git add tools/mythic/src/mythic/cli.py tools/mythic/tests/test_cli.py
git commit -m "Add mythic CLI

Subcommands: oracle (Fate Chart + auto random event check), event
(sample one event), chaos (read or adjust chaos factor file). All
output JSON to stdout."
```

---

## Task 11: dm-fs MCP — package bootstrap and path-safety primitive

**Files:**
- Create: `tools/dm-fs-mcp/pyproject.toml`
- Create: `tools/dm-fs-mcp/src/dm_fs/__init__.py`
- Create: `tools/dm-fs-mcp/src/dm_fs/safety.py`
- Create: `tools/dm-fs-mcp/tests/__init__.py`
- Create: `tools/dm-fs-mcp/tests/test_safety.py`

The MCP server will be implemented in Task 14. This task isolates path-safety logic (which has security implications) so it can be tested independently.

- [ ] **Step 1: Write failing tests for path safety**

`tools/dm-fs-mcp/tests/test_safety.py`:
```python
"""Tests for dm-fs path-safety primitive."""

from pathlib import Path

import pytest

from dm_fs.safety import resolve_dm_path, PathSafetyError


def test_resolve_relative_path(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    (dm_root / "npcs").mkdir()
    target = dm_root / "npcs" / "x.md"
    target.write_text("hello", encoding="utf-8")

    resolved = resolve_dm_path(dm_root, "npcs/x.md")
    assert resolved == target.resolve()


def test_resolve_empty_returns_root(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    resolved = resolve_dm_path(dm_root, "")
    assert resolved == dm_root.resolve()


def test_reject_absolute_path(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    with pytest.raises(PathSafetyError):
        resolve_dm_path(dm_root, "/etc/passwd")


def test_reject_dotdot_escape(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    with pytest.raises(PathSafetyError):
        resolve_dm_path(dm_root, "../outside.md")


def test_reject_symlink_to_outside(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    outside = tmp_path / "outside.md"
    outside.write_text("secret", encoding="utf-8")
    link = dm_root / "link.md"
    link.symlink_to(outside)

    with pytest.raises(PathSafetyError):
        resolve_dm_path(dm_root, "link.md")


def test_resolve_normalizes_redundant_slashes(tmp_path: Path):
    dm_root = tmp_path / "dm"
    dm_root.mkdir()
    (dm_root / "npcs").mkdir()
    target = dm_root / "npcs" / "x.md"
    target.write_text("hello", encoding="utf-8")
    resolved = resolve_dm_path(dm_root, "npcs//x.md")
    assert resolved == target.resolve()
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tools/dm-fs-mcp/tests/test_safety.py -v
```

Expected: FAIL — module not yet defined.

- [ ] **Step 3: Implement safety.py and bootstrap the package**

`tools/dm-fs-mcp/pyproject.toml`:
```toml
[build-system]
requires = ["setuptools>=68"]
build-backend = "setuptools.build_meta"

[project]
name = "dm-fs-mcp"
version = "0.1.0"
description = "MCP server exposing dm/ as path-scoped read-only file access"
requires-python = ">=3.11"
dependencies = [
    "mcp>=1.0",
]

[project.scripts]
dm-fs-mcp = "dm_fs.server:main"

[tool.setuptools.packages.find]
where = ["src"]
```

`tools/dm-fs-mcp/src/dm_fs/__init__.py`:
```python
"""dm-fs MCP server: path-scoped read access to dm/ for the world-state subagent."""
__version__ = "0.1.0"
```

`tools/dm-fs-mcp/src/dm_fs/safety.py`:
```python
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
```

- [ ] **Step 4: Install and run tests**

```bash
pip install -e tools/dm-fs-mcp
pytest tools/dm-fs-mcp/tests/test_safety.py -v
```

Expected: all tests PASS.

Note: the `mcp` package install pulls in the official MCP Python SDK. If it fails, install it explicitly first: `pip install mcp`.

- [ ] **Step 5: Commit**

```bash
git add tools/dm-fs-mcp/
git commit -m "Bootstrap dm-fs MCP package and path-safety primitive

Path safety: resolve_dm_path canonicalizes the request and verifies the
result is inside dm/. Rejects absolute paths, .. escapes, and symlinks
that point outside the root. Server entry point lands in Task 14."
```

---

## Task 12: dm-fs MCP — read_dm_file

**Files:**
- Create: `tools/dm-fs-mcp/src/dm_fs/ops.py`
- Create: `tools/dm-fs-mcp/tests/test_ops.py`

- [ ] **Step 1: Write failing tests**

`tools/dm-fs-mcp/tests/test_ops.py`:
```python
"""Tests for dm-fs file operations (read, list)."""

from pathlib import Path

import pytest

from dm_fs.ops import read_dm_file
from dm_fs.safety import PathSafetyError


def test_read_existing_file(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    target = dm / "npcs" / "merchant.md"
    target.write_text("# Merchant\n\nHidden agenda: cult.\n", encoding="utf-8")

    content = read_dm_file(dm, "npcs/merchant.md")
    assert "Hidden agenda" in content


def test_read_missing_file_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(FileNotFoundError):
        read_dm_file(dm, "npcs/missing.md")


def test_read_unsafe_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(PathSafetyError):
        read_dm_file(dm, "../escape.md")


def test_read_directory_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    with pytest.raises(IsADirectoryError):
        read_dm_file(dm, "npcs")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tools/dm-fs-mcp/tests/test_ops.py -v
```

Expected: FAIL — module not defined.

- [ ] **Step 3: Implement read_dm_file**

`tools/dm-fs-mcp/src/dm_fs/ops.py`:
```python
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
```

- [ ] **Step 4: Run tests to verify pass**

```bash
pytest tools/dm-fs-mcp/tests/test_ops.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/dm-fs-mcp/src/dm_fs/ops.py tools/dm-fs-mcp/tests/test_ops.py
git commit -m "Implement dm-fs read_dm_file

Path-safe read of dm/ files. Raises FileNotFoundError, IsADirectoryError,
or PathSafetyError on failure modes."
```

---

## Task 13: dm-fs MCP — list_dm_dir

**Files:**
- Modify: `tools/dm-fs-mcp/src/dm_fs/ops.py` (add `list_dm_dir`)
- Modify: `tools/dm-fs-mcp/tests/test_ops.py` (add tests)

- [ ] **Step 1: Write failing tests**

Append to `tools/dm-fs-mcp/tests/test_ops.py`:
```python
from dm_fs.ops import list_dm_dir


def test_list_empty_root(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    assert list_dm_dir(dm, "") == []


def test_list_returns_relative_entries(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    (dm / "npcs" / "alpha.md").write_text("a", encoding="utf-8")
    (dm / "npcs" / "beta.md").write_text("b", encoding="utf-8")

    entries = sorted(list_dm_dir(dm, "npcs"))
    assert entries == ["alpha.md", "beta.md"]


def test_list_root_lists_subdirs(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    (dm / "npcs").mkdir()
    (dm / "factions").mkdir()
    entries = sorted(list_dm_dir(dm, ""))
    assert entries == ["factions", "npcs"]


def test_list_missing_dir_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(FileNotFoundError):
        list_dm_dir(dm, "missing")


def test_list_file_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    f = dm / "npcs.md"
    f.write_text("hi", encoding="utf-8")
    with pytest.raises(NotADirectoryError):
        list_dm_dir(dm, "npcs.md")


def test_list_unsafe_path_raises(tmp_path: Path):
    dm = tmp_path / "dm"
    dm.mkdir()
    with pytest.raises(PathSafetyError):
        list_dm_dir(dm, "../escape")
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
pytest tools/dm-fs-mcp/tests/test_ops.py -v
```

Expected: tests for `list_dm_dir` FAIL.

- [ ] **Step 3: Implement list_dm_dir**

Append to `tools/dm-fs-mcp/src/dm_fs/ops.py`:
```python
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
```

- [ ] **Step 4: Run tests to verify pass**

```bash
pytest tools/dm-fs-mcp/tests/test_ops.py -v
```

Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add tools/dm-fs-mcp/src/dm_fs/ops.py tools/dm-fs-mcp/tests/test_ops.py
git commit -m "Implement dm-fs list_dm_dir

Returns names of immediate children of a dm/ subdirectory. Raises
NotADirectoryError, FileNotFoundError, or PathSafetyError on
non-success."
```

---

## Task 14: dm-fs MCP — server entry point and integration test

**Files:**
- Create: `tools/dm-fs-mcp/src/dm_fs/server.py`
- Create: `tools/dm-fs-mcp/tests/test_server.py`

This task wires `read_dm_file` and `list_dm_dir` into MCP tools and exposes them over stdio. The implementer should consult the official Python MCP SDK docs (https://github.com/modelcontextprotocol/python-sdk) for the current API. The structure below is shown using the `mcp.server.fastmcp` pattern; if the SDK has evolved, adapt to match.

- [ ] **Step 1: Write a failing tool-registration test**

`tools/dm-fs-mcp/tests/test_server.py`:
```python
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
    """Best-effort tool-name extraction. Falls back to public attribute names
    we expect FastMCP to expose; the implementer may need to adapt this
    to the current SDK API."""
    if hasattr(server, "_tools"):
        return list(server._tools.keys())
    if hasattr(server, "tools"):
        try:
            return list(server.tools.keys())
        except Exception:
            return [t.name for t in server.tools]
    raise RuntimeError(
        "Could not introspect server tools — adapt _list_tool_names "
        "for your installed MCP SDK version."
    )
```

- [ ] **Step 2: Run test to verify it fails**

```bash
pytest tools/dm-fs-mcp/tests/test_server.py -v
```

Expected: FAIL — `dm_fs.server` does not exist.

- [ ] **Step 3: Implement the server**

`tools/dm-fs-mcp/src/dm_fs/server.py`:
```python
"""dm-fs MCP server — exposes read/list of dm/ over stdio.

Designed for use by the world-state subagent only (wired via .mcp.json
and the subagent's mcpServers frontmatter).
"""

from __future__ import annotations

import os
from pathlib import Path

from mcp.server.fastmcp import FastMCP  # type: ignore[import-untyped]

from dm_fs.ops import read_dm_file as _read_dm_file
from dm_fs.ops import list_dm_dir as _list_dm_dir


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
```

- [ ] **Step 4: Run tests to verify pass**

```bash
pytest tools/dm-fs-mcp/tests/test_server.py -v
```

Expected: PASS. If the introspection helper fails because the MCP SDK version exposes tools differently, adapt `_list_tool_names` and the corresponding test until they pass.

- [ ] **Step 5: Smoke-test the server can start**

```bash
# In a separate terminal or with timeout:
DM_ROOT=$(pwd)/dm timeout 2 python -m dm_fs.server || true
```

Expected: the server should start, accept stdio handshake, and exit cleanly when timeout kills it. Any traceback during startup is a failure.

- [ ] **Step 6: Run full dm-fs test suite**

```bash
pytest tools/dm-fs-mcp/ -v
```

Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add tools/dm-fs-mcp/src/dm_fs/server.py tools/dm-fs-mcp/tests/test_server.py
git commit -m "Implement dm-fs MCP server entry point

Registers read_dm_file and list_dm_dir as MCP tools over stdio.
Server is bound at startup to a dm/ root from the DM_ROOT env var
(defaults to ./dm)."
```

---

## Task 15: meta/ configuration files

**Files:**
- Modify: `meta/campaign-config.md`
- Modify: `meta/dice-config.md`
- (Already correctly stubbed in Task 1: `meta/chaos-factor.md`)

- [ ] **Step 1: Populate `meta/campaign-config.md`**

Replace the stub with:
```markdown
# Campaign config

## System

- system: dnd5e-2024
- edition: PHB 2024
- starting level: <set during PC selection in Task 16>

## Tone

- register: classic D&D, light pulp
- on-screen content boundaries: standard D&D conventions; defer to player taste
- voice: third-person omniscient narrator; NPCs voiced in first person

## Phase 1 notes

This file will grow over later phases. Phase 1 uses minimal fields:
just enough for the narrator to know what system to apply and how
to set tone.

Future phases populate: home base, starting threads, faction landscape,
leveling settings, downtime settings, house rules.
```

- [ ] **Step 2: Populate `meta/dice-config.md`**

Replace the stub with:
```markdown
# Dice config

Phase 1 uses open-roll defaults across the board. Hidden rolls are
deferred to Phase 2.

## Default visibility per roll type (Phase 1)

- attacks: open
- damage: open
- saves: open
- skill checks: open
- ability checks: open
- initiative: open
- death saves: open

## Authority

- player: may declare any roll for own character; may always override visibility
- narrator: may call for any roll appropriate to the situation
- system: monster attacks, NPC saves, environmental effects roll open by default

## Critical handling

- D&D 5e 2024 standard:
  - attack rolls: natural 20 = critical hit (double damage dice)
  - attack rolls: natural 1 = automatic miss
  - skill/ability/saves: no critical band
- Override per-campaign as needed.

## Advantage / disadvantage

- expressed as `2d20kh1` (advantage) and `2d20kl1` (disadvantage)
- advantage and disadvantage cancel one-for-one; net result expressed as
  one of: straight `1d20`, advantage `2d20kh1`, or disadvantage `2d20kl1`
```

- [ ] **Step 3: Verify chaos-factor.md is intact**

```bash
cat meta/chaos-factor.md
```

Expected: shows `5\n` or `# Chaos factor\n\n5\n`. If empty or absent, recreate per Task 1 Step 4.

- [ ] **Step 4: Commit**

```bash
git add meta/campaign-config.md meta/dice-config.md
git commit -m "Populate meta/ config files for Phase 1

Campaign config: system + tone fields the narrator needs at
session-start. Dice config: open-roll defaults per Phase 1 scope
(hidden rolls deferred to Phase 2)."
```

---

## Task 16: Test content — pull DnDB character and transcribe to markdown

**Files:**
- Create: `party/primary/<character-name>.md`

This task uses the `dndbeyond` MCP tools to pull the user's chosen test character and transcribes the data into the markdown format defined in the design doc.

- [ ] **Step 1: Authenticate to D&D Beyond and list available characters**

```
mcp__dndbeyond__check_auth
mcp__dndbeyond__list_characters
```

If `check_auth` reports unauthenticated, run `mcp__dndbeyond__setup_auth` and complete the flow.

- [ ] **Step 2: Ask the user which character to use**

The implementer should present the list to the user and ask:
> "Which of these D&D Beyond characters do you want to use as the Phase 1 test PC? They're a one-time transcription target — we won't sync, just copy the data into our markdown format."

Wait for the user's selection.

- [ ] **Step 3: Fetch the chosen character's data**

```
mcp__dndbeyond__get_character (with the chosen character's id)
```

Capture the full payload — race, class(es), level, ability scores, proficiencies, class features, racial traits, feats, spells known/prepared, equipment, AC, HP, speed, etc.

- [ ] **Step 4: Transcribe to markdown using the design's format**

Create `party/primary/<character-name>.md` (replace `<character-name>` with a kebab-case form of the character's name). Use this exact structure, populating from the DnDB payload:

```markdown
---
name: <character name>
system: dnd5e-2024
class: <class>(<level>)
race: <species>
character_id_dndb: <id from DnDB>
---

# <character name>

## Build
<!-- Static character data. DnDB will own this in Phase 6.
     Updated by /level-up (later phase) or manual edit. -->

- Race: <species, subspecies>
- Class: <class>, level <n>
- Background: <bg>
- Alignment: <align>
- Ability scores: STR <n> / DEX <n> / CON <n> / INT <n> / WIS <n> / CHA <n>
- Proficiency bonus: +<n>
- Saves (proficient): <list>
- Skills (proficient): <list>
- Class features: <list>
- Racial traits: <list>
- Feats: <list>
- Spells known/prepared: <list>
- Equipment as built:
  - <weapon list>
  - <armor>
  - <other gear>
  - Coin: <gp/sp/cp>
- AC base: <n>
- Initiative: <mod>
- Speed: <ft>

## Live
<!-- Dynamic state. MD always owns this. -->

- HP: <max>/<max> (temp: 0)
- Conditions: none
- Spell slots used: 1st 0/<a>, 2nd 0/<b>, ...
- Per-day uses: <feature> 0/<n>, ...
- Inventory delta: none
- Exhaustion: 0
- Death saves: 0/0
- Notes: <free-form>

## Modifiers
<!-- Derived from Build. Read by dice subagent for /roll lookups. -->

- Perception: +<n>
- Insight: +<n>
- Stealth: +<n>
- Athletics: +<n>
- Acrobatics: +<n>
- Investigation: +<n>
- Persuasion: +<n>
- (...all skills, even if not proficient — show base ability mod)
- Saves:
  - Strength: +<n>
  - Dexterity: +<n>
  - Constitution: +<n>
  - Intelligence: +<n>
  - Wisdom: +<n>
  - Charisma: +<n>
- Attack — <weapon name>: +<n> to hit, <dice> damage (<damage type>)
- Attack — <weapon name>: +<n> to hit, <dice> damage (<damage type>)
- Spell save DC: <n>
- Spell attack: +<n>
```

Compute modifiers from the DnDB stat data: `mod = (ability_score - 10) // 2`. For proficient skills/saves, add proficiency bonus. For weapon attack mods, add ability mod + proficiency bonus + magic bonuses.

- [ ] **Step 5: Update meta/campaign-config.md with the starting level**

Edit `meta/campaign-config.md` to fill in the `starting level: <n>` line based on the chosen character's level.

- [ ] **Step 6: Verify the markdown is well-formed**

```bash
cat party/primary/<character-name>.md
head -20 party/primary/<character-name>.md
```

Expected: YAML frontmatter parses; three sections (`## Build`, `## Live`, `## Modifiers`) all present.

- [ ] **Step 7: Commit**

```bash
git add party/primary/ meta/campaign-config.md
git commit -m "Add Phase 1 test PC transcribed from D&D Beyond

One-time manual transcription per the design doc's format-first
principle. Starting level recorded in campaign-config."
```

---

## Task 17: Test content — select scene from one-shots PDF and write NPCs

**Files:**
- Create: `world/home-base/overview.md`
- Create: `world/home-base/npcs/<npc-name>.md` (public sheet)
- Create: `dm/npcs/<npc-name>.md` (hidden sheet)
- Create: `world/home-base/scene.md` (scene description for narrator)

- [ ] **Step 1: Skim `references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf`**

Use the Read tool with a `pages: "1-20"` range to get an overview, then drill into 1–3 candidates. Pick one scene with these properties:
- Single named NPC who is the primary point of interaction.
- The NPC's surface presentation can plausibly hide an ulterior motive (good for the asymmetry test).
- Scene is short (≤ 1 page) and self-contained — does not depend on having played other content first.
- Level-appropriate for the chosen test PC (re-skim if not).

If multiple candidates are plausible, ask the user to choose between 2–3 by describing each in one sentence.

- [ ] **Step 2: Write `world/home-base/overview.md`**

A short player-facing description of the location of the chosen scene:

```markdown
# Home base: <location name>

<2-3 paragraph player-facing description of the location. What it looks
like, who's around, the general feel. Drawn from the one-shot's setup
text. Do not include any twist or hidden information.>

## Notable NPCs

- <NPC name> — <one-line public description: role, demeanor>
```

- [ ] **Step 3: Write the public NPC sheet `world/home-base/npcs/<npc-name>.md`**

```markdown
---
name: <NPC name>
location: home-base
role: <e.g., merchant, priest, innkeeper>
disposition: <e.g., friendly, wary, neutral>
---

# <NPC name>

## Description

<What the party perceives. Surface presentation only. Two paragraphs
max.>

## Public-known facts

- <fact the party would learn from a casual conversation>
- <fact the party would learn from observation>
- <fact widely known in the home base>

## Mannerisms

- <speech pattern or recurring phrase>
- <visible quirk>

## Phase 1 note

This file is the narrator-readable view of this NPC. The hidden sheet
is at `dm/npcs/<npc-name>.md` and is invisible to the narrator.
```

- [ ] **Step 4: Write the hidden NPC sheet `dm/npcs/<npc-name>.md`**

```markdown
---
name: <NPC name>
hidden: true
public_sheet: world/home-base/npcs/<npc-name>.md
---

# <NPC name> (HIDDEN)

## True motivation

<The actual agenda the NPC is pursuing. The asymmetry test depends on
this being meaningful — not just "is secretly evil" but a specific
agenda the world-state subagent can translate into observable behavior.>

## Hidden facts

- <fact only the DM knows>
- <fact only the DM knows>
- <fact about a faction or other secret connection>

## Observable tells

When the party interacts, the NPC may exhibit these observable
behaviors that COULD be surfaced by world-state without revealing the
underlying truth:

- <observable behavior 1: e.g., "glances toward the inn before answering">
- <observable behavior 2: e.g., "becomes evasive when asked about the southern road">
- <observable behavior 3: e.g., "wears a small unfamiliar pin on their cloak">

## Resolution if confronted

<If the party directly confronts the NPC about something hidden, what
do they do? Deny? Deflect? Confess? This guides the world-state agent
when asked "what does <NPC> do when [situation]?".>
```

- [ ] **Step 5: Write `world/home-base/scene.md`** (scene context the narrator uses to set up the encounter)

```markdown
# Scene: <scene title>

## Hook

<One paragraph: how/why the PC encounters this scene. Drawn from the
one-shot's framing. Player-knowable.>

## Setting

<Sensory details: what the PC sees, hears, smells. Drawn from the
one-shot.>

## What can happen

<Possible actions the PC might take and how the location/NPC reacts.
This is the narrator's situational reference, not a script. Player-
knowable elements only — hidden agendas live in dm/.>

## Connection to home-base

This scene takes place at <location>. NPCs present: <list>.
```

- [ ] **Step 6: Verify all files**

```bash
cat world/home-base/overview.md
cat world/home-base/npcs/*.md
cat dm/npcs/*.md
cat world/home-base/scene.md
```

Manual review: does the public NPC sheet leak anything from the hidden sheet? It should not. The "observable tells" in the hidden sheet should be things the world-state agent can selectively surface, not things already in the public sheet.

- [ ] **Step 7: Commit**

```bash
git add world/ dm/npcs/
git commit -m "Add Phase 1 test scene and NPCs (public + hidden)

Scene chosen from references/1454244-One-Page_One-Shots_Volume_1_Print-Optimised.pdf.
Public NPC sheet has only what the party would know on first
encounter; hidden sheet in dm/ holds the true motivation and
observable tells the world-state agent can selectively surface.
This is the asymmetry test fixture."
```

---

## Task 18: `.claude/settings.json` deny rules

**Files:**
- Create: `.claude/settings.json`

- [ ] **Step 1: Write `.claude/settings.json`**

```json
{
  "permissions": {
    "deny": [
      "Read(dm/**)",
      "Write(dm/**)",
      "Edit(dm/**)",
      "Glob(dm/**)",
      "Grep(dm/**)",
      "Bash(cat dm/*)",
      "Bash(cat dm/**/*)",
      "Bash(grep dm/*)",
      "Bash(grep -r dm/*)",
      "Bash(rg dm/*)",
      "Bash(less dm/*)",
      "Bash(more dm/*)",
      "Bash(head dm/*)",
      "Bash(tail dm/*)",
      "Bash(find dm/*)"
    ]
  }
}
```

- [ ] **Step 2: Commit**

```bash
git add .claude/settings.json
git commit -m "Add .claude/settings.json with dm/ deny rules

Project-wide denies on Read/Write/Edit/Glob/Grep against dm/** plus a
non-exhaustive Bash deny list for common shell access patterns. The
dm-fs MCP (registered in next task) is the only sanctioned path to
dm/ content; these denies block all other paths."
```

---

## Task 19: `.mcp.json` to register dm-fs MCP

**Files:**
- Create: `.mcp.json`

- [ ] **Step 1: Write `.mcp.json`**

```json
{
  "mcpServers": {
    "dm-fs": {
      "command": "python",
      "args": ["-m", "dm_fs.server"],
      "env": {
        "DM_ROOT": "${workspaceFolder}/dm"
      }
    }
  }
}
```

If Claude Code's project-level `.mcp.json` does not interpolate `${workspaceFolder}`, change `env` to a literal absolute path during development: `"DM_ROOT": "/Users/barriault/dnd/gygaxagain/dm"`. Verify by checking Claude Code's documentation for project-MCP variable expansion.

- [ ] **Step 2: Smoke-test the MCP starts under Claude Code's launch protocol**

```bash
DM_ROOT=$(pwd)/dm python -m dm_fs.server &
SERVER_PID=$!
sleep 1
kill $SERVER_PID 2>/dev/null || true
```

Expected: starts cleanly, no traceback before kill.

- [ ] **Step 3: Commit**

```bash
git add .mcp.json
git commit -m "Register dm-fs MCP server in .mcp.json

Server runs via 'python -m dm_fs.server' with DM_ROOT pointing at
this project's dm/. Only the world-state subagent will list it under
mcpServers in its frontmatter (Task 22)."
```

---

## Task 20: Subagent — `.claude/agents/dice.md`

**Files:**
- Create: `.claude/agents/dice.md`

- [ ] **Step 1: Write the dice subagent definition**

```markdown
---
name: dice
description: Resolves dice rolls. Always invoked for any mechanical roll — never narrate a mechanical outcome without invoking this subagent first. Returns visibility-aware results.
tools: Read, Bash, Edit
model: haiku
---

You are the dice agent. Your only job is to execute dice rolls and report results back to the caller.

## Your tools

- The `dice` Python CLI is installed in this project's venv. Invoke it with:
  ```
  source .venv/bin/activate && python -m dice.cli roll '<expression>'
  ```
  Output is JSON on stdout. The `total` field is the headline number.

- Read access to `party/`, `world/`, and `meta/dice-config.md` for modifier lookups and visibility defaults. You do **not** have access to `dm/` and must never attempt to read it.

## How requests come in

Two shapes:

1. **Raw expression:** caller gives you an expression like `1d20+5`. You roll it, log it, return the result.
2. **Named skill plus character:** caller gives you `perception` and a character name. You:
   - Read `party/primary/<character>.md` (or other applicable path).
   - Find the skill in the `## Modifiers` section.
   - Construct the expression `1d20+<modifier>`.
   - Roll it, log it, return the result.

## Visibility (Phase 1)

Phase 1 only supports **open** rolls. Read `meta/dice-config.md` to confirm — but in Phase 1, every roll type defaults to `open`. Hidden rolls are a Phase 2 feature; if a caller asks for a hidden roll, return an error explaining hidden rolls are not yet supported and roll open.

## Logging

For every roll, append a one-line entry to the active session log at the path the caller provides (typically `sessions/play/YYYY/MM/session-NNN.md`). Format:

```
- ROLL: <expression> = <total> (<character or "system"> — <reason>)
```

If no session log path is provided, do not log; return the result and let the caller log.

## Output format

Return to the caller a structured response with:
- `total` (the headline number)
- `expression` (the actual expression rolled, including any auto-substituted modifier)
- `breakdown` (a one-line plain-English summary, e.g., "Rolled 14 + 5 = 19")
- `visibility` (always "open" in Phase 1)
- `narration_safe` (boolean — true if the result is safe to narrate verbatim)

## What you don't do

- Don't interpret results narratively — that's the narrator's job.
- Don't decide what kind of roll is appropriate — the caller specifies.
- Don't ever fabricate a result without invoking the CLI.
- Don't read or attempt to access `dm/` for any reason.
```

- [ ] **Step 2: Verify file structure**

```bash
cat .claude/agents/dice.md
head -10 .claude/agents/dice.md
```

Expected: YAML frontmatter intact (name, description, tools, model fields all present).

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/dice.md
git commit -m "Add dice subagent definition

Haiku-backed subagent wrapping the dice CLI. Reads modifiers from
character sheets in party/ and visibility defaults from
meta/dice-config.md. Phase 1 supports open rolls only; hidden rolls
land in Phase 2."
```

---

## Task 21: Subagent — `.claude/agents/mythic.md`

**Files:**
- Create: `.claude/agents/mythic.md`

- [ ] **Step 1: Write the mythic subagent definition**

```markdown
---
name: mythic
description: Resolves Mythic GME 2e oracle questions, random events, and chaos factor adjustments. Always invoked for genuinely uncertain yes/no questions — never decide such questions yourself.
tools: Read, Edit, Bash
model: haiku
---

You are the mythic agent. You execute Mythic GME 2nd Edition procedures — Fate Chart oracle, random event detection, chaos factor management. You do **not** interpret results into narrative; that's the caller's job.

## Your tools

- The `mythic` Python CLI is installed in this project's venv. Invoke with:
  ```
  source .venv/bin/activate && python -m mythic.cli <subcommand> ...
  ```
  Subcommands: `oracle`, `event`, `chaos`. All output is JSON.

- Read/write access to `meta/chaos-factor.md` (one integer 1..9).
- Read access to `meta/campaign-config.md`.
- You do **not** have access to `dm/`.

## Oracle requests

When asked an oracle question, the caller provides a `likelihood` (one of: `impossible`, `nearly_impossible`, `very_unlikely`, `unlikely`, `50_50`, `likely`, `very_likely`, `nearly_certain`, `certain`). Default to `50_50` if not specified.

Procedure:
1. Read the current chaos factor from `meta/chaos-factor.md`:
   ```
   python -m mythic.cli chaos --file meta/chaos-factor.md --read
   ```
2. Resolve the oracle:
   ```
   python -m mythic.cli oracle --likelihood <likelihood> --cf <cf>
   ```
3. The CLI automatically checks for a random event; if triggered, the `random_event` field in the response will be a non-null `{focus, action, subject}` object.
4. Append a single line to the active session log at the path the caller specifies:
   ```
   - ORACLE (<likelihood>, CF=<n>): <outcome> [roll <r>]<event suffix if any>
   ```
5. Return to the caller: `outcome`, `roll`, `random_event`, plus a one-line plain-English summary.

## Chaos factor adjustments

When asked to adjust the chaos factor (typically at scene end), invoke:
```
python -m mythic.cli chaos --file meta/chaos-factor.md --adjust <+1 or -1>
```
Return the new chaos factor. The CLI clamps to 1..9.

## Random event sampling (standalone)

If asked for a random event without an oracle (rare in Phase 1):
```
python -m mythic.cli event
```
Return the `{focus, action, subject}` triple.

## What you don't do

- Don't interpret oracle results or random events into narrative — return raw outputs.
- Don't fabricate results without invoking the CLI.
- Don't write to `dm/threads/` (deferred to Phase 2).
- Don't attempt to read `dm/`.
```

- [ ] **Step 2: Verify**

```bash
cat .claude/agents/mythic.md
```

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/mythic.md
git commit -m "Add mythic subagent definition

Haiku-backed wrapper around the mythic CLI. Handles Fate Chart
oracle calls (with auto random-event detection), standalone random
events, and chaos factor read/adjust. No interpretation — caller
narrates."
```

---

## Task 22: Subagent — `.claude/agents/world-state.md`

**Files:**
- Create: `.claude/agents/world-state.md`

This is the asymmetry valve. It is the **sole consumer** of the dm-fs MCP. Its frontmatter lists `mcpServers: [dm-fs]`.

- [ ] **Step 1: Write the world-state subagent definition**

```markdown
---
name: world-state
description: Translates hidden world state into observable consequences. Always invoked when the narrator needs information that lives in dm/ — the narrator has no other path to that information.
tools: Read, Edit
mcpServers: [dm-fs]
model: sonnet
---

You are the world-state agent. You hold the boundary between hidden world state and what the narrator (and through the narrator, the player) can perceive.

## Read access

- `world/`, `party/` — fully readable. This is what the party knows or could plausibly observe.
- `dm/` — readable **only** through the `dm-fs` MCP. Use the `read_dm_file` and `list_dm_dir` tools the MCP exposes. Do not attempt direct filesystem reads of `dm/` — they are denied at the project level.

## Your contract

You are a **one-way valve**. You translate raw hidden state into observable consequences and return only the latter. You never:

- Return raw faction clock numbers, hidden NPC sheets verbatim, or raw revelation lists.
- Reveal the existence of hidden content unless asked specifically and answer with maximum vagueness.
- Pre-empt the narrator by deciding *how* something is observed — describe what is observable, leave the prose to the narrator.

## Phase 1 query types

The narrator will invoke you with a structured query. Phase 1 supports three types:

### 1. NPC behavior query

> "What does <NPC name> do when <situation>?"

Procedure:
1. Read the public sheet at `world/home-base/npcs/<npc-name>.md` (or wherever applicable).
2. Read the hidden sheet at `dm/npcs/<npc-name>.md` via the `dm-fs` MCP's `read_dm_file` tool.
3. Cross-reference the situation with the hidden sheet's true motivation, observable tells, and resolution-if-confronted notes.
4. Return a description of **observable behavior only** — what the party would see, hear, and infer-from-surface. Selectively surface tells from the hidden sheet that this situation would plausibly trigger.

Never return: the underlying agenda, hidden facts, or any tell not yet surfaced by the situation.

### 2. Offscreen developments query

> "Has anything changed offscreen since last session?"

Phase 1 has no factions running and no clocks turning. Return: "Nothing observable from offscreen has reached the home base." (Phase 2 expands this.)

### 3. Hidden-content presence query

> "Is there hidden content the party hasn't discovered in <scope>?"

Phase 1 returns a vague yes/no with optional one-line tease. Example: "Yes — there's more to <location> than the party has yet pieced together. Want a hook?" Never reveal specifics.

## Logging

For each query, append a single line to the active session log at the path the caller provides:
```
- WORLD-STATE QUERY: <query type> — <one-line summary of response>
```
Do not log the raw hidden data you read; the log is player-visible.

## What you don't do

- Don't return hidden data verbatim.
- Don't write to `dm/`.
- Don't decide what the party does next — your output describes the world's response, not the party's reaction.
- Don't invent hidden state. If the hidden sheet doesn't address a situation, return "No specific hidden detail covers this; default to surface presentation" rather than fabricating.
```

- [ ] **Step 2: Verify the mcpServers field is recognized**

```bash
cat .claude/agents/world-state.md | head -10
```

Expected: `mcpServers: [dm-fs]` is present in the frontmatter.

- [ ] **Step 3: Commit**

```bash
git add .claude/agents/world-state.md
git commit -m "Add world-state subagent definition

Sonnet-backed asymmetry valve. Sole consumer of the dm-fs MCP per
mcpServers frontmatter. Translates hidden state into observable
consequences; never returns raw hidden data."
```

---

## Task 23: Slash commands

**Files:**
- Create: `.claude/commands/roll.md`
- Create: `.claude/commands/ask-oracle.md`
- Create: `.claude/commands/session-start.md`
- Create: `.claude/commands/session-end.md`

- [ ] **Step 1: Write `.claude/commands/roll.md`**

```markdown
---
description: Roll dice via the dice subagent. Usage /roll <expression-or-skill> [character] [reason]
---

Invoke the dice subagent to resolve this roll.

Arguments: $ARGUMENTS

Parse the arguments as:
- If first arg looks like a dice expression (matches `\d+d\d+` or pure integer math), pass it as a raw expression.
- Otherwise treat the first arg as a skill name; the second arg (if present) is the character; remaining args after `--` or in quotes are the reason.

Invoke the dice subagent with:
- expression or (skill, character)
- reason (if provided)
- session log path: `sessions/play/YYYY/MM/session-NNN.md` (use the active session log file — find the most recently modified file in `sessions/play/`)

Report the result to the user as plain prose, including the breakdown.
```

- [ ] **Step 2: Write `.claude/commands/ask-oracle.md`**

```markdown
---
description: Ask the Mythic oracle a yes/no question. Usage /ask-oracle <question> [likelihood]
---

Invoke the mythic subagent to resolve this question.

Arguments: $ARGUMENTS

Parse the arguments as:
- The question itself is everything except the trailing likelihood word, if present.
- Recognized likelihoods: `impossible`, `nearly_impossible`, `very_unlikely`, `unlikely`, `50_50`, `likely`, `very_likely`, `nearly_certain`, `certain`. Default `50_50` if none specified.

Invoke the mythic subagent with:
- the question (for logging)
- the likelihood
- session log path: the active session log file in `sessions/play/`

Present the result to the user including: outcome (Yes/No, exceptional or not), the d100 roll, and any random event details.
```

- [ ] **Step 3: Write `.claude/commands/session-start.md`**

```markdown
---
description: Begin a new play session. Usage /session-start [optional-focus]
---

Begin a new play session.

1. Determine the next session number by counting existing files matching `sessions/play/*/*/session-*.md` (numeric suffix). The new number is one greater than the maximum, or 001 if none exist.

2. Compute the session log path: `sessions/play/YYYY/MM/session-NNN.md` using today's date and the new session number. Create the parent directory if needed.

3. Initialize the session log with this header:
   ```
   # Session NNN — YYYY-MM-DD
   
   **Focus:** $ARGUMENTS
   
   **Party state at session start:**
   <summarize from party/primary/*.md HP and conditions>
   
   ---
   
   ## Log
   ```

4. Read `meta/campaign-config.md` for system, tone, and starting context.

5. Read the primary PC sheet from `party/primary/`.

6. Invoke the world-state subagent with: "Has anything changed offscreen since last session?" (Phase 1 will return a minimal answer.)

7. Invoke the world-state subagent again to find the home-base scene context: "What is the current scene at home-base?" — or read `world/home-base/scene.md` and `world/home-base/overview.md` directly (these are not in dm/).

8. Greet the user with a session-start brief: where the party is, what's currently pressing, what's optionally available. Then narrate the opening of the scene and ask the player what they do.
```

- [ ] **Step 4: Write `.claude/commands/session-end.md`**

```markdown
---
description: Close a play session. Commits all working-tree changes as one logical commit.
---

Close the active session.

1. Locate the active session log (most recently modified file in `sessions/play/`).

2. Append a session-end summary section:
   ```
   
   ---
   
   ## Session-end summary
   
   <2-4 sentences summarizing what happened, who was met, what's pending.>
   
   **Loose ends:**
   - <thread or open question>
   - <thread or open question>
   ```

3. Invoke the mythic subagent to adjust the chaos factor based on whether the player was in or out of control of the session arc. Default in Phase 1: leave unchanged. If asked for a recommendation, surface the question to the user.

4. Run:
   ```
   git add -A
   git commit -m "session NNN: <one-line summary>"
   ```

5. Report success and the commit hash to the user.

Phase 1 does **not** run a bookkeeper verification phase — that lands in Phase 4. The working-tree-as-committed is trusted as the session record.
```

- [ ] **Step 5: Verify all four files**

```bash
ls .claude/commands/
cat .claude/commands/roll.md
cat .claude/commands/ask-oracle.md
cat .claude/commands/session-start.md
cat .claude/commands/session-end.md
```

Expected: all four files present with frontmatter and bodies.

- [ ] **Step 6: Commit**

```bash
git add .claude/commands/
git commit -m "Add Phase 1 slash commands

/roll, /ask-oracle, /session-start, /session-end. session-end is
lite (single commit, no bookkeeper verification — that's Phase 4)."
```

---

## Task 24: CLAUDE.md routing rules

**Files:**
- Create: `CLAUDE.md`

- [ ] **Step 1: Write the project CLAUDE.md**

```markdown
# Solo Campaign Engine — narrator routing

You are the **narrator** of a solo D&D campaign. The player drives one primary PC; you describe the world they experience, voice the NPCs they meet, and resolve the mechanical consequences of their declared actions. You never declare actions for the primary PC.

## Architecture you operate within

This project uses subagents and slash commands to enforce information asymmetry. You are the main agent. Three subagents and a custom MCP enforce the boundaries:

- **dice** subagent — resolves all mechanical rolls. Invoke for any roll. Never fabricate a result.
- **mythic** subagent — resolves genuinely uncertain yes/no questions. Invoke for any question whose answer you don't know and shouldn't decide.
- **world-state** subagent — owns hidden world state in `dm/`. Invoke for any question whose answer would require information you don't have access to.
- **dm-fs** MCP — only the world-state subagent can use it. You have **no path** to `dm/` content. The project's `.claude/settings.json` denies all read/write/grep/glob/bash access to `dm/**`.

## Routing rules (firm — these are the spec's load-bearing claims)

### 1. Dice routing

Any mechanical outcome — attack hit/miss, damage, save success/failure, skill check pass/fail — must come from the dice subagent or `/roll`. Never narrate "you hit," "you spot the door," or "the orc's blade glances off your armor" without a real roll behind it.

If you need a roll mid-narration, invoke the dice subagent with the appropriate expression or skill+character, then narrate based on the returned `total`.

### 2. Oracle routing

Any genuinely uncertain yes/no question — *will the merchant agree to the deal? are the guards alert? does the rumor turn out to be true?* — must go through the mythic subagent or `/ask-oracle`. You do not decide.

If the answer is determined by something already established (e.g., "is the door locked? — yes, the location file says it is"), you may narrate from that. But if there's genuine uncertainty, route it.

### 3. Hidden-info routing

Any question whose answer would require reading `dm/` content must go through the world-state subagent. You have no other path. Examples:

- "What does the merchant do when accused?" → world-state.
- "Is there more to the chapel than meets the eye?" → world-state.
- "What's actually motivating the Curate?" → world-state.

If you find yourself wanting to know something hidden, that's the cue to invoke world-state. Do not try to read `dm/` directly — the deny rules will stop you, and even attempting it is a routing error.

### 4. Primary PC authority

You never declare actions, dialogue, or reactions for the primary PC. If you believe the PC would do something — recognize a smell, react to a noise — surface it as a possibility for the player ("Sariel, your ranger ears pick up a footstep cadence — what do you do?") rather than narrating the action directly.

The matrix:
- Player decides: combat actions, dialogue, movement, accepting/refusing offers, equipment use.
- You decide: scene description, NPC voicing, mechanical consequences of declared actions.

## Session log conventions

Every session log lives at `sessions/play/YYYY/MM/session-NNN.md`. Append-only during play. Record:
- Inline rolls (the dice subagent appends these).
- Inline oracle results (the mythic subagent appends these).
- World-state queries (one-line summaries; the world-state subagent appends these).
- Scene boundary markers (you append `## Scene: <title>` at scene transitions).

The `/session-end` command appends a summary section and commits.

## Phase 1 scope

This is the Phase 1 build. You operate without revelations, librarian, milestones, or full bookkeeper. If you'd benefit from a feature that isn't here yet, note it in the session log under `## Notes for later phases` rather than improvising it.

## What "smart prep" means here

If the player goes somewhere not yet detailed, ask before generating: "I don't have detail on <place>. Want me to improvise a sketch for now, with a note for the bookkeeper to formalize later?" Then either improvise (flagged) or pause for the player.

## What you must never do

- Never read `dm/`. Don't try.
- Never narrate a mechanical outcome without a real roll.
- Never decide an uncertain yes/no without the oracle.
- Never declare an action for the primary PC.
- Never invent hidden state. If you don't know it and shouldn't decide it, route the question.
```

- [ ] **Step 2: Verify**

```bash
cat CLAUDE.md | head -30
```

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "Add project CLAUDE.md with Phase 1 narrator routing rules

Establishes the four routing rules (dice, oracle, hidden-info, primary
PC authority), session log conventions, and Phase 1 scope. This is the
narrator's operating manual."
```

---

## Task 25: Verify deny rules block direct dm/ access

**Files:**
- (None — this task is integration testing.)

This task verifies that the asymmetry enforcement layer works end-to-end before the smoke test runs. The implementer manually tests that the main agent (this Claude Code session) cannot read `dm/` files.

- [ ] **Step 1: Attempt direct read of dm/ file**

In a fresh interaction, attempt:
```
Read tool with file_path=/Users/barriault/dnd/gygaxagain/dm/npcs/<some-file>.md
```

Expected: a permission deny — the Read tool reports the path is denied. If the read succeeds, the deny rules are not in effect; debug `.claude/settings.json` syntax until the deny works. Common issues: glob pattern syntax, JSON escaping, file location.

- [ ] **Step 2: Attempt direct grep of dm/**

```
Bash: grep -r "anything" dm/
```

Expected: deny per `Bash(grep -r dm/*)` rule. If it succeeds, expand the deny rules until it blocks.

- [ ] **Step 3: Attempt cat of dm/ file**

```
Bash: cat dm/npcs/<file>.md
```

Expected: deny per `Bash(cat dm/*)` rule.

- [ ] **Step 4: If any of the above succeed, expand deny rules and re-test**

Note: Claude Code's exact glob support and Bash matching may differ from naive expectations. The implementer may need to add additional deny patterns. Document any additions in a comment in `.claude/settings.json` and update Task 18's reference output if needed.

- [ ] **Step 5: Once denies work, commit any updated settings.json**

```bash
git add .claude/settings.json
git commit -m "Refine dm/ deny rules based on bring-up test

Empirical adjustments after verifying the deny rules block direct
read/grep/cat attempts on dm/ files. The dm-fs MCP remains the only
path to dm/ content."
```

(If no changes needed, skip this commit.)

---

## Task 26: Verify world-state subagent can read dm/ via MCP

**Files:**
- (None — this task is integration testing.)

- [ ] **Step 1: Invoke the world-state subagent with a test query**

In a fresh interaction, invoke:
```
Use the world-state subagent to answer: "What does <NPC name> do when the party greets them politely?"
```

Expected: the subagent successfully invokes the dm-fs MCP, reads the public and hidden NPC sheets, and returns observable behavior. The response should:
- Describe what the party would see (mannerisms, body language, surface response).
- Optionally surface one of the "observable tells" from the hidden sheet if appropriate to the situation.
- **Not** include the underlying motivation, hidden facts, or any reveal not appropriate to the situation.

- [ ] **Step 2: Verify the response respects the asymmetry**

Manually inspect the response. If it leaks anything from the hidden sheet that shouldn't be observable yet, the world-state subagent's prompt needs tightening — return to Task 22 and adjust.

- [ ] **Step 3: Verify the dm-fs MCP was actually invoked**

Look at the tool-use trace for the world-state subagent. It should show calls to `dm-fs.read_dm_file` (or similar). If it didn't call the MCP, the mcpServers wiring is wrong — debug `.mcp.json` and the subagent's frontmatter.

- [ ] **Step 4: If any issue surfaces, fix and re-test before proceeding**

Common issues:
- MCP server not starting (check Python venv activation, DM_ROOT env var).
- Subagent doesn't see the MCP (check `mcpServers` frontmatter syntax).
- Subagent leaks hidden content (tighten the system prompt's "what you don't do" section).

- [ ] **Step 5: Commit any fixes**

```bash
git add -A
git commit -m "Refine world-state subagent and MCP wiring per integration test

Empirical adjustments to ensure dm-fs MCP invokes correctly and
asymmetry holds in observed behavior."
```

(If no changes needed, skip this commit.)

---

## Task 27: End-to-end smoke test

**Files:**
- (None — this task is the empirical Definition of Done.)

This task runs the smoke test described in the design's "Smoke test scenario" section. All four routing flows must fire. The narrator must not read `dm/`.

- [ ] **Step 1: Start a fresh Claude Code session in this project root**

Open a fresh Claude Code session in `/Users/barriault/dnd/gygaxagain`. Do not bring any prior context.

- [ ] **Step 2: Run `/session-start`**

Invoke `/session-start`. Expected:
- A new file at `sessions/play/2026/05/session-001.md` is created with the templated header.
- The narrator greets the player with a session brief (location, what's around, opening situation drawn from `world/home-base/`).
- The narrator describes the opening scene and asks what the player does.

- [ ] **Step 3: Trigger the dice routing flow**

As the player, declare an action that requires a roll. Example: "I make a Perception check to see what's unusual about the merchant."

Expected:
- The narrator invokes the dice subagent (visible in tool-use trace).
- The dice subagent invokes the dice CLI (`python -m dice.cli roll '1d20+<perception_mod>'`).
- A `total` comes back; the narrator narrates the consequence.
- One line is appended to the session log of the form `- ROLL: 1d20+<n> = <total> (<character> — perception)`.

- [ ] **Step 4: Trigger the oracle routing flow**

Ask a question with genuine uncertainty. Example: "Does the merchant recognize me from somewhere?"

Use `/ask-oracle does the merchant recognize me likely` (or similar) — or let the narrator route it.

Expected:
- The mythic subagent invokes the mythic CLI.
- A Yes/No (possibly Exceptional) comes back; the narrator weaves it in.
- One line is appended to the session log of the form `- ORACLE (likely, CF=5): yes [roll 28]`.

- [ ] **Step 5: Trigger the asymmetry routing flow**

Have the PC interact with the hidden-stub NPC in a way that should reveal an observable tell but not the underlying agenda. Example: "I ask the merchant about the southern road."

Expected:
- The narrator invokes the world-state subagent with "What does <merchant> do when asked about the southern road?"
- The world-state subagent invokes the dm-fs MCP's `read_dm_file` tool against `dm/npcs/<merchant>.md`.
- The world-state subagent returns observable behavior: e.g., "He stiffens slightly and glances toward the inn before answering, then says..."
- The narrator narrates this observable behavior to the player.
- The narration does **not** include the underlying motivation or hidden facts.

- [ ] **Step 6: Verify the narrator never read dm/ directly**

Inspect the tool-use trace from `/session-start` to this point. Search for any direct Read, Bash, Grep, or Glob calls against `dm/**`. There should be **none**. The only access to `dm/` should be through the world-state subagent's invocation of the dm-fs MCP.

If any direct access shows up:
- Determine whether the deny rules failed (Task 25 didn't catch it) or the narrator attempted and was blocked (acceptable but worth a note).
- Update `.claude/settings.json` deny rules if the access succeeded.

- [ ] **Step 7: Run `/session-end`**

Invoke `/session-end`. Expected:
- A session-end summary is appended to the log.
- The chaos factor may be adjusted (or left alone).
- A single git commit is created of the form `session 001: <summary>`.
- `git status` is clean afterward.

- [ ] **Step 8: Manually inspect the resulting commit**

```bash
git show HEAD --stat
git show HEAD -- sessions/play/2026/05/session-001.md
```

Expected: the diff includes the session log with all four routing flows visible (dice rolls inline, oracle calls inline, world-state queries inline, scene boundaries). The `dm/` files have **not** been modified (the world-state agent is read-only on `dm/` in Phase 1).

- [ ] **Step 9: Document the smoke test result**

Create `docs/superpowers/specs/2026-05-09-phase-1-smoke-result.md`:

```markdown
# Phase 1 smoke test result

**Date:** <today>
**Session log:** `sessions/play/2026/05/session-001.md`
**Commit:** <hash from session-end>

## Routing flows exercised

- [x] Dice routing — perception check at <log line ~N>, total <X>.
- [x] Oracle routing — <question> at <log line ~N>, outcome <X>.
- [x] World-state asymmetry — <NPC> behavior query at <log line ~N>, observable tell surfaced.
- [x] Session-start / session-end — full bracket.

## Asymmetry verification

The narrator did not read `dm/` directly during the session. Verified by:
- <how you verified — e.g., "tool-use trace inspection showed no Read/Bash/Grep against dm/**">
- <confirmation that deny rules fired if any such attempt occurred>

## Issues found

<list any issues discovered during smoke test, with resolution status>

## Phase 1 exit criteria

All Definition of Done items per the design doc satisfied:
- [x] One playable scene from /session-start through /session-end.
- [x] At least one dice roll through the dice subagent + script.
- [x] At least one Mythic oracle call through the mythic subagent + script.
- [x] At least one world-state query surfacing dm/ info to the narrator.
- [x] Narrator demonstrably could not read dm/** directly.
- [x] Session log written; /session-end produced one clean commit.

Phase 1 is complete.
```

- [ ] **Step 10: Commit the smoke test result**

```bash
git add docs/superpowers/specs/2026-05-09-phase-1-smoke-result.md
git commit -m "Record Phase 1 smoke test pass

All four routing flows exercised. Asymmetry boundary held. Phase 1
exit criteria met; ready to plan Phase 2 (hidden-state machinery)."
```

---

## Plan complete

Phase 1 is complete when Task 27 commits cleanly. Next phase (per design doc roadmap): **Phase 2 — Hidden-state machinery** (full world-state agent with faction clocks, revelation agent, expanded `dm/` population, mythic threads, hidden rolls, broader CLAUDE.md routing).
