#!/usr/bin/env bash
#
# test_date_filename_mismatch.sh
#
# scripts/validate_posts.sh의 3-2 검사(frontmatter의 date 필드가 파일명의
# 날짜와 일치하는지 검사) 로직이 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: 3-2 검사는 date_line에서 정규식 ^\"?([0-9]{4}-[0-9]{2}-[0-9]{2})\"?로
#   frontmatter_date를 뽑아내고, 파일명 접두어(^[0-9]{4}-[0-9]{2}-[0-9]{2}-)에서
#   filename_date를 뽑아내어 두 값이 다르면 FAIL 처리한다. 이 검사는
#   2026-10-17 마스터 지시로 REQUIRED_FIELDS의 date 필수 검사(3번)와 역할이
#   분리되었지만(위 scripts/test_required_date_field.sh가 3번을 다룬다),
#   3-2 자체를 전용으로 검증하는 회귀 테스트는 아직 없었다. 이 공백을 메우기
#   위해 2026-10-31 마스터 지시로 추가했다. 이 테스트는
#   scripts/test_required_date_field.sh와 같은 "임시 디렉터리에 validate_posts.sh
#   사본과 임시 posts/ 구조를 만들어 그 사본을 실행 → PASS/FAIL 출력 → exit
#   code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/validate_posts.sh 사본과
#   임시 posts/ 구조를 통째로 구성해 그 사본을 실행한다(validate_posts.sh는
#   자기 자신의 위치를 기준으로 REPO_ROOT/POSTS_DIR을 계산하므로, 사본을
#   임시 디렉터리 안 scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만
#   동작한다).
#
# 검사 내용:
#   1) [일치 케이스] date 필드 값이 파일명의 날짜와 정확히 일치하는 글
#      하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때,
#      exit code가 0(PASS)이고 "파일명의 날짜" 관련 FAIL 메시지가 출력되지
#      않는지 확인한다.
#   2) [불일치 케이스] date 필드 값이 파일명의 날짜와 다른 글(파일명은
#      2026-09-13, date는 2026-09-14) 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)이고
#      출력에 "파일명의 날짜"와 "다릅니다" 문구가 모두 포함되는지 확인한다.
#   3) [따옴표 케이스] date 필드 값이 따옴표로 감싸여 있지만(date: "2026-09-13")
#      그 안의 날짜가 파일명과 일치하는 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, 정규식이 따옴표를 올바르게
#      벗겨내 exit code가 0(PASS)이고 "파일명의 날짜" 관련 FAIL 메시지가
#      출력되지 않는지 확인한다.
#
# 사용법:
#   bash scripts/test_date_filename_mismatch.sh
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

echo "=== 검사 1: date 필드가 파일명 날짜와 정확히 일치하는 글 -> PASS 이어야 함 ==="
MATCH_FILE="2026-09-13-date-filename-match-regression-test.md"
MATCH_CONTENT='---
title: "date/파일명 일치 회귀 테스트용 정상 글"
meta_description: "date 필드가 파일명의 날짜와 정확히 일치하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-09-13
---

이 글은 scripts/test_date_filename_mismatch.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

match_result="$(run_validate_with_post "${MATCH_FILE}" "${MATCH_CONTENT}")"
match_status="$(echo "${match_result}" | head -n 1)"
match_output="$(echo "${match_result}" | tail -n +2)"

echo "${match_output}"
echo "(실행 exit code: ${match_status})"

if [ "${match_status}" -ne 0 ]; then
  echo "[FAIL] date가 파일명과 일치하는 경우 exit code가 0이 아니었습니다 (실제: ${match_status})."
  failures+=("date/파일명 일치 케이스 exit code != 0")
else
  echo "[PASS] date가 파일명과 일치하는 경우 exit code가 0(PASS)입니다."
fi

if echo "${match_output}" | grep -qF "파일명의 날짜"; then
  echo "[FAIL] 일치 케이스인데 \"파일명의 날짜\" 관련 FAIL 메시지가 출력되었습니다."
  failures+=("일치 케이스에서 날짜 불일치 오탐")
else
  echo "[PASS] 일치 케이스에서는 \"파일명의 날짜\" 관련 FAIL 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 2: date 필드가 파일명 날짜와 다른 글 -> FAIL 이어야 함 ==="
MISMATCH_FILE="2026-09-13-date-filename-mismatch-regression-test.md"
MISMATCH_CONTENT='---
title: "date/파일명 불일치 회귀 테스트용 글"
meta_description: "date 필드가 파일명의 날짜와 다른 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-09-14
---

이 글은 scripts/test_date_filename_mismatch.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

mismatch_result="$(run_validate_with_post "${MISMATCH_FILE}" "${MISMATCH_CONTENT}")"
mismatch_status="$(echo "${mismatch_result}" | head -n 1)"
mismatch_output="$(echo "${mismatch_result}" | tail -n +2)"

echo "${mismatch_output}"
echo "(실행 exit code: ${mismatch_status})"

if [ "${mismatch_status}" -ne 1 ]; then
  echo "[FAIL] date가 파일명과 다른 경우 exit code가 1이 아니었습니다 (실제: ${mismatch_status})."
  failures+=("date/파일명 불일치 케이스 exit code != 1")
else
  echo "[PASS] date가 파일명과 다른 경우 exit code가 1(FAIL)입니다."
fi

if echo "${mismatch_output}" | grep -qF "파일명의 날짜" && echo "${mismatch_output}" | grep -qF "다릅니다"; then
  echo "[PASS] 출력에 \"파일명의 날짜\"와 \"다릅니다\" 관련 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"파일명의 날짜\"/\"다릅니다\" 관련 메시지가 없습니다."
  failures+=("date/파일명 불일치 메시지 누락")
fi

echo ""
echo "=== 검사 3: date 필드 값이 따옴표로 감싸여 있지만 파일명과 일치하는 글 -> PASS 이어야 함 ==="
QUOTED_MATCH_FILE="2026-09-13-date-filename-quoted-match-regression-test.md"
QUOTED_MATCH_CONTENT='---
title: "date 따옴표 회귀 테스트용 정상 글"
meta_description: "date 필드 값이 따옴표로 감싸여 있지만 파일명과 일치하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: "2026-09-13"
---

이 글은 scripts/test_date_filename_mismatch.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

quoted_match_result="$(run_validate_with_post "${QUOTED_MATCH_FILE}" "${QUOTED_MATCH_CONTENT}")"
quoted_match_status="$(echo "${quoted_match_result}" | head -n 1)"
quoted_match_output="$(echo "${quoted_match_result}" | tail -n +2)"

echo "${quoted_match_output}"
echo "(실행 exit code: ${quoted_match_status})"

if [ "${quoted_match_status}" -ne 0 ]; then
  echo "[FAIL] 따옴표로 감싸인 date가 파일명과 일치하는 경우 exit code가 0이 아니었습니다 (실제: ${quoted_match_status})."
  failures+=("따옴표 date/파일명 일치 케이스 exit code != 0")
else
  echo "[PASS] 따옴표로 감싸인 date가 파일명과 일치하는 경우 exit code가 0(PASS)입니다."
fi

if echo "${quoted_match_output}" | grep -qF "파일명의 날짜"; then
  echo "[FAIL] 따옴표 일치 케이스인데 \"파일명의 날짜\" 관련 FAIL 메시지가 출력되었습니다."
  failures+=("따옴표 일치 케이스에서 날짜 불일치 오탐")
else
  echo "[PASS] 따옴표 일치 케이스에서는 \"파일명의 날짜\" 관련 FAIL 메시지가 출력되지 않았습니다."
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
