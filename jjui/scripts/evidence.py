#!/usr/bin/env python3
"""Screenshot evidence reconciliation for jjui prototypes.

命名契约：<page_id>-<场景>.png（如 p-01-dashboard.png、p-02-customers-empty.png）。
截图必须用绝对路径落盘到 .jjui/reports/screenshots/，本脚本做逐页对账，
不依赖 AI 记忆或截图工具的返回消息。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from jjui_lib import read_json

SCREENSHOTS_DIR = ".jjui/reports/screenshots"
PAGE_PLAN = ".jjui/page-plan.json"
MIN_BYTES = 1024  # 低于该值视为可疑截图（空白页/失败输出通常极小）


def check(root: Path) -> int:
    root = root.resolve()
    try:
        plan = read_json(root / PAGE_PLAN)
    except Exception as exc:
        print(f"ERROR: page-plan 不可读: {exc}", file=sys.stderr)
        return 2
    pages = plan.get("pages")
    if not isinstance(pages, list) or not pages:
        print("ERROR: page-plan.pages 须为非空数组", file=sys.stderr)
        return 2

    shots = root / SCREENSHOTS_DIR
    if not shots.is_dir():
        print(f"ERROR: 截图目录缺失: {shots}", file=sys.stderr)
        return 2

    files = sorted(p for p in shots.iterdir() if p.is_file())
    known_prefixes = tuple(f"{page.get('id', '')}-" for page in pages)
    stray = [p for p in files if not p.name.startswith(known_prefixes)]

    missing: list[str] = []
    suspicious: list[str] = []
    ok: list[str] = []
    for page in pages:
        page_id = page.get("id", "")
        slug = page.get("slug", "")
        matched = [p for p in files if p.name.startswith(f"{page_id}-")]
        if not matched:
            missing.append(f"{page_id}-{slug}.png")
            continue
        tiny = [p.name for p in matched if p.stat().st_size < MIN_BYTES]
        if tiny:
            suspicious.extend(tiny)
        else:
            ok.append(f"{page_id}({len(matched)} 张)")

    for name in stray:
        print(f"WARN: 命名不符页面 ID 前缀: {name}")
    for name in suspicious:
        print(f"FAIL: 截图过小（疑似空白/失败输出）: {name}")
    for name in missing:
        print(f"FAIL: 页面缺截图物证: {name}")
    for name in ok:
        print(f"OK: {name}")

    if missing or suspicious:
        print("EVIDENCE CHECK FAIL")
        return 1
    print("EVIDENCE CHECK PASS")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)
    p_check = sub.add_parser("check", help="逐页对账截图物证")
    p_check.add_argument("target", type=Path)
    p_check.set_defaults(func=lambda a: check(a.target))
    return result


def main() -> int:
    args = parser().parse_args()
    try:
        return args.func(args)
    except OSError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
