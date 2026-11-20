#!/usr/bin/env python3
"""Screenshot evidence reconciliation for jjui prototypes.

命名规则正源：references/prototype-contract.md 截图物证纪律段。
本脚本只做确定性对账：命名、非 0 字节，不依赖 AI 记忆或截图工具的返回消息。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from jjui_lib import read_json

SCREENSHOTS_DIR = ".jjui/reports/screenshots"
PAGE_PLAN = ".jjui/page-plan.json"
MIN_BYTES = 1024  # 低于该值视为可疑截图（空白页/失败输出通常极小）


# 命名规则正源: references/prototype-contract.md 截图物证纪律段
def screenshot_name(page: dict) -> str:
    return f"{page.get('id', '')}-{page.get('slug', '')}.png"


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

    # 忽略点文件（macOS Finder 的 .DS_Store、.gitkeep 等），避免命名对账误伤
    files = sorted(p for p in shots.iterdir() if p.is_file() and not p.name.startswith("."))
    expected = {screenshot_name(page) for page in pages}
    stray = [p.name for p in files if p.name not in expected]

    missing: list[str] = []
    suspicious: list[str] = []
    ok: list[str] = []
    for page in pages:
        page_id = page.get("id", "")
        name = screenshot_name(page)
        shot = shots / name
        if not shot.is_file():
            missing.append(name)
            continue
        if shot.stat().st_size < MIN_BYTES:
            suspicious.append(name)
            continue
        ok.append(page_id)

    for name in stray:
        print(f"FAIL: 截图目录存在非预期命名文件（规则见 references/prototype-contract.md 截图物证纪律段）: {name}")
    for name in suspicious:
        print(f"FAIL: 截图过小（疑似空白/失败输出）: {name}")
    for name in missing:
        print(f"FAIL: 页面缺截图物证: {name}")
    for page_id in ok:
        print(f"OK: {page_id}")

    if stray or missing or suspicious:
        print("EVIDENCE CHECK FAIL")
        return 1
    print("EVIDENCE CHECK PASS")
    return 0


def parser() -> argparse.ArgumentParser:
    result = argparse.ArgumentParser(description=__doc__)
    sub = result.add_subparsers(dest="command", required=True)
    p_check = sub.add_parser("check", help="逐页对账截图物证（命名 + 非 0 字节）")
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
