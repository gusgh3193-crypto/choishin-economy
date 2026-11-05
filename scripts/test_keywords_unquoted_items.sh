#!/usr/bin/env bash
#
# test_keywords_unquoted_items.sh
#
# scripts/validate_posts.sh의 3-5 검사(keywords 필드가 배열 형식([...])일 때,
# 그 안의 각 항목이 따옴표(쌍따옴표 또는 홑따옴표)로 감싸여 있는지 검사하고,
# 감싸여 있지 않으면 FAIL 처리하는 로직, 162~181행)가 실제로 동작하는지
# 확인하는 회귀 테스트다.
#
#   배경: validate_posts.sh의 다른 검사들(date 필드 필수, category 빈 값,
#   title/meta_description 빈 값, keywords 빈 배열 등)은 모두 전용 회귀 테스트
#   파일(test_required_date_field.sh, test_category_empty_field.sh,
#   test_title_meta_empty_quoted.sh, test_keywords_empty_array.sh 등)이 있고
#   scripts/daily_check.sh에 단계로 등록돼 있었지만, keywords 배열 항목
#   따옴표 검사(3-5번, 162~181행)에는 이런 전용 회귀 테스트가 없었다.
#   scripts/test_split_keywords.sh는 split_keywords_items() 함수 자체의
#   동작(쉼표 분리 로직)만 테스트할 뿐, validate_posts.sh의 3-5번 검사(따옴표
#   유무 판정)를 직접 테스트하지 않으므로 이 공백을 메우기 위해 2026-11-05
#   마스터 지시로 추가했다. 이 테스트는 scripts/test_keywords_empty_array.sh,
#   scripts/test_category_empty_field.sh와 같은 "자동 실행 → PASS/FAIL 출력 →
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
#   1) [따옴표 없는 배열 항목 케이스] keywords: [금리 인상, 기준금리]처럼
#      배열 항목에 따옴표가 전혀 없는 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)이고
#      출력에 "frontmatter의 keywords 배열 항목에 따옴표가 없습니다" 메시지가
#      포함되는지 확인한다.
#   2) [정상 값 케이스 — 회귀 방지] keywords: ["금리 인상", "기준금리"]처럼
#      배열 항목이 모두 쌍따옴표로 감싸여 있는 글 하나를 임시 posts/ 안에
#      만들고 validate_posts.sh(사본)를 실행했을 때, exit code가 0(PASS)이고
#      keywords 항목 따옴표 관련 FAIL 메시지가 출력되지 않는지 확인한다.
#   3) [배열 형식이 아닌 콤마 구분 문자열 케이스 — 오탐 방지] keywords: 금리,
#      기준금리처럼 대괄호로 감싸여 있지 않은 콤마 구분 문자열은 3-5번 검사의
#      대상이 아니므로(3-3번과 동일하게 keywords_line이 ^\[(.*)\]...$ 에
#      매칭된 경우에만 검사), 이 검사 때문에 "frontmatter의 keywords 배열
#      항목에 따옴표가 없습니다" FAIL 메시지가 출력되지 않는지 확인한다.
#
# 사용법:
#   bash scripts/test_keywords_unquoted_items.sh
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

KEYWORDS_UNQUOTED_FAIL_MESSAGE="frontmatter의 keywords 배열 항목에 따옴표가 없습니다"

echo "=== 검사 1: keywords 배열 항목에 따옴표가 없는 글 (keywords: [금리 인상, 기준금리]) -> FAIL 이어야 함 ==="
UNQUOTED_KEYWORDS_FILE="2026-01-01-unquoted-keywords-array-regression-test.md"
UNQUOTED_KEYWORDS_CONTENT='---
title: "keywords 배열 항목 따옴표 검사 회귀 테스트용 임시 글(따옴표 없음)"
meta_description: "frontmatter의 keywords 배열 항목에 따옴표가 없는 테스트용 임시 글입니다"
keywords: [금리 인상, 기준금리]
date: 2026-01-01
---

이 글은 scripts/test_keywords_unquoted_items.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

unquoted_keywords_result="$(run_validate_with_post "${UNQUOTED_KEYWORDS_FILE}" "${UNQUOTED_KEYWORDS_CONTENT}")"
unquoted_keywords_status="$(echo "${unquoted_keywords_result}" | head -n 1)"
unquoted_keywords_output="$(echo "${unquoted_keywords_result}" | tail -n +2)"

echo "${unquoted_keywords_output}"
echo "(실행 exit code: ${unquoted_keywords_status})"

