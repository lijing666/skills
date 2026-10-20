#!/usr/bin/env bash
# ui-pack-check.test.sh — ui-pack-check.sh 回归测试
# 在临时目录构造最小合规包，逐一破坏各校验点验证 fail-closed；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：合规包放行 / 缺 icons.json / 缺类别行 / 「无」缺理由 / 图标处置非法 /
#       位图素材=assets 缺 assets.md / 素材清单未处置条目 / 字体族=assets 缺 assets.md /
#       页面跳号 / 页面缺锚点 / 缺 tokens / 非法 JSON / 引用素材不出清单 /
#       icons.json svg 指向缺失 / 品牌字体缺字体文件条目 / 品牌字体有字体条目放行 /
#       6c 素材与文案必备列 / 6d TEXT 文案位 / 6e 矢量素材引用 / 6f 账本处置态 / 6g 文案清单非空 / 6h 渐变完整性 /
#       3c 真源指纹清单（--require-final 或 状态=可用）/
#       3b assets.md 用途页面值域（画布名拦截 / p-xx·通用·豁免·人工补录放行）
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
  printf '{"source_type":"figma","file_key":"test-key","version":"1","generated_at":"2026-10-20","pages":[{"page":"p-01","node_id":"1:2","last_modified":"2026-10-19T00:00:00Z"},{"page":"p-02","node_id":"1:3","last_modified":"2026-10-19T00:00:00Z"}]}' > "${d}/source-manifest.json"
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
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 bg--color-primary |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n\n动态数据区：.demo-data\n' > "${WORK}/c13/pages/p-01-login.md"
expect "消化门槛：单页 quantified 放行" 0 "UI-PACK PASS" "${WORK}/c13" --require-digest p-01

# 场景15：同包 + --require-digest（全量）→ 拦截（p-02 仍 list-level）
expect "消化门槛：全量模式拦截清单级页" 1 "digest" "${WORK}/c13" --require-digest

# 场景16：全部页 quantified（含量化表段）+ --require-digest → 放行
mk_pack "${WORK}/c14"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c14/pages/p-01-login.md"
printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\ndigest: quantified\nentry: menu\n---\n# 列表\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| list | TEXT | 列表 \| PingFang 16 w400 | — | h88 p12 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 列表 | 标题 |\n' > "${WORK}/c14/pages/p-02-list.md"
expect "消化门槛：全页 quantified 放行" 0 "UI-PACK PASS" "${WORK}/c14" --require-digest

# 场景17：不带开关时 digest 缺失不影响（向后兼容）
expect "向后兼容：无开关不校验 digest" 0 "UI-PACK PASS" "${WORK}/c12"

# 场景18：中文短名拦截（宪法第九节第 10 条：英文短名 kebab-case）
mk_pack "${WORK}/c15"
mv "${WORK}/c15/pages/p-01-login.md" "${WORK}/c15/pages/p-01-登录.md"
expect "中文短名拦截" 1 "英文 kebab-case" "${WORK}/c15"

# 场景18b：惰性短名拦截——容器词+序号（frame-N 不构成短名，宪法第九节第 10 条）
mk_pack "${WORK}/c15b"
mv "${WORK}/c15b/pages/p-01-login.md" "${WORK}/c15b/pages/p-01-frame-5.md"
expect "惰性短名拦截：frame-N" 1 "语义英文概括" "${WORK}/c15b"

# 场景18c：惰性短名拦截——p- 编号段转抄（p-01-p-00 形态第二段）
mk_pack "${WORK}/c15c"
mv "${WORK}/c15c/pages/p-01-login.md" "${WORK}/c15c/pages/p-01-p-00.md"
expect "惰性短名拦截：p-编号转抄" 1 "语义英文概括" "${WORK}/c15c"

# 场景18d：惰性短名拦截——纯数字短名
mk_pack "${WORK}/c15d"
mv "${WORK}/c15d/pages/p-01-login.md" "${WORK}/c15d/pages/p-01-2.md"
expect "惰性短名拦截：纯数字" 1 "语义英文概括" "${WORK}/c15d"

# 场景18e：语义+变体号短名放行（customer-service-1 形态合法，宪法第九节第 10 条）
mk_pack "${WORK}/c15e"
mv "${WORK}/c15e/pages/p-01-login.md" "${WORK}/c15e/pages/p-01-customer-service-1.md"
expect "语义+变体号短名放行" 0 "UI-PACK PASS" "${WORK}/c15e"

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
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c25/pages/p-01-login.md"
printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\ndigest: quantified\nentry: menu\n---\n# 列表\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| list | TEXT | 列表 \| PingFang 16 w400 | — | h88 p12 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 列表 | 标题 |\n' > "${WORK}/c25/pages/p-02-list.md"
mkdir -p "${WORK}/c25/assets"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途 | 处置 |\n|---|---|---|---|---|\n| — | 字体-AlibabaPuHuiTi | 设计稿字体引用 | 全部品牌标题页 | 人工补录 |\n' > "${WORK}/c25/assets/assets.md"
expect "并用：digest 过但人工补录挂起拦截" 1 "复刻阻塞清单未清零" "${WORK}/c25" --require-digest --require-final
expect "并用：仅 digest 开关挂起不拦（独立生效）" 0 "UI-PACK PASS" "${WORK}/c25" --require-digest

