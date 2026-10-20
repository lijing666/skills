#!/usr/bin/env bash
# ui-pack-check.sh — UI 规范包资产完整性门禁（fail-closed）
# 执行前提：bash（macOS/Linux 原生；Windows 用 Git Bash 或 WSL 执行同一脚本，零改动）。
# 跨平台口径：下方「校验」清单是本门禁语义的唯一正源——确无 bash 环境时，可在会话内据此自编
#   一次性等价校验（不得增删检查项、fail-closed 语义不变、逐项对账输出、禁入库禁提交）。
# 用法：ui-pack-check.sh <ui-specs/<产品ID>-<业务大项>> [--require-digest [all | p-<两位序号>]] [--require-final]
#   --require-digest      页面消化门槛（页面卡开工前置，见 taskcard-template 拆卡规则 8）：
#                         不带值 = 全部页须 digest: quantified；带 p-<序号> = 仅校验指定页
#   --require-final       定稿清零门禁（规范置「可用」与绑定入口前置，宪法第九节第 11 条）：
#                         「人工补录」按挂起态拦截——assets.md 与 README 不得残留，须消解为 已导出/豁免
#   （开关可并用；均不带时行为与旧版完全兼容）
# 校验（任一失败即退出 1 并逐条列明；全部通过输出 UI-PACK PASS）：
#   1. README.md 存在，且含「## 资产类别登记」节
#   2. 资产类别登记表 15 类封闭齐全：颜色/字号/字重/行高/字体族/间距/圆角/边框/阴影/透明度/渐变/布局/动效/图标/位图素材
#      处置 ∈ {token化, icons.json, assets, 无}；「无」必须写理由；「图标」必须为 icons.json；
#      「位图素材」∈ {assets, 无}；任何处置=assets 的类须 assets/assets.md 存在、assets/ 有文件、清单无未处置条目
#   3. tokens 文件恰好 1 个（css/scss/json）
#   4. icons/icons.json 存在且为合法 JSON（HTML 与设计稿路线均必须产出）
#   5. pages/p-<两位序号>-<短名>.md 存在：编号自 01 连续、无重号；短名须英文 kebab-case（宪法第九节第 10 条）；
#      每页含 source_anchor 视觉输入锚点
#   6. （启用 --require-digest 时）指定页面的 frontmatter 含 digest: quantified，
#      且页面含「## 节点样式量化表」与「## 布局语义表」两段（quantified 的强制载体，缺段按清单级拦截）；
#      并校验 frontmatter entry 字段（多值枚举 menu/internal-tab/internal-entry/drawer/modal/unreachable，
#      采集判据见 ui-spec-guide 生成管线步 2 导航结构采集，宪法第九节第 12 条——缺失或枚举外值即拦）
#      与「## 文案清单」段（静态结构文案封闭清单 + 动态数据区选择器，文案覆盖率断言数据源，
#      见 ui-spec-guide 第三节第 7 条——缺段即拦）
#      source_node_count 必须等于量化表与覆盖账本行数；两表首列定位符集合相同且唯一，登记 source=N spec=N uncovered=0
#   7. 引用不出清单（宪法第九节第 9 条）：pages/ 中引用的 icons/*.svg 与 assets/*.png、
#      icons.json 的 svg 字段指向，文件必须实际存在
#   8. 字体文件联动（guide 语义归并步「字体处置拆分」）：tokens 含非系统字体族名（品牌字体）时，
#      assets/assets.md 必须有字体文件条目（登记态 已导出/人工补录；--require-final 下人工补录即拦）——
#      禁止以 token 化登记掩盖文件缺失
#   9. 定稿清零门禁（--require-final，宪法第九节第 11 条）：assets.md 不得存在「人工补录」挂起条目、
#      README 不得残留人工补录登记——人工补录是挂起态非终态，置「可用」与绑定入口前须消解
#      （设计侧提供转「已导出」并附格式与授权，或经用户批准转「豁免」并留替代口径）
#   10. 定稿清零门禁扩展（--require-final，宪法第九节第 12 条）：页面 frontmatter entry 含
#       unreachable（渲染态不可达页面 = 结构类复刻阻塞项）即拦——消解 = 用户判定后更新：
#       死页面剔除页面清单，或设计侧补入口经渲染验证后改真实到达值
set -uo pipefail

