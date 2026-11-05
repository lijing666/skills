#!/usr/bin/env bash
# extract-boundary.test.sh — extract-boundary.sh 回归测试
# 在临时 git 仓库中构造场景验证；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：基线白名单/缺卡覆盖/卡未声明边界/全豁免 diff/子目录仓根解析/
#       --worktree 预演口径:未提交卡进白名单(缺口回归锚)·默认模式警告·未跟踪拦截·
#       extract→boundary-check 全链路预演(两件套必须同开)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
EXTRACT="${DIR}/extract-boundary.sh"
CHECK="${DIR}/boundary-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

git init -q "${WORK}/repo"
cd "${WORK}/repo"
git config user.email test@test && git config user.name test

mkdir -p src/allowed src/forbidden changes/req/tasks
echo a > src/allowed/a.py
echo b > src/forbidden/b.py
git add -A && git commit -qm "init"

FAILED=0
expect_rc() { # expect_rc <场景名> <期望退出码> <命令...>
  local name="$1" want="$2"; shift 2
  local rc out
  out="$(bash "$@" 2>&1)" && rc=0 || rc=$?
  if [ "${rc}" -eq "${want}" ]; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}（期望退出码 ${want}，实际 ${rc}）"
    echo "---- 输出 ----"; echo "${out}"; echo "--------------"
    FAILED=1
  fi
  LAST_OUT="${out}"
}
assert_out() { # assert_out <场景名> <期望 grep 模式:有=1/无=0> <模式>
  local name="$1" has="$2" pat="$3"
  if { [ "${has}" -eq 1 ] && echo "${LAST_OUT}" | grep -q "${pat}"; } \
     || { [ "${has}" -eq 0 ] && ! echo "${LAST_OUT}" | grep -q "${pat}"; }; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}（期望输出$([ "${has}" -eq 1 ] && echo 含 || echo 不含)「${pat}」）"
    echo "---- 输出 ----"; echo "${LAST_OUT}"; echo "--------------"
    FAILED=1
  fi
}
mkcard() { # mkcard <卡路径> <boundary glob...>——boundary 围栏格式
  local card="$1"; shift
  { echo "# 任务卡"; echo '```boundary'; printf '%s\n' "$@"; echo '```'; } > "${card}"
}

# ── 基线（默认 CI 口径）──

# 场景1：已提交卡 + 已提交代码改动 → 白名单含卡边界
mkcard changes/req/tasks/TASK-001.md 'src/allowed/*'
echo x >> src/allowed/a.py && git add -A && git commit -qm "c1 卡+代码"
expect_rc "已提交卡进白名单" 0 "${EXTRACT}" HEAD~1
assert_out "白名单含卡边界" 1 'src/allowed/\*'
assert_out "输出恒含豁免段" 1 '豁免段'

# 场景2：代码已提交但无卡覆盖 → 缺卡 fail-closed（既有裁决锚定）
echo y >> src/forbidden/c2.py && git add -A && git commit -qm "c2 无卡代码"
expect_rc "缺卡覆盖拦截" 1 "${EXTRACT}" HEAD~1
assert_out "缺卡错误信息" 1 '缺任务卡覆盖'
git reset -q --hard HEAD~1

# 场景3：卡未声明边界（与代码改动同 commit,非豁免文件在场才触发第二道闸）→ fail-closed
echo z >> src/allowed/a.py
mkcard changes/req/tasks/TASK-002.md && printf '正文无边界声明\n' >> changes/req/tasks/TASK-002.md
git add -A && git commit -qm "c3 代码+无边界卡"
expect_rc "卡未声明边界拦截" 1 "${EXTRACT}" HEAD~1
assert_out "未声明边界错误信息" 1 '未声明边界'
git reset -q --hard HEAD~1

# 场景4：只动豁免文件（changes/ 下）→ 全豁免,输出仅豁免段
echo note >> changes/req/notes.md && git add -A && git commit -qm "c4 纯文档"
expect_rc "全豁免 diff 放行" 0 "${EXTRACT}" HEAD~1
assert_out "纯豁免时无卡边界混入" 0 'src/allowed/\*'
git reset -q --hard HEAD~1

