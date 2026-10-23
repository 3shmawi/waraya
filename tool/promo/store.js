// The store's images — screenshots for Google Play, the iPhone and the iPad,
// and Play's feature graphic — in the videos' style (docs/store-listing.md):
// the same sky, the same phone on its side, the same words.
//
//   node tool/promo/store.js WORK [OUT]
//
// WORK/frames/<NN-slug>/NNNNN.png is the game's own footage at a phone's
// screen size (tool/clips.dart with WARAYA_CLIP_DEVICE=844x390@2), and
// WORK/mark/panel/045.png the ending's panel (tool/promo/mark_frames.dart).
// Each shot is a clip and a moment in its recorded solution — so a
// screenshot cannot show a solution the game no longer accepts — drawn by
// window.still in tool/promo/motion.html.
//
// Writes OUT/{ar,en}/{play,iphone,iphone-6.3,iphone-6.5,ipad,iphone-duo}/N-<slug>.png and
// OUT/{ar,en}/play/feature-graphic.png (default OUT: WORK/store). RGB with
// no alpha channel, through ffmpeg: Play refuses an image that has one.
// Needs ffmpeg and Playwright (CHROMIUM=<executable> if its own browser is
// not installed).
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { chromium } = require('playwright');

// The shapes the stores ask for. `phone` is the screen's width as a share of
// the image's; the rest follows the videos' story layout, scaled.
const DEVICES = {
  play: { W: 1080, H: 1920 },
  iphone: { W: 1290, H: 2796 },
  'iphone-6.5': { W: 1284, H: 2778 },
  // App Store, «iPhone with Dynamic Island (medium display)», 6.1"/6.3":
  // 1206x2622 or 1179x2556, and it refuses every other size.
  'iphone-6.3': { W: 1206, H: 2622 },
  ipad: { W: 2064, H: 2752, phone: 0.8 },
  // App Store, iPhone Duo: 1398x2034 or 2007x2853 — the bigger one, which
  // App Store Connect scales down.
  'iphone-duo': { W: 2007, H: 2853, phone: 0.8 },
};

function layout({ W, H, phone = 0.926 }) {
  const s = W / 1080;
  const w = W * phone, h = w * 390 / 844, bezel = 22 * w / 1000;
  const y = H * 0.4;
  const big = phone < 0.9 ? 1.02 : 1;
  return {
    W, H, bezel, reflect: true,
    screen: { x: (W - w) / 2, y, w, h },
    horizon: y + h + bezel + 8, sunY: y - 40 * s,
    lowY: y + h + bezel + (H - y - h) * 0.45,
    pad: 70 * s, gap: 18 * s,
    markS: 240 * s,
    type: { big: 104 * s * big, mid: 60 * s, small: 50 * s * big },
    k: w / 844,
  };
}

// The six moments, the first two the ones a listing shows without scrolling:
// the idea itself. Positions on the footage are the videos' own
// (tool/promo/film.js), in the phone screen's pixels (844 x 390).
const SHOTS = [
  { slug: 'the-door', clip: '01-the-plate', at: 6.05, ring: { x: 690, y: 311 },
    ar: { text: 'الباب ده فتح لوحده؟', sub: 'لأ… ده انت، من تانيتين ونص', label: 'انت · من ٢٫٥ ثانية' },
    en: { text: 'Who opened that door?', sub: 'You did. Two and a half seconds ago.', label: 'you · 2.5 s ago' } },
  { slug: 'the-step', clip: '02-the-step', at: 7.75, tag: { x: 322, y: 271 },
    ar: { text: 'وطّي… وماضيك يبقى سلّمة', sub: 'ظلك جسم حقيقي، تطلع فوقه', label: 'سلّمة' },
    en: { text: 'Crouch, and your past is a step', sub: 'Your shadow is a real body you can climb', label: 'a step' } },
  { slug: 'the-mirror', clip: '16-the-mirror', at: 5.1, ring: { x: 172, y: 190 },
    ar: { text: 'المراية بترجّعك', sub: 'ماضيك يوصلها… تلاقي نفسك مكانه', label: 'ماضيك', chip: 'جديد' },
    en: { text: 'The mirror brings you back', sub: 'Your past reaches it, and you are there', label: 'your past', chip: 'New' } },
  { slug: 'two-of-you', clip: '09-two-of-you', at: 8.2,
    ar: { text: 'ظلّين في نفس الوقت', sub: 'تبقى في مكانين في نفس اللحظة' },
    en: { text: 'Two shadows at once', sub: 'Be in two places at the same moment' } },
  { slug: 'in-the-light', clip: '08-in-the-light', at: 4.9,
    ar: { text: 'جوّه النور… ماضيك مش موجود', sub: 'مش بيدوس، ومش بتقف عليه' },
    en: { text: 'In the light, your past is gone', sub: 'It presses nothing, and holds nobody up' } },
  { slug: 'all-of-it', clip: '15-all-of-it', at: 12.0, mark: true,
    ar: { text: 'ورايا', sub: '٤٥ مرحلة · مجانية · من غير إعلانات', brand: 'لعبة ألغاز مصرية' },
    en: { text: 'Waraya', sub: '45 levels · Free · No ads', brand: 'A puzzle game from Egypt' } },
];

