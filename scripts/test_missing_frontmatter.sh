#!/usr/bin/env bash
#
# test_missing_frontmatter.sh
#
# scripts/validate_posts.sh의 "2) frontmatter 추출" 검사(파일의 첫 줄이
# "---"가 아니면 "파일 시작 부분에 frontmatter(---)가 없습니다"로 FAIL
# 처리하는 로직, 162~169행)와, 그 뒤에 이어지는 "3) 필수 필드 검사"가
# frontmatter 자체가 없는 경우에는 중복으로 실행되지 않고 건너뛰는지
# (172행의 `[[ ! " ${file_problems[*]} " == *"frontmatter"* ]]` 가드)를
# 함께 검증하는 회귀 테스트다.
#
#   배경: 다른 검사들(date 필드 필수, title/meta_description/keywords
#   필드 필수, category 빈 값, keywords 빈 배열 등)은 모두 frontmatter가
#   "존재하되 그 안의 특정 필드/값이 문제"인 경우를 다루는 전용 회귀
#   테스트가 있었지만, frontmatter 블록 자체가 통째로 없는 글(파일이
#   "---"로 시작하지 않는 경우)을 다루는 전용 회귀 테스트는 없었다.
#   validate_posts.sh 코드 자체에는 이 경우를 처리하는 분기가 162~178행에
#   이미 존재하지만(파일 시작에 "---"가 없으면 FAIL 처리하고, 이어지는
#   필수 필드 루프는 이미 "frontmatter 없음" 문제가 기록된 경우 건너뛰어
#   중복/혼란스러운 메시지를 막는다), 이를 실행해 검증하는 전용 테스트가
#   없던 공백을 2026-11-08 마스터 지시로 메운다. 이 테스트는
#   scripts/test_required_date_field.sh, scripts/test_required_title_meta_keywords_field.sh와
#   동일한 "자동 실행 → PASS/FAIL 출력 → exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/validate_posts.sh 사본과
#   임시 posts/ 구조를 통째로 구성해 그 사본을 실행한다(validate_posts.sh는
#   자기 자신의 위치를 기준으로 REPO_ROOT/POSTS_DIR을 계산하므로, 사본을
#   임시 디렉터리 안 scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만
#   동작한다).
#
# 검사 내용:
#   1) [frontmatter 자체가 없는 케이스] 파일 첫 줄이 "---"가 아니라
#      title/meta_description/keywords/date 필드를 바로 나열하는 글 하나를
#      임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때,
#      exit code가 1(FAIL)이고 출력에 "파일 시작 부분에 frontmatter(---)가
#      없습니다" 메시지가 포함되는지 확인한다. 또한 "필수 필드 검사" 가드가
#      정상 동작해, title/meta_description/keywords/date 각각의 "필드가
#      없거나 비어 있습니다" 메시지가 중복으로 더 출력되지 않는지까지
#      함께 확인한다.
#   2) [정상 케이스] 파일이 "---"로 정상적으로 시작하는 글 하나를 임시
#      posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때, exit
#      code가 0(PASS)이고 "파일 시작 부분에 frontmatter(---)가 없습니다"
#      메시지가 출력되지 않는지 확인한다.
#
# 사용법:
#   bash scripts/test_missing_frontmatter.sh
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

MISSING_FRONTMATTER_FAIL_MESSAGE="파일 시작 부분에 frontmatter(---)가 없습니다"

run_validate_with_post() {
  # 인자: 임시 posts/ 안에 만들 파일명, 그리고 그 파일의 전체 내용
  local filename="$1"
  local content="$2"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  mkdir -p "${tmp_dir}/scripts" "${tmp_dir}/posts"
  cp "${VALIDATE_SCRIPT}" "${tmp_dir}/scripts/validate_posts.sh"
  printf '%s' "${content}" > "${tmp_dir}/posts/${filename}"

  local output status
  output="$(bash "${tmp_dir}/scripts/validate_posts.sh" 2>&1)"
  status=$?

  rm -rf "${tmp_dir}"

  printf '%s\n' "${status}"
  printf '%s\n' "${output}"
}

echo "=== 검사 1: 파일이 '---'로 시작하지 않는(frontmatter 자체가 없는) 글 -> FAIL 이어야 함 ==="
NO_FRONTMATTER_FILE="2026-01-03-no-frontmatter-regression-test.md"
NO_FRONTMATTER_CONTENT='title: "frontmatter 자체가 없는 테스트용 임시 글"
meta_description: "파일 맨 앞에 --- 구분자가 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-03

