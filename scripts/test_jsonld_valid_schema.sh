#!/usr/bin/env bash
#
# test_jsonld_valid_schema.sh
#
# scripts/generate_jsonld.sh가 seo/jsonld/ 에 생성한 실제 JSON-LD 파일들을
# 검증하는 스크립트다.
#
#   배경: 지금까지 JSON-LD 산출물에 대한 검증은 "스크립트가 exit 0으로
#   끝나는지", "기존 산출물과 해시가 같은지" 정도였다. seo/jsonld/*.json
#   파일 자체를 JSON 파서로 파싱해서 실제로 유효한 JSON인지, schema.org
#   Article/BlogPosting에 필요한 핵심 필드(headline, datePublished,
#   dateModified, author, description, @type)가 실제로 존재하고 값이
#   비어있지 않은지를 프로그래밍적으로 검증한 적은 없었다(2026-11-28
#   마스터 지시로 이 공백을 메우기 위해 추가).
#
#   daily_check.sh의 [6/32] "JSON-LD 필수 필드 검증" 단계도 비슷한 검사를
#   하지만 @context/@type/headline/description/datePublished/url/
#   author.name/publisher.name/mainEntityOfPage.@id 만 보고 dateModified는
#   보지 않는다. 이 스크립트는 dateModified도 함께 검사하고, 다른
#   test_*.sh와 달리 임시 디렉터리의 가짜 글이 아니라 seo/jsonld/ 안의
#   "실제" 산출물을 대상으로 하며, 검사한 핵심 필드의 실제 값을 그대로
#   출력해 결과를 눈으로 확인할 수 있게 한다.
#
# 검사 내용 (seo/jsonld/*.json 파일마다):
#   1) [JSON 유효성] python3 json 모듈로 파싱 가능한 유효한 JSON인지 확인한다.
#   2) [핵심 필드 존재/비어있지 않음] 아래 필드가 모두 존재하고 빈 문자열이
#      아닌지 확인하고, 실제 값을 출력한다.
#        - @type
#        - headline
#        - description
#        - datePublished
#        - dateModified
#        - author (객체, author.@type / author.name 모두 비어있지 않아야 함)
#
# 사용법:
#   bash scripts/test_jsonld_valid_schema.sh
#
# exit code:
#   0 - seo/jsonld/ 안의 모든 .json 파일이 검사를 통과함
#   1 - 하나 이상의 파일에서 유효한 JSON이 아니거나 핵심 필드가 없거나
#       비어있음 (실패 내용을 함께 출력)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
JSONLD_DIR="${REPO_ROOT}/seo/jsonld"

failures=()

if [ ! -d "${JSONLD_DIR}" ]; then
  echo "오류: ${JSONLD_DIR} 디렉터리를 찾을 수 없습니다."
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 JSON-LD 스키마를 검증할 수 없습니다."
  exit 1
fi

shopt -s nullglob
jsonld_files=("${JSONLD_DIR}"/*.json)
shopt -u nullglob

if [ ${#jsonld_files[@]} -eq 0 ]; then
  echo "경고: ${JSONLD_DIR} 안에 검사할 .json 파일이 없습니다."
  exit 0
fi

for jsonld_file in "${jsonld_files[@]}"; do
  jsonld_filename="$(basename "${jsonld_file}")"
  echo "=== ${jsonld_filename} ==="

  check_output="$(python3 - "${jsonld_file}" <<'PYEOF'
import json
import sys

path = sys.argv[1]

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"PARSE_FAIL: {e}")
    sys.exit(1)

print("PARSE_OK")

def is_blank(value):
    if value is None:
        return True
    if isinstance(value, str) and value.strip() == "":
        return True
    return False

problems = []

simple_fields = ["@type", "headline", "description", "datePublished", "dateModified"]
for field in simple_fields:
    if field not in data:
        problems.append(f"{field} 필드가 없습니다")
    elif is_blank(data[field]):
        problems.append(f"{field} 값이 비어 있습니다")
    else:
        print(f"VALUE: {field} = {data[field]!r}")

if "author" not in data:
    problems.append("author 필드가 없습니다")
else:
    author = data["author"]
    if not isinstance(author, dict):
        problems.append("author 필드가 객체가 아닙니다")
    else:
        for subkey in ("@type", "name"):
            if subkey not in author:
                problems.append(f"author.{subkey} 필드가 없습니다")
            elif is_blank(author[subkey]):
                problems.append(f"author.{subkey} 값이 비어 있습니다")
            else:
                print(f"VALUE: author.{subkey} = {author[subkey]!r}")

if problems:
    for p in problems:
        print(f"PROBLEM: {p}")
    sys.exit(1)

sys.exit(0)
PYEOF
)"
  check_status=$?

  while IFS= read -r line; do
    [ -z "${line}" ] && continue
    case "${line}" in
      PARSE_FAIL:*)
        echo "[FAIL] 유효한 JSON이 아닙니다: ${line#PARSE_FAIL: }"
        ;;
      PARSE_OK)
        echo "[PASS] 유효한 JSON입니다."
        ;;
      VALUE:*)
        echo "        ${line#VALUE: }"
        ;;
      PROBLEM:*)
        echo "[FAIL] ${line#PROBLEM: }"
        ;;
      *)
        echo "${line}"
        ;;
    esac
  done <<< "${check_output}"

  if [ ${check_status} -eq 0 ]; then
    echo "[PASS] ${jsonld_filename} 핵심 필드 검증 통과"
  else
    failures+=("${jsonld_filename}")
  fi
  echo ""
done

if [ ${#failures[@]} -eq 0 ]; then
  echo "모든 JSON-LD 파일(${#jsonld_files[@]}건)이 검사를 통과했습니다."
  exit 0
else
  echo "다음 파일에서 검사가 실패했습니다:"
  for f in "${failures[@]}"; do
    echo "  - ${f}"
  done
  exit 1
fi
