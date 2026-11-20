#!/usr/bin/env bash
# task-done-gate.test.sh — task-done-gate.sh 回归测试
# 覆盖:合规 done PASS / 缺逐条证据 / AC 漏覆盖 / 高风险卡风险报告执法(缺报告/无条目/空壳条目/
#       赌注行无对账点拦截,红线条目/消解行/全角冒号放行) / blocked 合法跳过 / 非页面卡 /
#       验收节为空 / 验收器漂移 / 路线感知(谎报拦截+figma合规) / 批量模式命中 /
#       行为卡红基线(缺行拦截/占位拦截/豁免放行/证据放行/全角冒号兼容)——骨架先行执法锚点
#       (v1.21.0 卡级同步人审废止:校验④由「人审通过记录」改为「风险报告条目/消解行在场」)
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

# mk_card <路径> <status> <risk> <usp> <验收节正文> [ui-gate值] [报告模式:ok|empty|resolve|skip]
#   risk=high 且模式≠skip 时,按模式向 changes/r1/risk-report.md 追加本卡条目(id 与卡 frontmatter 同源)
mk_card() {
  mkdir -p "$(dirname "$1")"
  local cid="TASK-8$RANDOM"
  { echo "---"; echo "id: ${cid}"; echo "risk: ${3:-low}"; echo "spec: spec.md"; echo "spec_ac: [AC1, AC4]"
    echo "ui_source_page: ${4:-}"; echo "status: ${2}"; echo "---"
    echo "## 边界"; echo '- src/**'; echo
    echo "## 验收"; [ -n "$5" ] && printf '%s\n' "$5"; echo
    echo "## 执行进度"; echo "- 下一步/阻塞:完成"; echo "- ui-gate:${6:-pixel-diff 0.3% ≤ 0.5% PASS}"; } > "$1"
  if [ "${3:-low}" = "high" ] && [ "${7:-ok}" != "skip" ]; then
    local hdr="### ${cid} 测试卡 ｜ 红线 ｜ 2026-11-14"
    case "${7:-ok}" in
      empty)   printf '%s\n- 处置:待读\n\n' "${hdr}" >> changes/r1/risk-report.md ;;
      resolve) printf '%s\n- 预期赌注「锁定期金额不可变」消解——担保来源:spec AC1\n- 处置:待读\n\n' "${hdr}" >> changes/r1/risk-report.md ;;
      noacct)  printf '%s\n- 赌注:锁定期金额不可变——假设无并发改价\n- 处置:待读\n\n' "${hdr}" >> changes/r1/risk-report.md ;;
      fullacct) printf '%s\n- 赌注：锁定期金额不可变——假设无并发改价（对账点：结算对账时发现尾款不符）\n- 处置：待读\n\n' "${hdr}" >> changes/r1/risk-report.md ;;
      *)       printf '%s\n- 赌注:锁定期金额不可变——假设无并发改价(对账点:结算单与应收账款对账时发现尾款不符)\n- 处置:待读\n\n' "${hdr}" >> changes/r1/risk-report.md ;;
    esac
  fi
}
GOOD='- 定金支付后库存锁定(AC1) → 证据:deposit_test.py 全绿
- 超时拒付退款(AC4) → 证据:race_test 通过'
# mk_page <路径> <source_anchor> — 页面规格 fixture(frontmatter source_anchor + 量化表样例行)
mk_page() {
  mkdir -p "$(dirname "$1")"
  { echo "---"; echo "source_anchor: ${2}"; echo "digest: quantified"; echo "---"
    echo "## 节点样式量化表"; echo "| 节点 | 值 |"; echo "|---|---|"; echo "| btn | 24px |"; } > "$1"
}
mk_page "ui-specs/yzz/pages/p-01.md" "prototype/home.html#p-01"   # HTML 路线页面
mk_page "ui-specs/yzz/pages/p-02.md" "figma:node 12:34"           # 设计稿路线页面
D1="changes/r1/tasks/TASK-801.md"; mk_card "${D1}" done high "ui-specs/yzz/pages/p-01.md" "${GOOD}" "" ok             # 场景1 合规(红线条目在场)
D2="changes/r1/tasks/TASK-802.md"; mk_card "${D2}" done low  "" "- 锁定库存(AC1) → 证据:测试绿
- 超时拒付(AC4)"                                                                                                       # 场景2 第二条缺证据
D3="changes/r1/tasks/TASK-803.md"; mk_card "${D3}" done low  "" "- 锁定库存(AC1) → 证据:测试绿"                        # 场景3 漏 AC4
D4="changes/r1/tasks/TASK-804.md"; mk_card "${D4}" done high "ui-specs/yzz/pages/p-01.md" "${GOOD}" "" empty           # 场景4 报告条目空壳(无赌注无消解)
D5="changes/r1/tasks/TASK-805.md"; mk_card "${D5}" done low "ui-specs/yzz/pages/p-01.md" "${GOOD}" "待执行"             # 场景5 后门组合
D6="changes/r1/tasks/TASK-806.md"; mk_card "${D6}" blocked high "ui-specs/yzz/pages/p-01.md" "- 占位 → 证据:未跑" "待执行" skip  # 场景6 blocked 合法跳过
D7="changes/r1/tasks/TASK-807.md"; mk_card "${D7}" in_progress low "" "- 锁定(AC1) → 证据:未跑"                        # 场景7 in_progress 跳过
D8="changes/r1/tasks/TASK-808.md"; mk_card "${D8}" done low  "" "${GOOD}"                                              # 场景8 非页面卡 done
D9="changes/r1/tasks/TASK-809.md"; mk_card "${D9}" done low  "" ""                                                     # 场景9 验收节为空
D10="changes/r1/tasks/TASK-810.md"; mk_card "${D10}" done low "ui-specs/yzz/pages/p-01.md" "${GOOD}" "目测检查通过，页面与原型一致"     # 场景10 验收器漂移
D11="changes/r1/tasks/TASK-811.md"; mk_card "${D11}" done low "ui-specs/yzz/pages/p-02.md" "${GOOD}" "结构化断言 8/9 项通过 PASS（命令:node assert.mjs）"  # 场景11 设计稿路线断言合规
D12="changes/r1/tasks/TASK-812.md"; mk_card "${D12}" done low "ui-specs/yzz/pages/p-01.md" "${GOOD}" "结构化断言 8/9 项通过 PASS（命令:node assert.mjs）"  # 场景12 HTML路线谎报断言
# add_tfl <卡> — 追加「## 测试文件清单」节(行为卡代理:声明清单即触发红基线检查)
add_tfl() { printf '\n## 测试文件清单\n- grouping_agent/tests/test_guard.py\n' >> "$1"; }
D13="changes/r1/tasks/TASK-813.md"; mk_card "${D13}" done low "" "${GOOD}"; add_tfl "${D13}"                                          # 场景13 行为卡缺红基线行
D14="changes/r1/tasks/TASK-814.md"; mk_card "${D14}" done low "" "${GOOD}"; echo "- 红基线:待执行" >> "${D14}"; add_tfl "${D14}"       # 场景14 红基线占位
D15="changes/r1/tasks/TASK-815.md"; mk_card "${D15}" done low "" "${GOOD}"; echo "- 红基线:豁免——无新增测试,全部既有看护" >> "${D15}"; add_tfl "${D15}"  # 场景15 豁免行
D16="changes/r1/tasks/TASK-816.md"; mk_card "${D16}" done low "" "${GOOD}"; echo "- 红基线:pytest test_guard.py -q → 3 failed(先行失败留证) → 实现后全绿" >> "${D16}"; add_tfl "${D16}"  # 场景16 证据行
git add -A >/dev/null 2>&1; git commit -qm cards

