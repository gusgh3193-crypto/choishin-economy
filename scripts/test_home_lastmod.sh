#!/usr/bin/env bash
#
# test_home_lastmod.sh
#
# scripts/generate_sitemap.sh의 HOME_LASTMOD 계산 로직(66~87행)에 대한
# 회귀 테스트다.
#
#   배경: 이 로직은 홈페이지(<loc>${BASE_URL}/</loc>) 항목의 <lastmod>에
#   쓸 값을 "posts/ 전체 글의 lastmod(frontmatter date 우선, 없으면
#   파일명 날짜) 중 가장 최근(가장 큰) 날짜"로 계산한다. 코드 자체 주석에
#   "실제 각 글 URL의 lastmod 계산 로직 자체는 아래 본 루프에서 그대로
#   다시 계산한다"고 적혀 있을 만큼, 같은 종류의 날짜 계산을 두 곳(홈
#   lastmod 집계용 루프와 각 글 <url> 생성 루프)에서 독립적으로 수행하는
#   구조다. 이런 중복 계산 구조는 과거 split_keywords_items() 복붙 함수가
#   한쪽만 고쳐지고 다른 쪽이 안 고쳐져 최소 사흘 연속 같은 버그가
#   재발했던 것과 같은 유형의 위험이 있다(scripts/test_split_keywords.sh
#   참고). 그런데도 HOME_LASTMOD 계산값 자체가 올바른지 직접 확인하는
#   전용 회귀 테스트는 지금까지 없었다. 2026-11-09 마스터 지시로
#   회귀 테스트 공백을 메우기 위해 추가했다.
#
#   주의: 이 테스트는 posts/의 실제 글 파일을 절대 건드리지 않는다.
#   mktemp -d로 만든 임시 디렉터리 안에 scripts/generate_sitemap.sh
#   사본과 posts/, seo/ 구조를 흉내 낸 임시 환경을 통째로 구성해 그
#   사본을 실행한다(generate_sitemap.sh는 자기 자신의 위치를 기준으로
#   REPO_ROOT/POSTS_DIR/SEO_DIR을 계산하므로, 사본을 임시 디렉터리 안
#   scripts/ 밑에 두고 실행하면 그 임시 디렉터리 기준으로만 동작한다).
#
# 검사 내용:
#   1) [분기 발동 케이스] 파일명 날짜 순서로는 마지막으로 처리되는 글이
#      가장 최근이 아니고, 파일명 기준 "중간"에 있는 글이 frontmatter의
#      date 필드로 더 미래 날짜를 덮어써 실제 전체 최댓값이 되는 상황을
#      만든다. "가장 최근 날짜를 추적해 갱신"하는 비교 로직(84행의
#      candidate_lastmod > HOME_LASTMOD)이 아니라 "마지막으로 처리한 글의
#      값을 그냥 덮어쓰는" 식의 더 단순한(그리고 틀린) 구현이었다면 이
#      케이스에서 마지막 글의 날짜가 나왔을 것이다. 올바른 구현이라면
#      중간 글의 더 미래인 frontmatter date가 홈 <lastmod>가 되어야 한다.
#   2) [정상 케이스] frontmatter date 덮어쓰기 없이 파일명 날짜만으로
#      오름차순(처리 순서 = 날짜 순서)인 단순한 상황에서, 가장 나중 날짜가
#      그대로 홈 <lastmod>가 되는지 확인한다.
#
# 사용법:
#   bash scripts/test_home_lastmod.sh
#
# exit code:
#   0 - 모든 검사를 통과함
#   1 - 하나 이상의 검사에서 실패함 (실패 내용을 함께 출력)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITEMAP_SCRIPT="${SCRIPT_DIR}/generate_sitemap.sh"

failures=()

if [ ! -f "${SITEMAP_SCRIPT}" ]; then
  echo "오류: ${SITEMAP_SCRIPT} 파일을 찾을 수 없습니다."
  exit 1
fi

