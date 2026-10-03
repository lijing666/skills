#!/usr/bin/env bash
# risk-zone-check.sh — 风险区门禁（[risk-ok: @批准人] 唯一合法门；fail-closed：检查不了 = 不通过）
# 用途：逐 commit 对照"风险区清单"——三源取并集（见第 1 步）：
#       AGENTS.md 第 5 节（risk-zones-begin/end 标记包裹的 glob）
#       + 基准分支同文件版本（防止本 PR 自行缩小清单绕过门禁）
#       + 内置元风险区（门禁资产自身，任何项目不可豁免）
#       触碰风险区的 commit 必须在 message 中带 [risk-ok: @<批准人>] 标记，无标记即失败。
# 标记格式：[risk-ok: @<批准人>] <理由（可选）>——批准人是机器可解析字段，不是正文描述；
#       校验四项：① 标记存在 ② 填了批准人（裸 [risk-ok] 无效——否则提交者可自行添加，门禁形同虚设）
#       ③ 批准人不是模板占位符（拒绝 @<批准人> / @TODO 等）④ 批准人与 author **不同名**（同名检查）。
#       ⚠️ ③④ 都是**形式层**检查：只是字符串比对，不等同平台账号身份校验（平台别名/多邮箱可绕过），
#        更不证明批准属实。真正禁止自批靠平台"禁止作者自批 / required approvals"，
#        证明批准属实靠 CI 调平台 API 核验非作者 APPROVED review——脚本是补充不是替代。
# 合并提交：只检查"合并时新增"的改动（evil merge 夹带 / 冲突解决），正常合并不误报。
#       判定方法 = **自动合并重放比对**（git merge-tree --write-tree）：重放两父的自动合并得到
#       "若无人工干预应有的 tree"，与实际 tree 比对——
#         ① 重放成功且 tree 相同 → 纯自动合并，本提交无新增改动 → 不检查（两侧改同一文件不同行也不误报）
#         ② 重放成功但 tree 不同 → 有人在合并时改了东西 → 只检查两者差异文件（精确命中夹带）
#         ③ 重放返回冲突 → 检查全部冲突路径 + 重放 tree 与实际 tree 的差异，择边/删除也不豁免
#       缺少重放能力或运行出错 → 失败；多父合并取相对各父版本的改动并集，保守检查。
#       不用 combined diff：正常合并可能误报，冲突择边又可能漏报。
# 与 boundary-check.sh 的分工：boundary 查"改动是否超出任务卡边界"（白名单）；本脚本查
#       "改动是否擅入风险区且未走唯一门"（黑名单 + 门）。两道门禁并行，互不替代。
# 用法：risk-zone-check.sh <base_ref> [agents_md]
#   base_ref   比较基准，如 origin/main
#   agents_md  AGENTS.md 路径，默认仓库根 AGENTS.md（第 5 节须含 risk-zones-begin/end 标记）
# CI 集成见 ci-snippets/github-actions-risk-zone.yml；回归测试见 risk-zone-check.test.sh
set -euo pipefail

BASE="${1:?用法: risk-zone-check.sh <base_ref> [agents_md]}"
AGENTS="${2:-AGENTS.md}"

[ -f "${AGENTS}" ] || { echo "❌ AGENTS.md 不存在: ${AGENTS}（风险区清单缺失 = 无法执法，fail-closed）"; exit 1; }

# 临时文件用 mktemp（防并发 CI 互相干扰），trap 兜底清理
ZONES="$(mktemp)" ; ZONES_WORK="$(mktemp)" ; ZONES_BASE="$(mktemp)" ; ZONES_META="$(mktemp)"
COMMITS="$(mktemp)" ; FILES="$(mktemp)" ; REPLAY="$(mktemp)"
trap 'rm -f "${ZONES}" "${ZONES_WORK}" "${ZONES_BASE}" "${ZONES_META}" "${COMMITS}" "${FILES}" "${REPLAY}"' EXIT

# 提取风险区清单——begin/end 标记之间的"- <glob> —— <说明>"行，取 glob（首个 token）
extract_zones() { # stdin 读文件内容 → stdout 输出 glob 列表
  sed -n '/risk-zones-begin/,/risk-zones-end/p' \
    | grep -E '^[[:space:]]*-' \
    | sed -E 's/^[[:space:]]*-[[:space:]]*//' \
    | awk 'NF {print $1}' || true
}

