#!/usr/bin/env bash
#
# generate_sitemap.sh
#
# posts/ 폴더의 마크다운 글들을 읽어 SEO 초안용 sitemap.xml / robots.txt를
# seo/ 디렉터리에 생성한다. 실제 배포 경로가 아니라 로컬 산출물 "초안"이다.
#
#   - 파일명(YYYY-MM-DD-슬러그.md)에서 날짜와 슬러그를 추출한다.
#     (frontmatter에 date 필드가 있으면 그 값을 lastmod로 우선 사용한다.)
#   - frontmatter의 title은 XML 주석으로 참고용으로 남긴다.
#   - 도메인은 아직 정해지지 않았으므로 플레이스홀더(https://example.com)를
#     사용하고, 실제 도메인으로 교체해야 함을 명시한다.
#
# 사용법:
#   bash scripts/generate_sitemap.sh
#
# 출력:
#   seo/sitemap.xml
#   seo/robots.txt

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POSTS_DIR="${REPO_ROOT}/posts"
SEO_DIR="${REPO_ROOT}/seo"

# TODO: 실제 배포 도메인이 정해지면 아래 값을 교체할 것 (플레이스홀더)
BASE_URL="https://example.com"

if [ ! -d "${POSTS_DIR}" ]; then
  echo "오류: posts 디렉터리를 찾을 수 없습니다: ${POSTS_DIR}"
  exit 1
fi

mkdir -p "${SEO_DIR}"

# XML 특수문자를 이스케이프한다. <loc>(PCDATA)에 날 것(raw)으로 들어가는
# & / < / > 는 well-formed XML을 깨뜨릴 수 있고, XML 주석(<!-- ... -->)
# 안에서도 그대로 보존할 필요가 없으므로(이스케이프해도 사람이 읽는 데는
# 문제가 없다) title/slug 모두 이 함수를 통과시킨다.
xml_escape() {
  local s="$1"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  s="${s//\'/&apos;}"
  printf '%s' "${s}"
}

shopt -s nullglob
post_files=("${POSTS_DIR}"/*.md)
shopt -u nullglob

if [ ${#post_files[@]} -eq 0 ]; then
  echo "경고: ${POSTS_DIR} 안에 .md 파일이 없습니다. 빈 sitemap을 생성합니다."
fi

SITEMAP_FILE="${SEO_DIR}/sitemap.xml"
ROBOTS_FILE="${SEO_DIR}/robots.txt"

# 홈페이지 <lastmod>에 쓸 값을 먼저 구한다: posts/ 전체 글의 lastmod(프런트매터
# date 우선, 없으면 파일명 날짜) 중 가장 최근(가장 큰) 날짜.
# 실제 각 글 URL의 lastmod 계산 로직 자체는 아래 본 루프에서 그대로 다시 계산한다.
HOME_LASTMOD=""

for filepath in "${post_files[@]}"; do
  filename="$(basename "${filepath}")"

  if [[ "${filename}" =~ ^([0-9]{4}-[0-9]{2}-[0-9]{2})-(.+)\.md$ ]]; then
    filename_date="${BASH_REMATCH[1]}"
  else
    continue
  fi

  frontmatter="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "${filepath}")"
  date_line="$(echo "${frontmatter}" | grep -E '^date:' | head -n 1)"
  fm_date="${date_line#date:}"
  fm_date="$(echo "${fm_date}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  candidate_lastmod="${fm_date:-${filename_date}}"

  if [ -z "${HOME_LASTMOD}" ] || [[ "${candidate_lastmod}" > "${HOME_LASTMOD}" ]]; then
    HOME_LASTMOD="${candidate_lastmod}"
  fi
done

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<!-- 초안(draft): 실제 배포 도메인이 정해지기 전까지 임시 플레이스홀더(https://example.com)를 사용 중입니다. -->'
  echo '<!-- TODO: 실제 도메인으로 교체 필요 -->'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  echo "  <url>"
  echo "    <loc>${BASE_URL}/</loc>"
  if [ -n "${HOME_LASTMOD}" ]; then
    echo "    <lastmod>${HOME_LASTMOD}</lastmod>"
  fi
  echo "  </url>"
} > "${SITEMAP_FILE}"

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

  # frontmatter에서 title, date 추출 (있으면 사용, 없으면 파일명 기준값 사용)
  frontmatter="$(awk 'NR==1{next} /^---[[:space:]]*$/{exit} {print}' "${filepath}")"

  title_line="$(echo "${frontmatter}" | grep -E '^title:' | head -n 1)"
  title="${title_line#title:}"
  title="$(echo "${title}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/^"//' -e 's/"$//')"

  date_line="$(echo "${frontmatter}" | grep -E '^date:' | head -n 1)"
  fm_date="${date_line#date:}"
  fm_date="$(echo "${fm_date}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"

  lastmod="${fm_date:-${filename_date}}"

  {
    if [ -n "${title}" ]; then
      escaped_title="$(xml_escape "${title}")"
      # XML 주석(<!-- ... -->) 안에는 "--" 시퀀스가 올 수 없으므로(well-formed
      # XML 위반), title에 "--"가 포함되어 있으면 손실 없이 안전하게 치환할
      # 보편적인 규칙이 없어 가장 안전한 방법으로 주석 생성 자체를 건너뛴다.
      if [[ "${escaped_title}" != *"--"* ]]; then
        echo "  <!-- ${escaped_title} -->"
      fi
    fi
    echo "  <url>"
    echo "    <loc>${BASE_URL}/posts/$(xml_escape "${slug}")</loc>"
    echo "    <lastmod>${lastmod}</lastmod>"
    echo "  </url>"
  } >> "${SITEMAP_FILE}"

  file_count=$((file_count + 1))
done

echo "</urlset>" >> "${SITEMAP_FILE}"

{
  echo "# 초안(draft): 실제 배포 도메인이 정해지기 전까지 임시 값입니다."
  echo "# TODO: 실제 도메인으로 교체 필요"
  echo "User-agent: *"
  echo "Allow: /"
  echo ""
  echo "Sitemap: ${BASE_URL}/sitemap.xml"
} > "${ROBOTS_FILE}"

echo "생성 완료: ${SITEMAP_FILE} (글 ${file_count}건 반영)"
echo "생성 완료: ${ROBOTS_FILE}"