# 홈페이지 <lastmod> 값만 뽑아낸다. sitemap.xml 안에서 홈 <url> 블록은
# <loc>${BASE_URL}/</loc>를 담은 첫 번째 <url> 블록이며, 각 글의
# <url><loc>${BASE_URL}/posts/...</loc></url> 블록과는 </url> 태그로
# 구분된다. 홈 <url> 블록만 떼어내 그 안의 <lastmod> 값을 출력한다.
extract_home_lastmod() {
  local sitemap_file="$1"
  awk '
    /<url>/ { in_url=1; block="" }
    in_url { block = block $0 "\n" }
    /<\/url>/ {
      if (block ~ /<loc>https:\/\/example\.com\/<\/loc>/) {
        if (match(block, /<lastmod>[^<]*<\/lastmod>/)) {
          val = substr(block, RSTART + 9, RLENGTH - 9 - 10)
          print val
        }
        exit
      }
      in_url=0
    }
  ' "${sitemap_file}"
}

run_case() {
  local case_name="$1"
  shift
  local expected_lastmod="$1"
  shift
  # 나머지 인자: "파일명|frontmatter date 줄(비어있으면 date 필드 생성 안 함)" 쌍
  local -a post_specs=("$@")

  local tmp_dir
  tmp_dir="$(mktemp -d)"
  mkdir -p "${tmp_dir}/scripts" "${tmp_dir}/posts" "${tmp_dir}/seo"
  cp "${SITEMAP_SCRIPT}" "${tmp_dir}/scripts/generate_sitemap.sh"

  local spec filename fm_date post_file
  for spec in "${post_specs[@]}"; do
    filename="${spec%%|*}"
    fm_date="${spec#*|}"
    post_file="${tmp_dir}/posts/${filename}"
    {
      echo "---"
      echo "title: \"${case_name} 임시 글 (${filename})\""
      echo "meta_description: \"test_home_lastmod.sh가 만든 임시 테스트용 글\""
      echo "keywords: [\"테스트\"]"
      if [ -n "${fm_date}" ]; then
        echo "date: ${fm_date}"
      fi
      echo "---"
      echo ""
      echo "이 글은 scripts/test_home_lastmod.sh가 만든 임시 테스트용 글입니다."
      echo "posts/ 실제 디렉터리에는 저장되지 않습니다."
    } > "${post_file}"
  done

  local run_output run_status
  run_output="$(bash "${tmp_dir}/scripts/generate_sitemap.sh" 2>&1)"
  run_status=$?

  local sitemap_file="${tmp_dir}/seo/sitemap.xml"
  local actual_lastmod=""
  local ok=1

  if [ ${run_status} -ne 0 ]; then
    ok=0
  elif [ ! -f "${sitemap_file}" ]; then
    ok=0
  else
    actual_lastmod="$(extract_home_lastmod "${sitemap_file}")"
    if [ "${actual_lastmod}" != "${expected_lastmod}" ]; then
      ok=0
    fi
  fi

  if [ ${ok} -eq 1 ]; then
    echo "[PASS] ${case_name} (홈 <lastmod>: ${actual_lastmod})"
  else
    echo "[FAIL] ${case_name}"
    echo "        기대 홈 <lastmod>: ${expected_lastmod}"
    echo "        실제 홈 <lastmod>: ${actual_lastmod:-(없음)}"
    echo "        generate_sitemap.sh 실행 exit code: ${run_status}"
    if [ -f "${sitemap_file}" ]; then
      echo "        생성된 sitemap.xml:"
      sed 's/^/          /' "${sitemap_file}"
    fi
    failures+=("${case_name}")
  fi

  rm -rf "${tmp_dir}"
}

echo "=== 검사 1: 분기 발동 케이스 (중간 글의 frontmatter date 덮어쓰기가 전체 최댓값이 되어야 함) ==="
# 처리 순서(파일명 알파벳/날짜 순): early -> middle_override -> late
# late(2026-03-20)가 마지막으로 처리되지만, 전체 최댓값은 middle_override의
# frontmatter date(2026-06-01)다. "마지막 값을 그냥 덮어쓰는" 틀린 구현이면
# 2026-03-20이 나오고, "최댓값을 추적"하는 올바른 구현이면 2026-06-01이 나온다.
run_case "분기 발동 케이스" "2026-06-01" \
  "2026-01-10-early.md|" \
  "2026-02-15-middle-override.md|2026-06-01" \
  "2026-03-20-late.md|"

echo ""
echo "=== 검사 2: 정상 케이스 (frontmatter 덮어쓰기 없이 파일명 날짜 오름차순) ==="
run_case "정상 케이스" "2026-01-02" \
  "2026-01-01-first.md|" \
  "2026-01-02-second.md|"

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
