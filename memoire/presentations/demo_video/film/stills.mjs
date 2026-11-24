// node stills.mjs 30 240 ...   -> out/stills/s<sec>.png (half size), one bundle for all
import path from 'node:path';
import fs from 'node:fs';
import { bundle } from '@remotion/bundler';
import { renderStill, selectComposition } from '@remotion/renderer';
const secs = process.argv.slice(2).map(Number);
const serveUrl = await bundle({ entryPoint: path.resolve('src/index.ts') });
const composition = await selectComposition({ serveUrl, id: 'Film' });
fs.mkdirSync('out/stills', { recursive: true });
for (const s of secs) {
  await renderStill({ composition, serveUrl, output: `out/stills/s${s}.png`, frame: Math.round(s * 30), scale: 0.5 });
  console.log('still', s);
}
