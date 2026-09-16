#!/usr/bin/env bash
#
# validate_posts.sh
#
# posts/ 폴더의 모든 마크다운 글이 CLAUDE.md 콘텐츠 규칙을 지키는지 검증한다.
#   1) 파일명이 YYYY-MM-DD-슬러그.md 형식을 따르는가
#   2) frontmatter(--- ~ ---)에 title, meta_description, keywords 필드가 모두 있는가
#   3) 본문에 이탤릭(*...*) 처리된 면책 문구(책임/투자/권장 등 키워드 포함)가 있는가
#
# 사용법:
#   bash scripts/validate_posts.sh
#
# exit code:
#   0 - 모든 글이 규칙을 통과함
#   1 - 하나 이상의 글에서 문제가 발견됨

set -u

# 스크립트 위치 기준으로 저장소 루트/posts 디렉터리를 찾는다.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POSTS_DIR="${REPO_ROOT}/posts"

FILENAME_REGEX='^[0-9]{4}-[0-9]{2}-[0-9]{2}-.+\.md$'
REQUIRED_FIELDS=(title meta_description keywords)
# 면책 문구로 인정할 키워드 (이탤릭 처리된 한 줄 안에 하나 이상 포함되어야 함)
DISCLAIMER_KEYWORDS=(책임 투자 권장)

overall_status=0
file_count=0

if [ ! -d "${POSTS_DIR}" ]; then
  echo "오류: posts 디렉터리를 찾을 수 없습니다: ${POSTS_DIR}"
  exit 1
fi

shopt -s nullglob
post_files=("${POSTS_DIR}"/*.md)
shopt -u nullglob

if [ ${#post_files[@]} -eq 0 ]; then
  echo "경고: ${POSTS_DIR} 안에 검사할 .md 파일이 없습니다."
  exit 1
fi

for filepath in "${post_files[@]}"; do
  file_count=$((file_count + 1))
  filename="$(basename "${filepath}")"
  file_problems=()

  # 1) 파일명 형식 검사
  if [[ ! "${filename}" =~ ${FILENAME_REGEX} ]]; then
    file_problems+=("파일명이 YYYY-MM-DD-슬러그.md 형식이 아닙니다 (현재: ${filename})")
  fi

  # 2) frontmatter 추출 (첫 번째 '---' 와 두 번째 '---' 사이)
  if [ "$(head -n 1 "${filepath}")" != "---" ]; then
    file_problems+=("파일 시작 부분에 frontmatter(---)가 없습니다")
    frontmatter=""
  else
    # 2번째 줄부터 다음 '---' 줄 전까지 추출
    frontmatter="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "${filepath}")"
  fi

  # 3) 필수 필드 검사
  if [ -n "${frontmatter}" ] || [[ ! " ${file_problems[*]} " == *"frontmatter"* ]]; then
    for field in "${REQUIRED_FIELDS[@]}"; do
      if ! echo "${frontmatter}" | grep -qE "^${field}:[[:space:]]*.+"; then
        file_problems+=("frontmatter에 '${field}' 필드가 없거나 비어 있습니다")
      fi
    done
  fi

  # 4) 면책 문구 검사
  #    frontmatter 이후 본문에서, 이탤릭(*...*) 처리된 한 줄 중
  #    면책성 키워드(책임/투자/권장 등)를 포함한 줄이 하나라도 있는지 확인한다.
  #    (굵게 처리된 **...** 줄은 첫 글자가 '*'가 연속되므로 아래 정규식에서 자연스럽게 제외된다.)
  body="$(awk 'BEGIN{fence=0} /^---[[:space:]]*$/{fence++; next} fence>=2{print}' "${filepath}")"
  disclaimer_found=0
  while IFS= read -r line; do
    if [[ "${line}" =~ ^\*[^*].*[^*]\*[[:space:]]*$ ]]; then
      for kw in "${DISCLAIMER_KEYWORDS[@]}"; do
        if [[ "${line}" == *"${kw}"* ]]; then
          disclaimer_found=1
          break
        fi
      done
    fi
    [ ${disclaimer_found} -eq 1 ] && break
  done <<< "${body}"

  if [ ${disclaimer_found} -eq 0 ]; then
    file_problems+=("본문에 면책 문구(이탤릭 처리 + 책임/투자/권장 등 키워드 포함)가 없습니다")
  fi

  if [ ${#file_problems[@]} -eq 0 ]; then
    echo "[PASS] ${filename}"
  else
    overall_status=1
    echo "[FAIL] ${filename}"
    for problem in "${file_problems[@]}"; do
      echo "        - ${problem}"
    done
  fi
done

echo ""
echo "검사한 파일 수: ${file_count}"

if [ ${overall_status} -eq 0 ]; then
  echo "모든 글이 frontmatter(title, meta_description, keywords), 파일명, 면책 문구 규칙을 통과했습니다."
else
  echo "일부 글에서 문제가 발견되었습니다. 위 [FAIL] 항목을 확인해 수정하세요."
fi

exit ${overall_status}
