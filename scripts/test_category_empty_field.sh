#!/usr/bin/env bash
#
# test_category_empty_field.sh
#
# scripts/validate_posts.sh에 추가된 "category 필드 빈 값/공백 검사"(frontmatter에
# category 필드가 있는데 값이 비어있거나 공백뿐이면 FAIL) 로직이 실제로 동작하는지
# 확인하는 회귀 테스트다.
#
#   배경: category는 REQUIRED_FIELDS에 포함되지 않은 선택적 필드다. 필드 자체가
#   없는 글은 generate_jsonld.sh가 articleSection을 생성하지 않는 것이 정상
#   설계지만, category: "" 또는 category: "   "처럼 필드는 존재하되 값이 비어
#   있거나 공백뿐이면 generate_jsonld.sh의 "-n" 검사(공백 문자열도 비어있지
#   않은 것으로 판단)를 통과해 공백만 있는 articleSection이 그대로 생성되어버리는
#   공백이 있었다(2026-10-28 조사 확인, 커밋 4628ad2로 validate_posts.sh에
#   검사 로직만 추가됨). 이 테스트는 scripts/test_required_date_field.sh,
#   scripts/test_img_alt_required.sh와 같은 "자동 실행 → PASS/FAIL 출력 →
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
#   1) [category 빈 문자열 케이스] frontmatter에 category: ""(빈 문자열)가
#      있는 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 1(FAIL)이고 출력에 "frontmatter에 'category'
#      필드가 있지만 값이 비어 있거나 공백뿐입니다" 메시지가 포함되는지
#      확인한다.
#   2) [category 공백뿐 케이스] frontmatter에 category: "   "(공백만 있는
#      문자열)가 있는 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 1(FAIL)이고 같은 메시지가 출력되는지 확인한다.
#   3) [category 필드 없음 케이스 — 회귀 방지] category 필드가 아예 없는,
#      기존과 동일한 정상 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 0(PASS)인지 확인한다(category는 선택적 필드이므로
#      필드 자체가 없는 것은 FAIL 처리되지 않아야 한다).
#   4) [category 정상 값 케이스] category: "경제"처럼 값이 정상적으로 채워진
#      글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때,
#      exit code가 0(PASS)이고 category 관련 FAIL 메시지가 출력되지 않는지
#      확인한다.
#
# 사용법:
#   bash scripts/test_category_empty_field.sh
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

CATEGORY_FAIL_MESSAGE="frontmatter에 'category' 필드가 있지만 값이 비어 있거나 공백뿐입니다"

echo "=== 검사 1: category 필드 값이 빈 문자열(\"\")인 글 -> FAIL 이어야 함 ==="
EMPTY_CATEGORY_FILE="2026-01-01-empty-category-regression-test.md"
EMPTY_CATEGORY_CONTENT='---
title: "category 빈 값 검사 회귀 테스트용 임시 글(빈 문자열)"
meta_description: "frontmatter의 category 값이 빈 문자열인 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
category: ""
---

이 글은 scripts/test_category_empty_field.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

empty_category_result="$(run_validate_with_post "${EMPTY_CATEGORY_FILE}" "${EMPTY_CATEGORY_CONTENT}")"
empty_category_status="$(echo "${empty_category_result}" | head -n 1)"
empty_category_output="$(echo "${empty_category_result}" | tail -n +2)"

echo "${empty_category_output}"
echo "(실행 exit code: ${empty_category_status})"

if [ "${empty_category_status}" -ne 1 ]; then
  echo "[FAIL] category가 빈 문자열인 경우 exit code가 1이 아니었습니다 (실제: ${empty_category_status})."
  failures+=("category 빈 문자열 케이스 exit code != 1")
else
  echo "[PASS] category가 빈 문자열인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${empty_category_output}" | grep -qF "${CATEGORY_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${CATEGORY_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${CATEGORY_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("category 빈 문자열 케이스 메시지 누락")
fi

echo ""
echo "=== 검사 2: category 필드 값이 공백뿐(\"   \")인 글 -> FAIL 이어야 함 ==="
BLANK_CATEGORY_FILE="2026-01-01-blank-category-regression-test.md"
BLANK_CATEGORY_CONTENT='---
title: "category 빈 값 검사 회귀 테스트용 임시 글(공백뿐)"
meta_description: "frontmatter의 category 값이 공백뿐인 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
category: "   "
---

