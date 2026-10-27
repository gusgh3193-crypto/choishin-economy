#!/usr/bin/env bash
#
# test_category_article_section.sh
#
# scripts/generate_jsonld.sh에 추가된 "category → articleSection" 매핑
# 로직이 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: posts/의 frontmatter에는 category 필드가 있지만(블로그 글 작성
#   담당이 성실히 채우고 있음), generate_jsonld.sh/validate_posts.sh/
#   generate_sitemap.sh 어디에서도 이 값을 쓰지 않아 죽은 필드였다.
#   schema.org BlogPosting의 articleSection 속성이 이 분류값에 대응하므로,
#   category가 있으면 articleSection으로 반영하고, 없으면 필드 자체를
#   생성하지 않도록(빈 문자열로 채우지 않도록) 구현했다(2026-10-24
#   마스터 지시). 이 테스트는 scripts/test_required_date_field.sh,
#   scripts/test_sitemap_dash_title.sh와 같은 "자동 실행 → PASS/FAIL 출력 →
#   exit code" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/generate_jsonld.sh 사본과
#   posts/, seo/ 구조를 흉내 낸 임시 환경을 통째로 구성해 그 사본을
#   실행한다(generate_jsonld.sh는 자기 자신의 위치를 기준으로
#   REPO_ROOT/POSTS_DIR/SEO_DIR을 계산하므로, 사본을 임시 디렉터리 안
#   scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만 동작한다).
#
# 검사 내용:
#   1) [category 있음 케이스] frontmatter에 category: "경제"가 있는 글의
#      JSON-LD 출력에 "articleSection": "경제"가 포함되는지 확인한다.
#   2) [category 없음 케이스] frontmatter에 category 필드가 아예 없는 글의
#      JSON-LD 출력에 "articleSection" 키 자체가 생성되지 않는지 확인한다
#      (빈 문자열로도 채워지지 않아야 한다).
#   3) [JSON 유효성] 두 케이스 모두 생성된 JSON-LD가 python3 json 모듈로
#      파싱 가능한 유효한 JSON인지 확인한다.
#
# 사용법:
#   bash scripts/test_category_article_section.sh
#
# exit code:
#   0 - 모든 검사를 통과함
#   1 - 하나 이상의 검사에서 실패함 (실패 내용을 함께 출력)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSONLD_SCRIPT="${SCRIPT_DIR}/generate_jsonld.sh"

failures=()

if [ ! -f "${JSONLD_SCRIPT}" ]; then
  echo "오류: ${JSONLD_SCRIPT} 파일을 찾을 수 없습니다."
  exit 1
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

mkdir -p "${TMP_DIR}/scripts" "${TMP_DIR}/posts" "${TMP_DIR}/seo"

# generate_jsonld.sh 사본을 임시 디렉터리 안 scripts/ 밑에 둔다.
cp "${JSONLD_SCRIPT}" "${TMP_DIR}/scripts/generate_jsonld.sh"

WITH_CATEGORY_SLUG="with-category-regression-test"
WITH_CATEGORY_FILE="${TMP_DIR}/posts/2026-01-01-${WITH_CATEGORY_SLUG}.md"
cat > "${WITH_CATEGORY_FILE}" <<'EOF'
---
title: "category 반영 회귀 테스트용 임시 글"
meta_description: "category 필드가 articleSection으로 반영되는지 확인하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
category: "경제"
---

이 글은 scripts/test_category_article_section.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.
EOF

NO_CATEGORY_SLUG="no-category-regression-test"
NO_CATEGORY_FILE="${TMP_DIR}/posts/2026-01-01-${NO_CATEGORY_SLUG}.md"
cat > "${NO_CATEGORY_FILE}" <<'EOF'
---
title: "category 없는 글 회귀 테스트용 임시 글"
meta_description: "category 필드가 없을 때 해당 분류 속성이 생성되지 않는지 확인하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_category_article_section.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.
EOF

echo "=== 임시 환경에서 generate_jsonld.sh(사본) 실행 ==="
run_output="$(bash "${TMP_DIR}/scripts/generate_jsonld.sh" 2>&1)"
run_status=$?
echo "${run_output}"

if [ ${run_status} -ne 0 ]; then
  echo "[FAIL] generate_jsonld.sh(사본) 실행이 실패했습니다 (exit ${run_status})."
  failures+=("generate_jsonld.sh 실행 실패")
fi

WITH_CATEGORY_JSON="${TMP_DIR}/seo/jsonld/${WITH_CATEGORY_SLUG}.json"
NO_CATEGORY_JSON="${TMP_DIR}/seo/jsonld/${NO_CATEGORY_SLUG}.json"

echo ""
echo "=== 검사 1: category가 있는 글 -> articleSection 생성 확인 ==="
if [ ! -f "${WITH_CATEGORY_JSON}" ]; then
  echo "[FAIL] ${WITH_CATEGORY_JSON} 파일이 생성되지 않았습니다."
  failures+=("category 있음 케이스 JSON-LD 미생성")
else
  if grep -qF '"articleSection": "경제"' "${WITH_CATEGORY_JSON}"; then
    echo "[PASS] \"articleSection\": \"경제\" 가 생성되었습니다."
  else
    echo "[FAIL] \"articleSection\": \"경제\" 를 찾지 못했습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${WITH_CATEGORY_JSON}"
    failures+=("category 있음 케이스에서 articleSection 누락")
  fi
fi

echo ""
echo "=== 검사 2: category가 없는 글 -> articleSection 생성되지 않아야 함 ==="
if [ ! -f "${NO_CATEGORY_JSON}" ]; then
  echo "[FAIL] ${NO_CATEGORY_JSON} 파일이 생성되지 않았습니다."
  failures+=("category 없음 케이스 JSON-LD 미생성")
else
  if grep -q 'articleSection' "${NO_CATEGORY_JSON}"; then
    echo "[FAIL] category가 없는데도 articleSection 키가 생성되었습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${NO_CATEGORY_JSON}"
    failures+=("category 없음 케이스에서 articleSection이 잘못 생성됨")
  else
    echo "[PASS] articleSection 키가 생성되지 않았습니다."
  fi
fi

echo ""
echo "=== 검사 3: 두 JSON-LD 파일 모두 유효한 JSON인지 확인 ==="
if ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 JSON 유효성을 검증할 수 없습니다."
  failures+=("python3 없음")
else
  for jsonld_file in "${WITH_CATEGORY_JSON}" "${NO_CATEGORY_JSON}"; do
    if [ -f "${jsonld_file}" ]; then
      json_error="$(python3 -c "import json, sys; json.load(open(sys.argv[1]))" "${jsonld_file}" 2>&1 1>/dev/null)"
      if [ $? -eq 0 ]; then
        echo "[PASS] $(basename "${jsonld_file}") 은 유효한 JSON입니다."
      else
        echo "[FAIL] $(basename "${jsonld_file}") 은 유효한 JSON이 아닙니다: ${json_error}"
        failures+=("$(basename "${jsonld_file}") JSON 파싱 실패")
      fi
    fi
  done
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
