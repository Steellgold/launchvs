// Launches a visible Chromium window (disposable profile) on the virtual screen and runs an optional scenario.
// Called by `launchsv chrome`; configured through LAUNCHSV_* environment variables.
import { createRequire } from 'node:module'
import { execFile } from 'node:child_process'
import { promisify } from 'node:util'
import { mkdtemp, rm, writeFile } from 'node:fs/promises'
import { tmpdir } from 'node:os'
import path from 'node:path'
import { pathToFileURL } from 'node:url'

const exec = promisify(execFile)
const env = process.env
const require = createRequire(path.join(env.LAUNCHSV_HOME, 'node', 'package.json'))
const { chromium } = require('playwright')

const [width, height] = env.LAUNCHSV_SIZE.split('x').map(Number)
const out = env.LAUNCHSV_OUT
const extension = env.LAUNCHSV_EXTENSION || ''
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms))
const files = []

const sv = (...args) => exec(env.LAUNCHSV_BIN, args)
const shot = async (name, crop) => {
  const file = path.join(out, `${name}.png`)
  await sv('shot', file, ...(crop ? crop.map(String) : []))
  files.push(path.basename(file))
  console.log(file)
  return file
}

const profile = await mkdtemp(path.join(tmpdir(), 'launchsv-profile-'))
const args = ['--no-sandbox', `--window-size=${width},${height}`, '--window-position=0,0']
if (extension) args.push(`--disable-extensions-except=${extension}`, `--load-extension=${extension}`)

const context = await chromium.launchPersistentContext(profile, {
  channel: 'chromium',
  headless: false,
  viewport: null,
  locale: env.LAUNCHSV_LOCALE || 'en-US',
  colorScheme: 'light',
  reducedMotion: 'reduce',
  args,
})

let exitCode = 0
try {
  let worker
  let extensionId
  if (extension) {
    worker = context.serviceWorkers()[0] ?? (await context.waitForEvent('serviceworker', { timeout: 15000 }))
    extensionId = new URL(worker.url()).host
  }
  const page = context.pages()[0] ?? (await context.newPage())
  if (env.LAUNCHSV_URL) await page.goto(env.LAUNCHSV_URL, { waitUntil: 'domcontentloaded' })

  const ctx = {
    context, page, worker, extensionId, shot, sleep,
    click: (x, y) => sv('click', String(x), String(y)),
    key: (...keys) => sv('key', ...keys),
    type: text => sv('type', text),
  }

  if (env.LAUNCHSV_SCENARIO) {
    const scenario = (await import(pathToFileURL(env.LAUNCHSV_SCENARIO).href)).default
    if (typeof scenario !== 'function') throw new Error('the scenario must `export default async (ctx) => { ... }`')
    await scenario(ctx)
  } else {
    await page.evaluate(async () => {
      await document.fonts.ready
      await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
    })
    await shot('01-initial')
  }

  const manifest = {
    mode: 'Visible Chromium window on a virtual screen (Xvfb); screenshots of the whole screen or of an area',
    chromium: context.browser()?.version() ?? null,
    extension: extension || null,
    url: env.LAUNCHSV_URL || null,
    scenario: env.LAUNCHSV_SCENARIO || null,
    screen: { width, height, dpr: 1 },
    locale: env.LAUNCHSV_LOCALE || 'en-US',
    createdAt: new Date().toISOString(),
    files,
    notes: 'Disposable browser profile. State injected by the scenario does not prove an external integration.',
  }
  await writeFile(path.join(out, 'capture-manifest.json'), JSON.stringify(manifest, null, 2))
} catch (error) {
  console.error(error)
  exitCode = 1
} finally {
  await context.close().catch(() => {})
  await rm(profile, { recursive: true, force: true }).catch(() => {})
}
process.exit(exitCode)
