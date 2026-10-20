#!/usr/bin/env bash
# ui-pack-check.test.sh — ui-pack-check.sh 回归测试
# 在临时目录构造最小合规包，逐一破坏各校验点验证 fail-closed；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：合规包放行 / 缺 icons.json / 缺类别行 / 「无」缺理由 / 图标处置非法 /
#       位图素材=assets 缺 assets.md / 素材清单未处置条目 / 字体族=assets 缺 assets.md /
#       页面跳号 / 页面缺锚点 / 缺 tokens / 非法 JSON / 引用素材不出清单 /
#       icons.json svg 指向缺失 / 品牌字体缺字体文件条目 / 品牌字体有字体条目放行
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/ui-pack-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

FAILED=0
expect() { # expect <场景名> <期望退出码> <输出须含的模式(空=不查)> <被检目录…>
  local name="$1" want="$2" pat="${3:-}"; shift 3
  if [ "${want}" -eq 0 ] && [[ " $* " == *" --require-digest "* ]]; then
    prepare_digest_fixture "$1"
  fi
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

prepare_digest_fixture() { # add source scan ledger to otherwise-valid quantified test fixtures
  local d="$1" p n
  for p in "${d}"/pages/p-*.md; do
    [ -f "${p}" ] || continue
    grep -q '^digest: quantified$' "${p}" || continue
    n="$(awk '
      /^## 节点样式量化表/{in_table=1;next}
      /^## /&&in_table{exit}
      in_table&&/^\|/{line=$0;gsub(/[[:space:]]/,"",line);if(line !~ /^\|[-:|]+\|$/) rows++}
      END{print (rows > 0 ? rows-1 : 0)}
    ' "${p}")"
    if ! grep -q '^source_node_count:' "${p}"; then
      awk -v n="${n}" '/^digest: quantified$/{print;print "source_node_count: " n;next}{print}' "${p}" > "${p}.tmp" && mv "${p}.tmp" "${p}"
    fi
    if ! grep -q '^## 源节点覆盖对账' "${p}"; then
      {
        printf '\n## 源节点覆盖对账\n\n| 源定位符 | 分类/处理方式 | 量化表对应行 | 排除理由 |\n|---|---|---|---|\n'
        awk '
          /^## 节点样式量化表/{in_table=1;next}
          /^## /&&in_table{exit}
          in_table&&/^\|/ {
            line=$0; gsub(/[[:space:]]/,"",line)
            if(line ~ /^\|[-:|]+\|$/) next
            split($0, cells, "|")
            id=cells[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
            if(!header++){next}
            printf "| %s | 量化 | %s | — |\n", id, id
          }
        ' "${p}"
        printf '源节点覆盖: source=%s spec=%s uncovered=0\n' "${n}" "${n}"
      } >> "${p}"
    fi
  done
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
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 bg--color-primary |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n\n动态数据区：.demo-data\n' > "${WORK}/c13/pages/p-01-login.md"
expect "消化门槛：单页 quantified 放行" 0 "UI-PACK PASS" "${WORK}/c13" --require-digest p-01

# 场景15：同包 + --require-digest（全量）→ 拦截（p-02 仍 list-level）
expect "消化门槛：全量模式拦截清单级页" 1 "digest" "${WORK}/c13" --require-digest

# 场景16：全部页 quantified（含量化表段）+ --require-digest → 放行
mk_pack "${WORK}/c14"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c14/pages/p-01-login.md"
printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\ndigest: quantified\nentry: menu\n---\n# 列表\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| list | h88 p12 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 列表 | 标题 |\n' > "${WORK}/c14/pages/p-02-list.md"
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

# 场景20：pages/ 引用不存在的 icons/*.svg → 拦截（宪法第九节第 9 条：引用不出清单）
mk_pack "${WORK}/c17"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\n---\n# 登录\n图标 icons/missing-icon.svg\n' > "${WORK}/c17/pages/p-01-login.md"
expect "pages 引用素材缺失拦截" 1 "引用素材缺失" "${WORK}/c17"

# 场景21：icons.json svg 字段指向不存在的文件 → 拦截
mk_pack "${WORK}/c18"
printf '{"icons":[{"id":"i1","svg":"ghost.svg"}]}' > "${WORK}/c18/icons/icons.json"
expect "icons.json svg 指向缺失拦截" 1 "svg 指向文件缺失" "${WORK}/c18"

# 场景22：tokens 含品牌字体（非系统白名单）但 assets.md 无字体文件条目 → 拦截（guide「字体处置拆分」）
mk_pack "${WORK}/c19"
printf ':root{--app-font-brand:"Alibaba PuHuiTi 2.0", sans-serif}' > "${WORK}/c19/tokens.css"
expect "品牌字体缺字体文件条目拦截" 1 "品牌字体族" "${WORK}/c19"

# 场景23：同场景22 但 assets.md 有字体文件条目（人工补录登记态：基础模式放行，定稿门禁下为挂起）→ 放行
mk_pack "${WORK}/c20"
printf ':root{--app-font-brand:"Alibaba PuHuiTi 2.0", sans-serif}' > "${WORK}/c20/tokens.css"
mkdir -p "${WORK}/c20/assets"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途 | 处置 |\n|---|---|---|---|---|\n| — | 字体-AlibabaPuHuiTi | 设计稿字体引用 | 全部品牌标题页 | 人工补录 |\n' > "${WORK}/c20/assets/assets.md"
expect "品牌字体有字体条目放行" 0 "UI-PACK PASS" "${WORK}/c20"

# 场景24：digest=quantified 有量化表段但缺布局语义表段 → 拦截（guide「布局语义必须入表」（量化表定义））
mk_pack "${WORK}/c21"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| a |\n|---|\n| b |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c21/pages/p-01-login.md"
expect "quantified 缺布局语义表拦截" 1 "布局语义表" "${WORK}/c21" "--require-digest"

# 场景28：status: withdrawn 裁撤占位页（digest: list-level、无量化表）+ --require-digest → 放行（设计收敛占位页跳过消化门槛，保留编号连续性）
mk_pack "${WORK}/c23"
rm -f "${WORK}/c23/pages/p-02-list.md"
printf -- '---\ntitle: 登录变体\nsource_anchor: figma 1:2\ndigest: list-level\nentry: internal-entry\nstatus: withdrawn\n---\n# 登录变体（已裁撤）\n\n设计收敛，源帧删除，本页裁撤占位。\n' > "${WORK}/c23/pages/p-01-login.md"
expect "裁撤页跳过消化门槛放行" 0 "UI-PACK PASS" "${WORK}/c23" --require-digest

# ── 定稿清零门禁（--require-final，宪法第九节第 11 条）──

# 场景25：assets.md 人工补录挂起条目 + --require-final → 拦截（挂起态非终态；复用场景23 的 c20 包）
expect "定稿门禁：人工补录挂起拦截" 1 "复刻阻塞清单未清零" "${WORK}/c20" --require-final

# 场景26：同 c20 包不带 --require-final → 放行（向后兼容：生成期人工补录登记合法）
expect "向后兼容：无定稿开关不校验挂起" 0 "UI-PACK PASS" "${WORK}/c20"

# 场景27：README 未决项残留人工补录登记 + --require-final → 拦截
mk_pack "${WORK}/c22"
printf '\n## 未决项\n\n- 字体文件：人工补录（设计侧未提供）\n' >> "${WORK}/c22/README.md"
expect "定稿门禁：README 残留人工补录拦截" 1 "人工补录" "${WORK}/c22" --require-final

# 场景28：字体文件经设计侧提供转已导出 + --require-final → 放行
mk_pack "${WORK}/c23"
printf ':root{--app-font-brand:"Alibaba PuHuiTi 2.0", sans-serif}' > "${WORK}/c23/tokens.css"
mkdir -p "${WORK}/c23/assets"
printf 'x' > "${WORK}/c23/assets/AlibabaPuHuiTi-2.0.ttf"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途 | 处置 |\n|---|---|---|---|---|\n| AlibabaPuHuiTi-2.0.ttf | 字体-AlibabaPuHuiTi | 设计稿字体引用·商用授权已确认 | 全部品牌标题页 | 已导出 |\n' > "${WORK}/c23/assets/assets.md"
expect "定稿门禁：字体已导出放行" 0 "UI-PACK PASS" "${WORK}/c23" --require-final

# 场景29：字体经用户批准转豁免（留替代口径）+ --require-final → 放行
mk_pack "${WORK}/c24"
printf ':root{--app-font-brand:"Alibaba PuHuiTi 2.0", sans-serif}' > "${WORK}/c24/tokens.css"
mkdir -p "${WORK}/c24/assets"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途 | 处置 |\n|---|---|---|---|---|\n| — | 字体-AlibabaPuHuiTi | 设计稿字体引用 | 全部品牌标题页 | 豁免 |\n' > "${WORK}/c24/assets/assets.md"
expect "定稿门禁：字体经批准豁免放行" 0 "UI-PACK PASS" "${WORK}/c24" --require-final

# 场景30：--require-digest --require-final 并用，双门禁各自生效（构造全 quantified + 人工补录挂起包）
mk_pack "${WORK}/c25"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c25/pages/p-01-login.md"
printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\ndigest: quantified\nentry: menu\n---\n# 列表\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| list | h88 p12 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 列表 | 标题 |\n' > "${WORK}/c25/pages/p-02-list.md"
mkdir -p "${WORK}/c25/assets"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途 | 处置 |\n|---|---|---|---|---|\n| — | 字体-AlibabaPuHuiTi | 设计稿字体引用 | 全部品牌标题页 | 人工补录 |\n' > "${WORK}/c25/assets/assets.md"
expect "并用：digest 过但人工补录挂起拦截" 1 "复刻阻塞清单未清零" "${WORK}/c25" --require-digest --require-final
expect "并用：仅 digest 开关挂起不拦（独立生效）" 0 "UI-PACK PASS" "${WORK}/c25" --require-digest

# ── entry 到达方式与文案清单（--require-digest 伴随校验，宪法第九节第 12 条）──

# 场景31：--require-digest 下页面缺 entry 字段 → 拦截
mk_pack "${WORK}/c26"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c26/pages/p-01-login.md"
expect "entry：缺失拦截" 1 "缺 entry 字段" "${WORK}/c26" --require-digest

# 场景32：entry 枚举外值 → 拦截
mk_pack "${WORK}/c27"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: sidebar\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c27/pages/p-01-login.md"
expect "entry：枚举非法拦截" 1 "entry 枚举非法" "${WORK}/c27" --require-digest

# 场景33：entry 多值合法（menu + internal-entry）→ 放行（复用 c14 全合规包改 p-01 为多值）
mk_pack "${WORK}/c28"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu, internal-entry\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c28/pages/p-01-login.md"
printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\ndigest: quantified\nentry: menu\n---\n# 列表\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| list | h88 p12 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 列表 | 标题 |\n' > "${WORK}/c28/pages/p-02-list.md"
expect "entry：多值合法放行" 0 "UI-PACK PASS" "${WORK}/c28" --require-digest

# 场景34：quantified 齐全但缺「## 文案清单」段 → 拦截
mk_pack "${WORK}/c29"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n' > "${WORK}/c29/pages/p-01-login.md"
expect "文案清单：缺段拦截" 1 "文案清单" "${WORK}/c29" --require-digest

# 场景35：向后兼容——不带开关时 entry/文案清单缺失不影响（c26 包无开关放行）
expect "向后兼容：无开关不校验 entry/文案清单" 0 "UI-PACK PASS" "${WORK}/c26"

# ── unreachable 挂起清零（--require-final 扩展，宪法第九节第 12 条）──

# 场景36：entry 含 unreachable 页面 + --require-final → 拦截（结构类复刻阻塞挂起）
mk_pack "${WORK}/c30"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: unreachable\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点 | 量化 |\n|---|---|\n| btn | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c30/pages/p-01-login.md"
expect "unreachable：定稿门禁拦截" 1 "结构类复刻阻塞" "${WORK}/c30" --require-final

# 场景37：同 c30 包不带开关 → 放行（生成期挂起登记合法）
expect "向后兼容：无定稿开关不校验 unreachable" 0 "UI-PACK PASS" "${WORK}/c30"

# 场景38：源节点扫描数大于量化表行数 → --require-digest 拦截
mk_pack "${WORK}/c31"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nsource_node_count: 2\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 源节点ID | 量化 |\n|---|---|\n| 1:2:3 | btn h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n\n## 源节点覆盖对账\n源节点覆盖: source=2 spec=1 uncovered=1\n' > "${WORK}/c31/pages/p-01-login.md"
expect "源节点数大于量化行数拦截" 1 "数量不一致" "${WORK}/c31" --require-digest

# 场景39：计数相同但覆盖账本 locator 与量化表错配 → 拦截
mk_pack "${WORK}/c32"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nsource_node_count: 1\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 源定位符 | 量化 |\n|---|---|\n| 1:2:3 | btn h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n\n## 源节点覆盖对账\n\n| 源定位符 | 分类/处理方式 | 量化表对应行 | 排除理由 |\n|---|---|---|---|\n| 1:2:4 | 量化 | 1:2:3 | — |\n源节点覆盖: source=1 spec=1 uncovered=0\n' > "${WORK}/c32/pages/p-01-login.md"
expect "覆盖账本定位符错配拦截" 1 "定位符集合不一致" "${WORK}/c32" --require-digest

[ "${FAILED}" -eq 0 ] && echo "ALL PASS" || exit 1
