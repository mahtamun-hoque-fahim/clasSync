/**
 * Renders every now-state icon for the app's Now card and the home-screen
 * widget from the source SVGs in assets/icons/.
 *
 * Same dev-only helpers as generate_icons.js:
 *   npm i @resvg/resvg-js pngjs
 *
 * Run:
 *   node tool/generate_state_icons.js
 *
 * Sources keep their own white -> white@0.5 gradient fills, exactly the
 * reference look: a white glyph that sits on the accent gradient tile.
 */
const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'assets', 'icons');
const APP_OUT = path.join(SRC, 'png');
const RES = path.join(ROOT, 'android', 'app', 'src', 'main', 'res');

/** State icon key -> source SVG. Two plane states share the one plane glyph.
 *  Keys are also Android drawable suffixes (state_<key>.png), so they must
 *  stay lowercase a-z/0-9/underscore only. */
const KEYS = {
  grad_cap: 'reicon_grad-cap-filled.svg',
  test_tube: 'garden_test-tube-fill-20.svg',
  bus: 'solar_bus-bold.svg',
  home: 'bxs_home.svg',
  home_alert: 'mdi_home-alert.svg',
  plane_take_off: 'bxs_plane-take-off.svg',
  plane_take_off1: 'bxs_plane-take-off.svg',
  plane: 'bxs_plane-take-off.svg',
  clipboard48: 'fluent_clipboard-48-filled.svg',
  clipboard_arrow: 'fluent_clipboard-arrow-right-24-filled.svg',
  clipboard_check: 'fluent_clipboard-checkmark-16-filled.svg',
};

/** Widget drawable densities, matching the launcher generator's set. */
const DENSITIES = [
  { dir: 'mdpi', px: 48 },
  { dir: 'hdpi', px: 72 },
  { dir: 'xhdpi', px: 96 },
  { dir: 'xxhdpi', px: 144 },
  { dir: 'xxxhdpi', px: 192 },
];

function render(svgText, size) {
  return new Resvg(svgText, {
    fitTo: { mode: 'width', value: size },
    background: 'rgba(0,0,0,0)',
  })
    .render()
    .asPng();
}

for (const [key, file] of Object.entries(KEYS)) {
  const raw = fs.readFileSync(path.join(SRC, file), 'utf8');

  // App asset: one 256 px PNG, declared under assets/icons/png/.
  const appPath = path.join(APP_OUT, `${key}.png`);
  fs.mkdirSync(path.dirname(appPath), { recursive: true });
  fs.writeFileSync(appPath, render(raw, 256));
  console.log('  ', path.relative(ROOT, appPath), '256x256');

  // Widget drawable: density set under res/drawable-<dpi>/state_<key>.png.
  for (const d of DENSITIES) {
    const out = path.join(RES, `drawable-${d.dir}`, `state_${key}.png`);
    fs.mkdirSync(path.dirname(out), { recursive: true });
    fs.writeFileSync(out, render(raw, d.px));
    console.log('  ', path.relative(ROOT, out), `${d.px}x${d.px}`);
  }
}

console.log('\nDone.');
