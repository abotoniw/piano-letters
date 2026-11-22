// Builds my-sheets.json from every songs/*.abc file, using the app's own reader
// (index.html) in headless Chromium, so a song that passes here opens on the iPad.
//
//   node tools/build-sheets.mjs            build my-sheets.json
//   node tools/build-sheets.mjs --shot     also save a picture of each new or changed song in shots/
//
// A song keeps its "updated" date until its .abc file changes. A changed date is what
// makes the iPad replace its copy when "Check for update" is tapped.
import { createRequire } from 'node:module';
import { createHash } from 'node:crypto';
import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync } from 'node:fs';
import { join, dirname, basename } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const out = join(root, 'my-sheets.json');
const shot = process.argv.includes('--shot');

const old = existsSync(out) ? JSON.parse(readFileSync(out, 'utf8')) : { sheets: [] };
const before = new Map(old.sheets.map(s => [s.id, s]));
const files = readdirSync(join(root, 'songs')).filter(f => f.endsWith('.abc')).sort();
if (!files.length) throw new Error('No songs/*.abc files.');

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1180, height: 820 } });
const errors = [];
page.on('pageerror', e => errors.push(e.message));
await page.goto(pathToFileURL(join(root, 'index.html')).href);
await page.waitForFunction(() => window.__pl);

const now = new Date().toISOString(), sheets = [], changed = [];
for (const f of files) {
  const id = 'repo-' + basename(f, '.abc');
  const abc = readFileSync(join(root, 'songs', f), 'utf8');
  const src = createHash('sha256').update(abc).digest('hex').slice(0, 16);
  const piece = await page.evaluate(t => parseABC(t), abc);
  if (!piece.measures || !piece.measures.length) throw new Error(f + ': no bars were read.');
  if (piece.warn && piece.warn.length) console.warn(f + ': ' + piece.warn.join('; '));
  const was = before.get(id);
  const sheet = { id, title: piece.title || basename(f, '.abc'), piece, updated: was && was.src === src ? was.updated : now, src };
  if (!was || was.src !== src) changed.push(sheet);
  sheets.push(sheet);
  console.log((was ? (was.src === src ? 'same   ' : 'changed') : 'new    ') + '  ' + sheet.title + '  (' + piece.measures.length + ' bars)');
}

// Load the whole file into the app, as the iPad does, and open each changed song.
const file = { type: 'piano-letter-sheets', version: 1, sheets };
const r = await page.evaluate(o => window.__pl.addSheets(o, 'file'), file);
if (r.bad) throw new Error(r.bad + ' song(s) could not be read by the app.');
if (shot) mkdirSync(join(root, 'shots'), { recursive: true });
for (const s of changed) {
  await page.evaluate(id => window.__pl.openItem(window.__pl.byKey('my:' + id)), s.id);
  await page.waitForTimeout(600);
  if (shot) await page.screenshot({ path: join(root, 'shots', s.id + '.png') });
  await page.evaluate(() => { const b = document.getElementById('back'); if (b) b.click(); });
}
await browser.close();
if (errors.length) throw new Error('The app reported errors: ' + errors.join(' | '));

writeFileSync(out, JSON.stringify(file) + '\n');
console.log('my-sheets.json: ' + sheets.length + ' song(s), ' + changed.length + ' new or changed.');
