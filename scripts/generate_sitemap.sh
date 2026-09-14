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

shopt -s nullglob
post_files=("${POSTS_DIR}"/*.md)
shopt -u nullglob

if [ ${#post_files[@]} -eq 0 ]; then
  echo "경고: ${POSTS_DIR} 안에 .md 파일이 없습니다. 빈 sitemap을 생성합니다."
fi

SITEMAP_FILE="${SEO_DIR}/sitemap.xml"
ROBOTS_FILE="${SEO_DIR}/robots.txt"

{
  echo '<?xml version="1.0" encoding="UTF-8"?>'
  echo '<!-- 초안(draft): 실제 배포 도메인이 정해지기 전까지 임시 플레이스홀더(https://example.com)를 사용 중입니다. -->'
  echo '<!-- TODO: 실제 도메인으로 교체 필요 -->'
  echo '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
  echo "  <url>"
  echo "    <loc>${BASE_URL}/</loc>"
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
      echo "  <!-- ${title} -->"
    fi
    echo "  <url>"
    echo "    <loc>${BASE_URL}/posts/${slug}</loc>"
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