# 1. 三源取并集——任一来源单独使用都可被绕过，故必须合并：
#    ① 工作区清单（当前声明）② 基准分支清单（不可被本 PR 自行缩小的底线）③ 内置元风险区
#    标记缺失 = 风险区未显式声明（没写下来 = 不存在）→ fail-closed，禁止静默当作"无风险区"
grep -q 'risk-zones-begin' "${AGENTS}" || { echo "❌ ${AGENTS} 缺少 risk-zones-begin 标记（风险区清单未声明——确无风险区也须显式写 \"- 无\"）"; exit 1; }
grep -q 'risk-zones-end' "${AGENTS}" || { echo "❌ ${AGENTS} 缺少 risk-zones-end 标记"; exit 1; }
extract_zones < "${AGENTS}" > "${ZONES_WORK}"
[ -s "${ZONES_WORK}" ] || { echo "❌ 风险区清单为空（标记之间无 \"- <glob>\" 行；确无风险区也须显式写 \"- 无\"）"; exit 1; }

if git cat-file -e "${BASE}:${AGENTS}" 2>/dev/null; then
  git show "${BASE}:${AGENTS}" | extract_zones > "${ZONES_BASE}"
else
  : > "${ZONES_BASE}"   # 基准分支尚无该清单（首次引入）→ 仅用工作区清单，不视为失败
fi

