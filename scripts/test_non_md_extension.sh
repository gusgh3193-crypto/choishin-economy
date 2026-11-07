#!/usr/bin/env bash
#
# test_non_md_extension.sh
#
# scripts/validate_posts.sh의 "7) posts/ 디렉터리 안에 .md가 아닌 파일 검사"
# (2026-11-07 마스터 지시로 추가)가 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: 2026-11-06 scripts/test_filename_format.sh의 검사 4에서,
#   validate_posts.sh의 post_files=("${POSTS_DIR}"/*.md) 글롭(수정 전 기준
#   77~78행 부근)이 .md로 끝나지 않는 파일(.txt, 확장자 없는 파일 등)을
#   post_files 배열에 담기도 전에 조용히 걸러내 버려, 1)~6) 검사 루프에
#   전혀 도달하지 못하고 아무 FAIL도 없이 무시되는 공백이 발견되어
#   "추후 개발팀 작업 후보"로 남았다. 2026-11-07 이 공백을 메우기 위해
#   validate_posts.sh에 POSTS_DIR의 모든 항목(디렉터리 제외)을 훑어 파일명이
#   .md로 끝나지 않으면 FAIL 처리하는 전용 검사(7번)를 추가했고, 이 테스트는
#   그 검사만을 전용으로 검증한다.
#
#   이 테스트는 scripts/test_date_filename_mismatch.sh, scripts/test_filename_format.sh와
#   같은 "임시 디렉터리에 validate_posts.sh 사본과 임시 posts/ 구조를 만들어
#   그 사본을 실행 → PASS/FAIL 출력 → exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에서만 검증한다.
#
# 검사 내용:
#   (a) [.md 파일만 있는 경우] 정상적인 .md 글 하나만 임시 posts/ 안에 두고
#       validate_posts.sh(사본)를 실행했을 때 exit code가 0(PASS)이고
#       ".md가 아닌 파일 발견" 메시지가 전혀 출력되지 않는지 확인한다.
#   (b) [.txt 파일이 .md 파일과 섞여 있는 경우] 정상적인 .md 글과 함께
#       .txt 파일을 하나 추가했을 때, exit code가 1(FAIL)이고
#       ".md가 아닌 파일 발견: <파일명>" 메시지가 해당 파일명과 함께
#       출력되는지, 그리고 기존 .md 글은 여전히 [PASS]로 처리되는지(즉
#       1)~6) 검사 로직이 전혀 오염되지 않았는지) 확인한다.
#   (c) [확장자가 없는 파일인 경우] .md 글과 함께 확장자가 전혀 없는 파일을
#       추가했을 때도 (b)와 동일하게 FAIL로 잡히는지 확인한다.
#   (d) [.md 파일이 하나도 없고 비-.md 파일만 있는 경우] 이 경우 기존
#       validate_posts.sh는 post_files 배열이 비어 "검사할 .md 파일이
#       없습니다" 경고만 내고 exit 0으로 조용히 끝났었다(추가 전 동작).
#       이 공백까지 메웠는지 확인하기 위해, .md 파일이 전혀 없이 .txt
#       파일만 있는 경우에도 exit code가 1(FAIL)이고 ".md가 아닌 파일
#       발견" 메시지가 출력되는지 확인한다.
#
# 사용법:
#   bash scripts/test_non_md_extension.sh
#
# exit code:
#   0 - 모든 검사를 통과함
#   1 - 하나 이상의 검사에서 실패함 (실패 내용을 함께 출력)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="${SCRIPT_DIR}/validate_posts.sh"

failures=()

if [ ! -f "${VALIDATE_SCRIPT}" ]; then
  echo "오류: ${VALIDATE_SCRIPT} 파일을 찾을 수 없습니다."
  exit 1
fi

NON_MD_FAIL_MESSAGE=".md가 아닌 파일 발견"

# 정상적인 .md 글 하나를 만든다. 면책 문구/frontmatter 필수 필드를 모두
# 정상으로 채워 다른 검사(1~6번)가 오탐으로 섞여 들어오지 않게 한다.
make_normal_md_content() {
  cat <<'EOF'
---
title: "비-.md 파일 검출 회귀 테스트용 글"
meta_description: "scripts/test_non_md_extension.sh가 만든 임시 테스트용 글입니다"
keywords: ["테스트"]
date: "2026-11-07"
---

이 글은 scripts/test_non_md_extension.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
EOF
}

