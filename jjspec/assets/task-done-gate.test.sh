#!/usr/bin/env bash
# task-done-gate.test.sh — task-done-gate.sh 回归测试
# 覆盖:合规 done PASS / 缺逐条证据 / AC 漏覆盖 / 高风险卡无人审 / ui-gate 待执行后门 /
#       review 合法跳过 / 非页面卡 / 验收节为空 / 验收器漂移 / 路线感知(谎报拦截+figma合规) / 批量模式命中
# author: 李晶
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="${HERE}/task-done-gate.sh"
pass=0; fail=0
ck() {
  local exp="$1" name="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "${rc}" -eq "${exp}" ]; then pass=$((pass+1)); echo "  ok  ${name}"
  else fail=$((fail+1)); echo "  FAIL ${name} (rc=${rc} 期望${exp})"; echo "${out}" | sed 's/^/       /'; fi
}

W="$(mktemp -d)"; trap 'rm -rf "${W}"' EXIT
cd "${W}"; git init -q; git config user.email t@t; git config user.name t
echo base > README.md; git add -A >/dev/null 2>&1; git commit -qm base

mkdir -p changes/r1/tasks
echo "## AC1 定金锁定库存" > spec.md; echo "## AC4 超时拒付退款" >> spec.md

# mk_card <路径> <status> <risk> <usp> <验收节正文> [ui-gate值]
mk_card() {
  mkdir -p "$(dirname "$1")"
  { echo "---"; echo "id: TASK-8$RANDOM"; echo "risk: ${3:-low}"; echo "spec: spec.md"; echo "spec_ac: [AC1, AC4]"
    echo "ui_source_page: ${4:-}"; echo "status: ${2}"; echo "---"
    echo "## 边界"; echo '- src/**'; echo
    echo "## 验收"; [ -n "$5" ] && printf '%s\n' "$5"; echo
    echo "## 执行进度"; echo "- 下一步/阻塞:完成"; echo "- ui-gate:${6:-pixel-diff 0.3% ≤ 0.5% PASS}"; } > "$1"
}
GOOD='- 定金支付后库存锁定(AC1) → 证据:deposit_test.py 全绿
- 超时拒付退款(AC4) → 证据:race_test 通过
- 实现整体 100% 人审 → 证据:人审通过 2026-10-18 批准人李晶'
# mk_page <路径> <source_anchor> — 页面规格 fixture(frontmatter source_anchor + 量化表样例行)
mk_page() {
  mkdir -p "$(dirname "$1")"
  { echo "---"; echo "source_anchor: ${2}"; echo "digest: quantified"; echo "---"
    echo "## 节点样式量化表"; echo "| 节点 | 值 |"; echo "|---|---|"; echo "| btn | 24px |"; } > "$1"
}
mk_page "ui-specs/yzz/pages/p-01.md" "prototype/home.html#p-01"   # HTML 路线页面
mk_page "ui-specs/yzz/pages/p-02.md" "figma:node 12:34"           # 设计稿路线页面
D1="changes/r1/tasks/TASK-801.md"; mk_card "${D1}" done high "ui-specs/yzz/pages/p-01.md" "${GOOD}"            # 场景1 合规
D2="changes/r1/tasks/TASK-802.md"; mk_card "${D2}" done low  "" "- 锁定库存(AC1) → 证据:测试绿
- 超时拒付(AC4)"                                                                                               # 场景2 第二条缺证据
D3="changes/r1/tasks/TASK-803.md"; mk_card "${D3}" done low  "" "- 锁定库存(AC1) → 证据:测试绿"                 # 场景3 漏 AC4
D4="changes/r1/tasks/TASK-804.md"; mk_card "${D4}" done high "ui-specs/yzz/pages/p-01.md" "- 锁定(AC1) → 证据:绿
- 拒付(AC4) → 证据:绿
- 100% 人审 → 证据:待人工安排"                                                                                  # 场景4 无"人审通过"
D5="changes/r1/tasks/TASK-805.md"; mk_card "${D5}" done low "ui-specs/yzz/pages/p-01.md" "${GOOD}" "待执行"     # 场景5 后门组合
D6="changes/r1/tasks/TASK-806.md"; mk_card "${D6}" review high "ui-specs/yzz/pages/p-01.md" "- 人审 → 证据:未审" "待执行"  # 场景6 review 合法
D7="changes/r1/tasks/TASK-807.md"; mk_card "${D7}" in_progress low "" "- 锁定(AC1) → 证据:未跑"                 # 场景7 in_progress 跳过
D8="changes/r1/tasks/TASK-808.md"; mk_card "${D8}" done low  "" "${GOOD}"                                       # 场景8 非页面卡 done
D9="changes/r1/tasks/TASK-809.md"; mk_card "${D9}" done low  "" ""                                              # 场景9 验收节为空
D10="changes/r1/tasks/TASK-810.md"; mk_card "${D10}" done low "ui-specs/yzz/pages/p-01.md" "${GOOD}" "目测检查通过，页面与原型一致"  # 场景10 验收器漂移
D11="changes/r1/tasks/TASK-811.md"; mk_card "${D11}" done low "ui-specs/yzz/pages/p-02.md" "${GOOD}" "结构化断言 8/9 项通过 PASS（命令:node assert.mjs）"  # 场景11 设计稿路线断言合规
D12="changes/r1/tasks/TASK-812.md"; mk_card "${D12}" done low "ui-specs/yzz/pages/p-01.md" "${GOOD}" "结构化断言 8/9 项通过 PASS（命令:node assert.mjs）"  # 场景12 HTML路线谎报断言
git add -A >/dev/null 2>&1; git commit -qm cards

echo "── 单卡模式"
ck 0 "场景1 合规 done PASS"          bash "${SH}" "${D1}"
ck 1 "场景2 条目缺证据 FAIL"         bash "${SH}" "${D2}"
ck 1 "场景3 AC 漏覆盖 FAIL"          bash "${SH}" "${D3}"
ck 1 "场景4 高风险无人审 FAIL"       bash "${SH}" "${D4}"
ck 1 "场景5 ui-gate 待执行 FAIL"     bash "${SH}" "${D5}"
ck 0 "场景6 review 合法跳过 PASS"    bash "${SH}" "${D6}"
ck 0 "场景7 in_progress 跳过 PASS"   bash "${SH}" "${D7}"
ck 0 "场景8 非页面卡 done PASS"      bash "${SH}" "${D8}"
ck 1 "场景9 验收节为空 FAIL"         bash "${SH}" "${D9}"
ck 1 "场景10 验收器漂移 FAIL"        bash "${SH}" "${D10}"
ck 0 "场景11 断言证据合规 PASS"      bash "${SH}" "${D11}"
ck 1 "场景12 HTML路线谎报断言 FAIL"  bash "${SH}" "${D12}"

echo "── 批量模式(--diff)"
out="$(bash "${SH}" --diff HEAD~1 2>&1)"; rc=$?
if [ "${rc}" -eq 1 ] && echo "${out}" | grep -q "TASK-80[23459]"; then pass=$((pass+1)); echo "  ok  场景10 批量命中违规 done 卡"
else fail=$((fail+1)); echo "  FAIL 场景10 批量命中违规 done 卡"; echo "${out}" | sed 's/^/       /'; fi

echo; echo "结果:pass=${pass} fail=${fail}"
[ "${fail}" -eq 0 ]
