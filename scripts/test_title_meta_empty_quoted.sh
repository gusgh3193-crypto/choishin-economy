#!/usr/bin/env bash
#
# test_title_meta_empty_quoted.sh
#
# scripts/validate_posts.sh의 3-4 검사(title, meta_description 필드가
# 따옴표로는 감싸여 있지만 그 안이 빈 문자열("")이거나 공백만("   ")인
# 경우를 검사하는 로직)이 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: validate_posts.sh의 3) 필수 필드 검사(^${field}:[[:space:]]*.+)는
#   콜론 뒤에 따옴표 2개(예: title: "")만 있어도 "문자가 있다"고 판단해
#   PASS 처리해버린다. 이를 메우기 위해 3-4 검사(187~196행 부근)가
#   추가되어, 따옴표로 감싸인 값의 내부가 비어있거나 공백뿐이면 별도로
#   FAIL 처리한다. 그런데 이 3-4 검사 자체를 전용으로 검증하는 회귀
#   테스트는 아직 없었다. 이 공백을 메우기 위해 2026-11-01 마스터 지시로
#   추가했다. 이 테스트는 scripts/test_required_date_field.sh,
#   scripts/test_date_filename_mismatch.sh와 같은 "임시 디렉터리에
#   validate_posts.sh 사본과 임시 posts/ 구조를 만들어 그 사본을 실행 →
#   PASS/FAIL 출력 → exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/validate_posts.sh 사본과
#   임시 posts/ 구조를 통째로 구성해 그 사본을 실행한다(validate_posts.sh는
#   자기 자신의 위치를 기준으로 REPO_ROOT/POSTS_DIR을 계산하므로, 사본을
#   임시 디렉터리 안 scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만
#   동작한다).
#
# 검사 내용:
#   1) [title 정상 케이스] title이 정상적으로 채워진 글 하나를 임시 posts/
#      안에 만들고 validate_posts.sh(사본)를 실행했을 때, exit code가
#      0(PASS)이고 "title가 비어 있습니다" 관련 FAIL 메시지가 출력되지
#      않는지 확인한다.
#   2) [title 빈 문자열 케이스] title: ""(따옴표로는 감싸여 있지만 안이
#      빈 문자열)인 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh
#      (사본)를 실행했을 때, exit code가 1(FAIL)이고 출력에
#      "frontmatter의 title가 비어 있습니다" 메시지가 포함되는지 확인한다.
#   3) [meta_description 공백 케이스] meta_description: "   "(따옴표로는
#      감싸여 있지만 안이 공백만)인 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)이고
#      출력에 "frontmatter의 meta_description가 비어 있습니다" 메시지가
#      포함되는지 확인한다.
#   4) [meta_description 정상 케이스] meta_description이 정상적으로
#      채워진 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 0(PASS)이고 "meta_description가 비어
#      있습니다" 관련 FAIL 메시지가 출력되지 않는지 확인한다.
#
# 사용법:
#   bash scripts/test_title_meta_empty_quoted.sh
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

echo "=== 검사 1: title이 정상적으로 채워진 글 -> PASS 이어야 함 ==="
TITLE_OK_FILE="2026-11-01-title-ok-regression-test.md"
TITLE_OK_CONTENT='---
title: "title이 정상적으로 채워진 회귀 테스트용 글"
meta_description: "title/meta_description 빈 값 검사 회귀 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-11-01
---

이 글은 scripts/test_title_meta_empty_quoted.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

title_ok_result="$(run_validate_with_post "${TITLE_OK_FILE}" "${TITLE_OK_CONTENT}")"
title_ok_status="$(echo "${title_ok_result}" | head -n 1)"
title_ok_output="$(echo "${title_ok_result}" | tail -n +2)"

echo "${title_ok_output}"
echo "(실행 exit code: ${title_ok_status})"

if [ "${title_ok_status}" -ne 0 ]; then
  echo "[FAIL] title이 정상적으로 채워진 경우 exit code가 0이 아니었습니다 (실제: ${title_ok_status})."
  failures+=("title 정상 케이스 exit code != 0")
else
  echo "[PASS] title이 정상적으로 채워진 경우 exit code가 0(PASS)입니다."
fi

if echo "${title_ok_output}" | grep -qF "title가 비어 있습니다"; then
  echo "[FAIL] title 정상 케이스인데 \"title가 비어 있습니다\" 메시지가 출력되었습니다."
  failures+=("title 정상 케이스에서 빈 값 오탐")
else
  echo "[PASS] title 정상 케이스에서는 \"title가 비어 있습니다\" 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 2: title: \"\"(빈 문자열, 따옴표로는 감싸여 있음) -> FAIL 이어야 함 ==="
