// Screenshot of a web page together with the browser window around it (tabs, address bar).
// Run: launchvs browser --url https://example.com --scenario examples/scenarios/page-in-browser.mjs --out _tmp/shots
export default async ({ page, shot, key, sleep }) => {
  await page.evaluate(async () => {
    await document.fonts.ready
    await new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve)))
  })
  await shot('01-page')
  await key('ctrl+plus', 'ctrl+plus')         // native key presses reach the browser UI, not just the page
  await sleep(300)
  await shot('02-zoomed')
}
