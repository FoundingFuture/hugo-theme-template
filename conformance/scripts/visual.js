// Screenshots of the pages a design change is most likely to move.
//
// A difference is reported and lands in the pull request report. It does
// not fail the build. A deliberate design change is a difference too,
// and only a person can tell the two apart.
const fs = require('fs');
const path = require('path');

const PAGES = [
  ['home', 'index.html'],
  ['section', 'kitchen-sink/index.html'],
  ['term', 'tags/alpha/index.html'],
  ['bundle', 'kitchen-sink/bundle/index.html'],
  ['long', 'kitchen-sink/long/index.html'],
  ['goldmark', 'kitchen-sink/goldmark/index.html'],
  ['pager', 'posts/page/2/index.html'],
  ['taxonomy', 'tags/index.html'],
];
const WIDTHS = [430, 800, 1280];
const ROOT = 'conformance/public/ours';
const SNAPSHOTS = 'conformance/snapshots/screens';
const OUT = 'conformance/public/screens';

async function main() {
  let chromium, pixelmatch, PNG;
  try {
    ({ chromium } = require('playwright'));
    pixelmatch = require('pixelmatch');
    ({ PNG } = require('pngjs'));
  } catch (error) {
    console.log('SKIP visual: playwright, pixelmatch or pngjs is not installed');
    process.exit(3);
  }

  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch();
  const differences = [];

  for (const [name, page] of PAGES) {
    const file = path.resolve(ROOT, page);
    if (!fs.existsSync(file)) continue;
    for (const width of WIDTHS) {
      const context = await browser.newContext({ viewport: { width, height: 900 } });
      const tab = await context.newPage();
      await tab.goto('file://' + file);
      const shot = path.join(OUT, `${name}-${width}.png`);
      await tab.screenshot({ path: shot, fullPage: true });
      await context.close();

      const before = path.join(SNAPSHOTS, `${name}-${width}.png`);
      if (!fs.existsSync(before)) continue;
      const a = PNG.sync.read(fs.readFileSync(before));
      const b = PNG.sync.read(fs.readFileSync(shot));
      if (a.width !== b.width || a.height !== b.height) {
        differences.push(`${name}-${width}: size changed`);
        continue;
      }
      const diff = new PNG({ width: a.width, height: a.height });
      const moved = pixelmatch(a.data, b.data, diff.data, a.width, a.height, { threshold: 0.1 });
      const share = moved / (a.width * a.height);
      if (share > 0.001) {
        fs.writeFileSync(path.join(OUT, `${name}-${width}-diff.png`), PNG.sync.write(diff));
        differences.push(`${name}-${width}: ${(share * 100).toFixed(2)} percent of pixels moved`);
      }
    }
  }
  await browser.close();

  for (const line of differences) console.log(line);
  console.log(`${differences.length} screenshot difference(s), reported and not fatal`);
  process.exit(0);
}

main();
