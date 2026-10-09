#!/usr/bin/env bash
#
# generate_jsonld.sh
#
# posts/ 폴더의 마크다운 글들을 읽어 각 글에 대한 SEO 구조화 데이터
# (JSON-LD, schema.org "BlogPosting")를 seo/jsonld/ 디렉터리에 생성한다.
# 실제 배포 경로가 아니라 로컬 산출물 "초안"이다.
#
#   - 파일명(YYYY-MM-DD-슬러그.md)에서 날짜와 슬러그를 추출한다.
#     (frontmatter에 date 필드가 있으면 그 값을 datePublished로 우선 사용한다.)
#   - frontmatter의 title은 headline으로, meta_description은 description으로,
#     keywords는 keywords 배열로 사용한다.
#   - 도메인은 아직 정해지지 않았으므로 플레이스홀더(https://example.com)를
#     사용하고, 실제 도메인으로 교체해야 함을 명시한다.
#     # TODO: 실제 도메인으로 교체 필요
#     # TODO: 로고 준비되면 publisher.logo 추가 필요
#
# 사용법:
#   bash scripts/generate_jsonld.sh
#
# 출력:
#   seo/jsonld/<슬러그>.json  (글마다 1개씩)

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POSTS_DIR="${REPO_ROOT}/posts"
SEO_DIR="${REPO_ROOT}/seo"
JSONLD_DIR="${SEO_DIR}/jsonld"

# TODO: 실제 배포 도메인이 정해지면 아래 값을 교체할 것 (플레이스홀더)
BASE_URL="https://example.com"

if [ ! -d "${POSTS_DIR}" ]; then
  echo "오류: posts 디렉터리를 찾을 수 없습니다: ${POSTS_DIR}"
  exit 1
fi

mkdir -p "${JSONLD_DIR}"