NORMAL_MD_FILE="2026-11-07-test-slug.md"

# 인자: 임시 posts/ 안에 추가로 만들 비-.md 파일명(생략하면 .md 글만 둠)
run_validate() {
  local extra_filename="${1:-}"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  mkdir -p "${tmp_dir}/scripts" "${tmp_dir}/posts"
  cp "${VALIDATE_SCRIPT}" "${tmp_dir}/scripts/validate_posts.sh"
  make_normal_md_content > "${tmp_dir}/posts/${NORMAL_MD_FILE}"
  if [ -n "${extra_filename}" ]; then
    echo "임시 비-.md 파일 내용" > "${tmp_dir}/posts/${extra_filename}"
  fi

  local output status
  output="$(bash "${tmp_dir}/scripts/validate_posts.sh" 2>&1)"
  status=$?

  rm -rf "${tmp_dir}"

  printf '%s\n' "${status}"
  printf '%s\n' "${output}"
}

# 인자: 임시 posts/ 안에 만들 비-.md 파일명만 (정상 .md 글은 두지 않음)
run_validate_only_non_md() {
  local extra_filename="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  mkdir -p "${tmp_dir}/scripts" "${tmp_dir}/posts"
  cp "${VALIDATE_SCRIPT}" "${tmp_dir}/scripts/validate_posts.sh"
  echo "임시 비-.md 파일 내용" > "${tmp_dir}/posts/${extra_filename}"

  local output status
  output="$(bash "${tmp_dir}/scripts/validate_posts.sh" 2>&1)"
  status=$?

  rm -rf "${tmp_dir}"

  printf '%s\n' "${status}"
  printf '%s\n' "${output}"
}

echo "=== 검사 (a): .md 파일만 있는 경우 -> PASS 이어야 함 ==="
a_result="$(run_validate)"
a_status="$(echo "${a_result}" | head -n 1)"
a_output="$(echo "${a_result}" | tail -n +2)"

echo "${a_output}"
echo "(실행 exit code: ${a_status})"

if [ "${a_status}" -ne 0 ]; then
  echo "[FAIL] .md 파일만 있는데 exit code가 0이 아니었습니다 (실제: ${a_status})."
  failures+=(".md 파일만 있는 케이스 exit code != 0")
else
  echo "[PASS] .md 파일만 있는 경우 exit code가 0(PASS)입니다."
fi

if echo "${a_output}" | grep -qF "${NON_MD_FAIL_MESSAGE}"; then
  echo "[FAIL] .md 파일만 있는데 \"${NON_MD_FAIL_MESSAGE}\" 메시지가 출력되었습니다."
  failures+=(".md 파일만 있는 케이스에서 비-.md FAIL 오탐")
else
  echo "[PASS] .md 파일만 있는 경우 \"${NON_MD_FAIL_MESSAGE}\" 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 (b): .txt 파일이 .md 파일과 섞여 있는 경우 -> FAIL 이어야 함 ==="
TXT_FILE="notes.txt"
b_result="$(run_validate "${TXT_FILE}")"
b_status="$(echo "${b_result}" | head -n 1)"
b_output="$(echo "${b_result}" | tail -n +2)"

echo "${b_output}"
echo "(실행 exit code: ${b_status})"

if [ "${b_status}" -ne 1 ]; then
  echo "[FAIL] .txt 파일이 섞여 있는데 exit code가 1이 아니었습니다 (실제: ${b_status})."
  failures+=(".txt 혼합 케이스(${TXT_FILE}) exit code != 1")
else
  echo "[PASS] .txt 파일이 섞여 있는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${b_output}" | grep -qF "${NON_MD_FAIL_MESSAGE}" && echo "${b_output}" | grep -qF "${TXT_FILE}"; then
  echo "[PASS] 출력에 \"${NON_MD_FAIL_MESSAGE}\" 메시지와 해당 파일명(${TXT_FILE})이 함께 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${NON_MD_FAIL_MESSAGE}\" 메시지 또는 파일명(${TXT_FILE})이 없습니다."
  failures+=(".txt 혼합 케이스(${TXT_FILE}) 메시지 누락")
