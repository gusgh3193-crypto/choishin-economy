#!/usr/bin/env bash
#
# test_sitemap_dash_title.sh
#
# scripts/generate_sitemap.sh에는 글 frontmatter의 title에 XML 주석에서
# 금지된 "--" 시퀀스가 포함되어 있으면(well-formed XML을 깨뜨리므로) 해당
# 글의 XML 주석(<!-- ... -->) 생성 자체를 건너뛰는 안전장치가 이미 코드로
# 존재한다(생성 스크립트의 `if [[ "${escaped_title}" != *"--"* ]]` 부분).
#
#   배경: 이 안전장치는 코드로는 있지만 지금까지 실제로 실행해 검증한
#   회귀 테스트가 저장소에 전혀 없었다(2026-10-15 마스터 지시). 이 테스트는
#   scripts/test_color_palette.sh, scripts/test_split_keywords.sh와 같은
#   "자동 실행 → PASS/FAIL 출력 → exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/generate_sitemap.sh
#   사본과 posts/, seo/ 구조를 흉내 낸 임시 환경을 통째로 구성해 그
#   사본을 실행한다(generate_sitemap.sh는 자기 자신의 위치를 기준으로
#   REPO_ROOT/POSTS_DIR/SEO_DIR을 계산하므로, 사본을 임시 디렉터리 안
#   scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만 동작한다).
#
# 검사 내용:
#   1) "--"가 포함된 title을 가진 임시 글 하나를 임시 posts/ 안에 만들고
#      scripts/generate_sitemap.sh(사본)를 실행한다.
#   2) 생성된 sitemap.xml에 그 글의 <url><loc>이 정상적으로 포함되어
#      있는지 확인한다.
#   3) 생성된 sitemap.xml 안에 그 글의 title에서 비롯된 XML 주석이
#      생성되지 않았는지(즉 "--"가 포함된 주석이 출력에 없는지) 확인한다.
#      (sitemap.xml 상단의 고정 안내 주석 2개는 이 글과 무관하므로 항상
#      남아 있는 것이 정상이며, 그 2개를 넘는 추가 주석이 없는지를 본다.)
#
# 사용법:
#   bash scripts/test_sitemap_dash_title.sh
#
# exit code:
#   0 - 모든 검사를 통과함
#   1 - 하나 이상의 검사에서 실패함 (실패 내용을 함께 출력)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITEMAP_SCRIPT="${SCRIPT_DIR}/generate_sitemap.sh"

failures=()

if [ ! -f "${SITEMAP_SCRIPT}" ]; then
  echo "오류: ${SITEMAP_SCRIPT} 파일을 찾을 수 없습니다."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TMP_DIR}/scripts" "${TMP_DIR}/posts" "${TMP_DIR}/seo"

# generate_sitemap.sh 사본을 임시 디렉터리 안 scripts/ 밑에 둔다.
# (이 스크립트는 자기 자신의 위치를 기준으로 REPO_ROOT를 계산하므로,
#  사본을 이 위치에 두고 실행하면 posts/도 TMP_DIR/posts, seo/도
#  TMP_DIR/seo를 바라보게 된다. 실제 저장소의 posts/, seo/는 전혀
#  건드리지 않는다.)
cp "${SITEMAP_SCRIPT}" "${TMP_DIR}/scripts/generate_sitemap.sh"

TEST_SLUG="dash-title-regression-test"
TEST_POST_FILE="${TMP_DIR}/posts/2026-01-01-${TEST_SLUG}.md"
TEST_TITLE="테스트 제목 -- 대시 포함"

cat > "${TEST_POST_FILE}" <<EOF
---
title: "${TEST_TITLE}"
meta_description: "sitemap '--' 제목 회귀 테스트용 임시 글"
keywords: "테스트"
date: 2026-01-01
---

이 글은 scripts/test_sitemap_dash_title.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.
EOF

echo "=== 임시 환경에서 generate_sitemap.sh(사본) 실행 ==="
run_output="$(bash "${TMP_DIR}/scripts/generate_sitemap.sh" 2>&1)"
run_status=$?
echo "${run_output}"

if [ ${run_status} -ne 0 ]; then
  echo "[FAIL] generate_sitemap.sh(사본) 실행이 실패했습니다 (exit ${run_status})."
  failures+=("generate_sitemap.sh 실행 실패")
fi

SITEMAP_FILE="${TMP_DIR}/seo/sitemap.xml"

echo ""
echo "=== 검사 1: 임시 글의 <url><loc>이 sitemap.xml에 포함되는지 확인 ==="
if [ ! -f "${SITEMAP_FILE}" ]; then
  echo "[FAIL] ${SITEMAP_FILE} 파일이 생성되지 않았습니다."
  failures+=("sitemap.xml 미생성")
else
  if grep -qF "<loc>https://example.com/posts/${TEST_SLUG}</loc>" "${SITEMAP_FILE}"; then
    echo "[PASS] <loc>https://example.com/posts/${TEST_SLUG}</loc> 항목이 존재합니다."
  else
    echo "[FAIL] <loc>https://example.com/posts/${TEST_SLUG}</loc> 항목을 찾지 못했습니다."
    failures+=("임시 글의 <url><loc> 누락")
  fi
fi

echo ""
echo "=== 검사 2: '--'가 포함된 title의 XML 주석이 생략되었는지 확인 ==="
if [ -f "${SITEMAP_FILE}" ]; then
  # sitemap.xml 상단에는 항상 고정 안내 주석 2개
  # (초안/TODO 안내)가 있다. 이 글 때문에 추가 주석이 생기지 않았다면
  # 전체 <!-- 로 시작하는 줄 수는 정확히 2개여야 한다.
  comment_count="$(grep -c '<!--' "${SITEMAP_FILE}")"

  if [ "${comment_count}" -eq 2 ]; then
    echo "[PASS] 고정 안내 주석 2개 외에 추가 주석(이 글의 title 주석)이 생성되지 않았습니다."
  else
    echo "[FAIL] 예상치 못한 주석 개수입니다 (기대: 2, 실제: ${comment_count})."
    echo "        sitemap.xml의 전체 주석 줄:"
    grep -n '<!--' "${SITEMAP_FILE}" | sed 's/^/          /'
    failures+=("예상치 못한 주석 개수(기대 2, 실제 ${comment_count})")
  fi

  # 추가 방어: "--"가 포함된 임시 제목 자체가 주석으로라도 출력에 나타나면 안 된다.
  if grep -qF "테스트 제목" "${SITEMAP_FILE}"; then
    echo "[FAIL] sitemap.xml에 임시 글의 title 문자열이 (아마도 주석으로) 그대로 노출되어 있습니다."
    failures+=("'--' 포함 title이 출력에 노출됨")
  else
    echo "[PASS] sitemap.xml에 임시 글의 title 문자열이 노출되지 않았습니다."
  fi
else
  echo "[FAIL] ${SITEMAP_FILE} 파일이 없어 주석 생략 여부를 확인할 수 없습니다."
  failures+=("sitemap.xml 미생성으로 주석 검사 불가")
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
