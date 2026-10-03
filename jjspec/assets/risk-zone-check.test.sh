#!/usr/bin/env bash
# risk-zone-check.test.sh — risk-zone-check.sh 回归测试
# 在临时 git 仓库中构造场景验证；全部通过输出 ALL PASS，任一失败退出码非 0。
# 覆盖：普通改动放行/风险区无标记拦截/带标记放行(subject与body)/混合commit/清单缺标记(fail-closed)/
#       清单为空(fail-closed)/显式"无风险区"放行/基准不存在(fail-closed)/中文路径/merge跳过/报告完整/
#       evil merge 夹带改动拦截/缩小清单绕过拦截/改门禁资产自身拦截（后三项为审计发现的漏报场景）/
#       改平台CI配置拦截/裸[risk-ok]缺批准人拦截/同名拦截（@自己）/批准人≠author放行/
#       正常合并不误报（两侧改同一文件不同行）/占位符批准人拦截/noreply邮箱同名拦截/
#       冲突择边与删除解决/普通邮箱加号别名/合并能力缺失与执行失败
set -euo pipefail

SCRIPT="$(cd "$(dirname "$0")" && pwd)/risk-zone-check.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

git init -q "${WORK}/repo"
cd "${WORK}/repo"
git config user.email test@test && git config user.name test

mkdir -p src/normal src/payment docs
echo a > src/normal/a.py
echo b > src/payment/b.py

cat > AGENTS.md <<'EOF'
# AGENTS.md
## 5. 风险区清单（AI 禁改区）
<!-- risk-zones-begin（机器解析区）
     行格式：- <glob> —— <说明> -->
