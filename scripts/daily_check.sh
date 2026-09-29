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
#   5) sitemap.xml 유효성 검증 - 2)에서 생성된 seo/sitemap.xml이
#      실제로 파싱 가능한 well-formed XML인지 검증(python3 xml.etree.ElementTree 사용)
#   6) robots.txt 기본 유효성 검증 - 2)에서 생성된 seo/robots.txt가
#      존재/비어있지 않음, User-agent: 줄 존재, Sitemap: 줄 존재 및 그 URL이
#      /sitemap.xml로 끝나는지 검증
#
# 이 스크립트는 기존 세 스크립트(validate_posts.sh, generate_sitemap.sh,
# generate_jsonld.sh)의 내용을 절대 수정하지 않고, 그대로 호출만 한다.
# 4번째, 5번째, 6번째 검증 단계는 daily_check.sh 자체에 추가된 로직이며, 기존
# 세 스크립트를 건드리지 않는다.
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
SITEMAP_FILE="${REPO_ROOT}/seo/sitemap.xml"
ROBOTS_FILE="${REPO_ROOT}/seo/robots.txt"

overall_status=0

echo "=========================================="
echo "[1/6] 글 규칙 검증을 실행합니다: validate_posts.sh"
echo "=========================================="
bash "${VALIDATE_SCRIPT}"
validate_status=$?

echo ""
echo "=========================================="
echo "[2/6] sitemap.xml / robots.txt 생성을 실행합니다: generate_sitemap.sh"
echo "=========================================="
bash "${SITEMAP_SCRIPT}"
sitemap_status=$?

echo ""
echo "=========================================="
echo "[3/6] JSON-LD 생성을 실행합니다: generate_jsonld.sh"
echo "=========================================="
bash "${JSONLD_SCRIPT}"
jsonld_status=$?

echo ""
echo "=========================================="
echo "[4/6] JSON-LD 유효성 검증을 실행합니다: seo/jsonld/*.json"
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

echo ""
echo "=========================================="
echo "[5/6] sitemap.xml 유효성 검증을 실행합니다: seo/sitemap.xml"
echo "=========================================="
sitemap_validate_status=0
if [ ! -f "${SITEMAP_FILE}" ]; then
  echo "경고: ${SITEMAP_FILE} 파일을 찾을 수 없어 유효성 검증을 건너뜁니다."
elif ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 sitemap.xml 유효성을 검증할 수 없습니다."
  sitemap_validate_status=1
else
  sitemap_filename="$(basename "${SITEMAP_FILE}")"
  xml_error="$(python3 -c "import xml.etree.ElementTree as ET, sys; ET.parse(sys.argv[1])" "${SITEMAP_FILE}" 2>&1 1>/dev/null)"
  if [ $? -eq 0 ]; then
    echo "[PASS] ${sitemap_filename}"
  else
    sitemap_validate_status=1
    echo "[FAIL] ${sitemap_filename}"
    echo "        - 유효한 XML이 아닙니다: ${xml_error}"
  fi
fi

echo ""
echo "=========================================="
echo "[6/6] robots.txt 유효성 검증을 실행합니다: seo/robots.txt"
echo "=========================================="
robots_validate_status=0
if [ ! -f "${ROBOTS_FILE}" ]; then
  echo "경고: ${ROBOTS_FILE} 파일을 찾을 수 없어 유효성 검증을 건너뜁니다."
else
  robots_filename="$(basename "${ROBOTS_FILE}")"
  robots_errors=()

  if [ ! -s "${ROBOTS_FILE}" ]; then
    robots_errors+=("파일이 존재하지만 비어 있습니다.")
  fi

  if ! grep -q '^User-agent:' "${ROBOTS_FILE}"; then
    robots_errors+=("'User-agent:'로 시작하는 줄이 없습니다.")
  fi

  robots_sitemap_line="$(grep '^Sitemap:' "${ROBOTS_FILE}" | head -n 1)"
  if [ -z "${robots_sitemap_line}" ]; then
    robots_errors+=("'Sitemap:'으로 시작하는 줄이 없습니다.")
  else
    robots_sitemap_url="$(echo "${robots_sitemap_line}" | sed -e 's/^Sitemap:[[:space:]]*//' -e 's/[[:space:]]*$//')"
    case "${robots_sitemap_url}" in
      */sitemap.xml) ;;
      *)
        robots_errors+=("Sitemap 줄의 URL이 '/sitemap.xml'로 끝나지 않습니다: ${robots_sitemap_url}")
        ;;
    esac
  fi

  if [ ${#robots_errors[@]} -eq 0 ]; then
    echo "[PASS] ${robots_filename}"
  else
    robots_validate_status=1
    echo "[FAIL] ${robots_filename}"
    for robots_error in "${robots_errors[@]}"; do
      echo "        - ${robots_error}"
    done
  fi
fi

if [ ${validate_status} -ne 0 ] || [ ${sitemap_status} -ne 0 ] || [ ${jsonld_status} -ne 0 ] || [ ${jsonld_validate_status} -ne 0 ] || [ ${sitemap_validate_status} -ne 0 ] || [ ${robots_validate_status} -ne 0 ]; then
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
echo "5) sitemap.xml 유효성 검증 (seo/sitemap.xml) : $(status_label ${sitemap_validate_status})"
echo "6) robots.txt 유효성 검증 (seo/robots.txt) : $(status_label ${robots_validate_status})"
echo "------------------------------------------"
if [ ${overall_status} -eq 0 ]; then
  echo "전체 결과: 모든 점검을 통과했습니다."
else
  echo "전체 결과: 하나 이상의 점검이 실패했습니다. 위 로그를 확인해 수정하세요."
fi

exit ${overall_status}
