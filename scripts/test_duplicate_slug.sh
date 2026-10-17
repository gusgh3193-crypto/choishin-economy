#!/usr/bin/env bash
#
# test_duplicate_slug.sh
#
# scripts/validate_posts.sh에 추가된 "슬러그 중복 검사"(파일명 YYYY-MM-DD-슬러그.md에서
# 날짜 접두어를 뗀 나머지 슬러그가 같은 파일이 2개 이상이면 FAIL) 로직이
# 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: scripts/generate_sitemap.sh와 scripts/generate_jsonld.sh는 최종
#   공개 URL(${BASE_URL}/posts/${슬러그})과 JSON-LD 출력 파일명
#   (seo/jsonld/${슬러그}.json)에 날짜를 전혀 포함하지 않고 슬러그만 쓴다.
#   따라서 서로 다른 날짜의 두 글이 같은 슬러그를 쓰면 같은 URL로 충돌하거나
#   한쪽의 JSON-LD 파일이 조용히 덮어써진다. 이 공백을 막기 위해
#   validate_posts.sh에 슬러그 중복 검사를 추가했고(2026-10-16 마스터 지시),
#   이 테스트는 scripts/test_sitemap_dash_title.sh와 같은 "자동 실행 →
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
#   1) [중복 케이스] 같은 슬러그(interest-rate-impact)를 쓰지만 날짜가 다른
#      글 2개(2026-09-13-interest-rate-impact.md, 2026-10-20-interest-rate-impact.md)를
#      임시 posts/ 안에 만들고 validate_posts.sh(사본)를 실행했을 때,
#      exit code가 1(FAIL)이고 출력에 "슬러그 중복"과 두 파일명이 모두
#      포함되는지 확인한다.
#   2) [정상 케이스] 슬러그가 서로 다른 글 2개(frontmatter/면책 문구 등 다른
#      규칙도 모두 만족)를 임시 posts/ 안에 만들고 validate_posts.sh(사본)를
#      실행했을 때, exit code가 0(PASS)인지 확인한다.
#
# 사용법:
#   bash scripts/test_duplicate_slug.sh
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

# 정상 케이스에서 frontmatter/면책 문구 규칙을 모두 만족시키기 위한
# 공통 본문 조각.
# date는 파일명(YYYY-MM-DD-슬러그.md)의 날짜 부분을 그대로 사용해 frontmatter에
# 넣는다. validate_posts.sh에 date 필드 필수 검사(REQUIRED_FIELDS에 date 추가,
# 2026-10-17 마스터 지시)가 추가되면서 date 필드가 없던 이 fixture가 "정상
# 케이스"인데도 FAIL로 오판되는 문제가 생겨, 그 공백만 메우기 위해 추가함
# (슬러그 중복 검출이라는 이 테스트 본래 목적과는 무관).
make_valid_post() {
  local filepath="$1"
  local title="$2"
  local filename file_date
  filename="$(basename "${filepath}")"
  file_date="${filename:0:10}"
  cat > "${filepath}" <<EOF
---
title: "${title}"
meta_description: "슬러그 중복 회귀 테스트용 임시 글입니다"
keywords: ["테스트"]
date: ${file_date}
---

이 글은 scripts/test_duplicate_slug.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.

*이 글은 투자 판단에 대한 책임을 지지 않는 테스트용 면책 문구입니다.*
EOF
}

