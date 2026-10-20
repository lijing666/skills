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
#   3b. assets.md 用途页面列值域（仅已导出条目强制，消费方为实现 AI）：每值 ∈ {p-<两位序号>, 通用}，
#       多值逗号/顿号分隔，禁止登记画布名（宪法第九节第 10 条）
#   3c. 真源指纹清单（--require-final 或 README 状态=可用 时强制，draft 生成期不强制）：
#       source-manifest.json 存在且结构合法——figma: source_type/file_key/version/generated_at/
#       pages[{page,node_id,last_modified}]；html: files[{path,hash}]（生命周期条款：真源演进对账锚）
#   4. icons/icons.json 存在且为合法 JSON（HTML 与设计稿路线均必须产出）
#   5. pages/p-<两位序号>-<短名>.md 存在：编号自 01 连续、无重号；短名须英文 kebab-case（宪法第九节第 10 条）；
#      每页含 source_anchor 视觉输入锚点
#   6. （启用 --require-digest 时）指定页面的 frontmatter 含 digest: quantified，
#      且页面含「## 节点样式量化表」与「## 布局语义表」两段（quantified 的强制载体，缺段按清单级拦截）；
#      并校验 frontmatter entry 字段（多值枚举 menu/internal-tab/internal-entry/drawer/modal/unreachable，
#      采集判据见 ui-spec-guide 生成管线步 2 导航结构采集，宪法第九节第 12 条——缺失或枚举外值即拦）
#      与「## 文案清单」段（静态结构文案封闭清单 + 动态数据区选择器，文案覆盖率断言数据源，
#      见 ui-spec-guide 第三节第 7 条——缺段即拦）
#      source_node_count 必须等于量化表与覆盖账本行数；两表首列定位符集合相同且唯一，登记 source=N spec=N uncovered=0；
#      6c–6g 量化表字段级有效性（判据见 ui-spec-guide「厚规格完整性门槛」）：
#        6c 量化表含「素材/资产引用」「文案/字体排版」必备列（最小封闭列集）
#        6d TEXT 行文案位非「—」/空（设计稿路线取 Figma characters 字段机械提取）
#        6e 矢量/位图行素材列 ∈ {assets/<文件>, icons/<icon-xxx>, 代码复刻, 豁免, 人工补录} 且引用文件/条目实际存在
#        6f 覆盖账本矢量/位图条目「分类/处理方式」∈ 封闭处置态（图标位/导出资产/代码复刻/豁免/人工补录）
#        6g 量化表有 TEXT 行则文案清单静态区非空（空清单将使文案覆盖率断言全 FAIL）
#        6h 颜色/填充列渐变值括号配对完整（防提取脚本字符预算截断——半截渐变是非法视觉真源）
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

# ── 3b) assets.md 用途页面列值域（宪法第九节第 10 条；仅已导出条目强制——消费方为实现 AI，豁免/人工补录条目的消费方是人，不校验）──
if [ -f "${DIR}/assets/assets.md" ]; then
  usage_bad=""
  if ! usage_bad="$(python3 - "$DIR" <<'PYEOF'
import re, sys, os
d = sys.argv[1]
usage_i = dispose_i = -1
header_seen = False
bad = set()
for line in open(os.path.join(d, 'assets', 'assets.md'), encoding='utf-8'):
    s = line.strip()
    if not s.startswith('|'):
        if header_seen:
            break  # 表头后仅收集连续表格行，防误吞后续无关表
        continue
    tmp = s.replace('\\|', '\x00')
    cells = [c.replace('\x00', ' ').strip() for c in tmp.strip('|').split('|')]
    if all(re.fullmatch(r'[-: ]*', c) for c in cells):
        continue
    if not header_seen:
        for i, c in enumerate(cells):
            if '用途页面' in c:
                usage_i = i
            if '处置' in c:
                dispose_i = i
        if usage_i >= 0:
            header_seen = True
        continue
    if dispose_i < 0 or dispose_i >= len(cells) or cells[dispose_i] != '已导出':
        continue
    if usage_i >= len(cells):
        continue
    for part in (x.strip() for x in re.split(r'[,，、;；]', cells[usage_i])):
        if not part:
            continue
        if part == '通用' or re.fullmatch(r'[pP]-\d{2}', part):
            continue
        bad.add(part)
        break
if bad:
    print(' '.join(sorted(bad)))
