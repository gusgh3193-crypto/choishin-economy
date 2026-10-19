#!/usr/bin/env bash
#
# test_img_alt_required.sh
#
# scripts/validate_posts.sh에 추가된 "이미지 alt 속성 존재 검사"(본문에
# <img ...> 태그가 있는데 alt 속성이 전혀 없으면 FAIL) 로직이 실제로
# 동작하는지 확인하는 회귀 테스트다.
#
#   배경: design/style-guide.md 8번(접근성)은 2026-10-12부터 <img> 태그의
#   alt 속성 규칙(로고/장식용, 정보성 차트, 중복 표현 금지 등)을 상세히
#   정의하고 있었지만, validate_posts.sh에는 이를 강제하는 검사가 전혀
#   없었다. posts/에 이미지가 들어간 글이 아직 없더라도, date 필드 검사를
#   문제가 실제로 터지기 전에 미리 추가했던 것과 같은 이유로 이 공백을
#   미리 막기 위해 검사를 추가했다(2026-10-18 마스터 지시). 이 테스트는
#   scripts/test_required_date_field.sh, scripts/test_duplicate_slug.sh와
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
#   1) [alt 없음 케이스] 본문에 <img src="...">처럼 alt 속성이 전혀 없는
#      <img> 태그가 있는 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)이고
#      출력에 "alt 속성이 없습니다" 메시지가 포함되는지 확인한다.
#   2) [alt 있음 케이스] 본문에 alt="..."(내용 있음)와 alt=""(빈 문자열,
#      순수 장식용 이미지의 정상 패턴) 두 가지 <img> 태그가 모두 있는 글
#      하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을
#      때, exit code가 0(PASS)이고 alt 관련 FAIL 메시지가 출력되지
#      않는지 확인한다.
#   3) [img 태그 없음 케이스] <img> 태그가 전혀 없는, 기존과 동일한 정상
#      글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 0(PASS)인지 확인한다(회귀 방지 — 이미지가
#      없는 글은 이 검사로 FAIL 처리되지 않아야 한다).
#   4) [data-alt만 있는 케이스 — 2026-10-19 회귀 방지] 실제 alt 속성은
#      없고 "alt="로 끝나는 다른 속성(data-alt="...")만 있는 <img> 태그가
#      있는 글 하나를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 1(FAIL)이고 출력에 "alt 속성이 없습니다"
#      메시지가 포함되는지 확인한다. 이전에는 grep -qi 'alt='가 단순 부분
#      문자열 검사라 data-alt="..."의 "alt="까지 매치해 "alt 속성이
#      있다"고 잘못 판단(false positive)하는 회귀가 있었다(마스터가
#      `echo '<img src="x.jpg" data-alt="ignored">' | grep -qi 'alt='`로
#      직접 재현).
#
# 사용법:
#   bash scripts/test_img_alt_required.sh
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

echo "=== 검사 1: <img> 태그가 있는데 alt 속성이 전혀 없는 글 -> FAIL 이어야 함 ==="
NO_ALT_FILE="2026-01-01-no-alt-regression-test.md"
NO_ALT_CONTENT='---
title: "img alt 필수 검사 회귀 테스트용 임시 글(alt 없음)"
meta_description: "본문에 alt 속성이 없는 img 태그가 있는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_img_alt_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

<img src="/assets/charts/example.png">

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_alt_result="$(run_validate_with_post "${NO_ALT_FILE}" "${NO_ALT_CONTENT}")"
no_alt_status="$(echo "${no_alt_result}" | head -n 1)"
no_alt_output="$(echo "${no_alt_result}" | tail -n +2)"

echo "${no_alt_output}"
echo "(실행 exit code: ${no_alt_status})"

if [ "${no_alt_status}" -ne 1 ]; then
  echo "[FAIL] alt 속성이 없는 img 태그가 있는 경우 exit code가 1이 아니었습니다 (실제: ${no_alt_status})."
  failures+=("alt 없음 케이스 exit code != 1")
else
  echo "[PASS] alt 속성이 없는 img 태그가 있는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${no_alt_output}" | grep -qF "alt 속성이 없습니다"; then
  echo "[PASS] 출력에 \"alt 속성이 없습니다\" 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"alt 속성이 없습니다\" 메시지가 없습니다."
  failures+=("alt 속성 누락 메시지 누락")
fi

echo ""
echo "=== 검사 2: alt 속성이 있는 img 태그(내용 있음 + alt=\"\" 빈 문자열) -> PASS 이어야 함 ==="
WITH_ALT_FILE="2026-01-01-with-alt-regression-test.md"
WITH_ALT_CONTENT='---
title: "img alt 필수 검사 회귀 테스트용 정상 글(alt 있음)"
meta_description: "본문에 alt 속성이 있는 img 태그가 있는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_img_alt_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

<img src="/assets/charts/example.png" alt="2020~2026년 기준금리 변동 추이, 2026년 3.5%로 상승">

<img src="/assets/logo-mark.svg" alt="">

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

