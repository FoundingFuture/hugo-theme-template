// Screenshots of the pages a design change is most likely to move.
//
// The pages are served over HTTP, not opened as files.
//
// A built page links its stylesheet by an absolute path. Under file://
// that path resolves from the root of the disk, so no stylesheet ever
// loaded.
//
// Every screenshot was of an unstyled page. They all matched, and the
// gate could not have seen a design change.
//
// A difference is reported and lands in the pull request report. It does
// not fail the build. A deliberate design change is a difference too,
// and only a person can tell the two apart.
const fs = require('fs');
const path = require('path');
const { pathToFileURL } = require('url');
const http = require('http');

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
const ROOT = 'tools/conformance/public/ours';
const SNAPSHOTS = 'tools/conformance/snapshots/screens';
const OUT = 'tools/conformance/public/screens';

// --write takes the screenshots as the new baseline instead of comparing
// against one. ./c snapshot passes it, and a release runs ./c snapshot.
const WRITE = process.argv.includes('--write');

async function main() {
  // pixelmatch ships as an ES module, so require cannot load it.
  //
  // A bare dynamic import cannot find it either. ES resolution ignores
  // NODE_PATH, and a global install is nowhere near here.
  //
  // require.resolve does honour NODE_PATH, so the path is found the
  // CommonJS way and imported as a file URL.
  let chromium, pixelmatch, PNG;
  try {
    ({ chromium } = require('playwright'));
    ({ PNG } = require('pngjs'));
    pixelmatch = (await import(pathToFileURL(require.resolve('pixelmatch')).href)).default;
  } catch (error) {
    console.log('SKIP visual: playwright, pixelmatch or pngjs is not installed');
    console.log('  ' + error.message.split('\n')[0]);
    process.exit(3);
  }

  fs.mkdirSync(WRITE ? SNAPSHOTS : OUT, { recursive: true });

  const TYPES = {
    '.html': 'text/html', '.css': 'text/css', '.js': 'text/javascript',
    '.png': 'image/png', '.jpg': 'image/jpeg', '.svg': 'image/svg+xml',
    '.ico': 'image/x-icon', '.json': 'application/json',
    '.xml': 'application/xml', '.woff2': 'font/woff2',
  };
  const server = http.createServer((request, response) => {
    let target = decodeURIComponent(request.url.split('?')[0]);
    if (target.endsWith('/')) target += 'index.html';
    const file = path.join(ROOT, path.normalize(target).replace(/^(\.\.[/\\])+/, ''));
    fs.readFile(file, (error, body) => {
      if (error) {
        response.writeHead(404).end('not found');
        return;
      }
      response.writeHead(200, { 'content-type': TYPES[path.extname(file)] || 'application/octet-stream' });
      response.end(body);
    });
  });
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;

  const browser = await chromium.launch();
  const differences = [];

  for (const [name, page] of PAGES) {
    if (!fs.existsSync(path.resolve(ROOT, page))) continue;
    for (const width of WIDTHS) {
      const context = await browser.newContext({ viewport: { width, height: 900 } });
      const tab = await context.newPage();
      await tab.goto(`${origin}/${page}`, { waitUntil: 'networkidle' });
      const shot = WRITE
        ? path.join(SNAPSHOTS, `${name}-${width}.png`)
        : path.join(OUT, `${name}-${width}.png`);
      await tab.screenshot({ path: shot, fullPage: true });
      await context.close();

      if (WRITE) continue;
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
  await new Promise((resolve) => server.close(resolve));

  for (const line of differences) console.log(line);
  console.log(WRITE
    ? `screenshots written to ${SNAPSHOTS}`
    : `${differences.length} screenshot difference(s), reported and not fatal`);
  process.exit(0);
}

main();