이 글은 scripts/test_category_empty_field.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

blank_category_result="$(run_validate_with_post "${BLANK_CATEGORY_FILE}" "${BLANK_CATEGORY_CONTENT}")"
blank_category_status="$(echo "${blank_category_result}" | head -n 1)"
blank_category_output="$(echo "${blank_category_result}" | tail -n +2)"

echo "${blank_category_output}"
echo "(실행 exit code: ${blank_category_status})"

if [ "${blank_category_status}" -ne 1 ]; then
  echo "[FAIL] category가 공백뿐인 경우 exit code가 1이 아니었습니다 (실제: ${blank_category_status})."
  failures+=("category 공백뿐 케이스 exit code != 1")
else
  echo "[PASS] category가 공백뿐인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${blank_category_output}" | grep -qF "${CATEGORY_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${CATEGORY_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${CATEGORY_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("category 공백뿐 케이스 메시지 누락")
fi

echo ""
echo "=== 검사 3: category 필드가 아예 없는 글 -> PASS 이어야 함 (회귀 방지) ==="
NO_CATEGORY_FILE="2026-01-01-no-category-field-regression-test.md"
NO_CATEGORY_CONTENT='---
title: "category 빈 값 검사 회귀 테스트용 정상 글(필드 없음)"
meta_description: "frontmatter에 category 필드가 아예 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_category_empty_field.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다. category는 선택적 필드이므로
필드 자체가 없는 것은 FAIL 처리되지 않아야 합니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_category_result="$(run_validate_with_post "${NO_CATEGORY_FILE}" "${NO_CATEGORY_CONTENT}")"
no_category_status="$(echo "${no_category_result}" | head -n 1)"
no_category_output="$(echo "${no_category_result}" | tail -n +2)"

echo "${no_category_output}"
echo "(실행 exit code: ${no_category_status})"

if [ "${no_category_status}" -ne 0 ]; then
  echo "[FAIL] category 필드가 아예 없는 경우 exit code가 0이 아니었습니다 (실제: ${no_category_status})."
  failures+=("category 필드 없음 케이스 exit code != 0")
else
  echo "[PASS] category 필드가 아예 없는 경우 exit code가 0(PASS)입니다."
fi

if echo "${no_category_output}" | grep -qF "'category' 필드가 있지만"; then
  echo "[FAIL] category 필드가 없는 글인데 category 빈 값 FAIL 메시지가 출력되었습니다."
  failures+=("category 필드 없음 케이스에서 오탐")
else
  echo "[PASS] category 필드가 없는 글에서는 category 빈 값 FAIL 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 4: category 필드 값이 정상적으로 채워진 글 -> PASS 이어야 함 ==="
VALID_CATEGORY_FILE="2026-01-01-valid-category-regression-test.md"
VALID_CATEGORY_CONTENT='---
title: "category 빈 값 검사 회귀 테스트용 정상 글(정상 값)"
meta_description: "frontmatter의 category 값이 정상적으로 채워진 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
category: "경제"
---

이 글은 scripts/test_category_empty_field.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

valid_category_result="$(run_validate_with_post "${VALID_CATEGORY_FILE}" "${VALID_CATEGORY_CONTENT}")"
valid_category_status="$(echo "${valid_category_result}" | head -n 1)"
valid_category_output="$(echo "${valid_category_result}" | tail -n +2)"

echo "${valid_category_output}"
echo "(실행 exit code: ${valid_category_status})"

if [ "${valid_category_status}" -ne 0 ]; then
  echo "[FAIL] category 값이 정상적으로 있는 경우 exit code가 0이 아니었습니다 (실제: ${valid_category_status})."
  failures+=("category 정상 값 케이스 exit code != 0")
else
  echo "[PASS] category 값이 정상적으로 있는 경우 exit code가 0(PASS)입니다."
fi

if echo "${valid_category_output}" | grep -qF "'category' 필드가 있지만"; then
  echo "[FAIL] 정상 케이스인데 category 빈 값 FAIL 메시지가 출력되었습니다."
  failures+=("category 정상 값 케이스에서 오탐")
else
  echo "[PASS] 정상 케이스에서는 category 빈 값 FAIL 메시지가 출력되지 않았습니다."
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
