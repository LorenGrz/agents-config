#!/usr/bin/env node
// Sube imágenes a GitHub user-attachments desde la caja de comentario de un PR, sin publicar
// el comentario, e imprime la URL de cada una. GitHub no tiene API para esto: solo lo hace
// el navegador, así que se usa un perfil de Chromium con la sesión de GitHub iniciada.
//
// Uso:
//   node gh-upload-images.mjs --login [--profile <dir>]
//       Abre github.com/login en un Chromium visible; iniciá sesión (2FA incluido) y cerrá
//       la ventana. El perfil queda en <dir> (por defecto ~/.cache/gh-upload-images/profile).
//   node gh-upload-images.mjs --repo owner/name --pr 123 img1.png img2.png [--profile <dir>]
//       Imprime JSON [{ file, url, markdown }]. El texto del comentario se borra al final:
//       no se publica nada en el PR.
//
// Las URLs heredan la visibilidad del repo: en un repo privado solo las ve quien tiene acceso.
// Depende del HTML de GitHub; si falla buscando la caja de comentario, revisar SELECTORES.

import { chromium } from 'playwright';
import { homedir } from 'node:os';
import { basename, join, resolve } from 'node:path';

const SELECTORES = {
  textarea: [
    'textarea#new_comment_field',
    'textarea[name="comment[body]"]',
    'textarea[placeholder*="comment" i]',
    'textarea[aria-label*="comment" i]',
  ],
};
const ASSET_RE = /https:\/\/github\.com\/user-attachments\/assets\/[0-9a-f-]+/g;

function parseArgs(argv) {
  const args = { files: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (!a.startsWith('--')) { args.files.push(a); continue; }
    const key = a.slice(2);
    const next = argv[i + 1];
    if (next === undefined || next.startsWith('--')) args[key] = true;
    else { args[key] = next; i++; }
  }
  return args;
}

const args = parseArgs(process.argv.slice(2));
const profile = resolve(args.profile ?? join(homedir(), '.cache', 'gh-upload-images', 'profile'));

if (args.login) {
  const context = await chromium.launchPersistentContext(profile, { headless: false });
  const page = context.pages()[0] ?? (await context.newPage());
  await page.goto('https://github.com/login');
  console.error('Iniciá sesión en GitHub y después cerrá la ventana.');
  await page.waitForEvent('close', { timeout: 0 });
  await context.close();
  console.error(`Perfil guardado en ${profile}`);
  process.exit(0);
}

if (!args.repo || !args.pr || args.files.length === 0) {
  throw new Error('Uso: --repo owner/name --pr <n> <imagen>...');
}

const context = await chromium.launchPersistentContext(profile, { headless: !args.headed });
const page = context.pages()[0] ?? (await context.newPage());

try {
  await page.goto(`https://github.com/${args.repo}/pull/${args.pr}`, { waitUntil: 'domcontentloaded' });
  // Sin sesión, un repo privado responde 404 en vez de redirigir al login.
  const user = await page.locator('meta[name="user-login"]').getAttribute('content').catch(() => '');
  if (page.url().includes('/login') || !user) {
    throw new Error('Sin sesión de GitHub en el perfil: correr con --login primero.');
  }

  let textarea = null;
  for (const sel of SELECTORES.textarea) {
    const loc = page.locator(sel).last();
    if (await loc.count()) { textarea = loc; break; }
  }
  if (!textarea) throw new Error('No encontré la caja de comentario del PR (revisar SELECTORES).');
  await textarea.scrollIntoViewIfNeeded();
  await textarea.click();

  // El input de archivos es el más cercano a la caja: dentro del mismo form o contenedor.
  const fileInput = textarea
    .locator('xpath=ancestor::*[.//input[@type="file"]][1]')
    .locator('input[type="file"]')
    .first();

  const files = args.files.map((f) => resolve(f));
  const altOf = (f) => basename(f).replace(/\.[^.]+$/, '');
  // GitHub inserta una línea por imagen: <img ... alt="nombre" src="URL" /> o ![nombre](URL).
  const parse = (text) => {
    const urls = {};
    for (const line of text.split('\n')) {
      const url = line.match(ASSET_RE)?.[0];
      const alt = line.match(/alt="([^"]*)"/)?.[1] ?? line.match(/!\[([^\]]*)\]/)?.[1];
      if (url && alt != null) urls[alt] = url;
    }
    return urls;
  };
  const waitFor = async (n) => {
    await page.waitForFunction(
      ([el, n]) => (el.value.match(/user-attachments\/assets\/[0-9a-f-]+/g) ?? []).length >= n && !/Uploading/i.test(el.value),
      [await textarea.elementHandle(), n],
      { timeout: 30_000 + n * 10_000 },
    );
    return textarea.inputValue();
  };

  let urls = {};
  await textarea.fill('');
  try {
    // Todas juntas: GitHub sube en paralelo y hay una sola espera.
    await fileInput.setInputFiles(files);
    urls = parse(await waitFor(files.length));
    const missing = files.filter((f) => !urls[altOf(f)]);
    if (missing.length) throw new Error(`alt sin el nombre del archivo en ${missing.length} imagen(es)`);
  } catch (e) {
    // Input sin `multiple` o mapeo incompleto: de a una, como antes.
    console.error(`subida en lote falló (${String(e.message).split('\n')[0]}); sigo de a una`);
    urls = {};
    // Recargar: subidas del lote que sigan en curso no deben mezclarse con las de a una.
    await page.reload({ waitUntil: 'domcontentloaded' });
    await textarea.click();
    for (const file of files) {
      await textarea.fill('');
      await fileInput.setInputFiles(file);
      urls[altOf(file)] = (await waitFor(1)).match(ASSET_RE)[0];
    }
  }
  const results = files.map((file) => {
    const url = urls[altOf(file)];
    if (!url) throw new Error(`sin URL para ${basename(file)}`);
    return { file, url, markdown: `![${altOf(file)}](${url})` };
  });

  await textarea.fill('');
  console.log(JSON.stringify(results, null, 2));
} finally {
  await context.close();
}
