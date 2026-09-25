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
#   6) JSON-LD 필수 필드 검증 - 3)에서 생성된 seo/jsonld/*.json 각각이
#      schema.org BlogPosting에 필요한 필수 필드(@context, @type, headline,
#      description, datePublished, url, author.name, publisher.name,
#      mainEntityOfPage.@id)를 모두 갖추고 값이 비어있지 않은지 검증
#      (python3 json 모듈 사용). "파싱 가능한 JSON"인지만 보는 4)와 달리,
#      실제로 필요한 필드가 채워져 있는지까지 확인한다.
#   7) 도메인 일관성 검증 - seo/sitemap.xml의 모든 <loc> 값과
#      seo/jsonld/*.json 각각의 url, mainEntityOfPage.@id 값에서
#      스킴+호스트(예: https://example.com) 부분만 추출해, 이 값들이 전부
#      하나의 동일한 도메인인지 검증한다(python3 xml.etree.ElementTree,
#      json, urllib.parse.urlsplit 사용). generate_sitemap.sh와
#      generate_jsonld.sh는 각각 BASE_URL을 독립적으로 하드코딩하고 있어,
#      한쪽만 바꾸고 다른 쪽을 깜빡하는 실수를 잡아내기 위한 단계다.
#
# 이 스크립트는 기존 세 스크립트(validate_posts.sh, generate_sitemap.sh,
# generate_jsonld.sh)의 내용을 절대 수정하지 않고, 그대로 호출만 한다.
# 4번째, 5번째, 6번째, 7번째 검증 단계는 daily_check.sh 자체에 추가된
# 로직이며, 기존 세 스크립트를 건드리지 않는다.
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

overall_status=0

echo "=========================================="
echo "[1/7] 글 규칙 검증을 실행합니다: validate_posts.sh"
echo "=========================================="
bash "${VALIDATE_SCRIPT}"
validate_status=$?

echo ""
echo "=========================================="
echo "[2/7] sitemap.xml / robots.txt 생성을 실행합니다: generate_sitemap.sh"
echo "=========================================="
bash "${SITEMAP_SCRIPT}"
sitemap_status=$?

echo ""
echo "=========================================="
echo "[3/7] JSON-LD 생성을 실행합니다: generate_jsonld.sh"
echo "=========================================="
bash "${JSONLD_SCRIPT}"
jsonld_status=$?

echo ""
echo "=========================================="
echo "[4/7] JSON-LD 유효성 검증을 실행합니다: seo/jsonld/*.json"
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
echo "[5/7] sitemap.xml 유효성 검증을 실행합니다: seo/sitemap.xml"
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
echo "[6/7] JSON-LD 필수 필드 검증을 실행합니다: seo/jsonld/*.json"
echo "=========================================="
jsonld_required_fields_status=0
if [ ! -d "${JSONLD_DIR}" ]; then
  echo "경고: ${JSONLD_DIR} 디렉터리를 찾을 수 없어 필수 필드 검증을 건너뜁니다."
elif ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 JSON-LD 필수 필드를 검증할 수 없습니다."
  jsonld_required_fields_status=1