# ── entry 到达方式与文案清单（--require-digest 伴随校验，宪法第九节第 12 条）──

# 场景31：--require-digest 下页面缺 entry 字段 → 拦截
mk_pack "${WORK}/c26"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c26/pages/p-01-login.md"
expect "entry：缺失拦截" 1 "缺 entry 字段" "${WORK}/c26" --require-digest

# 场景32：entry 枚举外值 → 拦截
mk_pack "${WORK}/c27"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: sidebar\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c27/pages/p-01-login.md"
expect "entry：枚举非法拦截" 1 "entry 枚举非法" "${WORK}/c27" --require-digest

# 场景33：entry 多值合法（menu + internal-entry）→ 放行（复用 c14 全合规包改 p-01 为多值）
mk_pack "${WORK}/c28"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu, internal-entry\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c28/pages/p-01-login.md"
printf -- '---\ntitle: 列表\nsource_anchor: figma 1:3\ndigest: quantified\nentry: menu\n---\n# 列表\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| list | TEXT | 列表 \| PingFang 16 w400 | — | h88 p12 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 列表 | 标题 |\n' > "${WORK}/c28/pages/p-02-list.md"
expect "entry：多值合法放行" 0 "UI-PACK PASS" "${WORK}/c28" --require-digest

# 场景34：quantified 齐全但缺「## 文案清单」段 → 拦截
mk_pack "${WORK}/c29"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: menu\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n' > "${WORK}/c29/pages/p-01-login.md"
expect "文案清单：缺段拦截" 1 "文案清单" "${WORK}/c29" --require-digest

# 场景35：向后兼容——不带开关时 entry/文案清单缺失不影响（c26 包无开关放行）
expect "向后兼容：无开关不校验 entry/文案清单" 0 "UI-PACK PASS" "${WORK}/c26"

# ── unreachable 挂起清零（--require-final 扩展，宪法第九节第 12 条）──

# 场景36：entry 含 unreachable 页面 + --require-final → 拦截（结构类复刻阻塞挂起）
mk_pack "${WORK}/c30"
printf -- '---\ntitle: 登录\nsource_anchor: figma 1:2\ndigest: quantified\nentry: unreachable\n---\n# 登录\n\n## 节点样式量化表\n\n| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 素材/资产引用 | 量化 |\n|---|---|---|---|---|\n| btn | TEXT | 登录 \| PingFang 16 w500 | — | h44 p16 |\n\n## 布局语义表\n\n| 坐标键 | 节点 | 方向 |\n|---|---|---|\n| (0,0) 402×874 | root | 纵排 |\n\n## 文案清单\n\n| 文案 | 类型 |\n|---|---|\n| 登录 | 标题 |\n' > "${WORK}/c30/pages/p-01-login.md"
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

# ── 6c–6g 量化表字段级有效性（--require-digest，ui-spec-guide「厚规格完整性门槛」）──

