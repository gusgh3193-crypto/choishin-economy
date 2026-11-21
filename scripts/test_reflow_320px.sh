#!/usr/bin/env bash
#
# test_reflow_320px.sh
#
# design/mockup-2026-09-13-interest-rate-impact.html을 Playwright(headless
# Chromium)로 CSS 뷰포트 320px 폭으로 렌더링해, WCAG 1.4.10(리플로우)
# 접근성 기준을 자동으로 검증하는 회귀 테스트다.
#
#   배경: 2026-11-18에 개발팀이 이 mockup을 Playwright로 320px 뷰포트
#   렌더링해 가로 스크롤 발생 여부, 주요 요소(H1/H2/본문 단락/
#   .table-wrapper/.disclaimer)의 뷰포트 넘침 여부, 형제 블록 간 겹침
#   여부를 실측하고 스크린샷(design/render-check-2026-11-18-reflow-320px.png)
#   을 저장했다(daily-logs/2026-11-18.md). 하지만 이는 그날 한 번만 수행한
#   수동(one-off) 점검이었고 scripts/daily_check.sh의 자동 회귀 테스트
#   목록에는 포함되지 않아, 이후 design/mockup-*.html이나 design/site.css가
#   바뀌어 320px에서 가로 스크롤/겹침이 생겨도 자동으로 잡아낼 수 없었다.
#   이 공백을 메우기 위해 2026-11-20 마스터 지시로 추가했다.
#
# 검사 내용(scripts/check_reflow_320px.js로 실측한 값을 2026-11-18
# 실측 기준값과 비교):
#   1) document.documentElement.scrollWidth === clientWidth
#      (가로 스크롤 없음)
#   2) H1, H2, 본문 단락(p, post-date/disclaimer 제외), .table-wrapper,
#      .disclaimer, .post-date 각각이 뷰포트를 오른쪽으로 넘치지 않음
#      (overflowsRight: false). .post-date는 2026-11-20 디자인팀 보완
#      제안(design/review-2026-09-13-interest-rate-impact.md)에 따라
#      2026-11-21 개발팀이 검사 대상에 추가했다.
#   3) .page 직계 자식(형제 블록) 간 겹침이 없음(overlapPairs: [])
#
# 기존 design/mockup-*.html, design/site.css는 전혀 수정하지 않고 읽기만
# 한다. 스크린샷은 임시 디렉터리에만 저장하고 저장소에는 남기지 않는다
# (design/render-check-2026-11-18-reflow-320px.png는 2026-11-18 수동 점검
# 산출물이므로 건드리지 않는다).
#
# 사용법:
#   bash scripts/test_reflow_320px.sh [mockup.html 경로]
#   (경로를 생략하면 design/mockup-2026-09-13-interest-rate-impact.html을 사용한다.)
#
# exit code:
#   0 - 모든 검사를 통과함
#   1 - 하나 이상의 검사에서 실패함 (불일치 항목을 함께 출력)
#   2 - 렌더링 자체에 실패함(Playwright/Node.js 오류, 파일 없음 등)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOCKUP_FILE="${1:-${SCRIPT_DIR}/../design/mockup-2026-09-13-interest-rate-impact.html}"
CHECK_JS="${SCRIPT_DIR}/check_reflow_320px.js"

if [ ! -f "${MOCKUP_FILE}" ]; then
  echo "오류: ${MOCKUP_FILE} 파일을 찾을 수 없습니다."
  exit 2
fi

if [ ! -f "${CHECK_JS}" ]; then
  echo "오류: ${CHECK_JS} 파일을 찾을 수 없습니다."
  exit 2
fi

if ! command -v node >/dev/null 2>&1; then
  echo "오류: node 명령을 찾을 수 없어 320px 리플로우를 렌더링/검증할 수 없습니다."
  exit 2
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "오류: python3 명령을 찾을 수 없어 렌더링 결과(JSON)를 검증할 수 없습니다."
  exit 2
fi

SCRATCH_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${SCRATCH_DIR}"
}
trap cleanup EXIT

SCREENSHOT_FILE="${SCRATCH_DIR}/reflow-320px.png"