echo "── 单卡模式"
ck 0 "场景1 合规 done PASS"          bash "${SH}" "${D1}"
ck 1 "场景2 条目缺证据 FAIL"         bash "${SH}" "${D2}"
ck 1 "场景3 AC 漏覆盖 FAIL"          bash "${SH}" "${D3}"
ck 1 "场景4 报告条目空壳 FAIL"       bash "${SH}" "${D4}"
ck 1 "场景5 ui-gate 待执行 FAIL"     bash "${SH}" "${D5}"
ck 0 "场景6 blocked 合法跳过 PASS"   bash "${SH}" "${D6}"
ck 0 "场景7 in_progress 跳过 PASS"   bash "${SH}" "${D7}"
ck 0 "场景8 非页面卡 done PASS"      bash "${SH}" "${D8}"
ck 1 "场景9 验收节为空 FAIL"         bash "${SH}" "${D9}"
ck 1 "场景10 验收器漂移 FAIL"        bash "${SH}" "${D10}"
ck 0 "场景11 断言证据合规 PASS"      bash "${SH}" "${D11}"
ck 1 "场景12 HTML路线谎报断言 FAIL"  bash "${SH}" "${D12}"
echo "── 行为卡红基线(骨架先行执法锚点)"
ck 1 "场景13 行为卡缺红基线行 FAIL"   bash "${SH}" "${D13}"
ck 1 "场景14 红基线占位 FAIL"         bash "${SH}" "${D14}"
ck 0 "场景15 红基线豁免行 PASS"       bash "${SH}" "${D15}"
ck 0 "场景16 红基线证据行 PASS"       bash "${SH}" "${D16}"
D17="changes/r1/tasks/TASK-817.md"; mk_card "${D17}" done low "" "${GOOD}"; echo "- 红基线：pytest test_x.py → 2 failed（全角冒号变体）→ 实现后全绿" >> "${D17}"; add_tfl "${D17}"  # 场景17 全角冒号红基线
ck 0 "场景17 全角冒号红基线 PASS"     bash "${SH}" "${D17}"
echo "── 高风险卡风险报告执法(校验④)"
D18="changes/r2/tasks/TASK-818.md"; mk_card "${D18}" done high "" "${GOOD}" "" skip                   # 场景18 风险报告不存在(r2 无报告)
ck 1 "场景18 缺风险报告 FAIL"         bash "${SH}" "${D18}"
D19="changes/r1/tasks/TASK-819.md"; mk_card "${D19}" done high "" "${GOOD}" "" resolve                # 场景19 消解行放行(预测落空闭环)
ck 0 "场景19 消解行 PASS"             bash "${SH}" "${D19}"
D20="changes/r1/tasks/TASK-820.md"; mk_card "${D20}" done high "" "${GOOD}" "" noacct                 # 场景20 赌注行无对账点(格式兜底)
ck 1 "场景20 赌注行无对账点 FAIL"     bash "${SH}" "${D20}"
D21="changes/r1/tasks/TASK-821.md"; mk_card "${D21}" done high "" "${GOOD}" "" fullacct               # 场景21 全角对账点放行
ck 0 "场景21 全角对账点 PASS"         bash "${SH}" "${D21}"

echo "── 批量模式(--diff)"
out="$(bash "${SH}" --diff HEAD~1 2>&1)"; rc=$?
if [ "${rc}" -eq 1 ] && echo "${out}" | grep -q "TASK-80[23459]"; then pass=$((pass+1)); echo "  ok  批量命中违规 done 卡"
else fail=$((fail+1)); echo "  FAIL 批量命中违规 done 卡"; echo "${out}" | sed 's/^/       /'; fi

echo; echo "结果:pass=${pass} fail=${fail}"
[ "${fail}" -eq 0 ]
