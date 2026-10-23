#!/usr/bin/env bash
#
# test_meta_length.sh
#
# scripts/validate_posts.sh에 추가된 "title/meta_description 길이 검사"
# (title 60자, meta_description 160자를 초과하면 FAIL) 로직이 실제로
# 동작하는지 확인하는 회귀 테스트다.
#
#   배경: 구글 검색결과 스니펫 기준으로 흔히 쓰이는 가이드라인은 title
#   약 60자 이내, meta_description 약 155~160자 이내이며, 이를 넘으면
#   검색결과에서 잘려 보일 수 있다. validate_posts.sh는 과거에
#   meta_description 길이를 [WARN]으로만 안내하고 절대 FAIL 처리하지
#   않았으나(title 길이 검사는 전혀 없었음), 검색 노출 품질을 위해
#   title까지 포함해 FAIL 레벨로 올렸다(2026-10-23 마스터 지시). 이
#   테스트는 scripts/test_img_alt_required.sh, scripts/test_duplicate_slug.sh와
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
#   1) [title 61자 초과 케이스] title이 61자(한글, 1글자=1자 기준)이고
#      meta_description은 정상 길이인 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)이고
#      출력에 "title 길이가 61자로 60자를 초과합니다" 메시지가 포함되는지
#      확인한다.
#   2) [meta_description 161자 초과 케이스] meta_description이 161자이고
#      title은 정상 길이인 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)이고
#      출력에 "meta_description 길이가 161자로 160자를 초과합니다" 메시지가
#      포함되는지 확인한다.
#   3) [정상 길이 케이스] title이 정확히 60자, meta_description이 정확히
#      160자(둘 다 기준치와 같음, 초과가 아님)인 글 하나를 임시 posts/
#      안에 만들고 validate_posts.sh(사본)를 실행했을 때, exit code가
#      0(PASS)이고 길이 관련 FAIL 메시지가 출력되지 않는지 확인한다
#      (경계값 회귀 방지 — 기준치와 "같은" 경우는 초과가 아니므로 FAIL이면
#      안 된다).
#   4) [한글 문자 수 계산 확인] 한글(멀티바이트 문자)로 채운 title이
#      61자일 때도 바이트 수가 아니라 "글자 수" 기준으로 61자로 계산되어
#      FAIL 처리되는지 확인한다(검사 1과 동일한 입력을 재사용해, 메시지에
#      찍힌 글자 수가 바이트 수(UTF-8 한글 1글자=3바이트이므로 183바이트)가
#      아니라 61자인지 확인한다).
#
# 사용법:
#   bash scripts/test_meta_length.sh
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

# 한글 N자로 채운 문자열을 만든다.
# 주의: bash의 ${#result}는 로케일이 UTF-8이 아니면(이 저장소의 기본 쉘
# 로케일은 POSIX) 문자 수가 아니라 바이트 수를 반환해 길이가 틀어진다.
# 그래서 bash 문자열 슬라이싱 대신 python3로 정확히 N개의 한글 문자를
# 만든다(저장소의 generate_jsonld.sh 등에서도 이미 python3을 사용 중이라
# 새 의존성은 아니다).
repeat_hangul() {
  local count="$1"
  python3 -c "import sys; print('가' * int(sys.argv[1]), end='')" "${count}"
}

TITLE_60="$(repeat_hangul 60)"
TITLE_61="$(repeat_hangul 61)"
META_160="$(repeat_hangul 160)"
META_161="$(repeat_hangul 161)"

echo "=== 검사 1: title이 61자(60자 초과)인 글 -> FAIL 이어야 함 ==="
LONG_TITLE_FILE="2026-01-01-long-title-regression-test.md"
LONG_TITLE_CONTENT='---
title: "'"${TITLE_61}"'"
meta_description: "정상 길이의 메타 설명입니다. 이 글은 title 길이 초과 검사용 테스트 글입니다."
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_meta_length.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

long_title_result="$(run_validate_with_post "${LONG_TITLE_FILE}" "${LONG_TITLE_CONTENT}")"
long_title_status="$(echo "${long_title_result}" | head -n 1)"
long_title_output="$(echo "${long_title_result}" | tail -n +2)"

echo "${long_title_output}"
echo "(실행 exit code: ${long_title_status})"

if [ "${long_title_status}" -ne 1 ]; then
  echo "[FAIL] title이 61자인 경우 exit code가 1이 아니었습니다 (실제: ${long_title_status})."
  failures+=("title 61자 케이스 exit code != 1")
