#!/usr/bin/env bash
# ui-pack-check.test.sh — ui-pack-check.sh 回归测试
# 在临时目录构造最小合规包，逐一破坏各校验点验证 fail-closed；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：合规包放行 / 缺 icons.json / 缺类别行 / 「无」缺理由 / 图标处置非法 /
#       位图素材=assets 缺 assets.md / 素材清单未处置条目 / 字体族=assets 缺 assets.md /
#       页面跳号 / 页面缺锚点 / 缺 tokens / 非法 JSON
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/ui-pack-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

FAILED=0
expect() { # expect <场景名> <期望退出码> <输出须含的模式(空=不查)> <被检目录…>
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

mk_pack() { # mk_pack <目标目录> —— 构造最小合规包
  local d="$1"
  mkdir -p "${d}/pages" "${d}/icons"
  cat > "${d}/README.md" <<'EOF'
---
title: 测试规范
type: ui-spec
---
# 测试规范
## 页面索引
- p-01 登录
- p-02 列表
## 资产类别登记
| 类别 | 处置 | 数量/说明 |
|---|---|---|
| 颜色 | token化 | 10 |
| 字号 | token化 | 5 |
| 字重 | 无 | 设计稿未约束字重 |
| 行高 | token化 | 3 |
| 字体族 | token化 | 2 |
| 间距 | token化 | 8 |
| 圆角 | token化 | 4 |
| 边框 | 无 | 无边框风格 |
| 阴影 | 无 | 平面风格无阴影 |
| 透明度 | 无 | 未使用元素级透明度 |
| 渐变 | token化 | 2 |
| 布局 | token化 | 6 |
| 动效 | 无 | 一期无动效 |
| 图标 | icons.json | 12 |
| 位图素材 | 无 | 原型无位图 |
EOF
  printf ':root{--c:#fff}' > "${d}/tokens.css"
  printf '{"menu":{}}' > "${d}/icons/icons.json"
  printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\n---\n# 登录\n' > "${d}/pages/p-01-login.md"
  printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\n---\n# 列表\n' > "${d}/pages/p-02-list.md"
}

# 场景1：合规包 → 通过
mk_pack "${WORK}/c00"
expect "合规包放行" 0 "UI-PACK PASS" "${WORK}/c00"

# 场景2：缺 icons/icons.json → 拦截
mk_pack "${WORK}/c01"; rm "${WORK}/c01/icons/icons.json"
expect "缺 icons.json 拦截" 1 "icons.json" "${WORK}/c01"

# 场景3：登记表缺「行高」行 → 拦截
mk_pack "${WORK}/c02"; grep -v '^| 行高' "${WORK}/c02/README.md" > "${WORK}/c02/rm.tmp" && mv "${WORK}/c02/rm.tmp" "${WORK}/c02/README.md"
expect "缺类别行拦截" 1 "缺「行高」行" "${WORK}/c02"

# 场景4：「无」处置未写理由 → 拦截
mk_pack "${WORK}/c03"; sed 's/^| 字重 | 无 | 设计稿未约束字重 |/| 字重 | 无 | |/' "${WORK}/c03/README.md" > "${WORK}/c03/rm.tmp" && mv "${WORK}/c03/rm.tmp" "${WORK}/c03/README.md"
expect "「无」缺理由拦截" 1 "未写理由" "${WORK}/c03"

# 场景5：「图标」处置非 icons.json → 拦截
mk_pack "${WORK}/c04"; sed 's/^| 图标 | icons.json | 12 |/| 图标 | token化 | 12 |/' "${WORK}/c04/README.md" > "${WORK}/c04/rm.tmp" && mv "${WORK}/c04/rm.tmp" "${WORK}/c04/README.md"
expect "图标处置非法拦截" 1 "「图标」行处置" "${WORK}/c04"

# 场景6：位图素材=assets 但缺 assets.md → 拦截
mk_pack "${WORK}/c05"; sed 's/^| 位图素材 | 无 | 原型无位图 |/| 位图素材 | assets | 1 张背景图 |/' "${WORK}/c05/README.md" > "${WORK}/c05/rm.tmp" && mv "${WORK}/c05/rm.tmp" "${WORK}/c05/README.md"
expect "assets 处置缺 assets.md 拦截" 1 "assets.md" "${WORK}/c05"

# 场景7：素材清单含未处置条目 → 拦截
mk_pack "${WORK}/c06"
sed 's/^| 位图素材 | 无 | 原型无位图 |/| 位图素材 | assets | 1 张背景图 |/' "${WORK}/c06/README.md" > "${WORK}/c06/rm.tmp" && mv "${WORK}/c06/rm.tmp" "${WORK}/c06/README.md"
mkdir -p "${WORK}/c06/assets"
printf 'x' > "${WORK}/c06/assets/bg.png"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途 | 处置 |\n|---|---|---|---|---|\n| bg.png | 背景 | figma 1:2 | p-01 | 待导出 |\n' > "${WORK}/c06/assets/assets.md"
expect "素材清单未终态处置条目拦截" 1 "未终态处置" "${WORK}/c06"

# 场景8：字体族=assets 但缺 assets.md → 拦截（assets 通用检查覆盖非位图类）
mk_pack "${WORK}/c07"; sed 's/^| 字体族 | token化 | 2 |/| 字体族 | assets | 1 个自定义字体 |/' "${WORK}/c07/README.md" > "${WORK}/c07/rm.tmp" && mv "${WORK}/c07/rm.tmp" "${WORK}/c07/README.md"
expect "字体族=assets 缺 assets.md 拦截" 1 "assets.md" "${WORK}/c07"

# 场景9：页面编号跳号 → 拦截
mk_pack "${WORK}/c08"; mv "${WORK}/c08/pages/p-02-list.md" "${WORK}/c08/pages/p-03-list.md"
expect "页面跳号拦截" 1 "跳号" "${WORK}/c08"

# 场景10：页面缺 source_anchor → 拦截
mk_pack "${WORK}/c09"; sed '/source_anchor/d' "${WORK}/c09/pages/p-01-login.md" > "${WORK}/c09/rm.tmp" && mv "${WORK}/c09/rm.tmp" "${WORK}/c09/pages/p-01-login.md"
expect "页面缺锚点拦截" 1 "source_anchor" "${WORK}/c09"

# 场景11：缺 tokens 文件 → 拦截
mk_pack "${WORK}/c10"; rm "${WORK}/c10/tokens.css"
expect "缺 tokens 文件拦截" 1 "tokens" "${WORK}/c10"

# 场景12：icons.json 非法 JSON → 拦截
mk_pack "${WORK}/c11"; printf 'not json' > "${WORK}/c11/icons/icons.json"
expect "icons.json 非法 JSON 拦截" 1 "合法 JSON" "${WORK}/c11"

# ── 页面消化门槛（--require-digest）──

# 场景13：全部页无 digest + --require-digest → 拦截
mk_pack "${WORK}/c12"
expect "消化门槛：全页无 digest 拦截" 1 "digest" "${WORK}/c12" --require-digest

# 场景14：p-01 quantified（含量化表段）、p-02 list-level + --require-digest p-01 → 放行（单页门槛）
mk_pack "${WORK}/c13"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 bg--color-primary |\n' > "${WORK}/c13/pages/p-01-login.md"
expect "消化门槛：单页 quantified 放行" 0 "UI-PACK PASS" "${WORK}/c13" --require-digest p-01

# 场景15：同包 + --require-digest（全量）→ 拦截（p-02 仍 list-level）
expect "消化门槛：全量模式拦截清单级页" 1 "digest" "${WORK}/c13" --require-digest

# 场景16：全部页 quantified（含量化表段）+ --require-digest → 放行
mk_pack "${WORK}/c14"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n' > "${WORK}/c14/pages/p-01-login.md"
printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\ndigest: quantified\n---\n# 列表\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| list | h88 p12 |\n' > "${WORK}/c14/pages/p-02-list.md"
expect "消化门槛：全页 quantified 放行" 0 "UI-PACK PASS" "${WORK}/c14" --require-digest

# 场景17：不带开关时 digest 缺失不影响（向后兼容）
expect "向后兼容：无开关不校验 digest" 0 "UI-PACK PASS" "${WORK}/c12"

# 场景18：中文短名拦截（宪法第九节第 10 条：英文短名 kebab-case）
mk_pack "${WORK}/c15"
mv "${WORK}/c15/pages/p-01-login.md" "${WORK}/c15/pages/p-01-登录.md"
expect "中文短名拦截" 1 "英文 kebab-case" "${WORK}/c15"

# 场景19：quantified 缺「节点样式量化表」段落拦截（单页模式）
mk_pack "${WORK}/c16"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\n---\n# 登录\n\n- 主用色：#000000(×19)\n' > "${WORK}/c16/pages/p-01-login.md"
expect "quantified 缺量化表段拦截" 1 "节点样式量化表" "${WORK}/c16" --require-digest p-01

[ "${FAILED}" -eq 0 ] && echo "ALL PASS" || exit 1
