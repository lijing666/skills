#!/usr/bin/env bash
# menu-recon-check.sh — 菜单三源对账门禁（fail-closed）
# 规则正源：prd-constitution.md 第九节第 12 条（菜单结构正源与排除项消费）、taskcard-template 拆卡规则 9
#   与页面卡「## 菜单/入口对账」固定节。菜单结构唯一正源 = ui-specs 中 entry 含 menu 的页面清单，
#   禁止以原型/工程源码数据结构（页面枚举、路由表、state 定义）推断菜单结构。
# 用法：menu-recon-check.sh --spec <ui-specs目录> --routes <路由清单文件> [--excluded <排除名单文件>]
#   --spec      ui-specs 规范包目录：读 pages/p-*.md frontmatter 的 entry 与 title 字段
#   --routes    实现工程路由注册表导出文件：每行一条 `页面路径[|菜单显示名]`
#               （无显示名时以路径尾段作名称；# 注释行与空行忽略）
#   --excluded  PRD 非目标表排除名单导出文件：每行一个被排除的菜单/页面名
#               （# 注释行与空行忽略；名称匹配为双向包含——排除名「数据看板」命中实现名「数据看板管理」）
# 对账（任一失败即退出 1 并逐条列明；全部通过输出 MENU-RECON PASS）：
#   1. 自造菜单（新增）：实现注册的菜单名不在 spec 的 entry: menu 页面名集合 → FAIL
#   2. 菜单缺失：spec 中 entry 含 menu 的页面在实现注册表中无对应项 → FAIL
#   3. 排除命中：实现注册的菜单名命中排除名单 → FAIL（永久排除/未解禁推迟项不得挂菜单）
#   4. 名称归一口径：去首尾空格后比较；spec 页面名取 frontmatter title，缺省用文件短名
# 输出：三源对账明细（spec 菜单清单 / 实现注册清单 / 差集 / 排除命中），禁止只报结论
# 执行前提：bash + python3（macOS/Linux 原生自带）。
set -uo pipefail

SPEC=""
ROUTES=""
EXCLUDED=""
_pending=""
for _arg in "$@"; do
  if [ -n "${_pending}" ]; then
    case "${_pending}" in
      spec) SPEC="${_arg}" ;;
      routes) ROUTES="${_arg}" ;;
      excluded) EXCLUDED="${_arg}" ;;
    esac
    _pending=""
    continue
  fi
  case "${_arg}" in
    --spec) _pending="spec" ;;
    --routes) _pending="routes" ;;
    --excluded) _pending="excluded" ;;
    *) echo "未知参数: ${_arg}"; exit 2 ;;
  esac
done
unset _pending _arg

[ -n "${SPEC}" ] && [ -d "${SPEC}" ] || { echo "用法: menu-recon-check.sh --spec <ui-specs目录> --routes <路由清单文件> [--excluded <排除名单文件>]"; exit 2; }
[ -n "${ROUTES}" ] && [ -f "${ROUTES}" ] || { echo "缺 --routes 路由清单文件（实现工程路由注册表导出）"; exit 2; }

python3 - "${SPEC}" "${ROUTES}" "${EXCLUDED}" <<'PYEOF'
import os
import re
import sys

spec_dir, routes_f, excl_f = sys.argv[1], sys.argv[2], (sys.argv[3] if len(sys.argv) > 3 else '')


def fm_field(path, key):
    """读取 markdown frontmatter 中指定 key 的值（首行 --- 起至次行 --- 止）。"""
    fm = False
    try:
        with open(path, encoding='utf-8') as f:
            for line in f:
                s = line.rstrip('\r\n')
                if s.strip() == '---':
                    if fm:
                        break
                    fm = True
                    continue
                if fm and s.startswith(key + ':'):
                    return s[len(key) + 1:].strip()
    except OSError:
        return ''
    return ''


# 源1：spec 中 entry 含 menu 的页面（名称 → 文件）
spec_menu = {}
for p in sorted(os.path.join(spec_dir, 'pages', f) for f in os.listdir(os.path.join(spec_dir, 'pages')) if re.match(r'^p-\d+-.*\.md$', f)):
    entry = fm_field(p, 'entry') or ''
    vals = {v.strip() for v in entry.split(',') if v.strip()}
    if 'menu' not in vals:
        continue
    title = fm_field(p, 'title') or re.sub(r'^p-\d+-|\.md$', '', os.path.basename(p))
    spec_menu[title] = os.path.basename(p)

# 源2：实现工程路由注册表（名称 → 路由行）
impl_menu = {}
with open(routes_f, encoding='utf-8') as f:
    for line in f:
        s = line.strip()
        if not s or s.startswith('#'):
            continue
        parts = s.split('|')
        if len(parts) > 1 and parts[1].strip():
            name = parts[1].strip()
        else:
            name = parts[0].rstrip('/').split('/')[-1]
        impl_menu[name] = parts[0].strip()

# 源3：排除名单
excluded = []
if excl_f and os.path.exists(excl_f):
    with open(excl_f, encoding='utf-8') as f:
        for line in f:
            s = line.strip()
            if s and not s.startswith('#'):
                excluded.append(s)

extra = sorted(set(impl_menu) - set(spec_menu))
missing = sorted(set(spec_menu) - set(impl_menu))
all_names = set(impl_menu) | set(spec_menu)
hits = sorted(n for n in all_names for e in excluded if e in n or n in e)

print('— 三源对账明细 —')
print('spec 菜单清单（entry 含 menu）:')
for n, f in sorted(spec_menu.items()):
    print(f'  [spec] {n}  ({f})')
print('实现注册清单（--routes）:')
for n, r in sorted(impl_menu.items()):
    print(f'  [impl] {n}  ({r})')
if excluded:
    print('排除名单（--excluded）:')
    for e in excluded:
        print(f'  [excl] {e}')

fails = []
if extra:
    fails.append('自造菜单（实现有而 spec 无——菜单正源在规范包，宪法第九节第 12 条）: ' + '、'.join(extra))
if missing:
    fails.append('菜单缺失（spec entry: menu 页面未在实现注册）: ' + '、'.join(missing))
if hits:
    fails.append('排除项命中（永久排除/未解禁推迟项不得挂菜单）: ' + '、'.join(hits))

if fails:
    print(f'MENU-RECON FAIL（{len(fails)} 项）:')
    for x in fails:
        print(f'  - {x}')
    sys.exit(1)
print('MENU-RECON PASS: 三源一致，无自造菜单、无缺失、无排除命中')
sys.exit(0)
PYEOF