# 元风险区——门禁资产自身：改它们等于改门禁，不受项目清单约束、不可缩小、不可豁免
# 覆盖主流托管平台的 CODEOWNERS 位置与 CI 配置；项目自建的门禁资产请在 AGENTS.md 清单中追加
cat > "${ZONES_META}" <<'EOF'
AGENTS.md
CODEOWNERS
.github/CODEOWNERS
.gitlab/CODEOWNERS
.gitea/CODEOWNERS
.gitee/CODEOWNERS
docs/CODEOWNERS
.github/workflows/*
.gitlab-ci.yml
.gitea/workflows/*
.gitee/workflows/*
.drone.yml
Jenkinsfile
azure-pipelines.yml
*boundary-check.sh
*risk-zone-check.sh
EOF

cat "${ZONES_WORK}" "${ZONES_BASE}" "${ZONES_META}" | awk 'NF && !seen[$0]++' > "${ZONES}"

# 2. 取范围内全部 commit（含 merge——合并时冲突解决可夹带新改动，evil merge 必须检查）
if ! git -c core.quotepath=off rev-list "${BASE}..HEAD" > "${COMMITS}" 2>/dev/null; then
  echo "❌ 风险区门禁未能执行：git rev-list 失败（基准 ${BASE} 是否存在？）——检查失败按不通过处理"
  exit 1
fi

# 3. 逐 commit 比对：改动文件 ∩ 风险区 glob ≠ ∅ 时，message 必须含合法的 [risk-ok: @批准人]
# 归一化：小写 + 去空白（批准人写法允许大小写/空格差异，但不允许子串含糊匹配）
norm() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]'; }

# 探测合并重放能力：git >= 2.38 才有 merge-tree --write-tree（精确判定合并期改动的前提）
# 用 case 匹配而非 grep 管道——pipefail 下 `git ... -h` 的非 0 退出码会污染管道结果
MERGE_TREE_OK=0
case "$(git merge-tree -h 2>&1 || true)" in *'--write-tree'*) MERGE_TREE_OK=1 ;; esac

# 从 message 提取批准人：匹配 [risk-ok: @xxx]，awk 无匹配时输出空（退出码恒 0，不触发 pipefail）
extract_approver() {
  printf '%s\n' "$1" | awk 'match($0, /\[risk-ok:[ \t]*@[^]]+\]/) {
    s = substr($0, RSTART, RLENGTH)
    gsub(/^\[risk-ok:[ \t]*@/,"",s); gsub(/[ \t]*\]$/,"",s)
    print s; exit
  }'
}

violations=0; flagged=0
while IFS= read -r commit || [ -n "${commit}" ]; do
  # 该 commit 的完整 message（subject + body，%B）
  if ! msg="$(git log -1 --format=%B "${commit}" 2>/dev/null)"; then
    echo "❌ 风险区门禁未能执行：git log 失败（${commit:0:7}）——检查失败按不通过处理"
    exit 1
  fi
  parents="$(git log -1 --format=%P "${commit}")"
  nparents="$(printf '%s' "${parents}" | awk '{print NF}')"
  if [ "${nparents}" -gt 1 ]; then
    # ——合并提交：只取"合并时新增"的改动，避免把两侧已有的改动重复算到合并提交头上
    if [ "${nparents}" -eq 2 ] && [ "${MERGE_TREE_OK}" -eq 1 ]; then
      p1="$(printf '%s' "${parents}" | awk '{print $1}')"
      p2="$(printf '%s' "${parents}" | awk '{print $2}')"
      # -z 保留特殊字符路径；退出码 1 才代表冲突，其余非零值都是执行错误。
      if git merge-tree --write-tree --name-only -z "${p1}" "${p2}" > "${REPLAY}" 2>/dev/null; then
        merge_rc=0
      else
        merge_rc=$?
      fi
      if [ "${merge_rc}" -gt 1 ]; then
        echo "❌ 风险区门禁未能执行：合并重放失败（${commit:0:7}，退出码 ${merge_rc}）——检查失败按不通过处理"
        exit 1
      fi
      : > "${FILES}"
      # 输出顺序：tree NUL；冲突时随后为路径列表、空字段、诊断信息。
      # 冲突路径独立纳入，不依赖最终内容是否与某个父版本相同。
      {
        if ! IFS= read -r -d '' auto_tree || [ -z "${auto_tree}" ]; then
          echo "❌ 风险区门禁未能执行：重放输出缺少 tree（${commit:0:7}）"; exit 1
        fi
        if [ "${merge_rc}" -eq 1 ]; then
          while :; do
            if ! IFS= read -r -d '' conflict_path; then
              echo "❌ 风险区门禁未能执行：冲突路径列表不完整（${commit:0:7}）"; exit 1
            fi
            [ -n "${conflict_path}" ] || break
            printf '%s\0' "${conflict_path}" >> "${FILES}"
          done
        fi
      } < "${REPLAY}"
      if ! actual_tree="$(git rev-parse "${commit}^{tree}" 2>/dev/null)" || [ -z "${actual_tree}" ]; then
        echo "❌ 风险区门禁未能执行：无法取得 ${commit:0:7} 的 tree——检查失败按不通过处理"; exit 1
      fi
      # 自动合并无差异时列表为空；冲突时仍检查额外夹带，重命名的两端都纳入。
      if ! git -c core.quotepath=off diff-tree --no-commit-id --name-only --no-renames -r -z "${auto_tree}" "${actual_tree}" >> "${FILES}" 2>/dev/null; then
        echo "❌ 风险区门禁未能执行：重放比对失败（合并提交 ${commit:0:7}）——检查失败按不通过处理"
        exit 1
      fi
    elif [ "${nparents}" -gt 2 ]; then
      # merge-tree 只支持两路；-m 取相对各父版本改动的并集，避免 combined diff 的交集漏检。
      echo "⚠️ 发现 octopus merge ${commit:0:7}（${nparents} 个父）——按各父版本改动并集保守检查，可能需要额外批准标记"
      if ! git -c core.quotepath=off diff-tree --no-commit-id --name-only --no-renames -r -m -z "${commit}" > "${FILES}" 2>/dev/null; then
        echo "❌ 风险区门禁未能执行：git diff-tree 失败（octopus merge ${commit:0:7}）——检查失败按不通过处理"
        exit 1
      fi
    else
      echo "❌ 风险区门禁未能执行：本环境 git 不支持 merge-tree --write-tree，无法检查合并提交 ${commit:0:7}。"
      echo "   请升级到 git >= 2.38 后重跑；检查失败按不通过处理。"
      exit 1
    fi
  else
    # 普通提交：diff-tree --root 覆盖仓库首 commit
    if ! git -c core.quotepath=off diff-tree --no-commit-id --name-only -r --root -z "${commit}" > "${FILES}" 2>/dev/null; then
      echo "❌ 风险区门禁未能执行：git diff-tree 失败（${commit:0:7}）——检查失败按不通过处理"
      exit 1
    fi
  fi
  touched=""
  while IFS= read -r -d '' file || [ -n "${file}" ]; do
    while IFS= read -r zone; do
      case "${file}" in
        ${zone}) touched="${touched}${file} " ; break ;;
      esac
    done < "${ZONES}"
  done < "${FILES}"
  [ -n "${touched}" ] || continue

  # author 身份（%an / %ae）：rebase 只改 committer 不改 author，故以 author 为自批比对基准
  if ! author_name="$(git log -1 --format=%an "${commit}" 2>/dev/null)" \
     || ! author_email="$(git log -1 --format=%ae "${commit}" 2>/dev/null)" \
     || [ -z "${author_name}" ] || [ -z "${author_email}" ]; then
    echo "❌ 风险区门禁未能执行：无法取得 ${commit:0:7} 的 author 身份（无法判定是否自批）——检查失败按不通过处理"
    exit 1
  fi

  approver="$(extract_approver "${msg}")"
  if [ -z "${approver}" ]; then
    # 区分"完全没有标记"与"标记缺批准人"——后者是升级后的新失效模式，提示必须给出正例
    if printf '%s' "${msg}" | grep -qF '[risk-ok]'; then
      violations=$((violations+1))
      echo "🚫 风险区改动但标记缺批准人：${commit:0:7} → ${touched}"
      echo "   裸 [risk-ok] 无效（提交者可自行添加 = 门禁形同虚设）；正确写法：[risk-ok: @li-jing] <理由>"
    else
      violations=$((violations+1))
      echo "🚫 风险区改动且无 [risk-ok: @批准人] 标记：${commit:0:7} → ${touched}"
    fi
    continue
  fi

  # 占位符检查：直接复制模板的 [risk-ok: @<批准人>] 或填 TODO/xxx 等 = 没填
  a_norm="$(norm "${approver}")"
  if [ -z "${a_norm}" ] || printf '%s' "${a_norm}" | grep -q '[<>]' \
     || printf '%s' "${a_norm}" | grep -qiE '^(todo|tbd|xxx+|placeholder|fixme|name|username|user|someone|somebody|none|null|n/?a|批准人|待填|待补|某人|示例|example)$'; then
    violations=$((violations+1))
    echo "🚫 风险区改动但批准人是占位符：${commit:0:7} → ${touched}"
    echo "   解析到的批准人『${approver}』不是真实身份（模板占位符/待填值）——须填实际批准人，如 [risk-ok: @li-jing]"
    continue
  fi

  # 同名检查（⚠️ 只是形式层的"同名/同邮箱"比对，**不等于平台账号身份校验**）：
  # 批准人与 author 的 name / email 全串 / email 本地部分 / noreply 邮箱的用户名部分任一相同即拦截。
  # 只做相等匹配（不做子串包含）——避免误伤真人。
  # 局限：无法覆盖平台账号别名（不同邮箱但同一账号等）；**真正禁止自批只能靠平台侧
  # "禁止作者自批 / required approvals"**，或 CI 调平台 API 核验非作者 APPROVED review。
  email_local="${author_email%%@*}"
  email_user="${email_local}"
  case "$(norm "${author_email##*@}")" in
    users.noreply.github.com) email_user="${email_local##*+}" ;;
  esac   # 只有 GitHub noreply 使用 <id>+<user>；普通邮箱的 + 后缀是邮件标签
  if [ "${a_norm}" = "$(norm "${author_name}")" ] \
     || [ "${a_norm}" = "$(norm "${author_email}")" ] \
     || [ "${a_norm}" = "$(norm "${email_local}")" ] \
     || [ "${a_norm}" = "$(norm "${email_user}")" ]; then
    violations=$((violations+1))
    echo "🚫 风险区改动：批准人与作者同名（同名检查未通过）：${commit:0:7} → ${touched}"
    echo "   标记批准人 @${approver} 与本 commit author（${author_name} <${author_email}>）相同——批准人须为作者以外的人"
    echo "   （本检查只比对姓名/邮箱字符串，不等同平台账号身份校验；真正的自批拦截在平台分支保护侧）"
    continue
  fi

  flagged=$((flagged+1))
  echo "⚠️ 风险区改动（批准人 @${approver}，作者 ${author_name}）：${commit:0:7} → ${touched}"
done < "${COMMITS}"

if [ "${violations}" -gt 0 ]; then
  echo ""
  echo "❌ 风险区门禁失败：${violations} 个 commit 触碰风险区且无有效批准标记（清单见 ${AGENTS} 第 5 节 + 基准分支同文件 + 内置元风险区）"
  echo "   有效标记格式：[risk-ok: @<批准人>] <理由>；批准人须为 author 以外的人，裸 [risk-ok] 无效。"
  echo "   修正方式：1) 对违规 commit 补有效标记（标记带在 commit message 上，须 rebase/reword 改写历史）；"
  echo "             2) 或重写历史移除违规改动（rebase -i drop / reset）。"
  echo "   注意：本门禁检查的是**提交历史**（${BASE}..HEAD 内每个 commit），普通 git revert 会产生新 commit、"
  echo "         历史中的违规记录仍在，仍需按上述方式处理——撤销改动 ≠ 历史合规。"
  exit 1
fi
if [ "${flagged}" -gt 0 ]; then
  echo "✅ 风险区门禁通过：${flagged} 个 commit 带有效批准标记（⚠️ 仅核验标记格式、非占位符及不同名，批准属实仍须人审核验）"
else
  echo "✅ 风险区门禁通过：无风险区改动"
fi
