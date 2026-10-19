#!/usr/bin/env bash
# page-excerpt-check.test.sh — page-excerpt-check.sh 回归测试
# 覆盖:转抄合规 PASS / 占位穿帮 / 占位符未替换 / 节缺失 / 指针悬空 / 非页面卡跳过 /
#       多页求和 / M 漂移 / 批量模式 PASS+FAIL / 空块拦截
# author: 李晶
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
SH="${HERE}/page-excerpt-check.sh"
pass=0; fail=0
ck() { # ck <期望:0成功1失败> <场景名> <命令...>
  local exp="$1" name="$2"; shift 2
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "${rc}" -eq "${exp}" ]; then pass=$((pass+1)); echo "  ok  ${name}"
  else fail=$((fail+1)); echo "  FAIL ${name} (rc=${rc} 期望${exp})"; echo "${out}" | sed 's/^/       /'; fi
}

W="$(mktemp -d)"; trap 'rm -rf "${W}"' EXIT
cd "${W}"; git init -q; git config user.email t@t; git config user.name t
echo base > README.md; git add -A >/dev/null 2>&1; git commit -qm base   # HEAD~1:批量模式基准

# ---------- fixture:页面规格(量化表 N 行) ----------
mk_page() { # mk_page <路径> <量化表数据行数>
  mkdir -p "$(dirname "$1")"
  { echo "---"; echo "page_id: p-99"; echo "digest: quantified"; echo "---"; echo "## 节点样式量化表"; echo "| 节点 | 属性 | 值 |"; echo "|---|---|---|";
    for i in $(seq 1 "$2"); do echo "| 节点${i} | 间距 | ${i}0px |"; done
    echo; echo "## 布局语义表"; echo "| 区块 | 方向 |"; echo "|---|---|"; echo "| 主体 | column |"; } > "$1"
}
mk_page "ui-specs/yzz/pages/p-01-a.md" 3
mk_page "ui-specs/yzz/pages/p-02-b.md" 4

# ---------- fixture:卡片 ----------
mk_card() { # mk_card <路径> <摘录节正文(可空=缺节)> [usp]
  mkdir -p "$(dirname "$1")"
  local usp="${3:-ui-specs/yzz/pages/p-01-a.md}"
  { echo "---"; echo "id: TASK-900"; echo "title: 页面卡测试"; echo "ui_source_page: ${usp}"; echo "---"
    echo "## 边界"; echo '- src/**'; echo
    echo "## UI 规格摘录"; [ -n "$2" ] && printf '%s\n' "$2"; echo
    echo "## 执行进度"; echo "- 下一步/阻塞:待执行"; } > "$1"
}
GOOD='- 节点样式摘录(逐节点全量):
- 页头 → 间距 24px
- 表格 → 行高 48px
- 节点3 → 字号 14px
- 源节点覆盖账本摘录(逐节点全量):
- 节点1 | 量化 | 节点1 | —
- 节点2 | 量化 | 节点2 | —
- 节点3 | 量化 | 节点3 | —
- 布局语义摘录(逐条):
- 主体 column
- 静态文案摘录(逐条):
- 标题:运营概况
- 九态映射:
- loading 骨架屏
- 摘录覆盖率:N=3 / M=3'

C1="changes/r1/tasks/TASK-901.md"; mk_card "${C1}" "${GOOD}"                                   # 场景1 合规
C2="changes/r1/tasks/TASK-902.md"; mk_card "${C2}" "- 开工门槛执行:两页全量摘录 + 覆盖率登记
- 摘录覆盖率:N=2 / M=2"                                                                        # 场景2 规则文字占位
C3="changes/r1/tasks/TASK-903.md"; mk_card "${C3}" "- 节点样式摘录(逐节点全量):
- 页头 → 24px
- 布局语义摘录(逐条):
- 主体 column
- 静态文案摘录(逐条):
- 标题
- 九态映射:
- 骨架屏
- 摘录覆盖率:N=<摘录条数> / M=<页面量化表节点数>"                                            # 场景3 占位符未替换
C4="changes/r1/tasks/TASK-904.md"; mk_card "${C4}" ""                                          # 场景4 节缺失
C5="changes/r1/tasks/TASK-905.md"; mk_card "${C5}" "${GOOD}" "ui-specs/yzz/pages/p-xx-ghost.md" # 场景5 悬空
C6="changes/r1/tasks/TASK-906.md"; mkdir -p "$(dirname "${C6}")"
  { echo "---"; echo "id: TASK-906"; echo "---"; echo "## 边界"; echo '- src/**'; } > "${C6}"   # 场景6 非页面卡
C7="changes/r1/tasks/TASK-907.md"; mk_card "${C7}" "${GOOD/p-01/XX}"; sed -i '' 's/XX/GOODX/' /dev/null 2>/dev/null
  # 场景7 多页:重建
  GOOD7='- 节点样式摘录(逐节点全量):
