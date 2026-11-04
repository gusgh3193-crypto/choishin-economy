#!/usr/bin/env bash
#
# test_keywords_empty_array.sh
#
# scripts/validate_posts.sh의 3-3 검사(keywords 필드가 배열 형식([...])일 때,
# 대괄호 안이 공백뿐인 "빈 배열"이면 FAIL 처리하는 로직)가 실제로 동작하는지
# 확인하는 회귀 테스트다.
#
#   배경: validate_posts.sh의 다른 검사들(date 필드 필수, category 빈 값,
#   title/meta_description 빈 값 등)은 모두 전용 회귀 테스트 파일
#   (test_required_date_field.sh, test_category_empty_field.sh,
#   test_title_meta_empty_quoted.sh 등)이 있고 scripts/daily_check.sh에
#   단계로 등록돼 있었지만, keywords 빈 배열 검사(3-3번, 149~159행)에는
#   이런 전용 회귀 테스트가 없었다. scripts/test_split_keywords.sh는
#   split_keywords_items() 함수 자체의 동작만 테스트할 뿐, validate_posts.sh의
#   3-3번 검사(빈 배열이면 실제로 FAIL 하는지)를 직접 테스트하지 않으므로
#   이 공백을 메우기 위해 2026-11-04 마스터 지시로 추가했다. 이 테스트는
#   scripts/test_category_empty_field.sh, scripts/test_required_date_field.sh와
#   같은 "자동 실행 → PASS/FAIL 출력 → exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/validate_posts.sh 사본과
#   임시 posts/ 구조를 통째로 구성해 그 사본을 실행한다(validate_posts.sh는
#   자기 자신의 위치를 기준으로 REPO_ROOT/POSTS_DIR을 계산하므로, 사본을
#   임시 디렉터리 안 scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만
#   동작한다).
#
# 검사 내용:
#   1) [keywords: [] 케이스] frontmatter의 keywords 필드가 완전히 빈 배열
#      "keywords: []"인 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh
#      (사본)를 실행했을 때, exit code가 1(FAIL)이고 출력에 "frontmatter의
#      keywords 배열이 비어 있습니다" 메시지가 포함되는지 확인한다.
#   2) [keywords: [   ] 케이스] 대괄호 안이 공백뿐인 "keywords: [   ]"인
#      글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때,
#      exit code가 1(FAIL)이고 같은 메시지가 출력되는지 확인한다.
#   3) [정상 값 케이스 — 회귀 방지] keywords: ["금리", "물가"]처럼 값이
#      정상적으로 채워진 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh
#      (사본)를 실행했을 때, exit code가 0(PASS)이고 keywords 빈 배열 관련
#      FAIL 메시지가 출력되지 않는지 확인한다.
#
# 사용법:
#   bash scripts/test_keywords_empty_array.sh
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

KEYWORDS_EMPTY_FAIL_MESSAGE="frontmatter의 keywords 배열이 비어 있습니다"

echo "=== 검사 1: keywords가 완전히 빈 배열(keywords: [])인 글 -> FAIL 이어야 함 ==="
EMPTY_KEYWORDS_FILE="2026-01-01-empty-keywords-array-regression-test.md"
EMPTY_KEYWORDS_CONTENT='---
title: "keywords 빈 배열 검사 회귀 테스트용 임시 글(완전히 빈 배열)"
meta_description: "frontmatter의 keywords가 완전히 빈 배열인 테스트용 임시 글입니다"
keywords: []
date: 2026-01-01
---

이 글은 scripts/test_keywords_empty_array.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

empty_keywords_result="$(run_validate_with_post "${EMPTY_KEYWORDS_FILE}" "${EMPTY_KEYWORDS_CONTENT}")"
empty_keywords_status="$(echo "${empty_keywords_result}" | head -n 1)"
empty_keywords_output="$(echo "${empty_keywords_result}" | tail -n +2)"

echo "${empty_keywords_output}"
echo "(실행 exit code: ${empty_keywords_status})"

