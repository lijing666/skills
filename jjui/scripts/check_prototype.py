#!/usr/bin/env python3
"""Deterministic structural check for a jjui admin prototype."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from jjui_lib import validate_root


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", type=Path, help="原型目录")
    args = parser.parse_args()
    errors = validate_root(args.root.resolve())
    if errors:
        print("PROTOTYPE CHECK FAIL", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("PROTOTYPE CHECK PASS")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
