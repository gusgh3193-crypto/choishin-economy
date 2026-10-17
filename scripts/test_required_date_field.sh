#!/usr/bin/env bash
#
# test_required_date_field.sh
#
# scripts/validate_posts.sh의 REQUIRED_FIELDS에 추가된 "date 필드 필수 검사"
# (frontmatter에 date 필드가 아예 없으면 FAIL) 로직이 실제로 동작하는지
# 확인하는 회귀 테스트다.
#
#   배경: 기존 3-2(frontmatter의 date가 파일명 날짜와 일치하는지 검사)
#   로직은 frontmatter에 date 필드가 "이미 존재할 때만" 동작했고, date
#   필드가 아예 없는 글은 조용히 PASS 처리되는 공백이 있었다. design/style-guide.md의
#   "작성일 표시" 규칙과 generate_sitemap.sh/generate_jsonld.sh의
#   lastmod/datePublished 우선 사용 로직이 모두 frontmatter의 date 값
#   존재를 전제로 하므로, 이 공백을 막기 위해 REQUIRED_FIELDS 배열에 date를
#   추가했다(2026-10-17 마스터 지시). 이 테스트는 scripts/test_duplicate_slug.sh,
#   scripts/test_sitemap_dash_title.sh와 같은 "자동 실행 → PASS/FAIL 출력 →
#   exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/validate_posts.sh 사본과
#   임시 posts/ 구조를 통째로 구성해 그 사본을 실행한다(validate_posts.sh는
#   자기 자신의 위치를 기준으로 REPO_ROOT/POSTS_DIR을 계산하므로, 사본을
#   임시 디렉터리 안 scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만
#   동작한다).
#
# 검사 내용:
#   1) [date 필드 없음 케이스] title/meta_description/keywords/면책 문구는
#      모두 정상이지만 frontmatter에 date 필드가 아예 없는 글 하나를 임시
#      posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때, exit code가
#      1(FAIL)이고 출력에 "frontmatter에 'date' 필드가 없거나 비어 있습니다"
#      메시지가 포함되는지 확인한다.
#   2) [정상 케이스] date 필드가 정상적으로 있고 그 값이 파일명의 날짜와
#      일치하는 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 0(PASS)이고 date 필드 관련 FAIL 메시지가
#      출력되지 않는지 확인한다.
#
# 사용법:
#   bash scripts/test_required_date_field.sh
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

run_validate_with_post() {
  # 인자: 임시 posts/ 안에 만들 파일명, 그리고 그 파일의 전체 내용(여기까지는
  # heredoc으로 호출 측에서 변수에 담아 넘긴다)
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

echo "=== 검사 1: frontmatter에 date 필드가 아예 없는 글 -> FAIL 이어야 함 ==="
NO_DATE_FILE="2026-01-01-no-date-regression-test.md"
NO_DATE_CONTENT='---
title: "date 필드 필수 검사 회귀 테스트용 임시 글"
meta_description: "frontmatter에 date 필드가 아예 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
---

이 글은 scripts/test_required_date_field.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_date_result="$(run_validate_with_post "${NO_DATE_FILE}" "${NO_DATE_CONTENT}")"
no_date_status="$(echo "${no_date_result}" | head -n 1)"
no_date_output="$(echo "${no_date_result}" | tail -n +2)"

echo "${no_date_output}"
echo "(실행 exit code: ${no_date_status})"

if [ "${no_date_status}" -ne 1 ]; then
  echo "[FAIL] date 필드가 없는 경우 exit code가 1이 아니었습니다 (실제: ${no_date_status})."
  failures+=("date 필드 없음 케이스 exit code != 1")
else
  echo "[PASS] date 필드가 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${no_date_output}" | grep -qF "frontmatter에 'date' 필드가 없거나 비어 있습니다"; then
  echo "[PASS] 출력에 \"frontmatter에 'date' 필드가 없거나 비어 있습니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"frontmatter에 'date' 필드가 없거나 비어 있습니다\" 메시지가 없습니다."
  failures+=("date 필드 누락 메시지 누락")
fi

echo ""
echo "=== 검사 2: date 필드가 정상적으로 있고 파일명과 일치하는 글 -> PASS 이어야 함 ==="
VALID_DATE_FILE="2026-01-01-valid-date-regression-test.md"
VALID_DATE_CONTENT='---
title: "date 필드 필수 검사 회귀 테스트용 정상 글"
meta_description: "frontmatter에 date 필드가 정상적으로 있는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_required_date_field.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

valid_date_result="$(run_validate_with_post "${VALID_DATE_FILE}" "${VALID_DATE_CONTENT}")"
valid_date_status="$(echo "${valid_date_result}" | head -n 1)"
valid_date_output="$(echo "${valid_date_result}" | tail -n +2)"

echo "${valid_date_output}"
echo "(실행 exit code: ${valid_date_status})"

if [ "${valid_date_status}" -ne 0 ]; then
  echo "[FAIL] date 필드가 정상적으로 있는 경우 exit code가 0이 아니었습니다 (실제: ${valid_date_status})."
  failures+=("정상 date 필드 케이스 exit code != 0")
else
  echo "[PASS] date 필드가 정상적으로 있는 경우 exit code가 0(PASS)입니다."
fi

if echo "${valid_date_output}" | grep -qF "'date' 필드가 없거나 비어 있습니다"; then
  echo "[FAIL] 정상 케이스인데 'date' 필드 누락 메시지가 출력되었습니다."
  failures+=("정상 케이스에서 date 필드 누락 오탐")
else
  echo "[PASS] 정상 케이스에서는 'date' 필드 누락 메시지가 출력되지 않았습니다."
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
