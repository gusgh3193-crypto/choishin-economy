// check_card_test_fixtures_render.js
//
// 목적: design/card-template-overflow-test.html, design/card-template-reconciled-test.html
// 두 "카드뉴스 오버플로/글자 수 테스트" 픽스처를 Playwright(headless Chromium)로
// 데스크톱(1280x900)과 모바일(375x800) 두 뷰포트에서 각각 렌더링해 스크린샷을 저장하고,
// 각 뷰포트에서 .card.ratio-1-1 / .card.ratio-4-5 두 카드의 실제 크기·오버플로 여부
// (clientHeight vs scrollHeight)를 측정한다.
//
// design/card-template-guide.md의 과거 측정(2026-10-13/14/20, 11-17)은 모두
// 뷰포트 1280x900(또는 1400x1600, 1080px 강제 주입) 고정이었고, 카드 자체는
// width: min(90vw, 440px)로 뷰포트에 반응하는 vw 기반 박스다. 즉 "데스크톱 폭에서는
// 440px로 캡핑되어 안전해도, 모바일처럼 좁은 뷰포트(375px)에서는 90vw가 440px보다
// 작아져(375 * 0.9 = 337.5px) 카드 자체가 더 좁아지고, 내부 padding(6%)도 함께
// 줄어들어 오버플로 여유가 달라질 수 있다" — 이 모바일 폭 케이스는 과거 기록
// 어디에도 없었으므로, 이번에 데스크톱/모바일 두 뷰포트를 모두 측정하도록 했다.
//
// 이 스크립트는 Bash가 없는 디자인팀이 작성만 했고, 실행/결과 확인은 하지 못했다.
// 반드시 마스터(또는 Bash가 있는 다른 팀)가 직접 실행해서 PASS/FAIL과 스크린샷
// 육안 확인을 해야 한다.
//
// 사용법 (저장소 루트에서):
//   node scripts/check_card_test_fixtures_render.js [출력 디렉터리]
//
// 출력 디렉터리 기본값: design/ (미지정 시)
// 생성되는 파일 (출력 디렉터리 기준, 날짜는 실행일로 바뀔 수 있으니 실행 후 직접 확인):
//   render-check-<오늘날짜>-overflow-test-desktop-1280.png
//   render-check-<오늘날짜>-overflow-test-mobile-375.png
//   render-check-<오늘날짜>-reconciled-test-desktop-1280.png
//   render-check-<오늘날짜>-reconciled-test-mobile-375.png
//
// 표준출력: 아래 형태의 JSON 배열 (파일 × 뷰포트 × 카드 비율 조합별 측정 결과)
//   [
//     {
//       "fixture": "card-template-overflow-test.html",
//       "viewport": "desktop-1280",
//       "card": "ratio-1-1",
//       "clientWidth": 438, "clientHeight": 602, "scrollHeight": 602,
//       "overflows": false,
//       "screenshot": "/abs/path/render-check-...png"
//     },
//     ...
//   ]
//
// 판정 기준(참고, design/card-template-guide.md "재조정 — 오버플로 실측 반영" 섹션과 동일):
//   - overflows = (scrollHeight > clientHeight) 이면 카드 내부 콘텐츠가 박스보다 커서
//     넘친다는 뜻이다(FAIL). clientHeight === scrollHeight 이면 넘치지 않는다(PASS).
//   - 이 스크립트는 측정만 하고 PASS/FAIL 문구를 콘솔에 추가로 출력하지 않는다
//     (scripts/check_reflow_320px.js와 동일한 "측정과 판정을 분리" 원칙).

const fs = require("fs");
const path = require("path");
const { chromium } = require("playwright");

const REPO_ROOT = path.resolve(__dirname, "..");

const FIXTURES = [
  {
    file: "card-template-overflow-test.html",
    shortName: "overflow-test",
  },
  {
    file: "card-template-reconciled-test.html",
    shortName: "reconciled-test",
  },
];

const VIEWPORTS = [
  { label: "desktop-1280", width: 1280, height: 900 },
  { label: "mobile-375", width: 375, height: 800 },
];

function todayStr() {
  const d = new Date();
  const yyyy = d.getFullYear();
  const mm = String(d.getMonth() + 1).padStart(2, "0");
  const dd = String(d.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

async function main() {
  const outputDir = process.argv[2]
    ? path.resolve(process.argv[2])
    : path.join(REPO_ROOT, "design");

  if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
  }

  const dateTag = todayStr();
  const results = [];

  const browser = await chromium.launch();
  try {
    for (const fixture of FIXTURES) {
      const htmlPath = path.join(REPO_ROOT, "design", fixture.file);
      if (!fs.existsSync(htmlPath)) {
        console.error(`오류: 픽스처 파일을 찾을 수 없습니다: ${htmlPath}`);
        process.exitCode = 2;
        continue;
      }
      const fileUrl = "file://" + htmlPath;

      for (const viewport of VIEWPORTS) {
        const page = await browser.newPage({
          viewport: { width: viewport.width, height: viewport.height },
        });
        try {
          await page.goto(fileUrl, { waitUntil: "load" });

          const screenshotName = `render-check-${dateTag}-${fixture.shortName}-${viewport.label}.png`;
          const screenshotPath = path.join(outputDir, screenshotName);
          await page.screenshot({ path: screenshotPath, fullPage: true });

          const cardMeasurements = await page.evaluate(() => {
            const selectors = [".card.ratio-1-1", ".card.ratio-4-5"];
            return selectors.map((sel) => {
              const el = document.querySelector(sel);
              if (!el) {
                return { selector: sel, found: false };
              }
              return {
                selector: sel,
                found: true,
                clientWidth: el.clientWidth,
                clientHeight: el.clientHeight,
                scrollHeight: el.scrollHeight,
                scrollWidth: el.scrollWidth,
                overflowsVertical: el.scrollHeight > el.clientHeight,
                overflowsHorizontal: el.scrollWidth > el.clientWidth,
              };
            });
          });

          for (const m of cardMeasurements) {
            results.push({
              fixture: fixture.file,
              viewport: viewport.label,
              card: m.selector,
              ...m,
              screenshot: screenshotPath,
            });
          }
        } finally {
          await page.close();
        }
      }
    }

    console.log(JSON.stringify(results, null, 2));
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error("오류: " + (err && err.stack ? err.stack : err));
  process.exit(2);
});
