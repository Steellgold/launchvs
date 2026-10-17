### Capturing outside the page (browser toolbar, extension badge or menu, native windows)

Playwright screenshots never include the browser UI. For those targets use `launchvs` (virtual screen, already on the PATH). Do not install Xvfb or extract `.deb` files by hand.

- `launchvs help` lists everything. If the command is missing, run `~/repos/launchvs/setup.sh` once.
- Write a short scenario, then run `launchvs chrome --extension <dist-dir> --scenario s.mjs --out <dir>` (add `--url` or `-s 1280x900` as needed). `--browser firefox` runs Firefox instead of Chromium (no `--extension` support):
  ```js
  export default async ({ page, extensionId, shot, click, sleep }) => {
    await page.goto(`chrome-extension://${extensionId}/sidepanel/index.html`)
    await shot('01-panel')                       // whole virtual screen
    await click(1166, 62)                        // native click, e.g. the extensions menu
    await shot('02-menu', [900, 0, 380, 300])    // cropped area x, y, w, h
  }
  ```
- It uses a disposable profile and writes `capture-manifest.json` next to the PNGs. Inspect every PNG as usual.
- Describe these captures as a real Chromium window on a virtual screen (Xvfb), not as a page screenshot.
