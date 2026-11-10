#!/usr/bin/env bash
#
# test_author_person_organization.sh
#
# scripts/generate_jsonld.sh의 author Person/Organization 분기(frontmatter에
# author 필드가 있으면 "@type": "Person"으로, 없으면 기본값
# "@type": "Organization", "name": "최신경제"로 채우는 로직)가 실제로
# 동작하는지 확인하는 회귀 테스트다.
#
#   배경: 2026-11-08 test_missing_frontmatter.sh 조사 과정에서 전용 회귀
#   테스트가 약한 후보로 4가지(author Person/Organization 분기,
#   dateModified/updated 필드 분기, keywords 콤마-문자열 분기, HOME_LASTMOD
#   계산 로직)가 참고로 남겨졌고, 그중 HOME_LASTMOD 계산 로직은
#   2026-11-09에 scripts/test_home_lastmod.sh로 먼저 메워졌다. 남은 세
#   후보 중 author 분기는 category→articleSection 매핑(2026-10-24,
#   test_category_article_section.sh)과 같은 "선택적 frontmatter 필드가
#   있을 때/없을 때" 패턴으로 가장 단순하고 단독으로 분리된 분기라 2026-11-10
#   마스터 지시로 이 공백을 메우기 위해 추가했다. 이 테스트는
#   scripts/test_category_article_section.sh와 같은 "임시 디렉터리에
#   generate_jsonld.sh 사본을 두고 실행 → 생성된 JSON-LD 파일 내용 확인"
#   패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/generate_jsonld.sh 사본과
#   posts/, seo/ 구조를 흉내 낸 임시 환경을 통째로 구성해 그 사본을
#   실행한다(generate_jsonld.sh는 자기 자신의 위치를 기준으로
#   REPO_ROOT/POSTS_DIR/SEO_DIR을 계산하므로, 사본을 임시 디렉터리 안
#   scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만 동작한다).
#
# 검사 내용:
#   1) [author 있음 케이스] frontmatter에 author: "홍길동"이 있는 글의
#      JSON-LD 출력에 "@type": "Person"과 "name": "홍길동"이 author
#      객체 안에 함께 포함되는지 확인한다.
#   2) [author 없음 케이스] frontmatter에 author 필드가 아예 없는 글의
#      JSON-LD 출력에 author 객체가 기본값 "@type": "Organization",
#      "name": "최신경제"로 채워지는지 확인한다(Person으로 잘못
#      채워지지 않는지까지 함께 본다).
#   3) [JSON 유효성] 두 케이스 모두 생성된 JSON-LD가 python3 json 모듈로
#      파싱 가능한 유효한 JSON인지 확인한다.
#
# 사용법:
#   bash scripts/test_author_person_organization.sh
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

WITH_AUTHOR_SLUG="with-author-regression-test"
WITH_AUTHOR_FILE="${TMP_DIR}/posts/2026-01-01-${WITH_AUTHOR_SLUG}.md"
cat > "${WITH_AUTHOR_FILE}" <<'EOF'
---
title: "author 있음 회귀 테스트용 임시 글"
meta_description: "author 필드가 있으면 Person으로 반영되는지 확인하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
author: "홍길동"
---

이 글은 scripts/test_author_person_organization.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.
EOF

NO_AUTHOR_SLUG="no-author-regression-test"
NO_AUTHOR_FILE="${TMP_DIR}/posts/2026-01-01-${NO_AUTHOR_SLUG}.md"
cat > "${NO_AUTHOR_FILE}" <<'EOF'
---
title: "author 없음 회귀 테스트용 임시 글"
meta_description: "author 필드가 없으면 기본 Organization으로 반영되는지 확인하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: 2026-01-01
---

이 글은 scripts/test_author_person_organization.sh가 만든 임시 테스트용 글입니다.
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

WITH_AUTHOR_JSON="${TMP_DIR}/seo/jsonld/${WITH_AUTHOR_SLUG}.json"
NO_AUTHOR_JSON="${TMP_DIR}/seo/jsonld/${NO_AUTHOR_SLUG}.json"

echo ""
echo "=== 검사 1: author가 있는 글 -> \"@type\": \"Person\", \"name\": \"홍길동\" 확인 ==="
if [ ! -f "${WITH_AUTHOR_JSON}" ]; then
  echo "[FAIL] ${WITH_AUTHOR_JSON} 파일이 생성되지 않았습니다."
  failures+=("author 있음 케이스 JSON-LD 미생성")
else
  if grep -qF '"@type": "Person"' "${WITH_AUTHOR_JSON}" && grep -qF '"name": "홍길동"' "${WITH_AUTHOR_JSON}"; then
    echo "[PASS] \"@type\": \"Person\" 과 \"name\": \"홍길동\" 이 모두 생성되었습니다."
  else
    echo "[FAIL] \"@type\": \"Person\" 또는 \"name\": \"홍길동\" 을 찾지 못했습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${WITH_AUTHOR_JSON}"
    failures+=("author 있음 케이스에서 Person 반영 누락")
  fi
fi

echo ""
echo "=== 검사 2: author가 없는 글 -> \"@type\": \"Organization\", \"name\": \"최신경제\" 확인 ==="
if [ ! -f "${NO_AUTHOR_JSON}" ]; then
  echo "[FAIL] ${NO_AUTHOR_JSON} 파일이 생성되지 않았습니다."
  failures+=("author 없음 케이스 JSON-LD 미생성")
else
  if grep -qF '"@type": "Organization"' "${NO_AUTHOR_JSON}" && grep -qF '"name": "최신경제"' "${NO_AUTHOR_JSON}"; then
    echo "[PASS] \"@type\": \"Organization\" 과 \"name\": \"최신경제\" 가 모두 생성되었습니다."
  else
    echo "[FAIL] \"@type\": \"Organization\" 또는 \"name\": \"최신경제\" 를 찾지 못했습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${NO_AUTHOR_JSON}"
    failures+=("author 없음 케이스에서 기본 Organization 반영 누락")
  fi

  if grep -qF '"@type": "Person"' "${NO_AUTHOR_JSON}"; then
    echo "[FAIL] author가 없는데도 \"@type\": \"Person\" 이 생성되었습니다."
    failures+=("author 없음 케이스에서 잘못 Person으로 생성됨")
  else
    echo "[PASS] author가 없는 경우 \"@type\": \"Person\" 은 생성되지 않았습니다."
  fi
fi

echo ""
echo "=== 검사 3: 두 JSON-LD 파일 모두 유효한 JSON인지 확인 ==="
if ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 JSON 유효성을 검증할 수 없습니다."
  failures+=("python3 없음")
else
  for jsonld_file in "${WITH_AUTHOR_JSON}" "${NO_AUTHOR_JSON}"; do
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
