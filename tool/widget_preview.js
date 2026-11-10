/**
 * Renders the widget picker preview from the source SVG.
 *
 * Requires the same dev-only helpers as generate_icons.js:
 *   npm i @resvg/resvg-js pngjs
 *
 * Run:
 *   node tool/widget_preview.js
 *
 * Source of truth: assets/widget/widget-preview.svg
 * Output: the previewImage the launcher inflates on the widgets page, so it
 * must never be hand-edited; edit the SVG and re-run.
 */
const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'assets', 'widget', 'widget-preview.svg');
const OUT = path.join(
  ROOT, 'android', 'app', 'src', 'main', 'res', 'drawable-nodpi', 'widget_preview.png',
);

const svg = fs.readFileSync(SRC, 'utf8');
const png = new Resvg(svg, {
  fitTo: { mode: 'width', value: 1000 },
  font: { loadSystemFonts: true },
  background: 'rgba(0,0,0,0)',
})
  .render()
  .asPng();

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, png);
console.log(' wrote', path.relative(ROOT, OUT));
console.log('Done.');