DIR=""
REQUIRE_DIGEST=""
REQUIRE_FINAL=""
_digest_pending=0
for _arg in "$@"; do
  if [ "${_digest_pending}" = "1" ]; then
    _digest_pending=0
    case "${_arg}" in
      --*) ;;  # 下一开关：--require-digest 保持默认 all
      *) REQUIRE_DIGEST="${_arg}"; continue ;;
    esac
  fi
  case "${_arg}" in
    --require-digest) REQUIRE_DIGEST="${REQUIRE_DIGEST:-all}"; _digest_pending=1 ;;
    --require-final) REQUIRE_FINAL=1 ;;
    *) [ -z "${DIR}" ] && DIR="${_arg}" ;;
  esac
done
unset _digest_pending _arg
FAILS=()
fail() { FAILS+=("$1"); }

[ -n "${DIR}" ] && [ -d "${DIR}" ] || { echo "用法: ui-pack-check.sh <ui-spec 目录>"; exit 2; }
[ -f "${DIR}/README.md" ] || fail "缺 README.md"

# ── 1) tokens 文件唯一 ──
tok_count=$(find "${DIR}" -maxdepth 1 -name 'tokens.*' -type f | grep -c . || true)
[ "${tok_count}" = "1" ] || fail "tokens 文件须恰好 1 个（css/scss/json），实得 ${tok_count} 个"

# ── 2) icons/icons.json 存在且合法 ──
if [ ! -f "${DIR}/icons/icons.json" ]; then
  fail "缺 icons/icons.json（HTML 与设计稿路线均必须产出图标封闭清单）"
elif ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "${DIR}/icons/icons.json" 2>/dev/null; then
  fail "icons/icons.json 不是合法 JSON"
fi

# ── 3) 资产类别登记表：15 类封闭，每类一行 ──
CATEGORIES=(颜色 字号 字重 行高 字体族 间距 圆角 边框 阴影 透明度 渐变 布局 动效 图标 位图素材)
if ! grep -q '^## 资产类别登记' "${DIR}/README.md" 2>/dev/null; then
  fail "README.md 缺「## 资产类别登记」节"
fi
for cat in "${CATEGORIES[@]}"; do
  row="$(grep -E "^\|[[:space:]]*${cat}[[:space:]]*\|" "${DIR}/README.md" 2>/dev/null | head -1)"
  if [ -z "${row}" ]; then
    fail "资产类别登记缺「${cat}」行（封闭清单禁止省略；无值填「无 + 理由」）"
    continue
  fi
  handle="$(printf '%s' "${row}" | awk -F'|' '{gsub(/[[:space:]]/,"",$3); print $3}')"
  note="$(printf '%s' "${row}" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/,"",$4); print $4}')"
  case "${handle}" in
    token化|icons.json|assets|无) ;;
    *) fail "「${cat}」处置非法: ${handle:-空}（允许 token化/icons.json/assets/无）" ;;
  esac
  if [ "${handle}" = "无" ] && [ -z "${note}" ]; then
    fail "「${cat}」处置为「无」但未写理由"
  fi
  if [ "${cat}" = "图标" ] && [ "${handle}" != "icons.json" ]; then
    fail "「图标」行处置须为 icons.json"
  fi
  if [ "${cat}" = "位图素材" ] && [ "${handle}" != "assets" ] && [ "${handle}" != "无" ]; then
    fail "「位图素材」处置仅允许 assets 或 无"
  fi
  # 处置=assets 的通用检查（位图素材、字体族等媒体资产）：assets.md 存在、清单无未处置条目、目录有资产文件
  if [ "${handle}" = "assets" ]; then
    [ -f "${DIR}/assets/assets.md" ] || fail "「${cat}」处置=assets 但缺 assets/assets.md 素材清单"
    if [ -f "${DIR}/assets/assets.md" ]; then
      bad="$(grep -E '^\|' "${DIR}/assets/assets.md" 2>/dev/null \
        | grep -vE '^\|[[:space:]]*文件[[:space:]]*\||^\|[[:space:]]*-' \
        | awk -F'|' '{v=$(NF-1); gsub(/[[:space:]]/,"",v); if(v!="" && v!="已导出" && v!="豁免" && v!="人工补录") print v}' \
        | sort -u | tr '\n' ' ' || true)"
      [ -z "${bad}" ] || fail "assets.md 存在未终态处置条目: ${bad}（处置仅允许 已导出/豁免/人工补录）"
    fi
    if [ -z "$(find "${DIR}/assets" -type f ! -name 'assets.md' -print -quit 2>/dev/null)" ]; then
      fail "「${cat}」处置=assets 但 assets/ 无资产文件"
    fi
  fi
