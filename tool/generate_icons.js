/**
 * Renders every ClasSync icon asset from the source SVG.
 *
 * Requires two dev-only helpers (not shipped, not part of the Flutter build):
 *   npm i @resvg/resvg-js pngjs
 *
 * Run:
 *   node tool/generate_icons.js
 *
 * Source of truth: assets/icon/clasSync-icon.svg
 */
const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'assets', 'icon', 'clasSync-icon.svg');
const RES = path.join(ROOT, 'android', 'app', 'src', 'main', 'res');
const WEB = path.join(ROOT, 'web');

/** Brand background: M3 primary generated from the `teal` seed (0xFF009688). */
const BRAND = '#006A60';

const raw = fs.readFileSync(SRC, 'utf8');
const vbMatch = raw.match(/viewBox="([\d.\-\s]+)"/);
const VIEWBOX = vbMatch ? vbMatch[1].trim() : '0 0 878 878';
const ART = raw
  .replace(/<\?xml[^>]*\?>/g, '')
  .replace(/<svg[^>]*>/, '')
  .replace(/<\/svg>\s*$/, '');

/**
 * @param {object} o
 * @param {number} o.size   canvas edge in px
 * @param {number} o.inset  fraction of the canvas kept clear on every side
 * @param {string|null} o.bg   background fill, null = transparent
 * @param {'circle'|'squircle'|null} o.clip  mask applied to the whole canvas
 * @param {boolean} o.white     repaint every shape white (monochrome / status bar)
 * @param {boolean} o.capOnly   drop the grey ring behind the cap
 */
function compose({ size, inset, bg = null, clip = null, white = false, capOnly = false }) {
  let art = ART;
  if (capOnly) art = art.replace(/<path[^>]*fill="#D9D9D9"[^>]*\/>/gi, '');
  if (white) art = art.replace(/fill="(?!none)[^"]*"/gi, 'fill="#fff"');

  const box = Math.round(size * (1 - inset * 2));
  const off = Math.round((size - box) / 2);
  const r = size / 2;

  let defs = '';
  let attr = '';
  if (clip === 'circle') {
    defs = `<clipPath id="m"><circle cx="${r}" cy="${r}" r="${r}"/></clipPath>`;
    attr = ' clip-path="url(#m)"';
  } else if (clip === 'squircle') {
    defs = `<clipPath id="m"><rect width="${size}" height="${size}" rx="${size * 0.42}"/></clipPath>`;
    attr = ' clip-path="url(#m)"';
  }

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="0 0 ${size} ${size}">
  <defs>${defs}</defs>
  <g${attr}>
    ${bg ? `<rect width="${size}" height="${size}" fill="${bg}"/>` : ''}
    <svg x="${off}" y="${off}" width="${box}" height="${box}" viewBox="${VIEWBOX}" preserveAspectRatio="xMidYMid meet">${art}</svg>
  </g>
</svg>`;
}

function write(svg, outPath, size) {
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  const png = new Resvg(svg, {
    fitTo: { mode: 'width', value: size },
    background: 'rgba(0,0,0,0)',
  })
    .render()
    .asPng();
  fs.writeFileSync(outPath, png);
  console.log('  ', path.relative(ROOT, outPath), `${size}x${size}`);
}

// ---------------------------------------------------------------------------
// Android
// ---------------------------------------------------------------------------
// Legacy launcher bitmap, adaptive foreground, adaptive monochrome, status bar.
const DENSITIES = [
  { dir: 'mdpi', legacy: 48, adaptive: 108, status: 24 },
  { dir: 'hdpi', legacy: 72, adaptive: 162, status: 36 },
  { dir: 'xhdpi', legacy: 96, adaptive: 216, status: 48 },
  { dir: 'xxhdpi', legacy: 144, adaptive: 324, status: 72 },
  { dir: 'xxxhdpi', legacy: 192, adaptive: 432, status: 96 },
];

console.log('Android launcher + adaptive layers:');
for (const d of DENSITIES) {
  write(
    compose({ size: d.legacy, inset: 0.10, bg: BRAND }),
    path.join(RES, `mipmap-${d.dir}`, 'ic_launcher.png'),
    d.legacy,
  );
  write(
    compose({ size: d.adaptive, inset: 0.16 }),
    path.join(RES, `mipmap-${d.dir}`, 'ic_launcher_foreground.png'),
    d.adaptive,
  );
  write(
    compose({ size: d.adaptive, inset: 0.16, white: true }),
    path.join(RES, `mipmap-${d.dir}`, 'ic_launcher_monochrome.png'),
    d.adaptive,
  );
  write(
    compose({ size: d.status, inset: 0.02, white: true, capOnly: true }),
    path.join(RES, `drawable-${d.dir}`, 'ic_status.png'),
    d.status,
  );
}

// Adaptive icon descriptor (API 26+). Background is a flat brand colour.
console.log('Adaptive icon XML:');
for (const name of ['ic_launcher', 'ic_launcher_round']) {
  const xml = `<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
`;
  const out = path.join(RES, 'mipmap-anydpi-v26', `${name}.xml`);
  fs.mkdirSync(path.dirname(out), { recursive: true });
  fs.writeFileSync(out, xml);
  console.log('  ', path.relative(ROOT, out));
}

const colors = path.join(RES, 'values', 'ic_launcher_background.xml');
fs.writeFileSync(
  colors,
  `<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">${BRAND}</color>
</resources>
`,
);
console.log('  ', path.relative(ROOT, colors));

// ---------------------------------------------------------------------------
// Web
// ---------------------------------------------------------------------------
console.log('Web icons:');
write(compose({ size: 32, inset: 0.10, bg: BRAND }), path.join(WEB, 'favicon.png'), 32);
write(compose({ size: 192, inset: 0.10, bg: BRAND }), path.join(WEB, 'icons', 'Icon-192.png'), 192);
write(compose({ size: 512, inset: 0.10, bg: BRAND }), path.join(WEB, 'icons', 'Icon-512.png'), 512);
write(compose({ size: 192, inset: 0.20, bg: BRAND }), path.join(WEB, 'icons', 'Icon-maskable-192.png'), 192);
write(compose({ size: 512, inset: 0.20, bg: BRAND }), path.join(WEB, 'icons', 'Icon-maskable-512.png'), 512);

// ---------------------------------------------------------------------------
// Store / README master
// ---------------------------------------------------------------------------
console.log('Master:');
write(compose({ size: 1024, inset: 0.10, bg: BRAND }), path.join(ROOT, 'assets', 'icon', 'icon-1024.png'), 1024);

console.log('\nDone.');