mk_quant_page() { # mk_quant_page <目录> —— 构造带矢量/文本行、素材引用齐备的合规 quantified 页（p-01 单页门槛）
  local d="$1"
  mk_pack "${d}"
  sed 's/^| 位图素材 | 无 | 原型无位图 |/| 位图素材 | assets | 1 张插画 |/' "${d}/README.md" > "${d}/rm.tmp" && mv "${d}/rm.tmp" "${d}/README.md"
  mkdir -p "${d}/assets"
  printf 'x' > "${d}/assets/hero.png"
  printf '{"icons":[{"name":"icon-001","svg":"icon-001.svg"}]}' > "${d}/icons/icons.json"
  printf 'x' > "${d}/icons/icon-001.svg"
  printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途页面 | 处置 |\n|---|---|---|---|---|\n| hero.png | 插画 | figma 9:9 | p-01 | 已导出 |\n' > "${d}/assets/assets.md"
  cat > "${d}/pages/p-01-login.md" <<'EOF'
---
title: 登录
source_anchor: figma 1:2
digest: quantified
source_node_count: 3
entry: menu
---
# 登录

## 节点样式量化表

| 节点/父级路径 | 类型/名称 | 文案/字体排版 | 颜色/填充 | 素材/资产引用 | 量化 |
|---|---|---|---|---|---|
| 1:10 | TEXT | 欢迎来到鱼找找 \| PuHuiTi 36 w700 | #FFFFFF | — | x16 y20 |
| 1:20 | IMAGE-SVG「Mask」 | — | 渐变: linear-gradient(176deg, rgba(188, 231, 254, 0.4) 17%, rgba(255, 255, 255, 0) 44%) | assets/hero.png | x0 y0 402×347 |
| 1:30 | IMAGE-SVG「Icon」 | — | #0A84FF | icons/icon-001 | x18 y18 |

## 布局语义表

| 坐标键 | 节点 | 方向 |
|---|---|---|
| (0,0) 402×874 | root | 纵排 |

## 文案清单

- 欢迎来到鱼找找
- 源头水产快速对接

动态数据区：.demo-data

## 源节点覆盖对账

| 源定位符 | 分类/处理方式 | 量化表对应行 | 排除理由 |
|---|---|---|---|
| 1:10 | 文本 | 1:10 | — |
| 1:20 | 导出资产 | 1:20 | — |
| 1:30 | 图标位 | 1:30 | — |
源节点覆盖: source=3 spec=3 uncovered=0
EOF
}

# 场景40：合规字段级形态 → 放行（6e assets 引用 + icons 条目引用 + 文案位实值 + 账本处置态）
mk_quant_page "${WORK}/c33"
expect "6c–6h：字段级合规放行" 0 "UI-PACK PASS" "${WORK}/c33" --require-digest p-01

# 场景41：6c 量化表缺素材列 → 拦截
mk_quant_page "${WORK}/c34"
sed 's/| 素材\/资产引用 | 量化 |/| 量化 |/' "${WORK}/c34/pages/p-01-login.md" > "${WORK}/c34/rm.tmp" && mv "${WORK}/c34/rm.tmp" "${WORK}/c34/pages/p-01-login.md"
expect "6c：缺素材列拦截" 1 "6c 量化表缺「素材/资产引用」必备列" "${WORK}/c34" --require-digest p-01

# 场景42：6d TEXT 行文案位「—」→ 拦截
mk_quant_page "${WORK}/c35"
sed 's/欢迎来到鱼找找/—/' "${WORK}/c35/pages/p-01-login.md" > "${WORK}/c35/rm.tmp" && mv "${WORK}/c35/rm.tmp" "${WORK}/c35/pages/p-01-login.md"
expect "6d：TEXT 文案位空拦截" 1 "6d 量化表第" "${WORK}/c35" --require-digest p-01

# 场景43：6e 矢量行素材列为空 → 拦截
mk_quant_page "${WORK}/c36"
sed 's#assets/hero.png#—#' "${WORK}/c36/pages/p-01-login.md" > "${WORK}/c36/rm.tmp" && mv "${WORK}/c36/rm.tmp" "${WORK}/c36/pages/p-01-login.md"
expect "6e：矢量行素材列空拦截" 1 "6e 量化表第" "${WORK}/c36" --require-digest p-01

# 场景44：6e 素材引用文件不存在 → 拦截
mk_quant_page "${WORK}/c37"
sed 's/assets\/hero.png/assets\/ghost.png/' "${WORK}/c37/pages/p-01-login.md" > "${WORK}/c37/rm.tmp" && mv "${WORK}/c37/rm.tmp" "${WORK}/c37/pages/p-01-login.md"
expect "6e：素材引用不存在拦截" 1 "素材引用文件不存在" "${WORK}/c37" --require-digest p-01

# 场景45：6e 图标引用非文件且非 icons.json 条目 → 拦截
mk_quant_page "${WORK}/c38"
sed 's/icons\/icon-001/icons\/icon-999/' "${WORK}/c38/pages/p-01-login.md" > "${WORK}/c38/rm.tmp" && mv "${WORK}/c38/rm.tmp" "${WORK}/c38/pages/p-01-login.md"
expect "6e：图标引用不存在拦截" 1 "图标引用不存在" "${WORK}/c38" --require-digest p-01

# 场景46：6f 账本矢量条目非封闭处置态 → 拦截
mk_quant_page "${WORK}/c39"
sed 's/| 1:20 | 导出资产 |/| 1:20 | 矢量组 |/' "${WORK}/c39/pages/p-01-login.md" > "${WORK}/c39/rm.tmp" && mv "${WORK}/c39/rm.tmp" "${WORK}/c39/pages/p-01-login.md"
expect "6f：账本非封闭处置态拦截" 1 "6f 覆盖账本第" "${WORK}/c39" --require-digest p-01