done

# ── 9a) 定稿清零门禁：assets.md 人工补录挂起条目（宪法第九节第 11 条）──
# 独立于类别登记的处置值检查——字体族等登记 token化 而素材挂在孤立 assets.md 时同样必须清零，防登记口径掩盖挂起
if [ -n "${REQUIRE_FINAL}" ] && [ -f "${DIR}/assets/assets.md" ]; then
  pend="$(grep -E '^\|' "${DIR}/assets/assets.md" 2>/dev/null \
    | grep -vE '^\|[[:space:]]*文件[[:space:]]*\||^\|[[:space:]]*-' \
    | awk -F'|' '{v=$(NF-1); gsub(/[[:space:]]/,"",v); if(v=="人工补录") print v}' \
    | sort -u | tr '\n' ' ' || true)"
  [ -z "${pend}" ] || fail "复刻阻塞清单未清零: ${pend}（宪法第九节第 11 条：人工补录是挂起态非终态——定稿前须消解：设计侧提供转「已导出」并附格式与授权，或经用户批准转「豁免」并留替代口径）"
fi

# ── 4) 页面规格：编号连续无重号；每页含 source_anchor ──
shopt -s nullglob
pages=("${DIR}"/pages/p-*.md)
shopt -u nullglob
[ ${#pages[@]} -gt 0 ] || fail "pages/ 无 p-*.md 页面规格"
nums=()
for p in "${pages[@]}"; do
  base="$(basename "${p}")"
  n="$(printf '%s' "${base}" | sed -E 's/^p-0*([0-9]+)-.*/\1/')"
  if [ "${n}" = "${base}" ]; then
    fail "页面文件名不符合 p-<序号>-<短名>.md: ${base}"
  else
    nums+=("${n}")
  fi
  if ! printf '%s' "${base}" | grep -qE '^p-[0-9]{2}-[a-z0-9][a-z0-9-]*\.md$'; then
    fail "页面短名须英文 kebab-case（p-<两位序号>-<英文短名>.md，宪法第九节第 10 条）: ${base}"
  fi
  grep -q 'source_anchor' "${p}" || fail "${base} 缺 source_anchor 视觉输入锚点"

  # ── 6) 页面消化门槛（仅 --require-digest 启用时）──
  if [ -n "${REQUIRE_DIGEST}" ]; then
    page_no="$(printf '%s' "${n}")"
    need_check=1
    # 裁撤页（status: withdrawn）跳过消化门槛：设计收敛/源帧删除的占位页，保留编号连续性但不作为实现输入
    grep -q '^status:[[:space:]]*withdrawn' "${p}" && need_check=0
    if [ "${REQUIRE_DIGEST}" != "all" ]; then
      want_no="$(printf '%s' "${REQUIRE_DIGEST}" | sed -E 's/^p-0*([0-9]+)/\1/')"
      [ "${page_no}" = "${want_no}" ] || need_check=0
    fi
    if [ "${need_check}" -eq 1 ]; then
      digest="$(awk 'NR==1&&/^---[[:space:]]*\r?$/{fm=1;next} fm&&/^---[[:space:]]*\r?$/{exit} fm&&/^digest:/{sub(/^digest:[[:space:]]*/,"");gsub(/\r$/,"");print;exit}' "${p}")"
      if [ "${digest}" != "quantified" ]; then
        fail "${base} 页面消化门槛未过：digest=${digest:-<缺失>}（页面卡开工须 quantified；清单级页先补逐项量化）"
      elif ! grep -q '^## 节点样式量化表' "${p}"; then
        fail "${base} digest=quantified 但缺「## 节点样式量化表」段落（逐节点量化载体，见 ui-spec-guide）——按清单级处理，补量化后再标 quantified"
      elif ! grep -q '^## 布局语义表' "${p}"; then
        fail "${base} digest=quantified 但缺「## 布局语义表」段落（布局方向/对齐/auto 行高/字间距/截断，guide「布局语义必须入表」（量化表定义）；纯坐标堆叠不构成 quantified）"
      fi
      # ── 6b) entry 到达方式与文案清单段（实现就绪必要条件，随 digest 门槛按页校验；宪法第九节第 12 条）──
      entry="$(awk 'NR==1&&/^---[[:space:]]*\r?$/{fm=1;next} fm&&/^---[[:space:]]*\r?$/{exit} fm&&/^entry:/{sub(/^entry:[[:space:]]*/,"");gsub(/\r$/,"");print;exit}' "${p}")"
      if [ -z "${entry}" ]; then
        fail "${base} 缺 entry 字段（页面到达方式必填，多值枚举见 ui-spec-guide 生成管线步 2 导航结构采集）"
      else
        bad_entry="$(printf '%s' "${entry}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -vE '^(menu|internal-tab|internal-entry|drawer|modal|unreachable)$' | grep -v '^$' | tr '\n' ' ' || true)"
        [ -z "${bad_entry}" ] || fail "${base} entry 枚举非法: ${bad_entry}（允许 menu/internal-tab/internal-entry/drawer/modal/unreachable，多值逗号分隔）"
      fi
      grep -q '^## 文案清单' "${p}" || fail "${base} 缺「## 文案清单」段（静态结构文案封闭清单 + 动态数据区选择器，文案覆盖率断言数据源，见 ui-spec-guide 第三节第 7 条）"
      source_count="$(awk 'NR==1&&/^---[[:space:]]*\r?$/{fm=1;next} fm&&/^---[[:space:]]*\r?$/{exit} fm&&/^source_node_count:/{sub(/^source_node_count:[[:space:]]*/,"");gsub(/\r$/,"");print;exit}' "${p}")"
      quant_count="$(awk '
        /^## 节点样式量化表/{in_table=1;next}
        /^## /&&in_table{exit}
        in_table&&/^\|/{
          line=$0; gsub(/[[:space:]]/,"",line)
          if(line ~ /^\|[-:|]+\|$/) next
          rows++
        }
        END{print (rows > 0 ? rows-1 : 0)}
      ' "${p}")"
      bad_node_ids="$(awk '
        /^## 节点样式量化表/{in_table=1;next}
        /^## /&&in_table{exit}
        in_table&&/^\|/{
          line=$0; gsub(/[[:space:]]/,"",line)
          if(line ~ /^\|[-:|]+\|$/) next
          split($0, cells, "|")
          id=cells[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
          if(!header++){next}
          if(id=="" || seen[id]++) print (id=="" ? "空源定位符" : "重复源定位符 " id)
        }
      ' "${p}")"
      [ -z "${bad_node_ids}" ] || fail "${base} 节点样式量化表源定位符缺失或重复：${bad_node_ids}"
      coverage_count="$(awk '
        /^## 源节点覆盖对账/{in_section=1;next}
        /^## /&&in_section{exit}
        in_section&&/^\|/ {
          line=$0; gsub(/[[:space:]]/,"",line)
          if(line !~ /^\|[-:|]+\|$/) rows++
        }
        END{print (rows > 0 ? rows-1 : 0)}
      ' "${p}")"
      bad_coverage_ids="$(awk '
        /^## 源节点覆盖对账/{in_section=1;next}
        /^## /&&in_section{exit}
        in_section&&/^\|/ {
          line=$0; gsub(/[[:space:]]/,"",line)
          if(line ~ /^\|[-:|]+\|$/) next
          split($0, cells, "|")
          id=cells[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
          if(!header++){next}
          if(id=="" || seen[id]++) print (id=="" ? "空源定位符" : "重复源定位符 " id)
        }
      ' "${p}")"
      [ -z "${bad_coverage_ids}" ] || fail "${base} 源节点覆盖账本定位符缺失或重复：${bad_coverage_ids}"
      quant_ids="$(awk '
        /^## 节点样式量化表/{in_table=1;next}
        /^## /&&in_table{exit}
        in_table&&/^\|/ {
          line=$0; gsub(/[[:space:]]/,"",line)
          if(line ~ /^\|[-:|]+\|$/) next
          split($0, cells, "|")
          id=cells[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
          if(!header++) next
          print id
        }
      ' "${p}" | LC_ALL=C sort)"
      coverage_ids="$(awk '
        /^## 源节点覆盖对账/{in_section=1;next}
        /^## /&&in_section{exit}
        in_section&&/^\|/ {
          line=$0; gsub(/[[:space:]]/,"",line)
          if(line ~ /^\|[-:|]+\|$/) next
          split($0, cells, "|")
          id=cells[2]; gsub(/^[[:space:]]+|[[:space:]]+$/, "", id)
          if(!header++) next
          print id
        }
      ' "${p}" | LC_ALL=C sort)"
      [ "${quant_ids}" = "${coverage_ids}" ] || fail "${base} 覆盖账本与量化表的源定位符集合不一致"
      if ! [[ "${source_count}" =~ ^[0-9]+$ ]]; then
        fail "${base} 缺合法 source_node_count（必须来自完整源节点扫描）"
      elif [ "${source_count}" -ne "${quant_count}" ]; then
        fail "${base} 源节点覆盖数量不一致：source_node_count=${source_count}，节点样式量化表行数=${quant_count}"
      elif [ "${source_count}" -ne "${coverage_count}" ]; then
        fail "${base} 源节点覆盖账本数量不一致：source_node_count=${source_count}，覆盖账本行数=${coverage_count}"
      fi
      coverage_line="$(awk '
        /^## 源节点覆盖对账/{in_coverage=1;next}
        /^## /&&in_coverage{exit}
        in_coverage&&/^源节点覆盖:/{print;exit}
      ' "${p}")"
      [ "${coverage_line}" = "源节点覆盖: source=${source_count:-invalid} spec=${quant_count} uncovered=0" ] \
        || fail "${base} 缺源节点覆盖对账或未满足 source=N spec=N uncovered=0"
    fi
  fi
done
if [ ${#nums[@]} -gt 0 ]; then
  dups="$(printf '%s\n' "${nums[@]}" | sort -n | uniq -d)"
  [ -z "${dups}" ] || fail "页面编号重复: $(printf '%s ' ${dups})"
  gap="$(printf '%s\n' "${nums[@]}" | sort -n | awk 'NR!=$1{print "期望 "NR"，实得 "$1; exit}')"
  [ -z "${gap}" ] || fail "页面编号跳号: ${gap}"
fi

# ── 7) 引用不出清单：pages/ 引用的 icons/*.svg、assets/*.png 与 icons.json 的 svg 字段必须实际存在 ──
missing=""
for ref in $(grep -ohE '(icons|assets)/[A-Za-z0-9._-]+\.(svg|png)' "${DIR}"/pages/*.md 2>/dev/null | sort -u); do
  [ -f "${DIR}/${ref}" ] || missing="${missing} ${ref}"
done
[ -z "${missing}" ] || fail "pages/ 引用素材缺失（引用不出清单）:${missing}"
if [ -f "${DIR}/icons/icons.json" ]; then
  m2="$(python3 -c "
import json, os, sys
d = json.load(open(sys.argv[1]))
base = os.path.dirname(sys.argv[1])
miss = sorted({i.get('svg', '') for i in d.get('icons', []) if i.get('svg') and not os.path.exists(os.path.join(base, i['svg']))})
print(' '.join(miss))
" "${DIR}/icons/icons.json" 2>/dev/null)"
  [ -z "${m2}" ] || fail "icons.json svg 指向文件缺失: ${m2}"
fi

# ── 8) 字体文件联动：tokens 含非系统字体族名（品牌字体）时，assets/assets.md 必须有字体文件条目 ──
# 白名单 = 通用族与各平台系统字体；超出白名单视为品牌字体——真机无文件即回退系统字体，须文件落地或人工补录留痕
# （--require-final 下人工补录挂起即拦，见检查 9 与宪法第九节第 11 条）
font_bad="$(python3 - "$DIR" <<'PYEOF'
import re, sys, os, glob
d = sys.argv[1]
WL = {'-apple-system','system-ui','sans-serif','serif','monospace','cursive','fantasy',
      'pingfang sc','pingfang tc','pingfang hk','sf pro','sf pro text','sf pro display',
      'helvetica','helvetica neue','arial','menlo','roboto','noto sans','noto sans cjk sc',
      'source han sans','思源黑体','microsoft yahei','微软雅黑','simhei','simsun','miui',
      'harmonyos sans'}
fams = set()
for t in glob.glob(os.path.join(d, 'tokens.*')):
    try:
        txt = open(t, encoding='utf-8').read()
    except OSError:
        continue
    fams |= {x.strip().lower() for x in re.findall(r'"([^"]+)"', txt)}
bad = sorted(f for f in fams if f and f not in WL and not f.startswith('sf pro'))
if not bad:
    sys.exit(0)
am = os.path.join(d, 'assets', 'assets.md')
have = False
if os.path.exists(am):
    for line in open(am, encoding='utf-8'):
        if re.search(r'\.(ttf|otf|ttc|woff2?)\b', line, re.I) or ('字体' in line and '|' in line):
            have = True
if not have:
    print(' '.join(bad))
PYEOF
)"
[ -z "${font_bad}" ] || fail "tokens 含品牌字体族 [${font_bad}] 但 assets/assets.md 无字体文件条目（guide「字体处置拆分」：取值 token 化 ≠ 文件落地；机械不可得须登记人工补录——--require-final 下挂起即拦，见宪法第九节第 11 条）"

# ── 9b) 定稿清零门禁：README 不得残留人工补录登记（--require-final，宪法第九节第 11 条）──
if [ -n "${REQUIRE_FINAL}" ] && [ -f "${DIR}/README.md" ] && grep -q '人工补录' "${DIR}/README.md"; then
  fail "README 仍残留人工补录登记（复刻阻塞清单未清零，宪法第九节第 11 条）——定稿前消解为「已导出」（附格式与授权）或经用户批准转「豁免」并留替代口径；若为豁免叙述中的历史用词请改写后重跑"
fi

# ── 9c) 定稿清零门禁扩展：entry 含 unreachable 的页面 = 结构类复刻阻塞挂起（--require-final，宪法第九节第 12 条）──
if [ -n "${REQUIRE_FINAL}" ]; then
  for p in ${pages[@]+"${pages[@]}"}; do
    entry="$(awk 'NR==1&&/^---[[:space:]]*\r?$/{fm=1;next} fm&&/^---[[:space:]]*\r?$/{exit} fm&&/^entry:/{sub(/^entry:[[:space:]]*/,"");gsub(/\r$/,"");print;exit}' "${p}")"
    if printf '%s' "${entry}" | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | grep -qx 'unreachable'; then
      fail "$(basename "${p}") entry 含 unreachable（渲染态不可达 = 结构类复刻阻塞项，宪法第九节第 12 条）——定稿前消解：用户判定死页面剔除页面清单，或设计侧补入口经渲染验证后改真实到达值"
    fi
  done
fi

# ── 结果 ──
if [ ${#FAILS[@]} -gt 0 ]; then
  echo "UI-PACK FAIL（${#FAILS[@]} 项）:"
  printf '  - %s\n' "${FAILS[@]}"
  exit 1
fi
echo "UI-PACK PASS: ${DIR}"
exit 0