run_validate_in_temp() {
  # 첫 번째 인자: 임시 posts/ 디렉터리에 만들 파일명들(공백 구분, 뒤의
  #              인자로 넘어오는 값들을 title로 사용해 make_valid_post로 생성)
  # 사용 패턴: run_validate_in_temp "파일명1:title1" "파일명2:title2" ...
  local tmp_dir
  tmp_dir="$(mktemp -d)"

  mkdir -p "${tmp_dir}/scripts" "${tmp_dir}/posts"
  cp "${VALIDATE_SCRIPT}" "${tmp_dir}/scripts/validate_posts.sh"

  local entry filename title
  for entry in "$@"; do
    filename="${entry%%:*}"
    title="${entry#*:}"
    make_valid_post "${tmp_dir}/posts/${filename}" "${title}"
  done

  local output status
  output="$(bash "${tmp_dir}/scripts/validate_posts.sh" 2>&1)"
  status=$?

  rm -rf "${tmp_dir}"

  printf '%s\n' "${status}"
  printf '%s\n' "${output}"
}

echo "=== 검사 1: 같은 슬러그·다른 날짜의 글 2개 -> FAIL 이어야 함 ==="
DUP_FILE_A="2026-09-13-interest-rate-impact.md"
DUP_FILE_B="2026-10-20-interest-rate-impact.md"

dup_result="$(run_validate_in_temp \
  "${DUP_FILE_A}:금리 인상의 영향 (9월)" \
  "${DUP_FILE_B}:금리 인상의 영향 (10월)")"
dup_status="$(echo "${dup_result}" | head -n 1)"
dup_output="$(echo "${dup_result}" | tail -n +2)"

echo "${dup_output}"
echo "(실행 exit code: ${dup_status})"

if [ "${dup_status}" -ne 1 ]; then
  echo "[FAIL] 슬러그가 중복된 경우 exit code가 1이 아니었습니다 (실제: ${dup_status})."
  failures+=("중복 케이스 exit code != 1")
else
  echo "[PASS] 슬러그가 중복된 경우 exit code가 1(FAIL)입니다."
fi

if echo "${dup_output}" | grep -q "슬러그 중복"; then
  echo "[PASS] 출력에 '슬러그 중복' 메시지가 포함되어 있습니다."
else
  echo "[FAIL] 출력에 '슬러그 중복' 메시지가 없습니다."
  failures+=("'슬러그 중복' 메시지 누락")
fi

if echo "${dup_output}" | grep -qF "${DUP_FILE_A}" && echo "${dup_output}" | grep -qF "${DUP_FILE_B}"; then
  echo "[PASS] 충돌하는 두 파일명(${DUP_FILE_A}, ${DUP_FILE_B})이 모두 출력에 포함되어 있습니다."
else
  echo "[FAIL] 충돌하는 두 파일명이 출력에 모두 포함되어 있지 않습니다."
  failures+=("충돌 파일명 출력 누락")
fi

echo ""
echo "=== 검사 2: 슬러그가 서로 다른 정상 글 2개 -> PASS 이어야 함 ==="
NORMAL_FILE_A="2026-09-13-interest-rate-impact.md"
NORMAL_FILE_B="2026-10-20-housing-market-outlook.md"

normal_result="$(run_validate_in_temp \
  "${NORMAL_FILE_A}:금리 인상의 영향" \
  "${NORMAL_FILE_B}:주택 시장 전망")"
normal_status="$(echo "${normal_result}" | head -n 1)"
normal_output="$(echo "${normal_result}" | tail -n +2)"

echo "${normal_output}"
echo "(실행 exit code: ${normal_status})"

if [ "${normal_status}" -ne 0 ]; then
  echo "[FAIL] 슬러그가 중복되지 않은 정상 케이스인데 exit code가 0이 아니었습니다 (실제: ${normal_status})."
  failures+=("정상 케이스 exit code != 0")
else
  echo "[PASS] 슬러그가 중복되지 않은 정상 케이스는 exit code가 0(PASS)입니다."
fi

if echo "${normal_output}" | grep -q "슬러그 중복"; then
  echo "[FAIL] 정상 케이스인데 '슬러그 중복' 메시지가 출력되었습니다."
  failures+=("정상 케이스에서 '슬러그 중복' 오탐")
else
  echo "[PASS] 정상 케이스에서는 '슬러그 중복' 메시지가 출력되지 않았습니다."
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
