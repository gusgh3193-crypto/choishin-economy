// check_reflow_320px.js
//
// design/mockup-2026-09-13-interest-rate-impact.html을 Playwright(headless Chromium)로
// CSS 뷰포트 320px 폭으로 렌더링해, WCAG 1.4.10(리플로우) 기준의 실측값을 JSON으로
// 출력한다. 호출하는 scripts/test_reflow_320px.sh가 이 JSON을 2026-11-18에 개발팀이
// 실측한 기준값과 비교해 PASS/FAIL을 판정한다.
//
// 이 스크립트 자체는 판정하지 않고, 측정만 한다(판정 로직은 쉘 스크립트에 둔다).
//
// 사용법:
//   node scripts/check_reflow_320px.js <mockup.html 절대경로> <스크린샷 저장 경로>
//
// 표준출력: 아래 형태의 JSON 한 줄
//   {
//     "scrollWidth": 320,
//     "clientWidth": 320,
//     "hasHorizontalScroll": false,
//     "elements": [
//       {"selector": "h1", "index": 0, "overflowsRight": false, "rect": {...}},
//       ...
//     ],
//     "overlapPairs": []
//   }

const path = require("path");
const { chromium } = require("playwright");

async function main() {
  const htmlPath = process.argv[2];
  const screenshotPath = process.argv[3];

  if (!htmlPath) {
    console.error("오류: mockup.html 경로를 첫 번째 인자로 넘겨야 합니다.");
    process.exit(2);
  }

  const fileUrl = "file://" + path.resolve(htmlPath);

  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: { width: 320, height: 800 } });
    await page.setViewportSize({ width: 320, height: 800 });
    await page.goto(fileUrl, { waitUntil: "load" });

    const result = await page.evaluate(() => {
      const docEl = document.documentElement;
      const scrollWidth = docEl.scrollWidth;
      const clientWidth = docEl.clientWidth;

      // 검사 대상 요소들: H1, H2, 본문 단락(p, post-date/disclaimer 제외),
      // .table-wrapper, .disclaimer
      const selectorGroups = [
        { label: "h1", elements: Array.from(document.querySelectorAll("h1")) },
        { label: "h2", elements: Array.from(document.querySelectorAll("h2")) },
        {
          label: "p.body",
          elements: Array.from(document.querySelectorAll("p")).filter(
            (el) => !el.classList.contains("post-date") && !el.classList.contains("disclaimer")
          ),
        },
        { label: ".table-wrapper", elements: Array.from(document.querySelectorAll(".table-wrapper")) },
        { label: ".disclaimer", elements: Array.from(document.querySelectorAll(".disclaimer")) },
      ];

      const elements = [];
      for (const group of selectorGroups) {
        group.elements.forEach((el, idx) => {
          const rect = el.getBoundingClientRect();
          elements.push({
            selector: group.label,
            index: idx,
            overflowsRight: rect.right > clientWidth,
            rect: {
              top: rect.top,
              bottom: rect.bottom,
              left: rect.left,
              right: rect.right,
            },
          });
        });
      }

      // 형제 블록 간 겹침: .page의 직계 자식들을 문서 순서대로 비교해,
      // 인접한(DOM 순서상 바로 다음) 형제끼리 세로(top/bottom) 범위가
      // 겹치는지 확인한다(가로 위치가 겹치는 영역이 있을 때만 "겹침"으로 본다).
      const page_el = document.querySelector(".page");
      const siblings = page_el ? Array.from(page_el.children) : [];
      const overlapPairs = [];
      for (let i = 0; i < siblings.length - 1; i++) {
        const a = siblings[i].getBoundingClientRect();
        const b = siblings[i + 1].getBoundingClientRect();
        const verticalOverlap = a.bottom > b.top && b.bottom > a.top;
        const horizontalOverlap = a.left < b.right && b.left < a.right;
        if (verticalOverlap && horizontalOverlap) {
          overlapPairs.push([
            `${siblings[i].tagName.toLowerCase()}.${siblings[i].className || ""}#${i}`,
            `${siblings[i + 1].tagName.toLowerCase()}.${siblings[i + 1].className || ""}#${i + 1}`,
          ]);
        }
      }

      return {
        scrollWidth,
        clientWidth,
        hasHorizontalScroll: scrollWidth > clientWidth,
        elements,
        overlapPairs,
      };
    });

    if (screenshotPath) {
      await page.screenshot({ path: screenshotPath, fullPage: true });
    }

    console.log(JSON.stringify(result));
  } finally {
    await browser.close();
  }
}

main().catch((err) => {
  console.error("오류: " + (err && err.stack ? err.stack : err));
  process.exit(2);
});
