// Draws the launch video's still layers: one PNG per entry in a JSON list.
//
//   node tool/promo/render.js layers.json OUT_DIR
//
// Each entry is {name, spec}; spec goes to window.layer() in cards.html.
// Needs Playwright (npm i playwright) and a Chromium; set CHROMIUM to its
// executable if Playwright's own is not installed.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const [list, out] = process.argv.slice(2);
  const entries = JSON.parse(fs.readFileSync(list, 'utf8'));
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch(
    process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {});
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.goto('file://' + path.resolve(__dirname, 'cards.html'));
  for (const { name, spec } of entries) {
    await page.setViewportSize({ width: spec.layout.W, height: spec.layout.H });
    await page.evaluate((s) => window.layer(s), spec);
    await page.locator('#frame').screenshot({
      path: path.join(out, name + '.png'),
      omitBackground: true,
    });
  }
  await browser.close();
  console.log(`${entries.length} layers -> ${out}`);
})();
