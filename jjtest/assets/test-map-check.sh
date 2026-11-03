#!/usr/bin/env bash
# test-map-check.sh — 测试地图结构门禁（jjtest 物料：阶段 0 全域定位 执法层）
#
# 职责：机械校验项目仓 quality/test-map.md 的 schema 完整性（判据见 jjtest references/test-map-guide.md）。
#   地图允许内容不完整（缺口显式留痕是合法形态），但结构不完整 = 盘点未完成 = 拦截（fail-closed）。
#
# 裁决口径：
#   ① frontmatter 含 title 与 generated_at（无版本时间戳的地图无腐化检测锚点）
#   ② 七节封闭齐备：业务域/接口契约/测试现状/风险/运行平台/自动化条件/分期计划——自拟/缺节即拦
#   ③ 每节非空：至少 1 条 `- ` 条目，或含显式「无——缺口:」理由行；空白节 = 盘点假象即拦
#   ④ 分期计划节：含第一期/第二期范围行 + 第一期完成条件四锚点
#      （可重复执行/运行时契约校验/阻断/可追溯）——锚点缺失 = 分期不可机械验收 = 拦
#
# 用法：test-map-check.sh <test-map.md 路径>
# author: 李晶
set -uo pipefail

MAP="${1:?用法: test-map-check.sh <test-map.md 路径>}"
[ -f "${MAP}" ] || { echo "❌ 测试地图文件不存在: ${MAP}" >&2; exit 2; }

if ! problems="$(python3 - "${MAP}" <<'PYEOF'
import re, sys

path = sys.argv[1]
problems = []
text = open(path, encoding='utf-8').read()

# ① frontmatter
fm = re.match(r'^---\s*\n(.*?)\n---\s*\n', text, re.S)
if not fm:
    problems.append('缺 YAML frontmatter（title/generated_at 无落点，腐化检测无锚点）')
else:
    block = fm.group(1)
    for key in ('title', 'generated_at'):
        if not re.search(r'^' + key + r':\s*\S', block, re.M):
            problems.append(f'frontmatter 缺 {key}（无版本时间戳 = 腐化检测无锚点）')

# ② 七节封闭
SECTIONS = ['业务域', '接口契约', '测试现状', '风险', '运行平台', '自动化条件', '分期计划']
pos = {}
for name in SECTIONS:
    m = re.search(r'^## ' + re.escape(name) + r'\s*$', text, re.M)
    if not m:
        problems.append(f'缺「## {name}」节（七节封闭，自拟节名不识别——schema 见 jjtest test-map-guide）')
        continue
    pos[name] = m.start()

if len(pos) == len(SECTIONS):
    # ③ 每节非空或显式理由
    for i, name in enumerate(SECTIONS):
        start = pos[name] + len(f'## {name}')
        end = pos[SECTIONS[i + 1]] if i + 1 < len(SECTIONS) else len(text)
        body = text[start:end]
        entries = re.findall(r'^[-*]\s+\S', body, re.M)
        if not entries and not re.search(r'无[——-]+缺口[:：]', body):
            problems.append(f'「## {name}」节为空且无「无——缺口:」显式理由（空白节 = 盘点假象）')
    # ④ 分期计划锚点
    idx = SECTIONS.index('分期计划')
    plan = text[pos['分期计划']:(pos[SECTIONS[idx + 1]] if idx + 1 < len(SECTIONS) else len(text))]
    for anchor in ('第一期', '第二期'):
        if not re.search(r'^[-*].*' + anchor, plan, re.M):
            problems.append(f'分期计划缺{anchor}范围行（分期范围 = 用户拍板产物，缺失即未盘点）')
    for key, pat in (('旅程可重复执行', r'可重复执行'),
                     ('运行时契约校验', r'运行时契约校验'),
                     ('CI 阻断', r'阻断'),
                     ('证据可追溯', r'可追溯')):
        if not re.search(pat, plan):
            problems.append(f'第一期完成条件缺锚点「{key}」（四锚点 = 第一期验收判据，缺失即无法机械判定完成）')

for p in problems:
    print(p)
PYEOF
)"; then
  echo "❌ 测试地图校验器执行异常（fail-closed）" >&2
  exit 1
fi

if [ -n "${problems}" ]; then
  echo "❌ 测试地图结构校验不通过（fail-closed）:" >&2
  while IFS= read -r p; do [ -n "${p}" ] && echo "  - ${p}" >&2; done <<< "${problems}"
  exit 1
fi
echo "✅ 测试地图结构校验通过: ${MAP}"
exit 0