# 场景5：子目录调用 → 仓根解析（同卡同 diff,行为一致）
printf '补充说明\n' >> changes/req/tasks/TASK-001.md && echo z >> src/allowed/a.py && git add -A && git commit -qm "c5 卡+代码"
out_sub="$(cd changes/req && bash "${EXTRACT}" HEAD~1 2>&1)" && rc=0 || rc=$?
if [ "${rc}" -eq 0 ] && echo "${out_sub}" | grep -q 'src/allowed/\*'; then
  echo "PASS: 子目录调用仓根解析一致"
else
  echo "FAIL: 子目录调用行为漂移（rc=${rc}）"; echo "${out_sub}"; FAILED=1
fi
git reset -q --hard HEAD~1

# ── --worktree 预演口径（2026-11 第三缺口修复）──

# 场景6：未提交卡 + 未提交代码 → 默认口径白名单缺卡（缺口回归锚：extract 仍看 BASE...HEAD,
#         check --worktree 却看见未提交代码 = 白名单缺卡假红）；--worktree 卡进白名单
mkcard changes/req/tasks/TASK-100.md 'src/allowed/*' && git add changes/req/tasks/TASK-100.md
echo dirty >> src/allowed/a.py
expect_rc "默认模式未提交卡不进白名单(不拦)" 0 "${EXTRACT}" HEAD
assert_out "默认模式白名单缺未提交卡" 0 'src/allowed/\*'
assert_out "默认模式脏工作区警告" 1 '未提交变更未纳入'
expect_rc "--worktree 未提交卡进白名单" 0 "${EXTRACT}" HEAD --worktree
assert_out "--worktree 白名单含未提交卡边界" 1 'src/allowed/\*'

# 场景7：extract→boundary-check 全链路预演（两件套必须同开）
LAST_OUT=""
OUT_F="$(mktemp)"; trap 'rm -f "${OUT_F}"' EXIT
bash "${EXTRACT}" HEAD --worktree > "${OUT_F}" 2>/dev/null
out="$(bash "${CHECK}" HEAD "${OUT_F}" --worktree 2>&1)" && rc=0 || rc=$?
if [ "${rc}" -eq 0 ]; then
  echo "PASS: 全链路预演——未提交卡边界内放行"
else
  echo "FAIL: 全链路预演应放行（rc=${rc}）"; echo "${out}"; FAILED=1
fi
# 越界未提交代码 → check 拦（extract 白名单正确,拦截来自比对层）
echo leak > src/forbidden/leak.py && git add src/forbidden/leak.py
bash "${EXTRACT}" HEAD --worktree > "${OUT_F}" 2>/dev/null
out="$(bash "${CHECK}" HEAD "${OUT_F}" --worktree 2>&1)" && rc=0 || rc=$?
if [ "${rc}" -eq 1 ] && echo "${out}" | grep -q 'src/forbidden/leak.py'; then
  echo "PASS: 全链路预演——未提交越界变更拦截"
else
  echo "FAIL: 全链路预演未拦截越界（rc=${rc}）"; echo "${out}"; FAILED=1
fi
rm -f "${OUT_F}"
git reset -q --hard HEAD && git clean -qfd

# 场景8：--worktree 未跟踪文件 fail-closed（新建任务卡未 git add 同样覆盖不到）
echo w > src/untracked_f.py
expect_rc "--worktree 未跟踪文件拦截" 1 "${EXTRACT}" HEAD --worktree
assert_out "未跟踪错误信息" 1 '未跟踪'
rm src/untracked_f.py

# 场景9：基准不存在 → fail-closed（fail-closed 语义锚定）
expect_rc "基准不存在时检查失败" 1 "${EXTRACT}" refs/heads/nonexistent

if [ "${FAILED}" -eq 0 ]; then echo "ALL PASS"; else exit 1; fi