if [ "${unquoted_keywords_status}" -ne 1 ]; then
  echo "[FAIL] keywords 배열 항목에 따옴표가 없는 경우 exit code가 1이 아니었습니다 (실제: ${unquoted_keywords_status})."
  failures+=("keywords 배열 항목 따옴표 없음 케이스 exit code != 1")
else
  echo "[PASS] keywords 배열 항목에 따옴표가 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${unquoted_keywords_output}" | grep -qF "${KEYWORDS_UNQUOTED_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${KEYWORDS_UNQUOTED_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${KEYWORDS_UNQUOTED_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("keywords 배열 항목 따옴표 없음 케이스 메시지 누락")
fi

echo ""
echo "=== 검사 2: keywords 배열 항목이 모두 따옴표로 감싸진 글 (keywords: [\"금리 인상\", \"기준금리\"]) -> PASS 이어야 함 (회귀 방지) ==="
QUOTED_KEYWORDS_FILE="2026-01-01-quoted-keywords-array-regression-test.md"
QUOTED_KEYWORDS_CONTENT='---
title: "keywords 배열 항목 따옴표 검사 회귀 테스트용 정상 글(따옴표 있음)"
meta_description: "frontmatter의 keywords 배열 항목이 모두 따옴표로 감싸진 테스트용 임시 글입니다"
keywords: ["금리 인상", "기준금리"]
date: 2026-01-01
---

이 글은 scripts/test_keywords_unquoted_items.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

quoted_keywords_result="$(run_validate_with_post "${QUOTED_KEYWORDS_FILE}" "${QUOTED_KEYWORDS_CONTENT}")"
quoted_keywords_status="$(echo "${quoted_keywords_result}" | head -n 1)"
quoted_keywords_output="$(echo "${quoted_keywords_result}" | tail -n +2)"

echo "${quoted_keywords_output}"
echo "(실행 exit code: ${quoted_keywords_status})"

if [ "${quoted_keywords_status}" -ne 0 ]; then
  echo "[FAIL] keywords 배열 항목이 모두 따옴표로 감싸진 경우 exit code가 0이 아니었습니다 (실제: ${quoted_keywords_status})."
  failures+=("keywords 배열 항목 따옴표 있음 케이스 exit code != 0")
else
  echo "[PASS] keywords 배열 항목이 모두 따옴표로 감싸진 경우 exit code가 0(PASS)입니다."
fi

if echo "${quoted_keywords_output}" | grep -qF "${KEYWORDS_UNQUOTED_FAIL_MESSAGE}"; then
  echo "[FAIL] 정상 케이스인데 keywords 배열 항목 따옴표 없음 FAIL 메시지가 출력되었습니다."
  failures+=("keywords 배열 항목 따옴표 있음 케이스에서 오탐")
else
  echo "[PASS] 정상 케이스에서는 keywords 배열 항목 따옴표 없음 FAIL 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 3: keywords가 배열 형식이 아닌 콤마 구분 문자열인 글 (keywords: 금리, 기준금리) -> 3-5번 검사 때문에 FAIL 되면 안 됨 (오탐 방지) ==="
COMMA_KEYWORDS_FILE="2026-01-01-comma-keywords-string-regression-test.md"
COMMA_KEYWORDS_CONTENT='---
title: "keywords 배열 항목 따옴표 검사 회귀 테스트용 정상 글(콤마 구분 문자열)"
meta_description: "frontmatter의 keywords가 배열 형식이 아닌 콤마 구분 문자열인 테스트용 임시 글입니다"
keywords: 금리, 기준금리
date: 2026-01-01
---

이 글은 scripts/test_keywords_unquoted_items.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다. keywords가 배열 형식([...])이
아니므로 3-5번 검사(배열 항목 따옴표 검사)의 대상이 아닙니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

comma_keywords_result="$(run_validate_with_post "${COMMA_KEYWORDS_FILE}" "${COMMA_KEYWORDS_CONTENT}")"
comma_keywords_status="$(echo "${comma_keywords_result}" | head -n 1)"
comma_keywords_output="$(echo "${comma_keywords_result}" | tail -n +2)"

echo "${comma_keywords_output}"
echo "(실행 exit code: ${comma_keywords_status})"

if echo "${comma_keywords_output}" | grep -qF "${KEYWORDS_UNQUOTED_FAIL_MESSAGE}"; then
  echo "[FAIL] 콤마 구분 문자열 케이스인데 keywords 배열 항목 따옴표 없음 FAIL 메시지가 출력되었습니다(3-5번 검사의 오탐)."
  failures+=("keywords 콤마 구분 문자열 케이스에서 3-5번 검사 오탐")
else
  echo "[PASS] 콤마 구분 문자열 케이스에서는 keywords 배열 항목 따옴표 없음 FAIL 메시지가 출력되지 않았습니다."
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
