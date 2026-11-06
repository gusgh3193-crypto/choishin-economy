#!/usr/bin/env bash
#
# test_filename_format.sh
#
# scripts/validate_posts.sh의 "1) 파일명 형식 검사" 로직(126~129행 부근,
# FILENAME_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$'로 파일명이
# YYYY-MM-DD-슬러그.md 형식인지만 보는 검사)이 실제로 동작하는지 확인하는
# 회귀 테스트다.
#
#   배경: 이 검사(1번)는 "3-2) frontmatter의 date 필드가 파일명의 날짜와
#   일치하는지 검사"(scripts/test_date_filename_mismatch.sh가 다룬다)와는
#   별개다. 1번은 파일명 문자열 자체가 정규식 구조에 맞는지만 보고, date
#   필드 값과는 무관하다. 그런데 기존 scripts/test_*.sh 목록(2026-11-06
#   확인 시점 기준 test_category_article_section.sh, test_category_empty_field.sh,
#   test_color_palette.sh, test_date_filename_mismatch.sh,
#   test_disclaimer_required.sh, test_duplicate_slug.sh,
#   test_img_alt_required.sh, test_keywords_empty_array.sh,
#   test_keywords_unquoted_items.sh, test_meta_length.sh,
#   test_required_date_field.sh, test_required_title_meta_keywords_field.sh,
#   test_sitemap_dash_title.sh, test_split_keywords.sh,
#   test_title_meta_empty_quoted.sh) 중 1번 검사(파일명 형식 자체) 자체를
#   전용으로 검증하는 회귀 테스트는 없었다. 과거 2026-10-31(3-2 공백),
#   2026-11-04(3-3 공백), 2026-11-05(3-5 공백)와 같은 유형의 공백을 메우기
#   위해 2026-11-06 마스터 지시로 추가했다. 이 테스트는
#   scripts/test_date_filename_mismatch.sh, scripts/test_required_date_field.sh와
#   같은 "임시 디렉터리에 validate_posts.sh 사본과 임시 posts/ 구조를 만들어
#   그 사본을 실행 → PASS/FAIL 출력 → exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/validate_posts.sh 사본과
#   임시 posts/ 구조를 통째로 구성해 그 사본을 실행한다.
#
#   주의(2026-11-06 확인): FILENAME_REGEX는 연-월-일 각 자리의 "글자 수와
#   구분자(-) 구조"만 검사하고, 실제 달력상 유효한 날짜인지는 검사하지
#   않는다. 예를 들어 "2026-13-45-test-slug.md"(13월, 45일처럼 달력상
#   존재하지 않는 값)는 자리수/구분자 구조가 정규식과 맞으므로 이 검사에서는
#   PASS로 처리된다(직접 bash [[ =~ ]]로 재현 확인). 따라서 이 테스트는
#   "날짜 부분이 틀린 형식"의 예로 자리수/구분자 구조 자체가 깨진 경우
#   (대시 없이 숫자가 붙어있는 경우, 월/일이 한 자리 숫자인 경우)를 사용한다.
#
# 검사 내용:
#   1) [정상 형식 케이스] "2026-11-06-test-slug.md"처럼 YYYY-MM-DD-슬러그.md
#      형식을 정확히 따르는 글 하나를 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 0(PASS)이고
#      "파일명이 YYYY-MM-DD-슬러그.md 형식이 아닙니다" 메시지가 출력되지
#      않는지 확인한다.
#   2) [날짜 부분 구조가 깨진 케이스] "20261106-test-slug.md"(연-월-일 사이에
#      대시가 전혀 없음)와 "2026-1-6-test-slug.md"(월/일이 한 자리 숫자라
#      {2} 자리수 요구를 어김) 두 글을 각각 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때, exit code가 1(FAIL)이고
#      "파일명이 YYYY-MM-DD-슬러그.md 형식이 아닙니다" 메시지가 해당 파일명과
#      함께 출력되는지 확인한다.
#   3) [슬러그 없음 케이스] "2026-11-06-.md"(대시 뒤에 슬러그가 전혀 없음)
#      글을 임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때,
#      exit code가 1(FAIL)이고 "파일명이 YYYY-MM-DD-슬러그.md 형식이
#      아닙니다" 메시지가 해당 파일명과 함께 출력되는지 확인한다.
#   4) [확장자 불일치 케이스, 2026-11-06 확인된 별도 공백] "2026-11-06-test-slug.txt"
#      (확장자가 .md가 아님) 글 하나만 임시 posts/ 안에 만들고
#      validate_posts.sh(사본)를 실행했을 때 실제로 어떻게 처리되는지 확인한다.
#      직접 실행해 재현한 결과, validate_posts.sh 77~78행의
#      post_files=("${POSTS_DIR}"/*.md) 글롭(glob) 자체가 ".md로 끝나지 않는
#      파일"을 배열에 담기도 전에 걸러내므로, 이런 파일은 1번 검사(FILENAME_REGEX)
#      루프에 도달하지 못하고 "검사할 .md 파일이 없습니다" 경고만 내며 exit
#      code 0(PASS)으로 끝난다. 즉 "확장자가 .md가 아니면 FAIL 메시지가
#      뜬다"는 기대는 현재 코드에서는 성립하지 않는다(글롭 단계에서 조용히
#      무시됨). 이 테스트는 FAIL을 기대하지 않고, 이 "조용히 무시되는" 실제
#      동작 자체를 고정해 회귀를 감지하는 용도로만 둔다(이 공백 자체를
#      메우는 것은 오늘 작업 범위가 아니므로 validate_posts.sh는 수정하지
#      않고, 마스터에게 별도로 보고한다).
#
# 사용법:
#   bash scripts/test_filename_format.sh
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