shopt -s nullglob
post_files=("${POSTS_DIR}"/*.md)
shopt -u nullglob

if [ ${#post_files[@]} -eq 0 ]; then
  echo "경고: ${POSTS_DIR} 안에 .md 파일이 없습니다. 생성할 파일이 없습니다."
fi

# JSON 문자열 안에 안전하게 넣을 수 있도록 이스케이프한다.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '%s' "${s}"
}

# keywords 배열 내부를 쉼표로 쪼갠다. 단, 쌍따옴표 안의 쉼표는 구분자로 보지
# 않는다("물가, 상승" 처럼 키워드 자체에 쉼표가 들어있으면 IFS=',' 단순 분리는
# 따옴표 경계를 무시하고 잘못 쪼개 stray quote가 섞여 들어간다, 2026-10-09 재현 확인).
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

file_count=0

for filepath in "${post_files[@]}"; do
  filename="$(basename "${filepath}")"

  # 파일명(YYYY-MM-DD-슬러그.md)에서 날짜/슬러그 추출
  if [[ "${filename}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.+)\.md$ ]]; then
    filename_date="${BASH_REMATCH[1]}"
    slug="${BASH_REMATCH[2]}"
  else
    echo "경고: '${filename}' 파일명이 YYYY-MM-DD-슬러그.md 형식이 아니라 건너뜁니다." >&2
    continue
  fi

  # frontmatter(--- ~ ---) 블록만 추출
  frontmatter="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "${filepath}")"

  # title
  title_line="$(echo "${frontmatter}" | grep -E '^title:' | head -n 1)"
  title="${title_line#title:}"
  title="$(echo "${title}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"

  # meta_description
  desc_line="$(echo "${frontmatter}" | grep -E '^meta_description:' | head -n 1)"
  meta_description="${desc_line#meta_description:}"
  meta_description="$(echo "${meta_description}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"

  # date (frontmatter 우선, 없으면 파일명 날짜)
  date_line="$(echo "${frontmatter}" | grep -E '^date:' | head -n 1)"
  fm_date="${date_line#date:}"
  fm_date="$(echo "${fm_date}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
  date_published="${fm_date:-${filename_date}}"

  # updated (frontmatter에 있으면 dateModified로 사용, 없으면 datePublished와 동일)
  updated_line="$(echo "${frontmatter}" | grep -E '^updated:' | head -n 1)"
  fm_updated="${updated_line#updated:}"
  fm_updated="$(echo "${fm_updated}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
  date_modified="${fm_updated:-${date_published}}"

  # keywords (예: keywords: ["금리 인상", "기준금리"])
  keywords_line="$(echo "${frontmatter}" | grep -E '^keywords:' | head -n 1)"
  keywords_raw="${keywords_line#keywords:}"

  if [[ "${keywords_raw}" == *"["*"]"* ]]; then
    # [ ... ] 사이 내용만 추출
    keywords_inner="${keywords_raw#*[}"
    keywords_inner="${keywords_inner%]*}"
    # 홑따옴표를 쌍따옴표로 통일 (frontmatter가 홑따옴표를 쓸 수도 있으므로)
    keywords_inner="$(echo "${keywords_inner}" | sed "s/'/\"/g")"
    keywords_inner="$(echo "${keywords_inner}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
    if [ -n "${keywords_inner}" ]; then
      # 각 항목을 json_escape()에 통과시킨다. 그대로 꽂아 넣으면 항목 안에
      # "나 \가 있을 때 유효하지 않은 JSON이 생성된다(2026-10-08 재현 확인).
      # 쪼개는 것 자체는 split_keywords_items()로 따옴표 안 쉼표를 보존한다
      # (2026-10-09 재현 확인: 단순 IFS=',' 분리는 "물가, 상승" 같은 키워드를
      # 두 조각으로 잘못 쪼갠다).
      keywords_json="["
      first=1
      while IFS= read -r kw_item; do
        kw_item_trimmed="$(echo "${kw_item}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        [ -z "${kw_item_trimmed}" ] && continue
        # 바깥 쌍따옴표를 벗겨내고 안쪽 내용만 이스케이프한다
        if [[ "${kw_item_trimmed}" =~ ^\"(.*)\"$ ]]; then
          kw_inner_value="${BASH_REMATCH[1]}"
        else
          kw_inner_value="${kw_item_trimmed}"
        fi
        if [ "${first}" -eq 1 ]; then
          keywords_json="${keywords_json}\"$(json_escape "${kw_inner_value}")\""
          first=0
        else
          keywords_json="${keywords_json}, \"$(json_escape "${kw_inner_value}")\""
        fi
      done < <(split_keywords_items "${keywords_inner}")
      keywords_json="${keywords_json}]"
    else
      keywords_json="[]"
    fi
  elif [ -n "$(echo "${keywords_raw}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')" ]; then
    # 배열 표기가 아니라 콤마로 구분된 문자열인 경우
    keywords_trimmed="$(echo "${keywords_raw}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
    keywords_json="["
    IFS=',' read -ra kw_parts <<< "${keywords_trimmed}"
    first=1
    for kw in "${kw_parts[@]}"; do
      kw="$(echo "${kw}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
      [ -z "${kw}" ] && continue
      if [ "${first}" -eq 1 ]; then
        keywords_json="${keywords_json}\"$(json_escape "${kw}")\""
        first=0
      else
        keywords_json="${keywords_json}, \"$(json_escape "${kw}")\""
      fi
    done
    keywords_json="${keywords_json}]"
  else
    keywords_json="[]"
  fi

  headline_escaped="$(json_escape "${title}")"
  description_escaped="$(json_escape "${meta_description}")"
  post_url="${BASE_URL}/posts/${slug}"

  # author (frontmatter에 있으면 Person, 없으면 기본 Organization "최신경제")
  author_line="$(echo "${frontmatter}" | grep -E '^author:' | head -n 1)"
  fm_author="${author_line#author:}"
  fm_author="$(echo "${fm_author}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"
  if [ -n "${fm_author}" ]; then
    author_type="Person"
    author_name="${fm_author}"
  else
    author_type="Organization"
    author_name="최신경제"
  fi
  author_name_escaped="$(json_escape "${author_name}")"

  output_file="${JSONLD_DIR}/${slug}.json"

  {
    echo "{"
    echo "  \"@context\": \"https://schema.org\","
    echo "  \"@type\": \"BlogPosting\","
    echo "  \"headline\": \"${headline_escaped}\","
    echo "  \"description\": \"${description_escaped}\","
    echo "  \"datePublished\": \"${date_published}\","
    echo "  \"dateModified\": \"${date_modified}\","
    echo "  \"keywords\": ${keywords_json},"
    echo "  \"url\": \"${post_url}\","
    echo "  \"author\": {"
    echo "    \"@type\": \"${author_type}\","
    echo "    \"name\": \"${author_name_escaped}\""
    echo "  },"
    echo "  \"publisher\": {"
    echo "    \"@type\": \"Organization\","
    echo "    \"name\": \"최신경제\""
    echo "  },"
    echo "  \"mainEntityOfPage\": {"
    echo "    \"@type\": \"WebPage\","
    echo "    \"@id\": \"${post_url}\""
    echo "  }"
    echo "}"
  } > "${output_file}"

  file_count=$((file_count + 1))
  echo "생성 완료: ${output_file}"
done

echo "총 ${file_count}건의 JSON-LD 파일을 ${JSONLD_DIR} 에 생성했습니다."
echo "주의: 도메인은 임시 플레이스홀더(${BASE_URL})입니다. TODO: 실제 도메인으로 교체 필요"