if [ "${empty_keywords_status}" -ne 1 ]; then
  echo "[FAIL] keywords가 완전히 빈 배열인 경우 exit code가 1이 아니었습니다 (실제: ${empty_keywords_status})."
  failures+=("keywords 완전히 빈 배열 케이스 exit code != 1")
else
  echo "[PASS] keywords가 완전히 빈 배열인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${empty_keywords_output}" | grep -qF "${KEYWORDS_EMPTY_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${KEYWORDS_EMPTY_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${KEYWORDS_EMPTY_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("keywords 완전히 빈 배열 케이스 메시지 누락")
fi

echo ""
echo "=== 검사 2: keywords 대괄호 안이 공백뿐(keywords: [   ])인 글 -> FAIL 이어야 함 ==="
BLANK_KEYWORDS_FILE="2026-01-01-blank-keywords-array-regression-test.md"
BLANK_KEYWORDS_CONTENT='---
title: "keywords 빈 배열 검사 회귀 테스트용 임시 글(공백뿐 배열)"
meta_description: "frontmatter의 keywords 대괄호 안이 공백뿐인 테스트용 임시 글입니다"
keywords: [   ]
date: 2026-01-01
---

이 글은 scripts/test_keywords_empty_array.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

blank_keywords_result="$(run_validate_with_post "${BLANK_KEYWORDS_FILE}" "${BLANK_KEYWORDS_CONTENT}")"
blank_keywords_status="$(echo "${blank_keywords_result}" | head -n 1)"
blank_keywords_output="$(echo "${blank_keywords_result}" | tail -n +2)"

echo "${blank_keywords_output}"
echo "(실행 exit code: ${blank_keywords_status})"

if [ "${blank_keywords_status}" -ne 1 ]; then
  echo "[FAIL] keywords 대괄호 안이 공백뿐인 경우 exit code가 1이 아니었습니다 (실제: ${blank_keywords_status})."
  failures+=("keywords 공백뿐 배열 케이스 exit code != 1")
else
  echo "[PASS] keywords 대괄호 안이 공백뿐인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${blank_keywords_output}" | grep -qF "${KEYWORDS_EMPTY_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${KEYWORDS_EMPTY_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${KEYWORDS_EMPTY_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("keywords 공백뿐 배열 케이스 메시지 누락")
fi

echo ""
echo "=== 검사 3: keywords 값이 정상적으로 채워진 글 -> PASS 이어야 함 (회귀 방지) ==="
VALID_KEYWORDS_FILE="2026-01-01-valid-keywords-array-regression-test.md"
VALID_KEYWORDS_CONTENT='---
title: "keywords 빈 배열 검사 회귀 테스트용 정상 글(정상 값)"
meta_description: "frontmatter의 keywords 값이 정상적으로 채워진 테스트용 임시 글입니다"
keywords: ["금리", "물가"]
date: 2026-01-01
---

이 글은 scripts/test_keywords_empty_array.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

valid_keywords_result="$(run_validate_with_post "${VALID_KEYWORDS_FILE}" "${VALID_KEYWORDS_CONTENT}")"
valid_keywords_status="$(echo "${valid_keywords_result}" | head -n 1)"
valid_keywords_output="$(echo "${valid_keywords_result}" | tail -n +2)"

echo "${valid_keywords_output}"
echo "(실행 exit code: ${valid_keywords_status})"

if [ "${valid_keywords_status}" -ne 0 ]; then
  echo "[FAIL] keywords 값이 정상적으로 있는 경우 exit code가 0이 아니었습니다 (실제: ${valid_keywords_status})."
  failures+=("keywords 정상 값 케이스 exit code != 0")
else
  echo "[PASS] keywords 값이 정상적으로 있는 경우 exit code가 0(PASS)입니다."
fi

if echo "${valid_keywords_output}" | grep -qF "${KEYWORDS_EMPTY_FAIL_MESSAGE}"; then
  echo "[FAIL] 정상 케이스인데 keywords 빈 배열 FAIL 메시지가 출력되었습니다."
  failures+=("keywords 정상 값 케이스에서 오탐")
else
  echo "[PASS] 정상 케이스에서는 keywords 빈 배열 FAIL 메시지가 출력되지 않았습니다."
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
