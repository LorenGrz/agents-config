#!/usr/bin/env node
// Captura el antes y el después de las mismas rutas en dos instancias de una app web.
//
// Uso:
//   node pr-screenshots.mjs --login --url http://localhost:3000/login [--state <archivo>]
//       Abre un Chromium visible para iniciar sesión a mano; al cerrarlo guarda cookies y
//       storage en <archivo> (por defecto ~/.cache/pr-screenshots/state.json).
//   node pr-screenshots.mjs --before http://localhost:3001 --after http://localhost:3000 \
//       --path /clientes --path /pedidos/123 [--out <dir>] [--viewport 1440x900 [--viewport 390x844]] \
//       [--state <archivo>] [--setup <modulo.mjs>] [--steps <modulo.mjs>] [--full-page] \
//       [--concurrency 4] [--step-timeout 20000]
//       Guarda <out>/before-<slug>.png y <out>/after-<slug>.png por cada --path (y
//       <side>-<slug>-<WxH>.png por cada --viewport extra) e imprime la lista en JSON.
//       --setup: módulo cuyo export `setup` (o default) es async (context, { side, base }) => {};
//       corre una vez por lado antes de abrir páginas (login por API, cookies, init scripts),
//       así cada ruta se carga una sola vez y ya con sesión.
//       --steps: módulo cuyo default export es async (page, { side, path }) => {}: corre
//       después de cargar la ruta y antes de la captura (clics, formularios). Si falla o pasa
//       --step-timeout, se captura igual y el error queda en el JSON (`error`).
//
// Cada lado usa su propio contexto (las cookies de localhost no distinguen puerto) y las
// capturas corren en paralelo, de a --concurrency.

import { chromium } from 'playwright';
import { existsSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

function parseArgs(argv) {
  const args = { path: [], viewport: [] };
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i].replace(/^--/, '');
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) {
      args[key] = true;
    } else {
      if (key === 'path' || key === 'viewport') args[key].push(next);
      else args[key] = next;
      i++;
    }
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const statePath = resolve(args.state ?? join(homedir(), '.cache', 'pr-screenshots', 'state.json'));
const viewports = (args.viewport.length ? args.viewport : ['1440x900']).map((v) => v.split('x').map(Number));
const [width, height] = viewports[0];

if (args.login) {
  if (!args.url) throw new Error('--login necesita --url');
  const browser = await chromium.launch({ headless: false });
  const context = await browser.newContext({ viewport: { width, height } });
  const page = await context.newPage();
  await page.goto(args.url);
  console.error('Iniciá sesión en la ventana y después cerrala.');
  await page.waitForEvent('close', { timeout: 0 });
  await mkdir(dirname(statePath), { recursive: true });
  await writeFile(statePath, JSON.stringify(await context.storageState(), null, 2), { mode: 0o600 });
  await browser.close();
  console.error(`Sesión guardada en ${statePath}`);
  process.exit(0);
}

if (!args.before || !args.after || args.path.length === 0) {
  throw new Error('Faltan --before, --after o al menos un --path');
}

const outDir = resolve(args.out ?? 'pr-screenshots');
await mkdir(outDir, { recursive: true });
const load = async (m) => (m ? import(pathToFileURL(resolve(m)).href) : {});
const steps = (await load(args.steps)).default ?? null;
const setupMod = await load(args.setup);
const setup = setupMod.setup ?? setupMod.default ?? null;
const stepTimeout = Number(args['step-timeout'] ?? 20000);
const concurrency = Number(args.concurrency ?? 4);

const slug = (p) => p.replace(/^\/+|\/+$/g, '').replace(/[^a-zA-Z0-9]+/g, '-') || 'home';

const browser = await chromium.launch();
const contexts = {};
for (const [side, base] of [['before', args.before], ['after', args.after]]) {
  const context = await browser.newContext({
    viewport: { width, height },
    storageState: existsSync(statePath) ? statePath : undefined,
  });
  context.setDefaultTimeout(10_000);
  context.setDefaultNavigationTimeout(60_000);
  if (setup) await setup(context, { side, base });
  contexts[side] = { context, base };
}

const jobs = [];
for (const path of args.path)
  for (const [i, [w, h]] of viewports.entries())
    for (const side of ['before', 'after']) jobs.push({ path, side, w, h, suffix: i ? `-${w}x${h}` : '' });

async function shoot({ path, side, w, h, suffix }) {
  const { context, base } = contexts[side];
  const page = await context.newPage();
  await page.setViewportSize({ width: w, height: h });
  const file = join(outDir, `${side}-${slug(path)}${suffix}.png`);
  let error;
  try {
    await page.goto(new URL(path, base).href, { waitUntil: 'load' });
    // networkidle es solo una pista: con polling o sockets puede no llegar nunca.
    await page.waitForLoadState('networkidle', { timeout: 5_000 }).catch(() => {});
    if (steps) {
      let timer;
      await Promise.race([
        steps(page, { side, path }),
        new Promise((_, rej) => { timer = setTimeout(() => rej(new Error(`steps > ${stepTimeout} ms`)), stepTimeout); }),
      ]).finally(() => clearTimeout(timer));
    }
  } catch (e) {
    error = String(e?.message ?? e).split('\n')[0];
    console.error(`[${side} ${path} ${w}x${h}] ${error}`);
  }
  await page.screenshot({ path: file, fullPage: Boolean(args['full-page']) });
  await page.close();
  return { side, path, viewport: `${w}x${h}`, url: page.url(), file, ...(error && { error }) };
}

const results = new Array(jobs.length);
let next = 0;
await Promise.all(Array.from({ length: Math.min(concurrency, jobs.length) }, async () => {
  while (next < jobs.length) { const i = next++; results[i] = await shoot(jobs[i]); }
}));

await browser.close();
console.log(JSON.stringify(results, null, 2));
