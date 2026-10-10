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
DISCLAIMER_KEYWORDS=(책임 투자 권장 대출)
# keywords 배열 항목이 따옴표로 감싸여 있는지 검사할 때 쓰는 정규식
# (쌍따옴표/홑따옴표 중 하나로 처음과 끝이 감싸여 있으면 통과)
KEYWORDS_ITEM_DOUBLE_QUOTED_REGEX='^"[^"]*"$'
KEYWORDS_ITEM_SINGLE_QUOTED_REGEX="^'[^']*'$"

# keywords 배열 내부를 쉼표로 쪼갠다. 단, 쌍따옴표 안의 쉼표는 구분자로 보지
# 않는다("물가, 상승" 처럼 키워드 자체에 쉼표가 들어있으면 IFS=',' 단순 분리는
# 따옴표 경계를 무시하고 잘못 쪼개 거짓 FAIL을 만들어낸다, 2026-10-10 재현 확인).
# scripts/generate_jsonld.sh의 동일 함수를 그대로 가져온 것이다(두 스크립트는
# 독립 실행 파일이라 공유 라이브러리로 추출하지 않고 복사해서 둔다).
split_keywords_items() {
  local s="$1"
  local current="" in_quotes=0 i char
  for (( i=0; i<${#s}; i++ )); do
    char="${s:$i:1}"
    if [ "${char}" = '"' ]; then
      in_quotes=$((1 - in_quotes))
      current="${current}${char}"
    elif [ "${char}" = ',' ] && [ "${in_quotes}" -eq 0 ]; then
      printf '%s\n' "${current}"
      current=""
    else
      current="${current}${char}"
    fi
  done
  if [ -n "${current}" ]; then
    printf '%s\n' "${current}"
  fi
}

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
  exit 0
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

  # 3-3) keywords 필드가 배열 형식([...])일 때, 그 안에 실제 항목이 있는지 검사
  #      "keywords: []"처럼 필드 자체는 존재하지만 대괄호 안이 공백뿐이면(빈 배열)
  #      SEO용 키워드가 0개인 것이므로 FAIL 처리한다. 배열 형식이 아닌 경우(단순 텍스트/
  #      콤마 구분 문자열 등)는 이 검사를 적용하지 않는다.
  keywords_line="$(echo "${frontmatter}" | sed -n -E '/^keywords:[[:space:]]*.+/{s/^keywords:[[:space:]]*//;p;q}')"
  if [[ "${keywords_line}" =~ ^\[(.*)\][[:space:]]*$ ]]; then
    keywords_inner="${BASH_REMATCH[1]}"
    keywords_trimmed="$(echo "${keywords_inner}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
    if [ -z "${keywords_trimmed}" ]; then
      file_problems+=("frontmatter의 keywords 배열이 비어 있습니다")
    fi
  fi

  # 3-5) keywords가 배열 형식([...])일 때, 그 안의 각 항목이 따옴표(쌍따옴표
  #      또는 홑따옴표)로 감싸여 있는지 검사한다. 예) keywords: [금리 인상, 기준금리]
  #      처럼 항목에 따옴표가 없으면 generate_jsonld.sh가 그 값을 그대로 JSON
  #      배열 원소 자리에 넣어 유효하지 않은 JSON(JSONDecodeError)을 만들어내므로,
  #      입구(validate_posts.sh)에서 미리 FAIL 처리한다. 배열 형식이 아닌 콤마
  #      구분 문자열(예: keywords: 금리, 기준금리)에는 적용하지 않는다
  #      (3-3과 동일하게 keywords_line이 ^\[(.*)\]...$ 에 매칭된 경우에만 검사).
  if [[ "${keywords_line}" =~ ^\[(.*)\][[:space:]]*$ ]] && [ -n "${keywords_trimmed}" ]; then
    keywords_unquoted_found=0
    while IFS= read -r kw_item; do
      kw_item_trimmed="$(echo "${kw_item}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      [ -z "${kw_item_trimmed}" ] && continue
      if [[ ! "${kw_item_trimmed}" =~ ${KEYWORDS_ITEM_DOUBLE_QUOTED_REGEX} ]] && [[ ! "${kw_item_trimmed}" =~ ${KEYWORDS_ITEM_SINGLE_QUOTED_REGEX} ]]; then
        keywords_unquoted_found=1
      fi
    done < <(split_keywords_items "${keywords_trimmed}")
    if [ ${keywords_unquoted_found} -eq 1 ]; then
      file_problems+=("frontmatter의 keywords 배열 항목에 따옴표가 없습니다 (예: [금리 인상] → [\"금리 인상\"])")
    fi
  fi

  # 3-4) title, meta_description 필드가 따옴표로는 감싸여 있지만 그 안이
  #      빈 문자열("")이거나 공백만("   ")인 경우를 검사한다.
  #      기존 3번 검사(^${field}:[[:space:]]*.+)는 콜론 뒤에 따옴표 2개만
  #      있어도 "문자가 있다"고 판단해 PASS 처리해버리므로, 그 공백을 메운다.
  for field in title meta_description; do
    field_line="$(echo "${frontmatter}" | sed -n -E "/^${field}:[[:space:]]*.+/{s/^${field}:[[:space:]]*//;p;q}")"
    if [[ "${field_line}" =~ ^\"(.*)\"[[:space:]]*$ ]]; then
      field_value="${BASH_REMATCH[1]}"
      field_trimmed="$(echo "${field_value}" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      if [ -z "${field_trimmed}" ]; then
        file_problems+=("frontmatter의 ${field}가 비어 있습니다 (따옴표 안 값이 비어있거나 공백뿐)")
      fi
    fi
  done

  # 3-1) meta_description 길이 검사 (SEO 권장: 약 160자 전후에서 스니펫이 잘림)
  #      이 검사는 CLAUDE.md가 정한 규칙이 아니므로 절대 FAIL 처리하지 않는다.
  #      file_problems/overall_status에 반영하지 않고 별도의 [WARN] 메시지로만 안내한다.
  #      한글 등 멀티바이트 문자를 바이트가 아닌 "글자 수"로 세기 위해 UTF-8 로케일에서
  #      wc -m 으로 계산한다 (LC_ALL=C.UTF-8, 스크립트 전역 로케일에는 영향 없음).
  meta_line="$(echo "${frontmatter}" | sed -n -E '/^meta_description:[[:space:]]*.+/{s/^meta_description:[[:space:]]*//;p;q}')"
  if [ -n "${meta_line}" ]; then
    if [[ "${meta_line}" =~ ^\"(.*)\"[[:space:]]*$ ]]; then
      meta_value="${BASH_REMATCH[1]}"
    else
      meta_value="${meta_line}"
    fi
    meta_length="$(LC_ALL=C.UTF-8 printf '%s' "${meta_value}" | LC_ALL=C.UTF-8 wc -m)"
    if [ "${meta_length}" -gt 160 ]; then
      echo "[WARN] ${filename}: meta_description 길이가 ${meta_length}자로 160자를 초과합니다 (검색 결과 스니펫에서 잘릴 수 있습니다)"
    fi
  fi

  # 3-2) frontmatter의 date 필드가 파일명의 날짜와 일치하는지 검사
  #      generate_sitemap.sh/generate_jsonld.sh는 frontmatter에 date가 있으면 그 값을
  #      lastmod/datePublished로 우선 사용하므로, 파일명 날짜와 다르면 틀린 날짜가 그대로
  #      SEO 산출물에 반영된다. frontmatter에 date 필드가 있을 때만 검사하며, 다르면 FAIL 처리한다.
  date_line="$(echo "${frontmatter}" | sed -n -E '/^date:[[:space:]]*.+/{s/^date:[[:space:]]*//;p;q}')"
  if [ -n "${date_line}" ]; then
    if [[ "${date_line}" =~ ^\"?([0-9]{4}-[0-9]{2}-[0-9]{2})\"? ]]; then
      frontmatter_date="${BASH_REMATCH[1]}"
      if [[ "${filename}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})- ]]; then
        filename_date="${BASH_REMATCH[1]}"
        if [ "${frontmatter_date}" != "${filename_date}" ]; then
          file_problems+=("frontmatter의 date(${frontmatter_date})가 파일명의 날짜(${filename_date})와 다릅니다")
        fi
      fi
    fi
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
