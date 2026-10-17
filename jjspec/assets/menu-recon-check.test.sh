#!/usr/bin/env bash
# menu-recon-check.test.sh — menu-recon-check.sh 回归测试
# 在临时目录构造最小 spec 包与路由清单，逐一验证三源对账 fail-closed；全部通过输出 ALL PASS。
# 覆盖：三源一致放行 / 自造菜单拦截 / 菜单缺失拦截 / 排除命中拦截 / 排除名单缺省 /
#       排除名双向包含命中 / 无菜单页 + 实现非空全算自造
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/menu-recon-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

FAILED=0
expect() { # expect <场景名> <期望退出码> <输出须含的模式(空=不查)> <参数…>
  local name="$1" want="$2" pat="${3:-}"; shift 3
  local rc out
  out="$(bash "${SCRIPT}" "$@" 2>&1)" && rc=0 || rc=$?
  if [ "${rc}" -eq "${want}" ] && { [ -z "${pat}" ] || grep -q "${pat}" <<< "${out}"; }; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}(期望退出码 ${want}、输出含「${pat:-—}」，实际 ${rc})"
    echo "---- 输出 ----"; echo "${out}"; echo "--------------"
    FAILED=1
  fi
}

mk_spec() { # mk_spec <目标目录> —— 构造最小 spec 包（p-01 菜单页、p-02 页内入口页）
  local d="$1"
  mkdir -p "${d}/pages" "${d}/icons"
  printf '{"icons":[]}' > "${d}/icons/icons.json"
  printf ':root{--c:#fff}' > "${d}/tokens.css"
  printf -- '---\ntitle: 首页看板\nsource_anchor: figma 1:2\nentry: menu, internal-entry\n---\n# 首页看板\n' > "${d}/pages/p-01-home.md"
  printf -- '---\ntitle: 数据详情\nsource_anchor: figma 1:3\nentry: internal-entry\n---\n# 数据详情\n' > "${d}/pages/p-02-detail.md"
}

mk_routes() { # mk_routes <目标文件> <行…>
  local f="$1"; shift
  printf '%s\n' "$@" > "${f}"
}

# 场景1：三源一致（实现注册 = spec 菜单页，无排除）→ 放行
mk_spec "${WORK}/s1"
mk_routes "${WORK}/r1" 'pages/home/index|首页看板' '# 侧栏菜单注册表'
expect "三源一致放行" 0 "MENU-RECON PASS" --spec "${WORK}/s1" --routes "${WORK}/r1"

# 场景2：实现自造菜单（routes.js 多挂「数据看板」——本次事故场景）→ 拦截
mk_spec "${WORK}/s2"
mk_routes "${WORK}/r2" 'pages/home/index|首页看板' 'pages/board/index|数据看板'
expect "自造菜单拦截" 1 "自造菜单" --spec "${WORK}/s2" --routes "${WORK}/r2"

# 场景3：spec 菜单页未在实现注册 → 拦截（两页均 entry: menu，实现只注册其一）
mk_spec "${WORK}/s3"
printf -- '---\ntitle: 数据详情\nsource_anchor: figma 1:3\nentry: menu\n---\n# 数据详情\n' > "${WORK}/s3/pages/p-02-detail.md"
mk_routes "${WORK}/r3" 'pages/home/index|首页看板'
expect "菜单缺失拦截" 1 "菜单缺失" --spec "${WORK}/s3" --routes "${WORK}/r3"

# 场景4：排除命中——实现注册的菜单名命中 PRD 排除名单 → 拦截
mk_spec "${WORK}/s4"
printf -- '---\ntitle: 首页看板\nsource_anchor: figma 1:2\nentry: menu\n---\n# 首页看板\n' > "${WORK}/s4/pages/p-01-home.md"
printf -- '---\ntitle: 数据看板\nsource_anchor: figma 1:3\nentry: menu\n---\n# 数据看板\n' > "${WORK}/s4/pages/p-02-board.md"
mk_routes "${WORK}/r4" 'pages/home/index|首页看板' 'pages/board/index|数据看板'
mk_routes "${WORK}/x4" '# PRD 非目标表导出' '数据看板'
expect "排除命中拦截" 1 "排除项命中" --spec "${WORK}/s4" --routes "${WORK}/r4" --excluded "${WORK}/x4"

# 场景5：同包不带排除名单 → 放行（--excluded 可选）
expect "排除名单缺省放行" 0 "MENU-RECON PASS" --spec "${WORK}/s4" --routes "${WORK}/r4"

# 场景6：排除名双向包含（排除名「数据看板」命中实现名「数据看板管理」）→ 拦截
mk_spec "${WORK}/s5"
mk_routes "${WORK}/r5" 'pages/home/index|首页看板' 'pages/board-mgmt/index|数据看板管理'
mk_routes "${WORK}/x5" '数据看板'
expect "排除名双向包含拦截" 1 "排除项命中" --spec "${WORK}/s5" --routes "${WORK}/r5" --excluded "${WORK}/x5"

# 场景7：spec 无 menu 页 + 实现注册非空 → 全部算自造，拦截（fail-closed）
mk_spec "${WORK}/s6"
printf -- '---\ntitle: 首页看板\nsource_anchor: figma 1:2\nentry: internal-entry\n---\n# 首页看板\n' > "${WORK}/s6/pages/p-01-home.md"
mk_routes "${WORK}/r6" 'pages/home/index|首页看板'
expect "无菜单页全算自造拦截" 1 "自造菜单" --spec "${WORK}/s6" --routes "${WORK}/r6"

[ "${FAILED}" -eq 0 ] && echo "ALL PASS" || exit 1
