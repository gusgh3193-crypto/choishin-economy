#!/usr/bin/env bash
#
# test_split_keywords.sh
#
# scripts/generate_jsonld.sh 와 scripts/validate_posts.sh 양쪽에 복붙되어
# 들어가 있는 split_keywords_items() 함수에 대한 회귀 테스트다.
#
#   배경: 두 스크립트는 독립 실행 파일 원칙상 공유 라이브러리로 추출하지
#   않고 동일한 함수를 각자 복사해서 가지고 있다(각 스크립트의 주석 참고).
#   과거 로그에 따르면 이 함수가 한쪽 파일에서만 수정되고 다른 쪽은 그대로
#   남아, 쉼표가 포함된 키워드를 잘못 쪼개는 같은 종류의 버그가 최소 사흘
#   연속 재발했다. 사람이 눈으로 diff를 확인하는 것에만 의존하지 않도록
#   이 테스트로 (1) 두 함수가 실제로 동일한 텍스트인지, (2) 함수가 올바르게
#   동작하는지를 자동으로 검증한다.
#
# 검사 내용:
#   1단계: generate_jsonld.sh / validate_posts.sh 각각에서
#          split_keywords_items() 함수 정의 블록만 추출해 텍스트가
#          바이트 단위로 동일한지 비교한다.
#   2단계: 추출한 함수를 실제로 실행해 아래 케이스들을 검증한다.
#          (a) 쉼표가 포함된 키워드 → 안쪽 쉼표는 보존되고 2개 항목으로 분리
#          (b) 평범한 케이스 → 3개 항목으로 분리
#          (c) 빈 문자열 입력 → 0개 항목, 에러 없이 처리
#
# 사용법:
#   bash scripts/test_split_keywords.sh
#
# exit code:
#   0 - 모든 검사를 통과함
#   1 - 하나 이상의 검사에서 실패함 (실패한 케이스를 함께 출력)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JSONLD_SCRIPT="${SCRIPT_DIR}/generate_jsonld.sh"
VALIDATE_SCRIPT="${SCRIPT_DIR}/validate_posts.sh"

failures=()

if [ ! -f "${JSONLD_SCRIPT}" ]; then
  echo "오류: ${JSONLD_SCRIPT} 파일을 찾을 수 없습니다."
  exit 1
fi
if [ ! -f "${VALIDATE_SCRIPT}" ]; then
  echo "오류: ${VALIDATE_SCRIPT} 파일을 찾을 수 없습니다."
  exit 1
fi

# split_keywords_items() 함수 정의 블록만 추출한다.
# "split_keywords_items() {" 로 시작하는 줄부터, 줄 전체가 "}" 하나뿐인
# 줄(함수를 닫는 줄)까지를 그대로 뽑아낸다.
extract_func() {
  local file="$1"
  awk '/^split_keywords_items\(\) \{/{flag=1} flag{print} flag && /^}$/{exit}' "${file}"
}

func_jsonld="$(extract_func "${JSONLD_SCRIPT}")"
func_validate="$(extract_func "${VALIDATE_SCRIPT}")"

if [ -z "${func_jsonld}" ]; then
  echo "오류: ${JSONLD_SCRIPT} 에서 split_keywords_items() 함수를 찾지 못했습니다."
  exit 1
fi
if [ -z "${func_validate}" ]; then
  echo "오류: ${VALIDATE_SCRIPT} 에서 split_keywords_items() 함수를 찾지 못했습니다."
  exit 1
fi

echo "=== 1단계: 두 파일의 split_keywords_items() 함수 텍스트 동일성 검사 ==="
if [ "${func_jsonld}" = "${func_validate}" ]; then
  echo "[PASS] 두 함수 정의가 바이트 단위로 동일합니다."
else
  echo "[FAIL] 두 함수 정의가 서로 다릅니다! diff 결과:"
  diff <(printf '%s\n' "${func_jsonld}") <(printf '%s\n' "${func_validate}")
  failures+=("1단계: 함수 동일성 검사")
fi

echo ""
echo "=== 2단계: 함수 동작 검사 ==="

# 테스트 대상 함수를 현재 쉘에 로드한다.
# (1단계에서 두 파일의 함수가 동일한지 이미 확인했으므로, 동일하다면 어느
#  쪽을 로드해도 결과는 같다. generate_jsonld.sh 쪽을 기준으로 로드한다.)
eval "${func_jsonld}"

# 케이스 하나를 실행하고 통과/실패를 판정한다.
# 사용법: run_case "이름" "입력" 기대항목수 [기대항목1] [기대항목2] ...
run_case() {
  local case_name="$1"
  local input="$2"
  local expected_count="$3"
  shift 3
  local expected_lines=("$@")

  local actual
  actual="$(split_keywords_items "${input}")"

  local actual_count=0
  if [ -n "${actual}" ]; then
    actual_count="$(printf '%s\n' "${actual}" | wc -l)"
  fi

  local pass=1

  if [ "${actual_count}" -ne "${expected_count}" ]; then
    pass=0
  fi

  if [ ${pass} -eq 1 ] && [ "${expected_count}" -gt 0 ]; then
    local i=0
    local line
    while IFS= read -r line; do
      if [ "${line}" != "${expected_lines[$i]}" ]; then
        pass=0
      fi
      i=$((i + 1))
    done <<< "${actual}"
  fi

  if [ ${pass} -eq 1 ]; then
    echo "[PASS] ${case_name}"
  else
    echo "[FAIL] ${case_name}"
    echo "        입력: ${input}"
    echo "        기대 항목 수: ${expected_count}, 실제 항목 수: ${actual_count}"
    echo "        실제 출력:"
    if [ -n "${actual}" ]; then
      printf '%s\n' "${actual}" | sed 's/^/          /'
    fi
    failures+=("${case_name}")
  fi
}

# (a) 쉼표가 포함된 키워드: 안쪽 쉼표는 보존되어 2개 항목으로 쪼개져야 함
run_case "케이스 a: 쉼표가 포함된 키워드" \
  '"물가, 상승", "금리"' \
  2 \
  '"물가, 상승"' ' "금리"'

# (b) 평범한 케이스: 3개 항목으로 쪼개져야 함
run_case "케이스 b: 평범한 케이스" \
  '"금리 인상", "기준금리", "물가"' \
  3 \
  '"금리 인상"' ' "기준금리"' ' "물가"'

# (c) 빈 문자열 입력: 0개 항목, 에러 없이 처리되어야 함
run_case "케이스 c: 빈 문자열 입력" \
  '' \
  0

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