- src/payment/** —— 支付核心：改动须人批准 + 100% 人审
<!-- risk-zones-end -->
EOF
git add -A && git commit -qm "init"

FAILED=0
expect() { # expect <场景名> <期望退出码> <base_ref> [agents_md]
  local name="$1" want="$2" base="$3" agents="${4:-AGENTS.md}" rc out
  out="$(bash "${SCRIPT}" "${base}" "${agents}" 2>&1)" && rc=0 || rc=$?
  if [ "${rc}" -eq "${want}" ]; then
    echo "PASS: ${name}"
  else
    echo "FAIL: ${name}（期望退出码 ${want}，实际 ${rc}）"
    echo "---- 输出 ----"; echo "${out}"; echo "--------------"
    FAILED=1
  fi
}

# 场景1：不触碰风险区的普通改动 → 通过
echo x >> src/normal/a.py && git add -A && git commit -qm "c1: normal change"
expect "普通改动放行" 0 "HEAD~1"

# 场景2：触碰风险区且无 [risk-ok: @批准人] → 拒绝
echo y >> src/payment/b.py && git add -A && git commit -qm "c2: payment change without marker"
expect "风险区无标记拦截" 1 "HEAD~1"

# 场景3：触碰风险区且 subject 带 [risk-ok: @批准人]（批准人 ≠ author）→ 放行
echo z >> src/payment/b.py && git add -A && git commit -qm "[risk-ok: @reviewer] c3: payment fix"
expect "带标记放行（subject）" 0 "HEAD~1"

# 场景4：标记在 message body → 放行（%B 全文检索）
echo w >> src/payment/b.py && git add -A && git commit -qm "c4: payment fix" -m "背景说明" -m "[risk-ok: @reviewer] 批准留痕"
expect "带标记放行（body）" 0 "HEAD~1"

# 场景5：混合 commits——普通无标记 + 风险区带标记 → 放行
echo q >> src/normal/a.py && git add -A && git commit -qm "c5: normal"
echo r >> src/payment/b.py && git add -A && git commit -qm "[risk-ok: @reviewer] c6: payment"
expect "混合commit风险区带标记放行" 0 "HEAD~2"

# 场景6：混合 commits——风险区无标记 → 只拦风险区那个 commit
echo s >> src/normal/a.py && git add -A && git commit -qm "c7: normal"
echo t >> src/payment/b.py && git add -A && git commit -qm "c8: payment no marker"
expect "混合commit风险区无标记拦截" 1 "HEAD~2"

# 场景7：AGENTS.md 缺 risk-zones 标记 → fail-closed（禁止静默当作无风险区）
printf '# AGENTS.md\n## 5. 风险区清单\n- src/payment/**\n' > AGENTS-bad.md
expect "清单缺标记fail-closed" 1 "HEAD~1" "AGENTS-bad.md"

# 场景8：标记之间无清单行 → fail-closed
printf '# AGENTS.md\n<!-- risk-zones-begin -->\n<!-- risk-zones-end -->\n' > AGENTS-empty.md
expect "清单为空fail-closed" 1 "HEAD~1" "AGENTS-empty.md"

# 场景9：显式"无风险区"（- 无）→ 一切改动放行
printf '# AGENTS.md\n<!-- risk-zones-begin -->\n- 无\n<!-- risk-zones-end -->\n' > AGENTS-none.md
expect "显式无风险区放行" 0 "HEAD~1" "AGENTS-none.md"

# 场景10：基准分支不存在 → 必须失败（fail-closed）
expect "基准不存在fail-closed" 1 "refs/heads/nonexistent"

# 场景11：风险区内中文文件名 → 正常拦截/放行（core.quotepath=off 处理）
echo u > src/payment/退款逻辑.py && git add -A && git commit -qm "c9: 中文路径无标记"
expect "中文路径无标记拦截" 1 "HEAD~1"
echo v >> src/payment/退款逻辑.py && git add -A && git commit -qm "[risk-ok: @reviewer] c10: 中文路径带标记"
expect "中文路径带标记放行" 0 "HEAD~1"

# 场景12：纯自动合并无新增改动（其构成 commit 各自负责）
git checkout -qb side HEAD~1
echo m >> docs/readme.md && git add -A && git commit -qm "side: docs"
git checkout -q -
git merge -q --no-ff side -m "merge: side"
expect "merge跳过不误报" 0 "HEAD^1"
CLEAN_DOCS_MERGE="$(git rev-parse HEAD)"

# 场景13：拦截报告完整——退出码、违规路径、错误摘要、无脚本自身报错
echo n > src/payment/new.py && git add -A && git commit -qm "c11: no marker"
out="$(bash "${SCRIPT}" "HEAD~1" 2>&1)" && rc=0 || rc=$?
if [ "${rc}" -eq 1 ] \
   && echo "${out}" | grep -q "src/payment/new.py" \
   && echo "${out}" | grep -q "风险区门禁失败" \
   && ! echo "${out}" | grep -q "unbound variable"; then
  echo "PASS: 拦截报告完整（退出码/违规路径/摘要/无脚本报错）"
else
  echo "FAIL: 拦截报告不完整（退出码=${rc}）"
  echo "---- 输出 ----"; echo "${out}"; echo "--------------"
  FAILED=1
fi

# 场景14：evil merge——两分支都只改普通文件，合并提交中夹带风险区改动且无标记 → 必须拦截
#         （重放自动合并后与实际 tree 比对，夹带改动必须被检出）
git checkout -qb evil HEAD~1
echo e1 >> docs/readme.md && git add -A && git commit -qm "evil: docs"
git checkout -q -
echo e2 >> src/normal/a.py && git add -A && git commit -qm "main: normal"
git merge -q --no-commit --no-ff evil 2>/dev/null
echo e3 >> src/payment/b.py && git add -A && git commit -qm "merge: evil（夹带支付改动，无标记）"
expect "evil merge夹带改动拦截" 1 "HEAD^1"

# 场景15：本 PR 缩小风险区清单以绕过门禁（工作区清单改"- 无"，只提交支付改动）→ 基准清单为底线，仍须拦截
printf '# AGENTS.md\n<!-- risk-zones-begin -->\n- 无\n<!-- risk-zones-end -->\n' > AGENTS.md
echo s1 >> src/payment/b.py && git add src/payment/b.py && git commit -qm "shrink: 改支付代码（清单已缩小）"
expect "缩小清单绕过拦截" 1 "HEAD~1"

# 场景16：改门禁资产自身（AGENTS.md）不带有效标记 → 拦截（元风险区内置于脚本，不受项目清单约束）
git checkout -q -- AGENTS.md
echo "补充说明" >> AGENTS.md && git add -A && git commit -qm "docs: 补充说明"
expect "改门禁资产自身拦截" 1 "HEAD~1"

# 场景17：改平台 CI 配置（GitLab/Gitea/Gitee）不带有效标记 → 拦截（元风险区须跨平台覆盖，不可只认 GitHub）
git checkout -q -- AGENTS.md
mkdir -p .gitea/workflows .gitee/workflows
echo "stages: [test]" > .gitlab-ci.yml
echo "name: ci" > .gitea/workflows/ci.yml
echo "name: ci" > .gitee/workflows/ci.yml
git add -A && git commit -qm "ci: 调整流水线"
expect "改平台CI配置拦截" 1 "HEAD~1"

# 场景18：裸 [risk-ok]（无批准人）→ 拦截（升级后失效模式：提交者可自行添加裸标记 = 门禁形同虚设）
git checkout -q -- AGENTS.md
echo b1 >> src/payment/b.py && git add -A && git commit -qm "[risk-ok] c12: 裸标记无批准人"
expect "裸标记缺批准人拦截" 1 "HEAD~1"

# 场景19：同名——批准人 = 本 commit author 的 name → 拦截（AI 自提自批是最常见的自动化绕过）
echo b2 >> src/payment/b.py && git add -A && git commit -qm "[risk-ok: @test] c13: 批准人即作者"
expect "同名拦截（name相同）" 1 "HEAD~1"

# 场景20：同名变体——批准人写 author 的完整 email → 同样拦截
echo b3 >> src/payment/b.py && git add -A && git commit -qm "[risk-ok: @test@test] c14: 批准人写作者邮箱"
expect "同名拦截（email相同）" 1 "HEAD~1"

# 场景21：批准人 ≠ author（含大小写/空格差异）→ 放行
echo b4 >> src/payment/b.py && git add -A && git commit -qm "[risk-ok: @ Reviewer ] c15: 合法批准人"
expect "批准人非作者放行" 0 "HEAD~1"

# 场景22：拦截报告须给出有效标记的正例（否则用户不知道怎么改）
echo b5 >> src/payment/b.py && git add -A && git commit -qm "c16: 无标记"
out="$(bash "${SCRIPT}" "HEAD~1" 2>&1)" && rc=0 || rc=$?
if [ "${rc}" -eq 1 ] && echo "${out}" | grep -qF '[risk-ok: @<批准人>]'; then
  echo "PASS: 提示含有效标记正例"
else
  echo "FAIL: 提示缺有效标记正例（退出码=${rc}）"
  echo "---- 输出 ----"; echo "${out}"; echo "--------------"
  FAILED=1
fi

# 场景23：正常合并——两侧分别改同一风险文件的不同行、各自带有效标记，自动合并成功 → 必须放行
#          （combined diff 是文件级粗粒度，会把该文件列为"合并期改动"而误报；新算法用自动合并重放比对）
CURBR="$(git branch --show-current)"
BASE23="$(git rev-parse HEAD)"
git checkout -qb s23 "${BASE23}"
python3 -c "p='src/payment/b.py';s=open(p).read();open(p,'w').write('SIDE\n'+s)"
git add -A && git commit -qm "[risk-ok: @reviewer] s23: 改首行"
git checkout -q "${CURBR}"
python3 -c "p='src/payment/b.py';s=open(p).read();open(p,'w').write(s+'MAIN\n')"
git add -A && git commit -qm "[risk-ok: @reviewer] m23: 改末行"
git merge -q --no-ff s23 -m "merge: 两侧自动合并"
expect "正常合并不误报（两侧改同一文件不同行）" 0 "HEAD^1"
CLEAN_MERGE="$(git rev-parse HEAD)"

# 场景24：批准人填模板占位符（直接复制 [risk-ok: @<批准人>]）→ 拦截
echo c1 >> src/payment/b.py && git add -A && git commit -qm '[risk-ok: @<批准人>] c17: 复制模板占位符'
expect "占位符批准人拦截" 1 "HEAD~1"

# 场景25：批准人填占位词 TODO → 拦截
echo c2 >> src/payment/b.py && git add -A && git commit -qm '[risk-ok: @TODO] c18: 占位词'
expect "占位词批准人拦截" 1 "HEAD~1"

# 场景26：noreply 邮箱作者自批——author=12345+alice-dev@users.noreply.github.com，标记 @alice-dev
#         （邮箱前缀是 12345+alice-dev，只比前缀会漏；须取 '+' 后的用户名部分比对）
echo c3 >> src/payment/b.py && git add -A
git -c user.name="Alice Smith" -c user.email="12345+alice-dev@users.noreply.github.com" \
    commit -qm "[risk-ok: @alice-dev] c19: noreply 自批"
expect "noreply邮箱同名拦截" 1 "HEAD~1"

# 场景27：普通邮箱的 + 后缀是邮件标签，不是 GitHub 用户名；不能据此误拦不同批准人
echo c4 >> src/payment/b.py && git add -A
git -c user.name="Alice Smith" -c user.email="alice+reviewer@company.test" \
    commit -qm "[risk-ok: @reviewer] 普通邮箱标签"
expect "普通邮箱加号标签不误报" 0 "HEAD~1"

# 场景28：真实冲突选择任一父版本，都必须检查合并提交；包括带空格/引号/中文的路径
ROOT_COMMIT="$(git rev-list --max-parents=0 HEAD)"
RISK_FILE='src/payment/限额 "值".txt'
for choice in ours theirs delete; do
  git checkout -qb "conflict-${choice}" "${ROOT_COMMIT}"
  echo 100 > "${RISK_FILE}" && git add -A && git commit -qm "[risk-ok: @reviewer] 初始化限额"
  git checkout -qb "conflict-side-${choice}"
  echo 200 > "${RISK_FILE}" && git add -A && git commit -qm "[risk-ok: @reviewer] 分支限额"
  git checkout -q "conflict-${choice}"
  if [ "${choice}" = delete ]; then
    git rm -q -- "${RISK_FILE}"
  else
    echo 50 > "${RISK_FILE}" && git add -A
  fi
  git commit -qm "[risk-ok: @reviewer] 主线限额"
  merge_rc=0
  git merge -q --no-ff --no-commit "conflict-side-${choice}" >/dev/null 2>&1 || merge_rc=$?
  [ "${merge_rc}" -eq 1 ] || { echo "FAIL: 冲突场景未形成预期冲突"; exit 1; }
  if [ "${choice}" = delete ]; then
    git rm -q -- "${RISK_FILE}"
  else
    git checkout -q "--${choice}" -- "${RISK_FILE}"
    git add -A
  fi
  git commit -qm "resolve: ${choice}"
  expect "风险冲突选择${choice}无标记拦截" 1 "HEAD^1"
  git commit --amend -qm "[risk-ok: @reviewer] resolve: ${choice}"
  expect "风险冲突选择${choice}有标记放行" 0 "HEAD^1"
done

# 场景29：非风险文件的真实冲突不应因为 merge-tree 返回 1 就被一概拒绝
git checkout -qb conflict-docs "${ROOT_COMMIT}"
mkdir -p docs
echo base > docs/conflict.md && git add -A && git commit -qm "docs: base"
git checkout -qb conflict-docs-side
echo side > docs/conflict.md && git add -A && git commit -qm "docs: side"
git checkout -q conflict-docs
echo main > docs/conflict.md && git add -A && git commit -qm "docs: main"
merge_rc=0
git merge -q --no-ff --no-commit conflict-docs-side >/dev/null 2>&1 || merge_rc=$?
[ "${merge_rc}" -eq 1 ] || { echo "FAIL: 文档冲突场景未形成预期冲突"; exit 1; }
git checkout -q --theirs -- docs/conflict.md && git add -A && git commit -qm "docs: resolve"
expect "非风险冲突无标记放行" 0 "HEAD^1"

# 场景30：仅模拟 merge-tree 的能力缺失/运行错误，其余 Git 操作仍使用真实 Git
export JJSPEC_TEST_REAL_GIT="$(command -v git)"
mkdir -p "${WORK}/mock-bin"
cat > "${WORK}/mock-bin/git" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = merge-tree ]; then
  if [ "${JJSPEC_TEST_MERGE_MODE:-}" = unsupported ] && [ "${2:-}" = -h ]; then
    echo 'usage: git merge-tree <base-tree> <branch1> <branch2>'
    exit 129
  fi
  if [ "${JJSPEC_TEST_MERGE_MODE:-}" = error ] && [ "${2:-}" = --write-tree ]; then
    echo 'fatal: simulated object read failure' >&2
    exit 128
  fi
fi
exec "${JJSPEC_TEST_REAL_GIT}" "$@"
EOF
chmod +x "${WORK}/mock-bin/git"
git checkout -q --detach "${CLEAN_MERGE}"
PATH="${WORK}/mock-bin:${PATH}" JJSPEC_TEST_MERGE_MODE=unsupported \
  expect "缺少合并重放能力必须失败" 1 "HEAD^1"
git checkout -q --detach "${CLEAN_DOCS_MERGE}"
PATH="${WORK}/mock-bin:${PATH}" JJSPEC_TEST_MERGE_MODE=error \
  expect "合并重放运行错误必须失败" 1 "HEAD^1"

# 场景31：多父合并取改动并集，合并结果等于某父版本的风险文件也不能漏掉
git checkout -qb octopus-main "${ROOT_COMMIT}"
mkdir -p docs
echo main > docs/octopus.md && git add -A && git commit -qm "docs: octopus main"
git checkout -qb octopus-one "${ROOT_COMMIT}"
echo one > src/payment/one.py && git add -A && git commit -qm "[risk-ok: @reviewer] octopus one"
git checkout -qb octopus-two "${ROOT_COMMIT}"
echo two > src/payment/two.py && git add -A && git commit -qm "[risk-ok: @reviewer] octopus two"
git checkout -q octopus-main
git merge -q --no-ff octopus-one octopus-two -m "merge: octopus" >/dev/null
expect "多父合并风险路径并集拦截" 1 "HEAD^1"
git commit --amend -qm "[risk-ok: @reviewer] merge: octopus"
expect "多父合并有效标记放行" 0 "HEAD^1"

if [ "${FAILED}" -eq 0 ]; then echo "ALL PASS"; else exit 1; fi
