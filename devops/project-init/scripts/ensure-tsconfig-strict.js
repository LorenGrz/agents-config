#!/usr/bin/env node
// ensure-tsconfig-strict.js <tsconfig-path> <project-dir>
//
// Adds strict/noUncheckedIndexedAccess/noImplicitOverride/noFallthroughCasesInSwitch
// to a tsconfig's "compilerOptions" if any are missing, without disturbing the
// rest of the file (vite/next/nestjs tsconfigs are JSONC - they can carry
// comments a naive JSON.parse + JSON.stringify round-trip would destroy).
//
// Uses the project's own installed `typescript` package to parse the file
// safely (ts.parseConfigFileTextToJson strips comments/trailing commas before
// we inspect which flags are already set), then does a plain text insertion
// right after the first "compilerOptions": { so untouched comments/formatting
// elsewhere in the file survive. If `typescript` isn't installed yet, or the
// file can't be parsed, it prints the manual edit instead of guessing.
'use strict'
const fs = require('fs')
const path = require('path')

const FLAGS = ['strict', 'noUncheckedIndexedAccess', 'noImplicitOverride', 'noFallthroughCasesInSwitch']

const [, , tsconfigPath, projectDir] = process.argv
if (!tsconfigPath || !projectDir) {
  console.error('Usage: ensure-tsconfig-strict.js <tsconfig-path> <project-dir>')
  process.exit(1)
}

function printManualEdit(reason) {
  console.log(`${reason}; add these to "${path.basename(tsconfigPath)}"'s compilerOptions manually:`)
  console.log(`  ${FLAGS.map((f) => `"${f}": true`).join(', ')}`)
}

let raw
try {
  raw = fs.readFileSync(tsconfigPath, 'utf8')
} catch {
  console.log(`no tsconfig found at ${tsconfigPath}, skipping strictness check`)
  process.exit(0)
}

// tsconfig is JSONC. Newer TypeScript builds (native 7.x) no longer expose
// ts.parseConfigFileTextToJson, so fall back to a small comment/trailing-comma stripper.
function parseJsonc(text) {
  let out = ''
  let inString = false
  for (let i = 0; i < text.length; i++) {
    const c = text[i]
    if (inString) {
      out += c
      if (c === '\\') out += text[++i]
      else if (c === '"') inString = false
    } else if (c === '"') {
      inString = true
      out += c
    } else if (c === '/' && text[i + 1] === '/') {
      while (i < text.length && text[i] !== '\n') i++
      out += '\n'
    } else if (c === '/' && text[i + 1] === '*') {
      i += 2
      while (i < text.length && !(text[i] === '*' && text[i + 1] === '/')) i++
      i++
    } else {
      out += c
    }
  }
  return JSON.parse(out.replace(/,(\s*[}\]])/g, '$1'))
}

let parsed
try {
  const ts = require(require.resolve('typescript', { paths: [projectDir] }))
  parsed = typeof ts.parseConfigFileTextToJson === 'function'
    ? ts.parseConfigFileTextToJson(tsconfigPath, raw)
    : { config: parseJsonc(raw) }
} catch {
  try {
    parsed = { config: parseJsonc(raw) }
  } catch {
    printManualEdit(`could not parse ${path.basename(tsconfigPath)} safely`)
    process.exit(0)
  }
}
if (parsed.error || !parsed.config || !parsed.config.compilerOptions) {
  printManualEdit(`could not parse ${path.basename(tsconfigPath)} safely`)
  process.exit(0)
}

const existing = parsed.config.compilerOptions
const missing = FLAGS.filter((flag) => !(flag in existing))
if (missing.length === 0) {
  console.log(`${path.basename(tsconfigPath)}: strict/noUncheckedIndexedAccess/noImplicitOverride/noFallthroughCasesInSwitch already set`)
  process.exit(0)
}

const marker = /"compilerOptions"\s*:\s*\{/
const match = raw.match(marker)
if (!match) {
  printManualEdit(`could not find "compilerOptions" in ${path.basename(tsconfigPath)}`)
  process.exit(0)
}

const insertAt = match.index + match[0].length
const insertion = '\n' + missing.map((flag) => `    "${flag}": true,`).join('\n')
const updated = raw.slice(0, insertAt) + insertion + raw.slice(insertAt)
fs.writeFileSync(tsconfigPath, updated)
console.log(`set ${missing.join(', ')} = true in ${path.relative(projectDir, tsconfigPath)}`)