echo "=== design/mockup-2026-09-13-interest-rate-impact.html 320px 리플로우 회귀 테스트 ==="
echo "대상 파일: ${MOCKUP_FILE}"

render_json="$(node "${CHECK_JS}" "${MOCKUP_FILE}" "${SCREENSHOT_FILE}" 2>&1 1>"${SCRATCH_DIR}/result.json")"
render_status=$?

if [ ${render_status} -ne 0 ]; then
  echo "오류: Playwright 렌더링에 실패했습니다."
  echo "${render_json}"
  exit 2
fi

if [ -n "${render_json}" ]; then
  # node 스크립트가 stderr로 경고를 출력한 경우 참고용으로 보여준다.
  echo "참고(stderr): ${render_json}"
fi

check_output="$(python3 - "${SCRATCH_DIR}/result.json" <<'PYEOF'
import json
import sys

path = sys.argv[1]

try:
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
except Exception as e:
    print(f"FATAL|렌더링 결과(JSON) 파싱 실패: {e}")
    sys.exit(2)

failures = []

# 1) 가로 스크롤 없음: scrollWidth == clientWidth
scroll_width = data.get("scrollWidth")
client_width = data.get("clientWidth")
has_horizontal_scroll = data.get("hasHorizontalScroll")

if has_horizontal_scroll or scroll_width != client_width:
    failures.append(
        f"가로 스크롤 발생: scrollWidth={scroll_width}, clientWidth={client_width} "
        f"(2026-11-18 기준값: scrollWidth==clientWidth==320, 가로 스크롤 없음)"
    )
else:
    print(f"PASS|가로 스크롤 없음 (scrollWidth={scroll_width}, clientWidth={client_width})")

# 2) 주요 요소 overflowsRight: false
expected_counts = {
    "h1": 1,
    "h2": 6,
    "p.body": 7,
    ".table-wrapper": 1,
    ".disclaimer": 1,
    ".post-date": 1,
}

elements = data.get("elements", [])
counts = {}
for el in elements:
    selector = el.get("selector")
    counts[selector] = counts.get(selector, 0) + 1
    if el.get("overflowsRight"):
        failures.append(
            f"{selector}[{el.get('index')}]가 뷰포트를 오른쪽으로 넘칩니다: "
            f"rect={el.get('rect')} (2026-11-18 기준값: overflowsRight=false)"
        )
    else:
        print(f"PASS|{selector}[{el.get('index')}] overflowsRight=false")

for selector, expected in expected_counts.items():
    actual = counts.get(selector, 0)
    if actual != expected:
        failures.append(
            f"{selector} 개수가 2026-11-18 기준값과 다릅니다: 실측 {actual}개, 기준 {expected}개 "
            f"(mockup.html 구조가 바뀌었을 수 있습니다)"
        )
    else:
        print(f"PASS|{selector} 개수 일치 ({actual}개)")

# 3) 형제 블록 간 겹침 없음
overlap_pairs = data.get("overlapPairs", [])
if overlap_pairs:
    for pair in overlap_pairs:
        failures.append(f"형제 블록 겹침 발생: {pair} (2026-11-18 기준값: overlapPairs=[])")
else:
    print("PASS|형제 블록 간 겹침 없음 (overlapPairs=[])")

if failures:
    for f in failures:
        print(f"FAIL|{f}")
    sys.exit(1)

sys.exit(0)
PYEOF
)"
check_status=$?

echo "${check_output}" | while IFS= read -r line; do
  case "${line}" in
    PASS\|*) echo "[PASS] ${line#PASS|}" ;;
    FAIL\|*) echo "[FAIL] ${line#FAIL|}" ;;
    FATAL\|*) echo "[FATAL] ${line#FATAL|}" ;;
    *) [ -n "${line}" ] && echo "${line}" ;;
  esac
done

echo ""
if [ ${check_status} -eq 0 ]; then
  echo "모든 검사를 통과했습니다."
elif [ ${check_status} -eq 2 ]; then
  echo "렌더링 결과를 검증하는 중 치명적 오류가 발생했습니다."
else
  echo "다음 검사에서 실패했습니다. 위 [FAIL] 항목을 확인하세요."
fi

exit ${check_status}
