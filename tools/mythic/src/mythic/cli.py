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