fi

if echo "${b_output}" | grep -qF "[PASS] ${NORMAL_MD_FILE}"; then
  echo "[PASS] 기존 .md 글(${NORMAL_MD_FILE})은 여전히 [PASS]로 처리되었습니다(1~6번 검사 오염 없음)."
else
  echo "[FAIL] 기존 .md 글(${NORMAL_MD_FILE})이 [PASS]로 처리되지 않았습니다. 1~6번 검사가 오염되었을 수 있습니다."
  failures+=(".txt 혼합 케이스에서 기존 .md 글(${NORMAL_MD_FILE}) PASS 처리 누락")
fi

echo ""
echo "=== 검사 (c): 확장자가 없는 파일이 .md 파일과 섞여 있는 경우 -> FAIL 이어야 함 ==="
NO_EXT_FILE="README"
c_result="$(run_validate "${NO_EXT_FILE}")"
c_status="$(echo "${c_result}" | head -n 1)"
c_output="$(echo "${c_result}" | tail -n +2)"

echo "${c_output}"
echo "(실행 exit code: ${c_status})"

if [ "${c_status}" -ne 1 ]; then
  echo "[FAIL] 확장자 없는 파일이 섞여 있는데 exit code가 1이 아니었습니다 (실제: ${c_status})."
  failures+=("확장자 없음 케이스(${NO_EXT_FILE}) exit code != 1")
else
  echo "[PASS] 확장자 없는 파일이 섞여 있는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${c_output}" | grep -qF "${NON_MD_FAIL_MESSAGE}" && echo "${c_output}" | grep -qF "${NO_EXT_FILE}"; then
  echo "[PASS] 출력에 \"${NON_MD_FAIL_MESSAGE}\" 메시지와 해당 파일명(${NO_EXT_FILE})이 함께 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${NON_MD_FAIL_MESSAGE}\" 메시지 또는 파일명(${NO_EXT_FILE})이 없습니다."
  failures+=("확장자 없음 케이스(${NO_EXT_FILE}) 메시지 누락")
fi

echo ""
echo "=== 검사 (d): .md 파일이 하나도 없고 비-.md 파일만 있는 경우 -> FAIL 이어야 함 ==="
ONLY_NON_MD_FILE="memo.txt"
d_result="$(run_validate_only_non_md "${ONLY_NON_MD_FILE}")"
d_status="$(echo "${d_result}" | head -n 1)"
d_output="$(echo "${d_result}" | tail -n +2)"

echo "${d_output}"
echo "(실행 exit code: ${d_status})"

if [ "${d_status}" -ne 1 ]; then
  echo "[FAIL] .md 파일이 하나도 없고 비-.md 파일만 있는데 exit code가 1이 아니었습니다 (실제: ${d_status})."
  failures+=("비-.md만 있는 케이스(${ONLY_NON_MD_FILE}) exit code != 1")
else
  echo "[PASS] .md 파일이 하나도 없고 비-.md 파일만 있는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${d_output}" | grep -qF "${NON_MD_FAIL_MESSAGE}" && echo "${d_output}" | grep -qF "${ONLY_NON_MD_FILE}"; then
  echo "[PASS] 출력에 \"${NON_MD_FAIL_MESSAGE}\" 메시지와 해당 파일명(${ONLY_NON_MD_FILE})이 함께 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${NON_MD_FAIL_MESSAGE}\" 메시지 또는 파일명(${ONLY_NON_MD_FILE})이 없습니다."
  failures+=("비-.md만 있는 케이스(${ONLY_NON_MD_FILE}) 메시지 누락")
fi

if [ ${#failures[@]} -eq 0 ]; then
  echo ""
  echo "모든 검사를 통과했습니다."
  exit 0
else
  echo ""
  echo "다음 검사에서 실패했습니다:"
  for f in "${failures[@]}"; do
    echo "  - ${f}"
  done
  exit 1
fi
