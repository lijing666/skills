#!/usr/bin/env python3
"""Initialize a jjui admin prototype from a stack template."""

from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path

from jjui_lib import SLUG_RE, STACKS, replace_tokens, validate_root

HERE = Path(__file__).resolve().parent


def init(args) -> int:
    if args.stack not in STACKS:
        raise ValueError(f"非法技术栈: {args.stack}")
    if not SLUG_RE.match(args.product_id):
        raise ValueError("product-id 须为 kebab-case")
    if not SLUG_RE.match(args.business):
        raise ValueError("business 须为 kebab-case")
    target = args.target.resolve()
    if target.exists() and any(target.iterdir()):
        raise ValueError(f"目标目录非空: {target}")
    template = HERE.parent / "assets" / f"{args.stack}-template"
    shutil.copytree(template, target, dirs_exist_ok=True)
    for rel in (".jjui/reports/screenshots", ".jjui/reports/smoke"):
        (target / rel).mkdir(parents=True, exist_ok=True)
    replace_tokens(target, args.product_id, args.business)
    errors = validate_root(target)
    if errors:
        raise ValueError("初始化校验失败:\n- " + "\n- ".join(errors))
    print(f"INIT PASS: {target}")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)
    p_init = sub.add_parser("init", help="从指定技术栈模板初始化原型")
    p_init.add_argument("target", type=Path)
    p_init.add_argument("--stack", required=True, choices=sorted(STACKS))
    p_init.add_argument("--product-id", required=True)
    p_init.add_argument("--business", required=True)
    p_init.set_defaults(func=init)
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        return args.func(args)
    except (OSError, ValueError, KeyError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
