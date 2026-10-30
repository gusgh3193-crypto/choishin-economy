#!/usr/bin/env bash
#
# test_disclaimer_required.sh
#
# scripts/validate_posts.sh의 "4) 면책 문구 검사"(본문에 이탤릭(*...*) 처리된
# 한 줄 중 면책성 키워드(책임/투자/권장/대출)를 포함한 줄이 하나라도 있어야
# PASS, 없으면 FAIL) 로직이 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: 이 검사는 validate_posts.sh의 다른 검사 항목(date 필드, img alt,
#   메타 길이, 슬러그 중복, category 빈값 등)과 달리 그동안 전용 회귀
#   테스트가 없었다(2026-10-30 조사 확인). 이 테스트는
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
#   1) [정상 케이스] 면책 키워드(투자/책임 등)를 포함한 이탤릭(*...*) 줄이
#      있는 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 0(PASS)이고 면책 문구 관련 FAIL 메시지가
#      출력되지 않는지 확인한다.
#   2) [이탤릭 전혀 없음 케이스] 본문에 이탤릭 처리가 전혀 없는 글 하나를
#      임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때,
#      exit code가 1(FAIL)이고 출력에 "본문에 면책 문구(이탤릭 처리 +
#      책임/투자/권장 등 키워드 포함)가 없습니다" 메시지가 포함되는지
#      확인한다.
#   3) [이탤릭은 있지만 키워드 없음 케이스] 이탤릭 처리된 줄은 있지만 그
#      안에 면책 키워드(책임/투자/권장/대출)가 전혀 없는 글 하나를 임시
#      posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때, exit
#      code가 1(FAIL)이고 같은 FAIL 메시지가 출력되는지 확인한다.
#   4) [굵게만 있고 이탤릭 없음 케이스 — 회귀 방지] 굵게(**...**) 처리된
#      줄만 있고 실제 이탤릭 처리는 없는 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)인지
#      확인한다(연속된 '*'로 시작/끝나는 굵게 문법이 이탤릭으로 잘못
#      인식되지 않아야 한다).
#
# 사용법:
#   bash scripts/test_disclaimer_required.sh
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

DISCLAIMER_FAIL_MESSAGE="본문에 면책 문구(이탤릭 처리 + 책임/투자/권장 등 키워드 포함)가 없습니다"

echo "=== 검사 1: 면책 키워드를 포함한 이탤릭 줄이 있는 글 -> PASS 이어야 함 ==="
VALID_DISCLAIMER_FILE="2026-01-01-valid-disclaimer-regression-test.md"
VALID_DISCLAIMER_CONTENT='---
title: "면책 문구 검사 회귀 테스트용 정상 글"
meta_description: "본문에 면책 키워드를 포함한 이탤릭 줄이 있는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_disclaimer_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

valid_disclaimer_result="$(run_validate_with_post "${VALID_DISCLAIMER_FILE}" "${VALID_DISCLAIMER_CONTENT}")"
valid_disclaimer_status="$(echo "${valid_disclaimer_result}" | head -n 1)"
valid_disclaimer_output="$(echo "${valid_disclaimer_result}" | tail -n +2)"

echo "${valid_disclaimer_output}"
echo "(실행 exit code: ${valid_disclaimer_status})"

if [ "${valid_disclaimer_status}" -ne 0 ]; then
  echo "[FAIL] 면책 키워드를 포함한 이탤릭 줄이 있는 경우 exit code가 0이 아니었습니다 (실제: ${valid_disclaimer_status})."
  failures+=("정상 면책 문구 케이스 exit code != 0")
else
  echo "[PASS] 면책 키워드를 포함한 이탤릭 줄이 있는 경우 exit code가 0(PASS)입니다."
fi

if echo "${valid_disclaimer_output}" | grep -qF "${DISCLAIMER_FAIL_MESSAGE}"; then
  echo "[FAIL] 정상 케이스인데 면책 문구 FAIL 메시지가 출력되었습니다."
  failures+=("정상 면책 문구 케이스에서 오탐")
else
  echo "[PASS] 정상 케이스에서는 면책 문구 FAIL 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 2: 본문에 이탤릭 처리가 전혀 없는 글 -> FAIL 이어야 함 ==="
NO_ITALIC_FILE="2026-01-01-no-italic-regression-test.md"
NO_ITALIC_CONTENT='---
title: "면책 문구 검사 회귀 테스트용 임시 글(이탤릭 없음)"
meta_description: "본문에 이탤릭 처리가 전혀 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_disclaimer_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다. 이 투자 정보에 대한 책임은
독자 본인에게 있지만, 이 문장은 이탤릭으로 감싸지 않은 평범한 문단입니다.
'