with_alt_result="$(run_validate_with_post "${WITH_ALT_FILE}" "${WITH_ALT_CONTENT}")"
with_alt_status="$(echo "${with_alt_result}" | head -n 1)"
with_alt_output="$(echo "${with_alt_result}" | tail -n +2)"

echo "${with_alt_output}"
echo "(실행 exit code: ${with_alt_status})"

if [ "${with_alt_status}" -ne 0 ]; then
  echo "[FAIL] alt 속성이 있는 img 태그만 있는 경우 exit code가 0이 아니었습니다 (실제: ${with_alt_status})."
  failures+=("alt 있음 케이스 exit code != 0")
else
  echo "[PASS] alt 속성이 있는 img 태그만 있는 경우 exit code가 0(PASS)입니다."
fi

if echo "${with_alt_output}" | grep -qF "alt 속성이 없습니다"; then
  echo "[FAIL] 정상 케이스인데 alt 속성 누락 메시지가 출력되었습니다."
  failures+=("정상 케이스에서 alt 속성 누락 오탐")
else
  echo "[PASS] 정상 케이스에서는 alt 속성 누락 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 3: <img> 태그가 전혀 없는 글 -> PASS 이어야 함 (회귀 방지) ==="
NO_IMG_FILE="2026-01-01-no-img-regression-test.md"
NO_IMG_CONTENT='---
title: "img alt 필수 검사 회귀 테스트용 정상 글(img 태그 없음)"
meta_description: "본문에 img 태그가 전혀 없는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_img_alt_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다. 이 글에는 img 태그가 전혀
없으므로 alt 속성 검사와 무관하게 통과해야 합니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

no_img_result="$(run_validate_with_post "${NO_IMG_FILE}" "${NO_IMG_CONTENT}")"
no_img_status="$(echo "${no_img_result}" | head -n 1)"
no_img_output="$(echo "${no_img_result}" | tail -n +2)"

echo "${no_img_output}"
echo "(실행 exit code: ${no_img_status})"

if [ "${no_img_status}" -ne 0 ]; then
  echo "[FAIL] img 태그가 전혀 없는 글인데 exit code가 0이 아니었습니다 (실제: ${no_img_status})."
  failures+=("img 태그 없음 케이스 exit code != 0")
else
  echo "[PASS] img 태그가 전혀 없는 글은 exit code가 0(PASS)입니다."
fi

if echo "${no_img_output}" | grep -qF "alt 속성이 없습니다"; then
  echo "[FAIL] img 태그가 없는 글인데 alt 속성 누락 메시지가 출력되었습니다."
  failures+=("img 태그 없음 케이스에서 alt 속성 누락 오탐")
else
  echo "[PASS] img 태그가 없는 글에서는 alt 속성 누락 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 4: 실제 alt 속성 없이 data-alt=\"...\"만 있는 img 태그 -> FAIL 이어야 함 (2026-10-19 회귀 방지) ==="
DATA_ALT_FILE="2026-01-01-data-alt-only-regression-test.md"
DATA_ALT_CONTENT='---
title: "img alt 필수 검사 회귀 테스트용 임시 글(data-alt만 있음)"
meta_description: "본문에 실제 alt 속성 없이 data-alt 속성만 있는 img 태그가 있는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_img_alt_required.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다. 이 img 태그는 실제 alt 속성이
없고 "alt="로 끝나는 data-alt 속성만 가지고 있어, 과거에는 단순 부분
문자열 검사(grep -qi "alt=")가 이를 "alt 속성이 있다"고 잘못 판단했다.

<img src="x.jpg" data-alt="ignored">

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
'

data_alt_result="$(run_validate_with_post "${DATA_ALT_FILE}" "${DATA_ALT_CONTENT}")"
data_alt_status="$(echo "${data_alt_result}" | head -n 1)"
data_alt_output="$(echo "${data_alt_result}" | tail -n +2)"

echo "${data_alt_output}"
echo "(실행 exit code: ${data_alt_status})"

if [ "${data_alt_status}" -ne 1 ]; then
  echo "[FAIL] data-alt 속성만 있고 실제 alt 속성이 없는 img 태그가 있는 경우 exit code가 1이 아니었습니다 (실제: ${data_alt_status})."
  failures+=("data-alt만 있는 케이스 exit code != 1")
else
  echo "[PASS] data-alt 속성만 있고 실제 alt 속성이 없는 img 태그가 있는 경우 exit code가 1(FAIL)입니다."
fi

if echo "${data_alt_output}" | grep -qF "alt 속성이 없습니다"; then
  echo "[PASS] 출력에 \"alt 속성이 없습니다\" 메시지가 포함되어 있습니다(= data-alt를 실제 alt로 오탐하지 않음)."
else
  echo "[FAIL] 출력에 \"alt 속성이 없습니다\" 메시지가 없습니다(= data-alt를 실제 alt로 잘못 인정하는 회귀가 재발했을 수 있습니다)."
  failures+=("data-alt만 있는 케이스에서 alt 속성 누락 메시지 누락 (false positive 회귀)")
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
