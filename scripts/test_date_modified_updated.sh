#!/usr/bin/env bash
#
# test_date_modified_updated.sh
#
# scripts/generate_jsonld.sh의 dateModified/updated 필드 분기(frontmatter에
# updated: 필드가 있으면 그 값을 dateModified로 사용하고, 없으면
# datePublished와 동일한 값을 dateModified로 사용하는 로직, 119~123행)가
# 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: 2026-11-08 test_missing_frontmatter.sh 조사 과정에서 전용 회귀
#   테스트가 약한 후보로 4가지(author Person/Organization 분기,
#   dateModified/updated 필드 분기, keywords 콤마-문자열 분기, HOME_LASTMOD
#   계산 로직)가 참고로 남겨졌다. 그중 HOME_LASTMOD 계산 로직은 2026-11-09
#   test_home_lastmod.sh로, author 분기는 2026-11-10
#   test_author_person_organization.sh로 먼저 메워졌다. 남은 두 후보
#   (dateModified/updated 필드 분기, keywords 콤마-문자열 분기) 중,
#   author 분기·category→articleSection 매핑과 완전히 같은 "선택적
#   frontmatter 필드가 있을 때/없을 때" 단순 if/else 패턴으로 가장 단순하고
#   단독으로 분리된 분기인 dateModified/updated 필드 분기를 메우기 위해
#   2026-11-11 마스터 지시로 추가했다. keywords 콤마-문자열 분기는 아직
#   전용 회귀 테스트가 없는 공백으로 남아 있다(참고용, 이 테스트의 대상이
#   아님). 이 테스트는 scripts/test_author_person_organization.sh와 같은
#   "임시 디렉터리에 generate_jsonld.sh 사본을 두고 실행 → 생성된 JSON-LD
#   파일 내용 확인" 패턴을 그대로 따른다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/generate_jsonld.sh 사본과
#   posts/, seo/ 구조를 흉내 낸 임시 환경을 통째로 구성해 그 사본을
#   실행한다(generate_jsonld.sh는 자기 자신의 위치를 기준으로
#   REPO_ROOT/POSTS_DIR/SEO_DIR을 계산하므로, 사본을 임시 디렉터리 안
#   scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만 동작한다).
#
# 검사 내용:
#   1) [updated 있음 케이스] frontmatter에 date: "2026-01-01"과
#      updated: "2026-03-15"가 함께 있는 글의 JSON-LD 출력에서
#      "datePublished": "2026-01-01"은 그대로이고 "dateModified"는
#      updated 값인 "2026-03-15"로 채워지는지 확인한다(datePublished와
#      달라야 함).
#   2) [updated 없음 케이스] frontmatter에 date: "2026-01-01"만 있고
#      updated 필드가 없는 글의 JSON-LD 출력에서 "dateModified"가
#      datePublished와 동일한 "2026-01-01"로 채워지는지 확인한다.
#   3) [JSON 유효성] 두 케이스 모두 생성된 JSON-LD가 python3 json 모듈로
#      파싱 가능한 유효한 JSON인지 확인한다.
#
# 사용법:
#   bash scripts/test_date_modified_updated.sh
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

WITH_UPDATED_SLUG="with-updated-regression-test"
WITH_UPDATED_FILE="${TMP_DIR}/posts/2026-01-01-${WITH_UPDATED_SLUG}.md"
cat > "${WITH_UPDATED_FILE}" <<'EOF'
---
title: "updated 있음 회귀 테스트용 임시 글"
meta_description: "updated 필드가 있으면 dateModified로 반영되는지 확인하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: "2026-01-01"
updated: "2026-03-15"
---

이 글은 scripts/test_date_modified_updated.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.
EOF

NO_UPDATED_SLUG="no-updated-regression-test"
NO_UPDATED_FILE="${TMP_DIR}/posts/2026-01-01-${NO_UPDATED_SLUG}.md"
cat > "${NO_UPDATED_FILE}" <<'EOF'
---
title: "updated 없음 회귀 테스트용 임시 글"
meta_description: "updated 필드가 없으면 dateModified가 datePublished와 동일한지 확인하는 테스트용 임시 글입니다"
keywords: ["테스트"]
date: "2026-01-01"
---

이 글은 scripts/test_date_modified_updated.sh가 만든 임시 테스트용 글입니다.
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

WITH_UPDATED_JSON="${TMP_DIR}/seo/jsonld/${WITH_UPDATED_SLUG}.json"
NO_UPDATED_JSON="${TMP_DIR}/seo/jsonld/${NO_UPDATED_SLUG}.json"

echo ""
echo "=== 검사 1: updated가 있는 글 -> \"datePublished\": \"2026-01-01\", \"dateModified\": \"2026-03-15\" 확인 ==="
if [ ! -f "${WITH_UPDATED_JSON}" ]; then
  echo "[FAIL] ${WITH_UPDATED_JSON} 파일이 생성되지 않았습니다."
  failures+=("updated 있음 케이스 JSON-LD 미생성")
else
  if grep -qF '"datePublished": "2026-01-01"' "${WITH_UPDATED_JSON}" && grep -qF '"dateModified": "2026-03-15"' "${WITH_UPDATED_JSON}"; then
    echo "[PASS] \"datePublished\": \"2026-01-01\" 과 \"dateModified\": \"2026-03-15\" 가 모두 생성되었습니다."
  else
    echo "[FAIL] \"datePublished\": \"2026-01-01\" 또는 \"dateModified\": \"2026-03-15\" 를 찾지 못했습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${WITH_UPDATED_JSON}"
    failures+=("updated 있음 케이스에서 dateModified 반영 누락")
  fi

  if grep -qF '"dateModified": "2026-01-01"' "${WITH_UPDATED_JSON}"; then
    echo "[FAIL] updated가 있는데도 dateModified가 datePublished와 같은 값(2026-01-01)으로 생성되었습니다."
    failures+=("updated 있음 케이스에서 dateModified가 잘못 datePublished로 채워짐")
  else
    echo "[PASS] updated가 있는 경우 dateModified가 datePublished와 다른 값으로 채워졌습니다."
  fi
fi

echo ""
echo "=== 검사 2: updated가 없는 글 -> \"datePublished\"와 \"dateModified\"가 모두 \"2026-01-01\" 확인 ==="
if [ ! -f "${NO_UPDATED_JSON}" ]; then
  echo "[FAIL] ${NO_UPDATED_JSON} 파일이 생성되지 않았습니다."
  failures+=("updated 없음 케이스 JSON-LD 미생성")
else
  if grep -qF '"datePublished": "2026-01-01"' "${NO_UPDATED_JSON}" && grep -qF '"dateModified": "2026-01-01"' "${NO_UPDATED_JSON}"; then
    echo "[PASS] \"datePublished\"와 \"dateModified\"가 모두 \"2026-01-01\"로 생성되었습니다."
  else
    echo "[FAIL] \"datePublished\": \"2026-01-01\" 또는 \"dateModified\": \"2026-01-01\" 를 찾지 못했습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${NO_UPDATED_JSON}"
    failures+=("updated 없음 케이스에서 dateModified가 datePublished와 동일하게 채워지지 않음")
  fi
fi

echo ""
echo "=== 검사 3: 두 JSON-LD 파일 모두 유효한 JSON인지 확인 ==="
if ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 JSON 유효성을 검증할 수 없습니다."
  failures+=("python3 없음")
else
  for jsonld_file in "${WITH_UPDATED_JSON}" "${NO_UPDATED_JSON}"; do
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