# 场景47：6g TEXT 行存在但文案清单静态区空 → 拦截
mk_quant_page "${WORK}/c40"
grep -vE '^- 欢迎来到鱼找找$|^- 源头水产快速对接$' "${WORK}/c40/pages/p-01-login.md" > "${WORK}/c40/rm.tmp" && mv "${WORK}/c40/rm.tmp" "${WORK}/c40/pages/p-01-login.md"
expect "6g：TEXT 行存在静态文案区空拦截" 1 "6g 量化表存在 TEXT 行但文案清单静态区为空" "${WORK}/c40" --require-digest p-01

# 场景48：6h 颜色列渐变值被截断（括号不配对）→ 拦截
mk_quant_page "${WORK}/c43"
sed 's/linear-gradient(176deg, rgba(188, 231, 254, 0.4) 17%, rgba(255, 255, 255, 0) 44%)/linear-gradient(176deg, rgba(188, 231, 254, 0.4) 17%, rgba(255, 25/' "${WORK}/c43/pages/p-01-login.md" > "${WORK}/c43/rm.tmp" && mv "${WORK}/c43/rm.tmp" "${WORK}/c43/pages/p-01-login.md"
expect "6h：渐变截断拦截" 1 "6h 量化表第" "${WORK}/c43" --require-digest p-01

# ── 3b assets.md 用途页面列值域（宪法第九节第 10 条，默认模式包级）──

# 场景49：已导出条目用途页面登记画布名 → 拦截
mk_pack "${WORK}/c41"
sed 's/^| 位图素材 | 无 | 原型无位图 |/| 位图素材 | assets | 1 张背景图 |/' "${WORK}/c41/README.md" > "${WORK}/c41/rm.tmp" && mv "${WORK}/c41/rm.tmp" "${WORK}/c41/README.md"
mkdir -p "${WORK}/c41/assets"
printf 'x' > "${WORK}/c41/assets/bg.png"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途页面 | 处置 |\n|---|---|---|---|---|\n| bg.png | 背景 | figma 1:2 | 效果图 | 已导出 |\n' > "${WORK}/c41/assets/assets.md"
expect "3b：用途页面画布名拦截" 1 "用途页面列值域非法" "${WORK}/c41"

# 场景50：p-xx 多值（顿号）+「通用」放行；豁免/人工补录条目不校验用途页面 → 放行
mk_pack "${WORK}/c42"
sed 's/^| 位图素材 | 无 | 原型无位图 |/| 位图素材 | assets | 2 张图 |/' "${WORK}/c42/README.md" > "${WORK}/c42/rm.tmp" && mv "${WORK}/c42/rm.tmp" "${WORK}/c42/README.md"
mkdir -p "${WORK}/c42/assets"
printf 'x' > "${WORK}/c42/assets/bg.png"
printf 'x' > "${WORK}/c42/assets/icon-set.png"
printf '# 素材清单\n| 文件 | 类别 | 来源锚点 | 用途页面 | 处置 |\n|---|---|---|---|---|\n| bg.png | 背景 | figma 1:2 | p-01、p-02 | 已导出 |\n| icon-set.png | 装饰 | figma 1:3 | 通用 | 已导出 |\n| — | 字体-X | 设计稿字体引用 | 通用 | 人工补录 |\n| — | 展板物料 | 画布外 | 效果图 | 豁免 |\n' > "${WORK}/c42/assets/assets.md"
expect "3b：p-xx/通用/豁免/人工补录放行" 0 "UI-PACK PASS" "${WORK}/c42"

# ── 真源指纹清单（3c，生命周期条款）──
# 场景51：--require-final 且缺 source-manifest.json → 拦截（真源指纹是置「可用」前置）
mk_pack "${WORK}/c44"
rm "${WORK}/c44/source-manifest.json"
expect "3c：--require-final 缺指纹清单拦截" 1 "缺 source-manifest.json" "${WORK}/c44" --require-final

# 场景52：README 状态=可用 且 manifest 结构非法（figma 缺 pages）→ 默认模式拦截
mk_pack "${WORK}/c45"
printf '\n状态：可用\n' >> "${WORK}/c45/README.md"
printf '{"source_type":"figma","file_key":"k","version":"1","generated_at":"2026-10-20"}' > "${WORK}/c45/source-manifest.json"
expect "3c：可用包指纹结构非法拦截" 1 "source-manifest.json 结构非法" "${WORK}/c45"

# 场景53：README 状态=可用 + 合法 manifest → 默认模式放行（对账锚就位）
mk_pack "${WORK}/c46"
printf '\n状态：可用\n' >> "${WORK}/c46/README.md"
expect "3c：可用包合法指纹放行" 0 "UI-PACK PASS" "${WORK}/c46"

[ "${FAILED}" -eq 0 ] && echo "ALL PASS" || exit 1