no_italic_result="$(run_validate_with_post "${NO_ITALIC_FILE}" "${NO_ITALIC_CONTENT}")"
no_italic_status="$(echo "${no_italic_result}" | head -n 1)"
no_italic_output="$(echo "${no_italic_result}" | tail -n +2)"

echo "${no_italic_output}"
echo "(실행 exit code: ${no_italic_status})"

if [ "${no_italic_status}" -ne 1 ]; then
  echo "[FAIL] 이탤릭 처리가 전혀 없는 경우 exit code가 1이 아니었습니다 (실제: ${no_italic_status})."
  failures+=("이탤릭 없음 케이스 exit code != 1")
else
  echo "[PASS] 이탤릭 처리가 전혀 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${no_italic_output}" | grep -qF "${DISCLAIMER_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${DISCLAIMER_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${DISCLAIMER_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("이탤릭 없음 케이스 메시지 누락")
fi

echo ""
echo "=== 검사 3: 이탤릭 처리는 있지만 면책 키워드가 전혀 없는 글 -> FAIL 이어야 함 ==="
ITALIC_NO_KEYWORD_FILE="2026-01-01-italic-no-keyword-regression-test.md"
ITALIC_NO_KEYWORD_CONTENT='---
title: "면책 문구 검사 회귀 테스트용 임시 글(키워드 없음)"
meta_description: "이탤릭 처리는 있지만 면책 키워드가 전혀 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_disclaimer_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 문장은 이탤릭으로 감싸져 있지만 면책 키워드는 전혀 포함하지 않습니다.*
'

italic_no_keyword_result="$(run_validate_with_post "${ITALIC_NO_KEYWORD_FILE}" "${ITALIC_NO_KEYWORD_CONTENT}")"
italic_no_keyword_status="$(echo "${italic_no_keyword_result}" | head -n 1)"
italic_no_keyword_output="$(echo "${italic_no_keyword_result}" | tail -n +2)"

echo "${italic_no_keyword_output}"
echo "(실행 exit code: ${italic_no_keyword_status})"

if [ "${italic_no_keyword_status}" -ne 1 ]; then
  echo "[FAIL] 이탤릭은 있지만 키워드가 없는 경우 exit code가 1이 아니었습니다 (실제: ${italic_no_keyword_status})."
  failures+=("이탤릭+키워드없음 케이스 exit code != 1")
else
  echo "[PASS] 이탤릭은 있지만 키워드가 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${italic_no_keyword_output}" | grep -qF "${DISCLAIMER_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${DISCLAIMER_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${DISCLAIMER_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("이탤릭+키워드없음 케이스 메시지 누락")
fi

echo ""
echo "=== 검사 4: 굵게(**...**) 처리된 줄만 있고 이탤릭 처리가 없는 글 -> FAIL 이어야 함 (회귀 방지) ==="
BOLD_ONLY_FILE="2026-01-01-bold-only-regression-test.md"
BOLD_ONLY_CONTENT='---
title: "면책 문구 검사 회귀 테스트용 임시 글(굵게만 있음)"
meta_description: "굵게 처리된 줄만 있고 이탤릭 처리가 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_disclaimer_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

**이 투자에 대한 책임은 전적으로 독자 본인에게 있습니다.**
'

bold_only_result="$(run_validate_with_post "${BOLD_ONLY_FILE}" "${BOLD_ONLY_CONTENT}")"
bold_only_status="$(echo "${bold_only_result}" | head -n 1)"
bold_only_output="$(echo "${bold_only_result}" | tail -n +2)"

echo "${bold_only_output}"
echo "(실행 exit code: ${bold_only_status})"

if [ "${bold_only_status}" -ne 1 ]; then
  echo "[FAIL] 굵게 처리된 줄만 있는 경우 exit code가 1이 아니었습니다 (실제: ${bold_only_status})."
  failures+=("굵게만 있음 케이스 exit code != 1")
else
  echo "[PASS] 굵게 처리된 줄만 있는 경우(이탤릭 아님) exit code가 1(FAIL)입니다."
fi

if echo "${bold_only_output}" | grep -qF "${DISCLAIMER_FAIL_MESSAGE}"; then
  echo "[PASS] 출력에 \"${DISCLAIMER_FAIL_MESSAGE}\" 메시지가 포함되어 있습니다(= 굵게를 이탤릭으로 오탐하지 않음)."
else
  echo "[FAIL] 출력에 \"${DISCLAIMER_FAIL_MESSAGE}\" 메시지가 없습니다."
  failures+=("굵게만 있음 케이스 메시지 누락")
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