# 면책 문구/기타 필드는 모두 정상으로 채워 넣어서, 이 검사 외의 다른 검사
# (3-3, 4, 5 등)가 오탐으로 섞여 들어오지 않게 한다. frontmatter의 date
# 필드는 "2026-11-06"으로 고정한다(이 스크립트가 쓰는 정상 케이스 파일명의
# 날짜 접두어와 동일한 값). 처음에는 파일명과 무관한 임의의 날짜("2026-01-01")를
# 썼으나, 실제로 실행해보니 정상 케이스 파일명(2026-11-06-test-slug.md)에서
# frontmatter date(2026-01-01)가 파일명 날짜(2026-11-06)와 달라 3-2 검사가
# 별도의 FAIL("frontmatter의 date가 파일명의 날짜와 다릅니다")을 추가해버려
# exit code가 1이 되는 오염이 발견되었다. 이를 막기 위해 날짜를 "2026-11-06"으로
# 맞춘다. 날짜 구조 자체가 깨진 파일명(20261106-..., 2026-1-6-...)은 3-2의
# 파일명 날짜 추출 정규식과도 애초에 매칭되지 않으므로 이 고정값이 영향을
# 주지 않는다(직접 실행해 확인함).
make_content() {
  cat <<'EOF'
---
title: "파일명 형식 회귀 테스트용 글"
meta_description: "scripts/test_filename_format.sh가 만든 임시 테스트용 글입니다"
keywords: ["테스트"]
date: "2026-11-06"
---

이 글은 scripts/test_filename_format.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
EOF
}

run_validate_with_post() {
  # 인자: 임시 posts/ 안에 만들 파일명
  local filename="$1"
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  mkdir -p "${tmp_dir}/scripts" "${tmp_dir}/posts"
  cp "${VALIDATE_SCRIPT}" "${tmp_dir}/scripts/validate_posts.sh"
  make_content > "${tmp_dir}/posts/${filename}"

  local output status
  output="$(bash "${tmp_dir}/scripts/validate_posts.sh" 2>&1)"
  status=$?

  rm -rf "${tmp_dir}"

  printf '%s\n' "${status}"
  printf '%s\n' "${output}"
}

FILENAME_FAIL_MESSAGE="파일명이 YYYY-MM-DD-슬러그.md 형식이 아닙니다"

echo "=== 검사 1: 정상 형식(YYYY-MM-DD-슬러그.md) -> PASS 이어야 함 ==="
NORMAL_FILE="2026-11-06-test-slug.md"
normal_result="$(run_validate_with_post "${NORMAL_FILE}")"
normal_status="$(echo "${normal_result}" | head -n 1)"
normal_output="$(echo "${normal_result}" | tail -n +2)"

echo "${normal_output}"
echo "(실행 exit code: ${normal_status})"

if [ "${normal_status}" -ne 0 ]; then
  echo "[FAIL] 정상 형식 파일명인데 exit code가 0이 아니었습니다 (실제: ${normal_status})."
  failures+=("정상 형식 케이스(${NORMAL_FILE}) exit code != 0")
else
  echo "[PASS] 정상 형식 파일명은 exit code가 0(PASS)입니다."
fi

if echo "${normal_output}" | grep -qF "${FILENAME_FAIL_MESSAGE}"; then
  echo "[FAIL] 정상 형식 파일명인데 \"${FILENAME_FAIL_MESSAGE}\" 메시지가 출력되었습니다."
  failures+=("정상 형식 케이스(${NORMAL_FILE})에서 파일명 형식 FAIL 오탐")
else
  echo "[PASS] 정상 형식 파일명에서는 \"${FILENAME_FAIL_MESSAGE}\" 메시지가 출력되지 않았습니다."
fi

echo ""
echo "=== 검사 2: 날짜 부분의 자리수/구분자 구조가 깨진 파일명 -> FAIL 이어야 함 ==="
BROKEN_DATE_FILES=(
  "20261106-test-slug.md"
  "2026-1-6-test-slug.md"
)