else
  echo "[PASS] title이 61자인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${long_title_output}" | grep -qF "title 길이가 61자로 60자를 초과합니다"; then
  echo "[PASS] 출력에 \"title 길이가 61자로 60자를 초과합니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 title 길이 초과 메시지가 없거나 글자 수가 다릅니다."
  failures+=("title 길이 초과 메시지 누락 또는 불일치")
fi

echo ""
echo "=== 검사 2: meta_description이 161자(160자 초과)인 글 -> FAIL 이어야 함 ==="
LONG_META_FILE="2026-01-01-long-meta-regression-test.md"
LONG_META_CONTENT='---
title: "정상 길이의 제목입니다"
meta_description: "'"${META_161}"'"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_meta_length.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

long_meta_result="$(run_validate_with_post "${LONG_META_FILE}" "${LONG_META_CONTENT}")"
long_meta_status="$(echo "${long_meta_result}" | head -n 1)"
long_meta_output="$(echo "${long_meta_result}" | tail -n +2)"

echo "${long_meta_output}"
echo "(실행 exit code: ${long_meta_status})"

if [ "${long_meta_status}" -ne 1 ]; then
  echo "[FAIL] meta_description이 161자인 경우 exit code가 1이 아니었습니다 (실제: ${long_meta_status})."
  failures+=("meta_description 161자 케이스 exit code != 1")
else
  echo "[PASS] meta_description이 161자인 경우 exit code가 1(FAIL)입니다."
fi

if echo "${long_meta_output}" | grep -qF "meta_description 길이가 161자로 160자를 초과합니다"; then
  echo "[PASS] 출력에 \"meta_description 길이가 161자로 160자를 초과합니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 meta_description 길이 초과 메시지가 없거나 글자 수가 다릅니다."
  failures+=("meta_description 길이 초과 메시지 누락 또는 불일치")
fi

echo ""
echo "=== 검사 3: title 정확히 60자, meta_description 정확히 160자(기준치와 같음) -> PASS 이어야 함 (경계값 회귀 방지) ==="
BOUNDARY_FILE="2026-01-01-boundary-length-regression-test.md"
BOUNDARY_CONTENT='---
title: "'"${TITLE_60}"'"
meta_description: "'"${META_160}"'"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_meta_length.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다. title은 정확히 60자,
meta_description은 정확히 160자로, 기준치를 초과하지 않으므로 통과해야
합니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

boundary_result="$(run_validate_with_post "${BOUNDARY_FILE}" "${BOUNDARY_CONTENT}")"
boundary_status="$(echo "${boundary_result}" | head -n 1)"
boundary_output="$(echo "${boundary_result}" | tail -n +2)"

echo "${boundary_output}"
echo "(실행 exit code: ${boundary_status})"

if [ "${boundary_status}" -ne 0 ]; then
  echo "[FAIL] title 60자/meta_description 160자(기준치와 같음)인데 exit code가 0이 아니었습니다 (실제: ${boundary_status})."
  failures+=("경계값(60자/160자) 케이스 exit code != 0")
else
  echo "[PASS] title 60자/meta_description 160자(기준치와 같음)인 경우 exit code가 0(PASS)입니다."
fi

if echo "${boundary_output}" | grep -qE "(title|meta_description) 길이가.*초과합니다"; then
  echo "[FAIL] 경계값(기준치와 같음) 케이스인데 길이 초과 메시지가 출력되었습니다."
  failures+=("경계값 케이스에서 길이 초과 오탐")
else
  echo "[PASS] 경계값(기준치와 같음) 케이스에서는 길이 초과 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 4: 한글 문자 수 기준 계산 확인(바이트 수 아님) ==="
# 검사 1의 결과를 재사용: title이 한글 61자일 때 메시지에 찍힌 숫자가
# 바이트 수(183바이트)가 아니라 글자 수(61자)인지 확인한다.
if echo "${long_title_output}" | grep -qF "183바이트"; then
  echo "[FAIL] 메시지에 바이트 수(183바이트)가 찍혔습니다. 글자 수가 아니라 바이트 수로 계산하는 회귀가 발생했을 수 있습니다."
  failures+=("한글 길이 계산이 바이트 수 기준으로 회귀함")
elif echo "${long_title_output}" | grep -qF "title 길이가 61자"; then
  echo "[PASS] 한글 61자가 바이트 수가 아닌 글자 수(61자) 기준으로 정확히 계산되었습니다."
else
  echo "[FAIL] 한글 문자 수 계산 결과를 확인할 수 없습니다."
  failures+=("한글 문자 수 계산 결과 확인 불가")
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