PYEOF
)"; then
    fail "assets.md 用途页面列校验器执行异常（fail-closed）"
    usage_bad=""
  fi
  [ -z "${usage_bad}" ] || fail "assets.md 用途页面列值域非法: ${usage_bad}（值域 = 页面编号 p-xx（多值逗号/顿号分隔）或「通用」；禁止登记 Figma 画布名，宪法第九节第 10 条）"
fi

# ── 3c) 真源指纹清单（生命周期条款，ui-spec-guide「规范包生命周期」；--require-final 或 README 状态=可用 时强制）──
_sm_status="$(grep -oE '状态[:：][[:space:]]*(draft|可用|归档)' "${DIR}/README.md" 2>/dev/null | head -1 | grep -oE '(draft|可用|归档)$' || true)"
if [ -n "${REQUIRE_FINAL}" ] || [ "${_sm_status}" = "可用" ]; then
  if [ ! -f "${DIR}/source-manifest.json" ]; then
    fail "缺 source-manifest.json（真源指纹清单——Figma 路线记 file key/version/逐页 node lastModified，HTML 路线记文件内容哈希；生命周期条款：确认置「可用」前必须产出，存量可用包须补产）"
  elif ! python3 - "${DIR}" <<'PYEOF'
import json, os, sys
try:
    m = json.load(open(os.path.join(sys.argv[1], 'source-manifest.json'), encoding='utf-8'))
    assert isinstance(m, dict) and m.get('source_type') in ('figma', 'html') and m.get('generated_at')
    if m['source_type'] == 'figma':
        assert m.get('file_key') and m.get('version') and isinstance(m.get('pages'), list) and m['pages']
        assert all(isinstance(p, dict) and all(k in p for k in ('page', 'node_id', 'last_modified')) for p in m['pages'])
    else:
        assert isinstance(m.get('files'), list) and m['files']
        assert all(isinstance(f, dict) and 'path' in f and 'hash' in f for f in m['files'])
except Exception:
    sys.exit(1)
PYEOF
  then
    fail "source-manifest.json 结构非法（fail-closed）——figma: source_type/file_key/version/generated_at/pages[{page,node_id,last_modified}]；html: source_type/generated_at/files[{path,hash}]"
  fi
fi

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
      # ── 6c–6h) 量化表字段级有效性（判据见 ui-spec-guide「厚规格完整性门槛」）──
      if [ "${digest}" = "quantified" ] && grep -q '^## 节点样式量化表' "${p}"; then
        field_problems=""
        if ! field_problems="$(python3 - "$p" "$DIR" <<'PYEOF'
import re, sys, os, json

path, pack = sys.argv[1], sys.argv[2]
base = os.path.basename(path)
problems = []
text = open(path, encoding='utf-8').read()

def section(t, title):
    m = re.search(r'^## ' + re.escape(title) + r'[^\n]*\n(.*?)(?=^## |\Z)', t, re.M | re.S)
    return m.group(1) if m else ''

def parse_table(sec):
    rows = []
    for line in sec.splitlines():
        s = line.strip()
        if not s.startswith('|'):
            continue
        tmp = s.replace('\\|', '\x00')
        rows.append([c.replace('\x00', '\\|').strip() for c in tmp.strip('|').split('|')])
    return [r for r in rows if not all(re.fullmatch(r'[-: ]*', c) for c in r)]

quant = parse_table(section(text, '节点样式量化表'))
if not quant:
    sys.exit(0)
header, data = quant[0], quant[1:]

def col(*keys):
    for i, h in enumerate(header):
        if any(k in h for k in keys):
            return i
    return -1

type_i = col('类型', '分类')
text_i = col('文案')
asset_i = col('素材')
role_i = col('角色')
color_i = col('颜色', '填充')

if asset_i < 0:
    problems.append(base + ' 6c 量化表缺「素材/资产引用」必备列（最小封闭列集，见 ui-spec-guide 厚规格完整性门槛）')
if text_i < 0:
    problems.append(base + ' 6c 量化表缺「文案/字体排版」必备列（最小封闭列集）')

icon_names = set()
ij = os.path.join(pack, 'icons', 'icons.json')
if os.path.exists(ij):
    try:
        icon_names = {i.get('name', '') for i in json.load(open(ij, encoding='utf-8')).get('icons', [])}
    except Exception:
        pass