else
  shopt -s nullglob
  jsonld_files_for_fields=("${JSONLD_DIR}"/*.json)
  shopt -u nullglob

  if [ ${#jsonld_files_for_fields[@]} -eq 0 ]; then
    echo "경고: ${JSONLD_DIR} 안에 검사할 .json 파일이 없습니다."
  else
    for jsonld_file in "${jsonld_files_for_fields[@]}"; do
      jsonld_filename="$(basename "${jsonld_file}")"
      field_check_output="$(python3 - "${jsonld_file}" <<'PYEOF'
import json
import sys

path = sys.argv[1]

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"JSON 파싱 실패: {e}")
    sys.exit(1)

def is_blank(value):
    if value is None:
        return True
    if isinstance(value, str) and value.strip() == "":
        return True
    return False

required_simple_fields = [
    "@context",
    "@type",
    "headline",
    "description",
    "datePublished",
    "url",
]
required_object_fields = {
    "author": "name",
    "publisher": "name",
    "mainEntityOfPage": "@id",
}

problems = []

for field in required_simple_fields:
    if field not in data:
        problems.append(f"{field} 필드가 없습니다")
    elif is_blank(data[field]):
        problems.append(f"{field} 값이 비어 있습니다")

for field, subkey in required_object_fields.items():
    if field not in data:
        problems.append(f"{field} 필드가 없습니다")
        continue
    obj = data[field]
    if not isinstance(obj, dict):
        problems.append(f"{field} 필드가 객체가 아닙니다")
        continue
    if subkey not in obj:
        problems.append(f"{field}.{subkey} 필드가 없습니다")
    elif is_blank(obj[subkey]):
        problems.append(f"{field}.{subkey} 값이 비어 있습니다")

if problems:
    for p in problems:
        print(p)
    sys.exit(1)

sys.exit(0)
PYEOF
)"
      field_check_status=$?
      if [ ${field_check_status} -eq 0 ]; then
        echo "[PASS] ${jsonld_filename}"
      else
        jsonld_required_fields_status=1
        echo "[FAIL] ${jsonld_filename}"
        while IFS= read -r problem_line; do
          if [ -n "${problem_line}" ]; then
            echo "        - ${problem_line}"
          fi
        done <<< "${field_check_output}"
      fi
    done
  fi
fi

echo ""
echo "=========================================="
echo "[7/7] 도메인 일관성 검증을 실행합니다: seo/sitemap.xml ↔ seo/jsonld/*.json"
echo "=========================================="
domain_consistency_status=0
if [ ! -f "${SITEMAP_FILE}" ]; then
  echo "경고: ${SITEMAP_FILE} 파일을 찾을 수 없어 도메인 일관성 검증을 건너뜁니다."
elif [ ! -d "${JSONLD_DIR}" ]; then
  echo "경고: ${JSONLD_DIR} 디렉터리를 찾을 수 없어 도메인 일관성 검증을 건너뜁니다."
elif ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 도메인 일관성을 검증할 수 없습니다."
  domain_consistency_status=1
else
  shopt -s nullglob
  jsonld_files_for_domain=("${JSONLD_DIR}"/*.json)
  shopt -u nullglob

  if [ ${#jsonld_files_for_domain[@]} -eq 0 ]; then
    echo "경고: ${JSONLD_DIR} 안에 검사할 .json 파일이 없습니다."
  else
    domain_check_output="$(python3 - "${SITEMAP_FILE}" "${jsonld_files_for_domain[@]}" <<'PYEOF'
import json
import sys
import xml.etree.ElementTree as ET
from urllib.parse import urlsplit

sitemap_path = sys.argv[1]
jsonld_paths = sys.argv[2:]

# domain(scheme+netloc) -> [출처 설명, ...]
domains = {}

def add_domain(url, source):
    if url is None:
        return
    url = str(url).strip()
    if url == "":
        return
    parts = urlsplit(url)
    domain = f"{parts.scheme}://{parts.netloc}"
    domains.setdefault(domain, []).append(source)

try:
    tree = ET.parse(sitemap_path)
    root = tree.getroot()
except Exception as e:
    print(f"sitemap.xml 파싱 실패: {e}")
    sys.exit(1)

for elem in root.iter():
    local_tag = elem.tag.split("}")[-1] if "}" in elem.tag else elem.tag
    if local_tag == "loc":
        add_domain(elem.text, f"sitemap.xml <loc>{elem.text}</loc>")

for jsonld_path in jsonld_paths:
    filename = jsonld_path.rsplit("/", 1)[-1]
    try:
        with open(jsonld_path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except Exception as e:
        print(f"{filename} 파싱 실패: {e}")
        sys.exit(1)

    if "url" in data:
        add_domain(data.get("url"), f"{filename} url={data.get('url')}")

    main_entity = data.get("mainEntityOfPage")
    if isinstance(main_entity, dict) and "@id" in main_entity:
        add_domain(
            main_entity.get("@id"),
            f"{filename} mainEntityOfPage.@id={main_entity.get('@id')}",
        )

if len(domains) <= 1:
    if domains:
        (only_domain,) = domains.keys()
        print(f"도메인: {only_domain}")
    sys.exit(0)

for domain, sources in domains.items():
    print(f"도메인 {domain}:")
    for source in sources:
        print(f"  {source}")
sys.exit(1)
PYEOF
)"
    domain_check_status=$?
    if [ ${domain_check_status} -eq 0 ]; then
      echo "[PASS] seo/sitemap.xml, seo/jsonld/*.json 모두 동일한 도메인을 사용합니다."
      if [ -n "${domain_check_output}" ]; then
        echo "        - ${domain_check_output}"
      fi
    else
      domain_consistency_status=1
      echo "[FAIL] seo/sitemap.xml ↔ seo/jsonld/*.json 도메인이 서로 다릅니다."
      while IFS= read -r problem_line; do
        if [ -n "${problem_line}" ]; then
          echo "        - ${problem_line}"
        fi
      done <<< "${domain_check_output}"
    fi
  fi
fi

if [ ${validate_status} -ne 0 ] || [ ${sitemap_status} -ne 0 ] || [ ${jsonld_status} -ne 0 ] || [ ${jsonld_validate_status} -ne 0 ] || [ ${sitemap_validate_status} -ne 0 ] || [ ${jsonld_required_fields_status} -ne 0 ] || [ ${domain_consistency_status} -ne 0 ]; then
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
echo "6) JSON-LD 필수 필드 검증 (seo/jsonld/*.json) : $(status_label ${jsonld_required_fields_status})"
echo "7) 도메인 일관성 검증 (sitemap.xml ↔ jsonld/*.json) : $(status_label ${domain_consistency_status})"
echo "------------------------------------------"
if [ ${overall_status} -eq 0 ]; then
  echo "전체 결과: 모든 점검을 통과했습니다."
else
  echo "전체 결과: 하나 이상의 점검이 실패했습니다. 위 로그를 확인해 수정하세요."
fi

exit ${overall_status}