이 글은 scripts/test_missing_frontmatter.sh가 만든 임시 테스트용 글입니다.
파일이 "---"로 시작하지 않아 frontmatter 블록 자체가 없습니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_frontmatter_result="$(run_validate_with_post "${NO_FRONTMATTER_FILE}" "${NO_FRONTMATTER_CONTENT}")"
no_frontmatter_status="$(echo "${no_frontmatter_result}" | head -n 1)"
no_frontmatter_output="$(echo "${no_frontmatter_result}" | tail -n +2)"

echo "${no_frontmatter_output}"
echo "(실행 exit code: ${no_frontmatter_status})"

if [ "${no_frontmatter_status}" -ne 1 ]; then
  echo "[FAIL] frontmatter가 없는 경우 exit code가 1이 아니었습니다 (실제: ${no_frontmatter_status})."
  failures+=("frontmatter 없음 케이스 exit code != 1")
else
  echo "[PASS] frontmatter가 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${no_frontmatter_output}" | grep -qF "${MISSING_FRONTMATTER_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${MISSING_FRONTMATTER_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${MISSING_FRONTMATTER_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("frontmatter 없음 메시지 누락")
fi

for field in title meta_description keywords date; do
  if echo "${no_frontmatter_output}" | grep -qF "frontmatter에 '${field}' 필드가 없거나 비어 있습니다"; then
    echo "[FAIL] frontmatter가 없는 케이스인데 '${field}' 필드 누락 메시지가 중복으로 출력되었습니다 (필수 필드 검사 가드가 동작하지 않았습니다)."
    failures+=("frontmatter 없음 케이스에서 ${field} 필드 누락 메시지 중복 출력")
  else
    echo "[PASS] frontmatter가 없는 케이스에서 '${field}' 필드 누락 메시지가 중복으로 출력되지 않았습니다."
  fi
done

echo ""
echo "=== 검사 2: 파일이 '---'로 정상적으로 시작하는 글 -> PASS 이어야 함 ==="
VALID_FRONTMATTER_FILE="2026-01-03-valid-frontmatter-regression-test.md"
VALID_FRONTMATTER_CONTENT='---
title: "frontmatter가 정상적으로 있는 테스트용 글"
meta_description: "파일이 --- 구분자로 정상적으로 시작하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-03
---

이 글은 scripts/test_missing_frontmatter.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

valid_frontmatter_result="$(run_validate_with_post "${VALID_FRONTMATTER_FILE}" "${VALID_FRONTMATTER_CONTENT}")"
valid_frontmatter_status="$(echo "${valid_frontmatter_result}" | head -n 1)"
valid_frontmatter_output="$(echo "${valid_frontmatter_result}" | tail -n +2)"

echo "${valid_frontmatter_output}"
echo "(실행 exit code: ${valid_frontmatter_status})"

if [ "${valid_frontmatter_status}" -ne 0 ]; then
  echo "[FAIL] frontmatter가 정상적으로 있는 경우 exit code가 0이 아니었습니다 (실제: ${valid_frontmatter_status})."
  failures+=("정상 frontmatter 케이스 exit code != 0")
else
  echo "[PASS] frontmatter가 정상적으로 있는 경우 exit code가 0(PASS)입니다."
fi

if echo "${valid_frontmatter_output}" | grep -qF "${MISSING_FRONTMATTER_FAIL_MESSAGE}"; then
  echo "[FAIL] 정상 케이스인데 \"${MISSING_FRONTMATTER_FAIL_MESSAGE}\" 메시지가 출력되었습니다."
  failures+=("정상 케이스에서 frontmatter 없음 메시지 오탐")
else
  echo "[PASS] 정상 케이스에서는 \"${MISSING_FRONTMATTER_FAIL_MESSAGE}\" 메시지가 출력되지 않았습니다."
fi

echo ""
if [ ${#failures[@]} -eq 0 ]; then
  echo "모든 검사를 통과했습니다."
  exit 0
else
  echo "다음 검사에서 실패했습니다:"
  for f in "${failures[@]}"; do
    echo "  - ${f}"
  done
  exit 1
fi