const BANNER = {
  clip: '16-the-mirror', at: 5.6,
  ar: { text: 'ورايا', sub: 'ظلك بيعيد كل اللي عملته… بعد ثواني' },
  en: { text: 'Waraya', sub: 'Your shadow repeats everything you did, seconds later' },
};

const frameOf = (work, clip, t) => {
  const dir = fs.readdirSync(path.join(work, 'frames')).find((d) => d === clip || d.startsWith(clip));
  if (!dir) throw new Error(`no footage for ${clip} in ${work}/frames`);
  const n = Math.round(t * 30) + 1;
  return `file://${path.join(work, 'frames', dir, String(n).padStart(5, '0') + '.png')}`;
};

// Playwright's PNG, then through ffmpeg to plain 24-bit RGB.
async function shoot(page, file) {
  fs.mkdirSync(path.dirname(file), { recursive: true });
  const tmp = file + '.rgba.png';
  await page.screenshot({ path: tmp });
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', tmp, '-pix_fmt', 'rgb24', file]);
  fs.unlinkSync(tmp);
}

(async () => {
  const work = path.resolve(process.argv[2]);
  const out = path.resolve(process.argv[3] || path.join(work, 'store'));
  const mark = `file://${path.join(work, 'mark', 'panel', '045.png')}`;
  const tile = `file://${path.join(work, 'mark', 'tile', '045.png')}`;
  const brand = { ar: 'ورايا · لعبة ألغاز مصرية', en: 'Waraya · a puzzle game from Egypt' };
  const browser = await chromium.launch({
    ...(process.env.CHROMIUM ? { executablePath: process.env.CHROMIUM } : {}),
    args: ['--allow-file-access-from-files'],
  });
  const page = await browser.newPage({ deviceScaleFactor: 1 });
  await page.goto('file://' + path.resolve(__dirname, 'motion.html'));
  for (const lang of ['ar', 'en']) {
    const dir = lang === 'ar' ? 'rtl' : 'ltr';
    for (const [device, size] of Object.entries(DEVICES)) {
      const L = layout(size);
      await page.setViewportSize({ width: L.W, height: L.H });
      for (const [i, shot] of SHOTS.entries()) {
        const w = shot[lang];
        await page.evaluate((spec) => window.still(spec), {
          config: { L }, dir,
          frame: frameOf(work, shot.clip, shot.at),
          ring: shot.ring && { ...shot.ring, label: w.label },
          tag: shot.tag && { ...shot.tag, label: w.label },
          mark: shot.mark ? mark : null,
          chip: w.chip, text: w.text, sub: w.sub, tile, brand: w.brand || brand[lang],
        });
        await shoot(page, path.join(out, lang, device, `${i + 1}-${shot.slug}.png`));
      }
    }
    // The feature graphic: 1024 x 500.
    const W = 1024, H = 500, sw = 560, sh = sw * 390 / 844;
    const L = {
      W, H, bezel: 12, reflect: false, k: sw / 844,
      screen: { x: dir === 'rtl' ? 36 : W - 36 - sw, y: (H - sh) / 2 - 10, w: sw, h: sh },
      horizon: 440, sunY: 220,
      textX: 24, textY: 70, textW: W - sw - 100, markS: 120,
      type: { big: 78, small: 30 },
    };
    await page.setViewportSize({ width: W, height: H });
    await page.evaluate((spec) => window.banner(spec), {
      config: { L }, dir, frame: frameOf(work, BANNER.clip, BANNER.at), mark, ...BANNER[lang],
    });
    await shoot(page, path.join(out, lang, 'play', 'feature-graphic.png'));
    console.log(`${lang}: done`);
  }
  await browser.close();
  console.log(`wrote ${out}`);
})();