for broken_file in "${BROKEN_DATE_FILES[@]}"; do
  echo "--- 파일명: ${broken_file} ---"
  broken_result="$(run_validate_with_post "${broken_file}")"
  broken_status="$(echo "${broken_result}" | head -n 1)"
  broken_output="$(echo "${broken_result}" | tail -n +2)"

  echo "${broken_output}"
  echo "(실행 exit code: ${broken_status})"

  if [ "${broken_status}" -ne 1 ]; then
    echo "[FAIL] 날짜 구조가 깨진 파일명(${broken_file})인데 exit code가 1이 아니었습니다 (실제: ${broken_status})."
    failures+=("날짜 구조 깨짐 케이스(${broken_file}) exit code != 1")
  else
    echo "[PASS] 날짜 구조가 깨진 파일명(${broken_file})은 exit code가 1(FAIL)입니다."
  fi

  if echo "${broken_output}" | grep -qF "${FILENAME_FAIL_MESSAGE}" && echo "${broken_output}" | grep -qF "${broken_file}"; then
    echo "[PASS] 출력에 \"${FILENAME_FAIL_MESSAGE}\" 메시지와 해당 파일명(${broken_file})이 함께 포함되어 있습니다."
  else
    echo "[FAIL] 출력에 \"${FILENAME_FAIL_MESSAGE}\" 메시지 또는 파일명(${broken_file})이 없습니다."
    failures+=("날짜 구조 깨짐 케이스(${broken_file}) 메시지 누락")
  fi
  echo ""
done

echo "=== 검사 3: 슬러그 없음(대시 뒤에 글자가 전혀 없는 파일명) -> FAIL 이어야 함 ==="
SLUGLESS_FILE="2026-11-06-.md"
slugless_result="$(run_validate_with_post "${SLUGLESS_FILE}")"
slugless_status="$(echo "${slugless_result}" | head -n 1)"
slugless_output="$(echo "${slugless_result}" | tail -n +2)"

echo "${slugless_output}"
echo "(실행 exit code: ${slugless_status})"

if [ "${slugless_status}" -ne 1 ]; then
  echo "[FAIL] 슬러그가 없는 파일명(${SLUGLESS_FILE})인데 exit code가 1이 아니었습니다 (실제: ${slugless_status})."
  failures+=("슬러그 없음 케이스(${SLUGLESS_FILE}) exit code != 1")
else
  echo "[PASS] 슬러그가 없는 파일명(${SLUGLESS_FILE})은 exit code가 1(FAIL)입니다."
fi

if echo "${slugless_output}" | grep -qF "${FILENAME_FAIL_MESSAGE}" && echo "${slugless_output}" | grep -qF "${SLUGLESS_FILE}"; then
  echo "[PASS] 출력에 \"${FILENAME_FAIL_MESSAGE}\" 메시지와 해당 파일명(${SLUGLESS_FILE})이 함께 포함되어 있습니다."
else
  echo "[FAIL] 출력에 \"${FILENAME_FAIL_MESSAGE}\" 메시지 또는 파일명(${SLUGLESS_FILE})이 없습니다."
  failures+=("슬러그 없음 케이스(${SLUGLESS_FILE}) 메시지 누락")
fi

echo ""
echo "=== 검사 4(정보성, FAIL 집계에 포함하지 않음): 확장자가 .md가 아닌 파일명의 실제 처리 방식 확인 ==="
echo "    (2026-11-06 확인된 별도 공백: posts/*.md 글롭이 먼저 걸러내 1번 검사 루프에 도달하지 못하고,"
echo "     '검사할 .md 파일이 없습니다' 경고만 내며 exit 0으로 끝난다. 이 동작을 고정해서 기록만 해둔다.)"
EXT_MISMATCH_FILE="2026-11-06-test-slug.txt"
ext_mismatch_result="$(run_validate_with_post "${EXT_MISMATCH_FILE}")"
ext_mismatch_status="$(echo "${ext_mismatch_result}" | head -n 1)"
ext_mismatch_output="$(echo "${ext_mismatch_result}" | tail -n +2)"

echo "${ext_mismatch_output}"
echo "(실행 exit code: ${ext_mismatch_status})"

if [ "${ext_mismatch_status}" -eq 0 ] && echo "${ext_mismatch_output}" | grep -qF "검사할 .md 파일이 없습니다"; then
  echo "[INFO] 예상대로 글롭 단계에서 조용히 무시되어 exit code 0, \"검사할 .md 파일이 없습니다\" 경고만 출력되었습니다."
  echo "[INFO] 참고: 이는 1번 검사(FILENAME_REGEX) 자체가 '통과'한 것이 아니라, 이 파일이 검사 대상에서"
  echo "       애초에 제외된 것입니다. 확장자 불일치를 FAIL로 잡는 전용 검사는 현재 없습니다(별도 보고 대상)."
else
  echo "[FAIL] 확장자 불일치 파일(${EXT_MISMATCH_FILE})의 실제 처리 방식이 기존에 확인한 동작과 달라졌습니다."
  echo "       (exit code: ${ext_mismatch_status}, 출력에 '검사할 .md 파일이 없습니다' 포함 여부도 확인하세요.)"
  failures+=("확장자 불일치 케이스(${EXT_MISMATCH_FILE})의 실제 동작이 기록된 것과 다름(validate_posts.sh 변경 여부 확인 필요)")
fi

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
