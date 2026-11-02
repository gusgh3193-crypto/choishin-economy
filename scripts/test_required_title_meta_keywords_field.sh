#!/usr/bin/env bash
#
# test_required_title_meta_keywords_field.sh
#
# scripts/validate_posts.sh의 REQUIRED_FIELDS(title, meta_description,
# keywords, date)에 대한 필수 필드 검사(140~147행 공통 루프) 중,
# title / meta_description / keywords 필드가 frontmatter에 "아예 없는"
# 경우를 다루는 전용 회귀 테스트다.
#
#   배경: REQUIRED_FIELDS 4개 필드는 동일한 하나의 루프로 "필드가 없거나
#   비어있으면 FAIL" 검사를 받는다. 그런데 이 중 date 필드만
#   scripts/test_required_date_field.sh로 "필드 자체가 없는 경우"를 다루는
#   전용 회귀 테스트가 있었고, title/meta_description/keywords 세 필드가
#   아예 없는 경우(필드 누락 자체)를 다루는 전용 회귀 테스트는 없었다
#   (test_title_meta_empty_quoted.sh는 필드가 존재하되 따옴표 안이 빈
#   문자열인 경우만 다루고, test_meta_length.sh는 길이 초과만 다루므로
#   둘 다 "필드 자체가 없는 경우"는 다루지 않는다). 2026-11-02 마스터
#   지시로 이 공백을 메우기 위해 추가했다.
#
#   이 테스트는 scripts/test_required_date_field.sh와 동일한 패턴
#   (mktemp -d로 임시 저장소를 만들어 validate_posts.sh 사본을 그 안에서
#   실행)을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/validate_posts.sh 사본과
#   임시 posts/ 구조를 통째로 구성해 그 사본을 실행한다.
#
# 검사 내용:
#   1) [title 필드 없음 케이스] meta_description/keywords/date/면책 문구는
#      모두 정상이지만 frontmatter에 title 필드가 아예 없는 글 -> FAIL
#      이고 "frontmatter에 'title' 필드가 없거나 비어 있습니다" 메시지가
#      출력되는지 확인한다.
#   2) [meta_description 필드 없음 케이스] 위와 동일한 구조로
#      meta_description 필드만 아예 없는 글 -> FAIL이고 해당 메시지가
#      출력되는지 확인한다.
#   3) [keywords 필드 없음 케이스] 위와 동일한 구조로 keywords 필드만
#      아예 없는 글 -> FAIL이고 해당 메시지가 출력되는지 확인한다.
#   4) [정상 케이스] title/meta_description/keywords/date 4개 필드가 모두
#      정상적으로 있는 글 -> PASS이고 위 세 FAIL 메시지가 전혀 출력되지
#      않는지 확인한다.
#
# 사용법:
#   bash scripts/test_required_title_meta_keywords_field.sh
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

echo "=== 검사 1: frontmatter에 title 필드가 아예 없는 글 -> FAIL 이어야 함 ==="
NO_TITLE_FILE="2026-01-02-no-title-regression-test.md"
NO_TITLE_CONTENT='---
meta_description: "frontmatter에 title 필드가 아예 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-02
---

이 글은 scripts/test_required_title_meta_keywords_field.sh가 만든 임시
테스트용 글입니다. posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_title_result="$(run_validate_with_post "${NO_TITLE_FILE}" "${NO_TITLE_CONTENT}")"
no_title_status="$(echo "${no_title_result}" | head -n 1)"
no_title_output="$(echo "${no_title_result}" | tail -n +2)"

echo "${no_title_output}"
echo "(실행 exit code: ${no_title_status})"

if [ "${no_title_status}" -ne 1 ]; then
  echo "[FAIL] title 필드가 없는 경우 exit code가 1이 아니었습니다 (실제: ${no_title_status})."
  failures+=("title 필드 없음 케이스 exit code != 1")
else
  echo "[PASS] title 필드가 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${no_title_output}" | grep -qF "frontmatter에 'title' 필드가 없거나 비어 있습니다"; then
  echo "[PASS] 출력에 \"frontmatter에 'title' 필드가 없거나 비어 있습니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"frontmatter에 'title' 필드가 없거나 비어 있습니다\" 메시지가 없습니다."
  failures+=("title 필드 누락 메시지 누락")
fi

echo ""
echo "=== 검사 2: frontmatter에 meta_description 필드가 아예 없는 글 -> FAIL 이어야 함 ==="
NO_META_FILE="2026-01-02-no-meta-regression-test.md"
NO_META_CONTENT='---
title: "meta_description 필드 필수 검사 회귀 테스트용 임시 글"
keywords: ["테스트"]
date: 2026-01-02
---

