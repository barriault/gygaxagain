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