def row_type(row):
    parts = []
    for i in (type_i, role_i):
        if 0 <= i < len(row):
            parts.append(row[i])
    return ' '.join(parts)

def is_material(row):
    return bool(re.search(r'IMAGE-SVG|IMAGE填充|矢量|位图', row_type(row)))

def is_text_row(row):
    return type_i >= 0 and type_i < len(row) and row[type_i].strip().startswith('TEXT')

has_text = False
for n, row in enumerate(data, start=2):
    if is_text_row(row):
        has_text = True
        if text_i >= 0 and text_i < len(row):
            first = row[text_i].split('\\|')[0].strip()
            if first in ('—', '-', '–', '——', ''):
                problems.append(base + ' 6d 量化表第' + str(n) + '行 TEXT 节点文案位为空/「—」（设计稿路线取 Figma characters 字段机械提取，禁止留空）')
    if asset_i >= 0 and is_material(row) and asset_i < len(row):
        v = row[asset_i].strip()
        if v in ('—', '-', ''):
            problems.append(base + ' 6e 量化表第' + str(n) + '行 矢量/位图节点素材列为空（值域: assets/<文件>/icons/<icon-xxx>/代码复刻/豁免/人工补录）')
        elif not (v == '代码复刻' or v.startswith('豁免') or v.startswith('人工补录')
                  or re.match(r'^(assets|icons)/[A-Za-z0-9._-]+$', v)):
            problems.append(base + ' 6e 量化表第' + str(n) + '行 素材列值非法: ' + v + '（值域: assets/<文件>/icons/<icon-xxx>/代码复刻/豁免/人工补录）')
        elif v.startswith('assets/') and not (os.path.exists(os.path.join(pack, v)) or os.path.exists(os.path.join(pack, v + '.png'))):
            problems.append(base + ' 6e 量化表第' + str(n) + '行 素材引用文件不存在: ' + v)
        elif v.startswith('icons/'):
            stem = os.path.basename(v)
            if not os.path.exists(os.path.join(pack, v)) and stem not in icon_names:
                problems.append(base + ' 6e 量化表第' + str(n) + '行 图标引用不存在（文件与 icons.json 条目均未命中）: ' + v)
    if color_i >= 0 and color_i < len(row):
        for seg in re.findall(r'渐变[:：]\s*(\S.*)', row[color_i]):
            seg = seg.strip()
            if seg.count('(') != seg.count(')'):
                problems.append(base + ' 6h 量化表第' + str(n) + '行 渐变值括号不配对（疑提取脚本字符预算截断，须回填完整值，禁止以半截渐变作视觉真源）: ' + seg[:80])

cov = parse_table(section(text, '源节点覆盖对账'))
if len(cov) > 1:
    ci = -1
    for i, h in enumerate(cov[0]):
        if '分类' in h or '处理' in h:
            ci = i
            break
    if ci >= 0:
        for n, row in enumerate(cov[1:], start=2):
            if ci < len(row) and re.search(r'IMAGE-SVG|IMAGE填充|矢量|位图', row[ci]) \
               and not re.search(r'图标位|导出资产|代码复刻|豁免|人工补录', row[ci]):
                problems.append(base + ' 6f 覆盖账本第' + str(n) + '行 矢量/位图条目「分类/处理方式」非封闭处置态（图标位/导出资产/代码复刻/豁免/人工补录）: ' + row[ci])

if has_text:
    copysec = section(text, '文案清单')
    static = copysec.split('动态数据区')[0]
    entries = re.findall(r'^[-*]\s+\S', static, re.M)
    tbl = [l for l in static.splitlines() if l.strip().startswith('|')]
    if '（无静态文案）' in static or (not entries and not tbl):
        problems.append(base + ' 6g 量化表存在 TEXT 行但文案清单静态区为空（设计稿路线 = TEXT 节点 characters 封闭清单；空清单将使文案覆盖率断言全 FAIL，禁止以「无静态文案」搪塞）')

for p_ in problems:
    print(p_)
PYEOF
)"; then
          fail "${base} 6c–6g 页面字段校验器执行异常（fail-closed）"
          field_problems=""
        fi
        if [ -n "${field_problems}" ]; then
          while IFS= read -r _prob; do
            [ -n "${_prob}" ] && fail "${_prob}"
          done <<< "${field_problems}"
        fi
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