이 글은 scripts/test_required_title_meta_keywords_field.sh가 만든 임시
테스트용 글입니다. posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_meta_result="$(run_validate_with_post "${NO_META_FILE}" "${NO_META_CONTENT}")"
no_meta_status="$(echo "${no_meta_result}" | head -n 1)"
no_meta_output="$(echo "${no_meta_result}" | tail -n +2)"

echo "${no_meta_output}"
echo "(실행 exit code: ${no_meta_status})"

if [ "${no_meta_status}" -ne 1 ]; then
  echo "[FAIL] meta_description 필드가 없는 경우 exit code가 1이 아니었습니다 (실제: ${no_meta_status})."
  failures+=("meta_description 필드 없음 케이스 exit code != 1")
else
  echo "[PASS] meta_description 필드가 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${no_meta_output}" | grep -qF "frontmatter에 'meta_description' 필드가 없거나 비어 있습니다"; then
  echo "[PASS] 출력에 \"frontmatter에 'meta_description' 필드가 없거나 비어 있습니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"frontmatter에 'meta_description' 필드가 없거나 비어 있습니다\" 메시지가 없습니다."
  failures+=("meta_description 필드 누락 메시지 누락")
fi

echo ""
echo "=== 검사 3: frontmatter에 keywords 필드가 아예 없는 글 -> FAIL 이어야 함 ==="
NO_KEYWORDS_FILE="2026-01-02-no-keywords-regression-test.md"
NO_KEYWORDS_CONTENT='---
title: "keywords 필드 필수 검사 회귀 테스트용 임시 글"
meta_description: "frontmatter에 keywords 필드가 아예 없는 테스트용 임시 글입니다"
date: 2026-01-02
---

이 글은 scripts/test_required_title_meta_keywords_field.sh가 만든 임시
테스트용 글입니다. posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_keywords_result="$(run_validate_with_post "${NO_KEYWORDS_FILE}" "${NO_KEYWORDS_CONTENT}")"
no_keywords_status="$(echo "${no_keywords_result}" | head -n 1)"
no_keywords_output="$(echo "${no_keywords_result}" | tail -n +2)"

echo "${no_keywords_output}"
echo "(실행 exit code: ${no_keywords_status})"

if [ "${no_keywords_status}" -ne 1 ]; then
  echo "[FAIL] keywords 필드가 없는 경우 exit code가 1이 아니었습니다 (실제: ${no_keywords_status})."
  failures+=("keywords 필드 없음 케이스 exit code != 1")
else
  echo "[PASS] keywords 필드가 없는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${no_keywords_output}" | grep -qF "frontmatter에 'keywords' 필드가 없거나 비어 있습니다"; then
  echo "[PASS] 출력에 \"frontmatter에 'keywords' 필드가 없거나 비어 있습니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"frontmatter에 'keywords' 필드가 없거나 비어 있습니다\" 메시지가 없습니다."
  failures+=("keywords 필드 누락 메시지 누락")
fi

echo ""
echo "=== 검사 4: title/meta_description/keywords/date 4개 필드가 모두 정상인 글 -> PASS 이어야 함 ==="
VALID_FILE="2026-01-02-valid-required-fields-regression-test.md"
VALID_CONTENT='---
title: "필수 필드 회귀 테스트용 정상 글"
meta_description: "title/meta_description/keywords/date가 모두 정상적으로 있는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-02
---

이 글은 scripts/test_required_title_meta_keywords_field.sh가 만든 임시
테스트용 글입니다. posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

valid_result="$(run_validate_with_post "${VALID_FILE}" "${VALID_CONTENT}")"
valid_status="$(echo "${valid_result}" | head -n 1)"
valid_output="$(echo "${valid_result}" | tail -n +2)"

echo "${valid_output}"
echo "(실행 exit code: ${valid_status})"

if [ "${valid_status}" -ne 0 ]; then
  echo "[FAIL] 4개 필드가 모두 정상인 경우 exit code가 0이 아니었습니다 (실제: ${valid_status})."
  failures+=("정상 케이스 exit code != 0")
else
  echo "[PASS] 4개 필드가 모두 정상인 경우 exit code가 0(PASS)입니다."
fi

for field in title meta_description keywords; do
  if echo "${valid_output}" | grep -qF "frontmatter에 '${field}' 필드가 없거나 비어 있습니다"; then
    echo "[FAIL] 정상 케이스인데 '${field}' 필드 누락 메시지가 출력되었습니다."
    failures+=("정상 케이스에서 ${field} 필드 누락 오탐")
  else
    echo "[PASS] 정상 케이스에서는 '${field}' 필드 누락 메시지가 출력되지 않았습니다."
  fi
done

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
