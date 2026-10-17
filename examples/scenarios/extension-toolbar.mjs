// Screenshots of an unpacked extension inside a real Chromium window: panel, toolbar and extensions menu.
// Run: launchvs browser --extension dist/chrome --scenario examples/scenarios/extension-toolbar.mjs --out _tmp/shots
export default async ({ page, extensionId, shot, click, sleep }) => {
  await page.goto(`chrome-extension://${extensionId}/sidepanel/index.html`) // adapt to your extension's entry page
  await sleep(1500)
  await shot('01-panel')                      // whole virtual screen, browser toolbar included
  await click(1166, 62)                       // the browser's "Extensions" button (1280x900 screen)
  await sleep(500)
  await shot('02-extensions-menu', [900, 0, 380, 300]) // cropped area: x, y, width, height
}
