#!/usr/bin/env bash
# boundary-check.test.sh — boundary-check.sh 回归测试
# 在临时 git 仓库中构造场景验证；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：放行/拦截/基准不存在(fail-closed)/重命名搬运/中文文件名
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/boundary-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

git init -q "${WORK}/repo"
cd "${WORK}/repo"
git config user.email test@test && git config user.name test

mkdir -p src/allowed src/forbidden
echo a > src/allowed/a.py
echo b > src/forbidden/b.py
printf 'src/allowed/*\n' > boundary.txt
git add -A && git commit -qm "init"

FAILED=0
expect() { # expect <场景名> <期望退出码> <base_ref>
  local name="$1" want="$2" base="$3" rc out
  out="$(bash "${SCRIPT}" "${base}" boundary.txt 2>&1)" && rc=0 || rc=$?
  if [ "${rc}" -eq "${want}" ]; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}（期望退出码 ${want}，实际 ${rc}）"
    echo "---- 输出 ----"; echo "${out}"; echo "--------------"
    FAILED=1
  fi
}

# 场景1：允许范围内的普通改动 → 通过
echo x >> src/allowed/a.py && git add -A && git commit -qm "c1"
expect "范围内改动放行" 0 "HEAD~1"

# 场景2：范围外改动 → 拒绝
echo y >> src/forbidden/b.py && git add -A && git commit -qm "c2"
expect "范围外改动拦截" 1 "HEAD~1"

# 场景3：基准分支不存在 → 必须失败（fail-closed，旧版 bug：报通过退出 0）
expect "基准不存在时检查失败（fail-closed）" 1 "refs/heads/nonexistent"

# 场景4：把边界外文件改名搬进允许目录 → 必须识别对原文件的改动（旧版漏报）
git mv src/forbidden/b.py src/allowed/b.py && git commit -qm "c3"
expect "重命名搬运越界拦截" 1 "HEAD~1"

# 场景5：允许范围内的中文文件名改动 → 正常通过（旧版误判越界）
echo z >> src/allowed/中文文件.py && git add -A && git commit -qm "c4"
expect "中文文件名范围内放行" 0 "HEAD~1"

# 场景6：允许范围内含引号/反斜杠的文件名 → 正常通过（NUL 分隔读取修复前被转义误拒）
echo q >> 'src/allowed/带"引号.py' && echo r >> 'src/allowed/反斜\杠.py' && git add -A && git commit -qm "c5"
expect "特殊字符文件名范围内放行" 0 "HEAD~1"

# 场景7：确定越界场景的完整报告——断言退出码、违规路径、错误摘要、无脚本自身报错
#         （b.py 已被场景4移走，用新文件构造越界）
echo w > src/forbidden/c2.py && git add -A && git commit -qm "c6"
out="$(bash "${SCRIPT}" "HEAD~1" boundary.txt 2>&1)" && rc=0 || rc=$?
if [ "${rc}" -eq 1 ] \
   && echo "${out}" | grep -q "src/forbidden/c2.py" \
   && echo "${out}" | grep -q "越界检测失败" \
   && ! echo "${out}" | grep -q "unbound variable"; then
  echo "PASS: 越界报告完整（退出码/违规路径/摘要/无脚本报错）"
else
  echo "FAIL: 越界报告不完整（退出码=${rc}）"
  echo "---- 输出 ----"; echo "${out}"; echo "--------------"
  FAILED=1
fi

if [ "${FAILED}" -eq 0 ]; then echo "ALL PASS"; else exit 1; fi
