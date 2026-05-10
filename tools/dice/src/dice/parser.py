"""Dice expression parser.

Grammar (Phase 1):
    expression := term ( ('+' | '-') term )*
    term       := dice | constant
    dice       := <count>d<sides>[k(h|l)<n>]
    constant   := <integer>
"""

from __future__ import annotations

import re
import secrets
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


def _roll_die(sides: int) -> int:
    return secrets.randbelow(sides) + 1


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
