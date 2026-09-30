// Run after npm run build: WEB_APP=admin node --test tool/ci/web-export-smoke.test.cjs
// Uses synthetic images and local export files only; no network or Firebase calls.
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { createRequire } = require('node:module');
const path = require('node:path');
const test = require('node:test');

const app = process.env.WEB_APP;
assert.ok(['admin', 'marketing'].includes(app), 'Set WEB_APP=admin or marketing');
const root = path.resolve(__dirname, '../../apps', app);
const appRequire = createRequire(path.join(root, 'package.json'));
const sharp = appRequire('sharp');
const { JSDOM } = appRequire('jsdom');

test(`${app}: synthetic PNG/AVIF round-trip preserves image dimensions`, async () => {
  const png = await sharp({
    create: { width: 12, height: 8, channels: 3, background: '#087e8b' },
  }).png().toBuffer();
  const avif = await sharp(png).avif({ lossless: true }).toBuffer();
  const decoded = await sharp(avif).png().toBuffer();
  const metadata = await sharp(decoded).metadata();
  assert.equal(metadata.format, 'png');
  assert.equal(metadata.width, 12);
  assert.equal(metadata.height, 8);
});

test(`${app}: exported HTML renders content and serves unoptimized images`, () => {
  const html = readFileSync(path.join(root, 'out/index.html'), 'utf8');
  // JSDOM does not execute scripts or load remote resources by default.
  const dom = new JSDOM(html);
  const document = dom.window.document;
  try {
    assert.match(document.title, /League Hub/);
    assert.ok(document.querySelector('main'), 'Main landmark must be prerendered');
    assert.ok(document.body.textContent.trim().length > 100, 'Page content must be prerendered');
    const images = [...document.querySelectorAll('img')];
    assert.ok(images.length > 0, 'Brand images must render in exported HTML');
    for (const image of images) {
      const src = image.getAttribute('src');
      assert.ok(src, 'Images must have a source');
      assert.ok(!src.includes('/_next/image'), 'Static hosting must not need an image optimizer server');
    }
  } finally {
    dom.window.close();
  }
});
