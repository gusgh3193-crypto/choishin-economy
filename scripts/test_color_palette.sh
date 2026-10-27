#!/usr/bin/env bash
#
# test_color_palette.sh
#
# design/site.css의 :root 블록에 정의된 9개 색상 변수 값이
# design/color-palette.md "## 1. 팔레트 요약 표"에 적힌 hex 코드와
# 정확히 일치하는지 자동으로 검증하는 회귀 테스트다.
#
#   배경: 디자인팀의 명도 대비 계산(design/color-palette.md 2번)은
#   1번 표에 적힌 hex 값을 기준으로 이뤄져 있다. site.css의 :root
#   변수가 이 표의 값과 어긋나면 그 계산 전체가 실제 사이트 색상과
#   맞지 않게 된다. 지금까지는 사람이 두 문서를 눈으로 대조해왔는데
#   (예: 2026-10-01 로그), scripts/generate_jsonld.sh와
#   scripts/validate_posts.sh 사이의 복붙 함수 불일치가 반복됐던
#   전례처럼 수동 대조는 언젠가 다시 놓칠 위험이 있어 이 테스트로
#   자동화한다. (scripts/test_split_keywords.sh의 "자동 추출 → 비교
#   → PASS/FAIL 출력 → exit code" 패턴을 그대로 따른다.)
#
# 검사 내용:
#   site.css :root 블록에서 9개 CSS 변수와 hex 값을 자동으로 추출하고,
#   color-palette.md 1번 표에서 같은 "용도"의 hex 값을 자동으로
#   추출해, 9개 항목 각각에 대해 대소문자 무관하게 정확히 일치하는지
#   비교하고 PASS/FAIL을 출력한다.
#
# 사용법:
#   bash scripts/test_color_palette.sh [site.css 경로] [color-palette.md 경로]
#   (경로를 생략하면 design/site.css, design/color-palette.md 를 사용한다.
#    경로를 다르게 지정하면 복사본/스크래치 파일로도 검증해볼 수 있다.)
#
# exit code:
#   0 - 모든 검사를 통과함
#   1 - 하나 이상의 검사에서 실패함 (불일치 항목을 함께 출력)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSS_FILE="${1:-${SCRIPT_DIR}/../design/site.css}"
MD_FILE="${2:-${SCRIPT_DIR}/../design/color-palette.md}"

if [ ! -f "${CSS_FILE}" ]; then
  echo "오류: ${CSS_FILE} 파일을 찾을 수 없습니다."
  exit 1
fi
if [ ! -f "${MD_FILE}" ]; then
  echo "오류: ${MD_FILE} 파일을 찾을 수 없습니다."
  exit 1
fi

failures=()

# 9개 CSS 변수 이름과, color-palette.md 1번 표에서 같은 색을 가리키는
# "용도" 문자열의 매핑. (표에는 있지만 CSS 변수가 따로 없는 "소제목 H2"
# 행은 건너뛴다. --color-heading이 H1/H2 공용이기 때문.)
var_names=(
  "--color-bg"
  "--color-text"
  "--color-heading"
  "--color-link"
  "--color-link-visited"
  "--color-warning-bg"
  "--color-warning-text"
  "--color-table-header-bg"
  "--color-table-header-text"
)

usages=(
  "배경 (본문 페이지)"
  "본문 텍스트"
  "소제목 H1"
  "링크 (방문 전)"
  "링크 (방문 후)"
  "면책 문구/경고 박스 배경"
  "면책 문구/경고 박스 텍스트"
  "표(table) 헤더 배경"
  "표(table) 헤더 텍스트"
)

# --- 1. site.css :root { ... } 블록 추출 ---

extract_root_block() {
  awk '/:root[[:space:]]*\{/{flag=1} flag{print} flag && /^[[:space:]]*\}/{exit}' "${CSS_FILE}"
}

root_block="$(extract_root_block)"

if [ -z "${root_block}" ]; then
  echo "오류: ${CSS_FILE} 에서 :root 블록을 찾지 못했습니다."
  exit 1
fi

# 변수 이름을 받아 :root 블록에서 해당 변수의 hex 값을 추출한다.
get_css_value() {
  local name="$1"
  printf '%s\n' "${root_block}" \
    | grep -oE -- "${name}:[[:space:]]*#[0-9A-Fa-f]{3,8}" \
    | head -n 1 \
    | sed -E 's/^[^:]+:[[:space:]]*//'
}

# --- 2. color-palette.md "## 1. 팔레트 요약 표" 섹션 추출 ---

extract_table_block() {
  awk '
    /^## 1\. 팔레트 요약 표/ { infile=1; next }
    infile && /^## / { exit }
    infile { print }
  ' "${MD_FILE}"
}

table_block="$(extract_table_block)"

if [ -z "${table_block}" ]; then
  echo "오류: ${MD_FILE} 에서 '## 1. 팔레트 요약 표' 섹션을 찾지 못했습니다."
  exit 1
fi

# "용도" 문자열을 받아 표에서 해당 행의 hex 값(색상 코드 열)을 추출한다.
get_md_value() {
  local usage="$1"
  printf '%s\n' "${table_block}" \
    | grep -F "| ${usage} |" \
    | head -n 1 \
    | awk -F'|' '{print $3}' \
    | grep -oE '#[0-9A-Fa-f]{3,8}'
}

# --- 3. 9개 변수 각각에 대해 비교 ---

echo "=== site.css :root 변수 ↔ color-palette.md 1번 표 hex 값 일치 검사 ==="

for i in "${!var_names[@]}"; do
  name="${var_names[$i]}"
  usage="${usages[$i]}"

  css_val="$(get_css_value "${name}")"
  md_val="$(get_md_value "${usage}")"

  if [ -z "${css_val}" ]; then
    echo "[FAIL] ${name} (${usage}): site.css의 :root 블록에서 값을 찾지 못했습니다."
    failures+=("${name}: site.css에서 값을 찾지 못함")
    continue
  fi

  if [ -z "${md_val}" ]; then
    echo "[FAIL] ${name} (${usage}): color-palette.md 1번 표에서 '${usage}' 행을 찾지 못했습니다."
    failures+=("${name}: color-palette.md에서 값을 찾지 못함")
    continue
  fi

  css_val_lc="$(printf '%s' "${css_val}" | tr '[:upper:]' '[:lower:]')"
  md_val_lc="$(printf '%s' "${md_val}" | tr '[:upper:]' '[:lower:]')"

  if [ "${css_val_lc}" = "${md_val_lc}" ]; then
    echo "[PASS] ${name} (${usage}): ${css_val}"
  else
    echo "[FAIL] ${name} (${usage}): site.css=${css_val}, color-palette.md=${md_val}"
    failures+=("${name} (${usage}): site.css=${css_val} vs color-palette.md=${md_val}")
  fi
done

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
