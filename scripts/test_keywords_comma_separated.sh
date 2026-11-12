#!/usr/bin/env bash
#
# test_keywords_comma_separated.sh
#
# scripts/generate_jsonld.sh의 keywords 분기 중, keywords가 YAML 배열
# ([...]) 형식이 아니라 콤마로 구분된 문자열(comma-separated string)로
# 주어지는 경우를 처리하는 분기(164~183행, "배열 표기가 아니라 콤마로
# 구분된 문자열인 경우")가 실제로 동작하는지 확인하는 회귀 테스트다.
#
#   배경: 2026-11-08 test_missing_frontmatter.sh 조사 과정에서 전용 회귀
#   테스트가 약한 후보로 4가지(author Person/Organization 분기,
#   dateModified/updated 필드 분기, keywords 콤마-문자열 분기, HOME_LASTMOD
#   계산 로직)가 참고로 남겨졌다. 그중 HOME_LASTMOD 계산 로직은 2026-11-09
#   test_home_lastmod.sh로, author 분기는 2026-11-10
#   test_author_person_organization.sh로, dateModified/updated 분기는
#   2026-11-11 test_date_modified_updated.sh로 먼저 메워졌다. 마지막으로
#   남은 keywords 콤마-문자열 분기를 메우기 위해 2026-11-12 마스터 지시로
#   이 테스트를 추가했다. 이 테스트는 test_author_person_organization.sh,
#   test_date_modified_updated.sh와 같은 "임시 디렉터리에
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
#   1) [따옴표 없는 콤마-문자열 케이스] frontmatter에
#      keywords: 금리, 물가, 환율 처럼 대괄호도 바깥 따옴표도 없는 콤마
#      구분 문자열이 있는 글의 JSON-LD 출력에서
#      "keywords": ["금리", "물가", "환율"] 처럼 3개 항목이 각각 올바르게
#      분리되어 배열로 채워지는지 확인한다.
#   2) [바깥 쌍따옴표로 감싼 콤마-문자열 케이스] frontmatter에
#      keywords: "금리, 물가, 환율" 처럼 전체가 쌍따옴표로 감싸인 콤마
#      구분 문자열이 있는 글도 동일하게
#      "keywords": ["금리", "물가", "환율"]로 채워지는지 확인한다(바깥
#      따옴표가 항목 안에 섞여 들어가지 않는지까지 함께 본다).
#   3) [JSON 유효성] 두 케이스 모두 생성된 JSON-LD가 python3 json 모듈로
#      파싱 가능한 유효한 JSON인지 확인한다.
#
# 사용법:
#   bash scripts/test_keywords_comma_separated.sh
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

UNQUOTED_SLUG="keywords-comma-unquoted-regression-test"
UNQUOTED_FILE="${TMP_DIR}/posts/2026-01-01-${UNQUOTED_SLUG}.md"
cat > "${UNQUOTED_FILE}" <<'EOF'
---
title: "keywords 콤마-문자열(따옴표 없음) 회귀 테스트용 임시 글"
meta_description: "keywords가 대괄호/따옴표 없는 콤마 구분 문자열일 때 배열로 분리되는지 확인하는 테스트용 임시 글입니다"
keywords: 금리, 물가, 환율
date: 2026-01-01
---

이 글은 scripts/test_keywords_comma_separated.sh가 만든 임시 테스트용 글입니다.
posts/ 실제 디렉터리에는 저장되지 않습니다.
EOF

QUOTED_SLUG="keywords-comma-quoted-regression-test"
QUOTED_FILE="${TMP_DIR}/posts/2026-01-01-${QUOTED_SLUG}.md"
cat > "${QUOTED_FILE}" <<'EOF'
---
title: "keywords 콤마-문자열(전체 따옴표) 회귀 테스트용 임시 글"
meta_description: "keywords가 전체를 쌍따옴표로 감싼 콤마 구분 문자열일 때도 배열로 분리되는지 확인하는 테스트용 임시 글입니다"
keywords: "금리, 물가, 환율"
date: 2026-01-01
---

이 글은 scripts/test_keywords_comma_separated.sh가 만든 임시 테스트용 글입니다.
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

UNQUOTED_JSON="${TMP_DIR}/seo/jsonld/${UNQUOTED_SLUG}.json"
QUOTED_JSON="${TMP_DIR}/seo/jsonld/${QUOTED_SLUG}.json"

echo ""
echo "=== 검사 1: 따옴표 없는 콤마-문자열 -> \"keywords\": [\"금리\", \"물가\", \"환율\"] 확인 ==="
if [ ! -f "${UNQUOTED_JSON}" ]; then
  echo "[FAIL] ${UNQUOTED_JSON} 파일이 생성되지 않았습니다."
  failures+=("따옴표 없는 콤마-문자열 케이스 JSON-LD 미생성")
else
  if grep -qF '"keywords": ["금리", "물가", "환율"]' "${UNQUOTED_JSON}"; then
    echo "[PASS] \"keywords\": [\"금리\", \"물가\", \"환율\"] 이 생성되었습니다."
  else
    echo "[FAIL] \"keywords\": [\"금리\", \"물가\", \"환율\"] 을 찾지 못했습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${UNQUOTED_JSON}"
    failures+=("따옴표 없는 콤마-문자열 케이스에서 keywords 배열 분리 실패")
  fi
fi

echo ""
echo "=== 검사 2: 전체를 쌍따옴표로 감싼 콤마-문자열 -> \"keywords\": [\"금리\", \"물가\", \"환율\"] 확인 ==="
if [ ! -f "${QUOTED_JSON}" ]; then
  echo "[FAIL] ${QUOTED_JSON} 파일이 생성되지 않았습니다."
  failures+=("전체 따옴표 콤마-문자열 케이스 JSON-LD 미생성")
else
  if grep -qF '"keywords": ["금리", "물가", "환율"]' "${QUOTED_JSON}"; then
    echo "[PASS] \"keywords\": [\"금리\", \"물가\", \"환율\"] 이 생성되었습니다."
  else
    echo "[FAIL] \"keywords\": [\"금리\", \"물가\", \"환율\"] 을 찾지 못했습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${QUOTED_JSON}"
    failures+=("전체 따옴표 콤마-문자열 케이스에서 keywords 배열 분리 실패")
  fi

  if grep -qF '\"금리' "${QUOTED_JSON}"; then
    echo "[FAIL] 바깥 쌍따옴표가 벗겨지지 않고 keywords 항목 안에 섞여 들어갔습니다."
    echo "        생성된 내용:"
    sed 's/^/        /' "${QUOTED_JSON}"
    failures+=("전체 따옴표 콤마-문자열 케이스에서 바깥 따옴표 잔존")
  else
    echo "[PASS] 바깥 쌍따옴표가 항목 안에 섞여 들어가지 않았습니다."
  fi
fi

echo ""
echo "=== 검사 3: 두 JSON-LD 파일 모두 유효한 JSON인지 확인 ==="
if ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 JSON 유효성을 검증할 수 없습니다."
  failures+=("python3 없음")
else
  for jsonld_file in "${UNQUOTED_JSON}" "${QUOTED_JSON}"; do
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