- a1 → 1
- a2 → 2
- a3 → 3
- b1 → 4
- b2 → 5
- b3 → 6
- b4 → 7
- 源节点覆盖账本摘录(逐节点全量):
- a1 | 量化 | a1 | —
- a2 | 量化 | a2 | —
- a3 | 量化 | a3 | —
- b1 | 量化 | b1 | —
- b2 | 量化 | b2 | —
- b3 | 量化 | b3 | —
- b4 | 量化 | b4 | —
- 布局语义摘录(逐条):
- 主体 column
- 静态文案摘录(逐条):
- 标题
- 九态映射:
- 骨架
- 摘录覆盖率:N=7 / M=7'
  mk_card "${C7}" "${GOOD7}" "ui-specs/yzz/pages/p-01-a.md, ui-specs/yzz/pages/p-02-b.md"
mk_page "ui-specs/yzz/pages/p-08-c.md" 3
C8="changes/r1/tasks/TASK-908.md"; mk_card "${C8}" "${GOOD}" "ui-specs/yzz/pages/p-08-c.md"     # 场景8 M 漂移(页面 3 行 vs 登记 3/3 但块内 3 条=3 行 ✓ 改页面为 4 行制造漂移)
  sed -i '' 's/| 节点3 | 间距 | 30px |/| 节点3 | 间距 | 30px |\n| 节点X | 新增 | 9px |/' "ui-specs/yzz/pages/p-08-c.md"
C9="changes/r1/tasks/TASK-909.md"; mk_card "${C9}" "- 节点样式摘录(逐节点全量):
- 页头 → 24px
- 布局语义摘录(逐条):
- 静态文案摘录(逐条):
- 标题
- 九态映射:
- 骨架
- 摘录覆盖率:N=1 / M=1"                                                                          # 场景10 空块(布局语义无条目)
git add -A >/dev/null 2>&1; git commit -qm init

echo "── 单卡模式"
ck 0 "场景1 合规转抄 PASS"           bash "${SH}" "${C1}"
ck 1 "场景2 规则文字占位 FAIL"       bash "${SH}" "${C2}"
ck 1 "场景3 占位符未替换 FAIL"       bash "${SH}" "${C3}"
ck 1 "场景4 摘录节缺失 FAIL"         bash "${SH}" "${C4}"
ck 1 "场景5 页面指针悬空 FAIL"       bash "${SH}" "${C5}"
ck 0 "场景6 非页面卡跳过 PASS"       bash "${SH}" "${C6}"
ck 0 "场景7 多页求和 N=M PASS"       bash "${SH}" "${C7}"
ck 1 "场景8 页面 M 漂移 FAIL"        bash "${SH}" "${C8}"
ck 1 "场景10 布局语义空块 FAIL"      bash "${SH}" "${C9}"

# ---------- 场景11:缺账本块(旧三段格式) → FAIL(六块齐全性)
mk_card "changes/r1/tasks/TASK-910.md" '- 节点样式摘录(逐节点全量):
- 页头 → 间距 24px
- 表格 → 行高 48px
- 节点3 → 字号 14px
- 布局语义摘录(逐条):
- 主体 column
- 静态文案摘录(逐条):
- 标题:运营概况
- 九态映射:
- loading 骨架屏
- 摘录覆盖率:N=3 / M=3'
ck 1 "场景11 缺账本块拦截(旧三段格式)" bash "${SH}" "changes/r1/tasks/TASK-910.md"

# ---------- 场景12:账本条数错配(2 条 vs N=3) → FAIL(一一对应)
mk_card "changes/r1/tasks/TASK-911.md" '- 节点样式摘录(逐节点全量):
- 页头 → 间距 24px
- 表格 → 行高 48px
- 节点3 → 字号 14px
- 源节点覆盖账本摘录(逐节点全量):
- 节点1 | 量化 | 节点1 | —
- 节点2 | 量化 | 节点2 | —
- 布局语义摘录(逐条):
- 主体 column
- 静态文案摘录(逐条):
- 标题:运营概况
- 九态映射:
- loading 骨架屏
- 摘录覆盖率:N=3 / M=3'
ck 1 "场景12 账本条数错配拦截" bash "${SH}" "changes/r1/tasks/TASK-911.md"

# ---------- 场景13:账本块缩进逃逸 → FAIL(计 0 即拦,防绕过)
mk_card "changes/r1/tasks/TASK-912.md" '- 节点样式摘录(逐节点全量):
- 页头 → 间距 24px
- 表格 → 行高 48px
- 节点3 → 字号 14px
- 源节点覆盖账本摘录(逐节点全量):
  - 节点1 | 量化 | 节点1 | —
  - 节点2 | 量化 | 节点2 | —
  - 节点3 | 量化 | 节点3 | —
- 布局语义摘录(逐条):
- 主体 column
- 静态文案摘录(逐条):
- 标题:运营概况
- 九态映射:
- loading 骨架屏
- 摘录覆盖率:N=3 / M=3'
ck 1 "场景13 账本缩进逃逸拦截" bash "${SH}" "changes/r1/tasks/TASK-912.md"

echo "── 批量模式(--diff)"
out="$(bash "${SH}" --diff HEAD~1 2>&1)"; rc=$?
if [ "${rc}" -eq 1 ] && echo "${out}" | grep -q "TASK-90[2589]"; then pass=$((pass+1)); echo "  ok  场景9b 批量命中违规卡明细"
else fail=$((fail+1)); echo "  FAIL 场景9b 批量命中违规卡明细"; echo "${out}" | sed 's/^/       /'; fi

echo; echo "结果:pass=${pass} fail=${fail}"
[ "${fail}" -eq 0 ]