TITLE_EMPTY_FILE="2026-11-01-title-empty-regression-test.md"
TITLE_EMPTY_CONTENT='---
title: ""
meta_description: "title이 따옴표만 있고 안은 빈 문자열인 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-11-01
---

이 글은 scripts/test_title_meta_empty_quoted.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

title_empty_result="$(run_validate_with_post "${TITLE_EMPTY_FILE}" "${TITLE_EMPTY_CONTENT}")"
title_empty_status="$(echo "${title_empty_result}" | head -n 1)"
title_empty_output="$(echo "${title_empty_result}" | tail -n +2)"

echo "${title_empty_output}"
echo "(실행 exit code: ${title_empty_status})"

if [ "${title_empty_status}" -ne 1 ]; then
  echo "[FAIL] title이 빈 문자열인 경우 exit code가 1이 아니었습니다 (실제: ${title_empty_status})."
  failures+=("title 빈 문자열 케이스 exit code != 1")
else
  echo "[PASS] title이 빈 문자열인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${title_empty_output}" | grep -qF "frontmatter의 title가 비어 있습니다"; then
  echo "[PASS] 출력에 \"frontmatter의 title가 비어 있습니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"frontmatter의 title가 비어 있습니다\" 메시지가 없습니다."
  failures+=("title 빈 문자열 메시지 누락")
fi

echo ""
echo "=== 검사 3: meta_description: \"   \"(공백만) -> FAIL 이어야 함 ==="
META_BLANK_FILE="2026-11-01-meta-description-blank-regression-test.md"
META_BLANK_CONTENT='---
title: "meta_description 공백 검사 회귀 테스트용 글"
meta_description: "   "
keywords: ["테스트"]
date: 2026-11-01
---

이 글은 scripts/test_title_meta_empty_quoted.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

meta_blank_result="$(run_validate_with_post "${META_BLANK_FILE}" "${META_BLANK_CONTENT}")"
meta_blank_status="$(echo "${meta_blank_result}" | head -n 1)"
meta_blank_output="$(echo "${meta_blank_result}" | tail -n +2)"

echo "${meta_blank_output}"
echo "(실행 exit code: ${meta_blank_status})"

if [ "${meta_blank_status}" -ne 1 ]; then
  echo "[FAIL] meta_description이 공백뿐인 경우 exit code가 1이 아니었습니다 (실제: ${meta_blank_status})."
  failures+=("meta_description 공백 케이스 exit code != 1")
else
  echo "[PASS] meta_description이 공백뿐인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${meta_blank_output}" | grep -qF "frontmatter의 meta_description가 비어 있습니다"; then
  echo "[PASS] 출력에 \"frontmatter의 meta_description가 비어 있습니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"frontmatter의 meta_description가 비어 있습니다\" 메시지가 없습니다."
  failures+=("meta_description 공백 메시지 누락")
fi

echo ""
echo "=== 검사 4: meta_description이 정상적으로 채워진 글 -> PASS 이어야 함 ==="
META_OK_FILE="2026-11-01-meta-description-ok-regression-test.md"
META_OK_CONTENT='---
title: "meta_description 정상 케이스 회귀 테스트용 글"
meta_description: "meta_description이 정상적으로 채워진 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-11-01
---

이 글은 scripts/test_title_meta_empty_quoted.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

meta_ok_result="$(run_validate_with_post "${META_OK_FILE}" "${META_OK_CONTENT}")"
meta_ok_status="$(echo "${meta_ok_result}" | head -n 1)"
meta_ok_output="$(echo "${meta_ok_result}" | tail -n +2)"

echo "${meta_ok_output}"
echo "(실행 exit code: ${meta_ok_status})"

if [ "${meta_ok_status}" -ne 0 ]; then
  echo "[FAIL] meta_description이 정상적으로 채워진 경우 exit code가 0이 아니었습니다 (실제: ${meta_ok_status})."
  failures+=("meta_description 정상 케이스 exit code != 0")
else
  echo "[PASS] meta_description이 정상적으로 채워진 경우 exit code가 0(PASS)입니다."
fi

if echo "${meta_ok_output}" | grep -qF "meta_description가 비어 있습니다"; then
  echo "[FAIL] meta_description 정상 케이스인데 \"meta_description가 비어 있습니다\" 메시지가 출력되었습니다."
  failures+=("meta_description 정상 케이스에서 빈 값 오탐")
else
  echo "[PASS] meta_description 정상 케이스에서는 \"meta_description가 비어 있습니다\" 메시지가 출력되지 않았습니다."
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
