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
