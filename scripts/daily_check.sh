#!/usr/bin/env bash
#
# daily_check.sh
#
# 매일 사이트 점검을 위해 아래 스크립트를 순서대로 실행하는 통합 스크립트다.
#   1) validate_posts.sh   - posts/ 글 규칙(파일명, frontmatter, 면책 문구) 검증
#   2) generate_sitemap.sh - sitemap.xml / robots.txt 생성
#   3) generate_jsonld.sh  - 글별 JSON-LD(구조화 데이터) 생성
#   4) JSON-LD 유효성 검증 - 3)에서 생성된 seo/jsonld/*.json 각각이
#      실제로 파싱 가능한 유효한 JSON인지 검증(python3 json 모듈 사용)
#
# 이 스크립트는 기존 세 스크립트(validate_posts.sh, generate_sitemap.sh,
# generate_jsonld.sh)의 내용을 절대 수정하지 않고, 그대로 호출만 한다.
# 4번째 검증 단계는 daily_check.sh 자체에 추가된 로직이며, 기존 세 스크립트를
# 건드리지 않는다.
#
# 한 단계가 실패(exit 1)해도 나머지 단계는 계속 진행한다. 다만 하나라도 실패한
# 단계가 있으면 이 스크립트도 최종적으로 exit 1로 끝난다.
#
# 사용법:
#   bash scripts/daily_check.sh

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

VALIDATE_SCRIPT="${SCRIPT_DIR}/validate_posts.sh"
SITEMAP_SCRIPT="${SCRIPT_DIR}/generate_sitemap.sh"
JSONLD_SCRIPT="${SCRIPT_DIR}/generate_jsonld.sh"
JSONLD_DIR="${REPO_ROOT}/seo/jsonld"

overall_status=0

echo "=========================================="
echo "[1/4] 글 규칙 검증을 실행합니다: validate_posts.sh"
echo "=========================================="
bash "${VALIDATE_SCRIPT}"
validate_status=$?

echo ""
echo "=========================================="
echo "[2/4] sitemap.xml / robots.txt 생성을 실행합니다: generate_sitemap.sh"
echo "=========================================="
bash "${SITEMAP_SCRIPT}"
sitemap_status=$?

echo ""
echo "=========================================="
echo "[3/4] JSON-LD 생성을 실행합니다: generate_jsonld.sh"
echo "=========================================="
bash "${JSONLD_SCRIPT}"
jsonld_status=$?

echo ""
echo "=========================================="
echo "[4/4] JSON-LD 유효성 검증을 실행합니다: seo/jsonld/*.json"
echo "=========================================="
jsonld_validate_status=0
if [ ! -d "${JSONLD_DIR}" ]; then
  echo "경고: ${JSONLD_DIR} 디렉터리를 찾을 수 없어 유효성 검증을 건너뜁니다."
elif ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 JSON-LD 유효성을 검증할 수 없습니다."
  jsonld_validate_status=1
else
  shopt -s nullglob
  jsonld_files=("${JSONLD_DIR}"/*.json)
  shopt -u nullglob

  if [ ${#jsonld_files[@]} -eq 0 ]; then
    echo "경고: ${JSONLD_DIR} 안에 검사할 .json 파일이 없습니다."
  else
    for jsonld_file in "${jsonld_files[@]}"; do
      jsonld_filename="$(basename "${jsonld_file}")"
      json_error="$(python3 -c "import json, sys; json.load(open(sys.argv[1]))" "${jsonld_file}" 2>&1 1>/dev/null)"
      if [ $? -eq 0 ]; then
        echo "[PASS] ${jsonld_filename}"
      else
        jsonld_validate_status=1
        echo "[FAIL] ${jsonld_filename}"
        echo "        - 유효한 JSON이 아닙니다: ${json_error}"
      fi
    done
  fi
fi

if [ ${validate_status} -ne 0 ] || [ ${sitemap_status} -ne 0 ] || [ ${jsonld_status} -ne 0 ] || [ ${jsonld_validate_status} -ne 0 ]; then
  overall_status=1
fi

status_label() {
  if [ "$1" -eq 0 ]; then
    echo "성공"
  else
    echo "실패 (exit ${1})"
  fi
}

echo ""
echo "=========================================="
echo "오늘의 사이트 점검 결과"
echo "=========================================="
echo "1) 글 규칙 검증 (validate_posts.sh)     : $(status_label ${validate_status})"
echo "2) sitemap/robots 생성 (generate_sitemap.sh) : $(status_label ${sitemap_status})"
echo "3) JSON-LD 생성 (generate_jsonld.sh)     : $(status_label ${jsonld_status})"
echo "4) JSON-LD 유효성 검증 (seo/jsonld/*.json) : $(status_label ${jsonld_validate_status})"
echo "------------------------------------------"
if [ ${overall_status} -eq 0 ]; then
  echo "전체 결과: 모든 점검을 통과했습니다."
else
  echo "전체 결과: 하나 이상의 점검이 실패했습니다. 위 로그를 확인해 수정하세요."
fi

exit ${overall_status}
