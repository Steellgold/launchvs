# launchvs

A virtual screen (Xvfb) that coding agents can use with a single command. It exists for screenshots that Playwright cannot take, because they include the browser itself: the toolbar, an extension badge or menu, a native window.

Without it, an agent without root rights has to download `.deb` files, extract them, patch Xvfb and write an image converter every time. With it: `launchvs chrome --scenario shots.mjs`.

## Requirements

- Linux x86_64 with `apt-get` (tested on Ubuntu 24.04), `bash`, `python3`.
- Node.js and npm, only for `launchvs chrome` (it installs Playwright and its Chromium).
- Network access during `setup`.
- Root is **not** required.

## Install

```bash
git clone <this repository> ~/repos/launchvs
~/repos/launchvs/setup.sh
ln -s ~/repos/launchvs/bin/launchvs ~/.local/bin/launchvs   # or any directory of your PATH
```

`setup.sh` is idempotent (`--force` redoes the extraction):

- **as root**: installs [`packages.txt`](packages.txt) with `apt-get install`.
- **as a regular user (bootstrap)**: downloads the same packages with `apt-get download` and extracts them into `$LAUNCHVS_HOME` (default `~/.local/share/launchvs`, about 400 MB). Nothing is installed system-wide.

In a Dockerfile you can skip the bootstrap: `RUN apt-get update && apt-get install -y --no-install-recommends $(grep -v '^#' packages.txt)`.

Check the installation with `test/smoke.sh`.

## Usage

```
launchvs run [-s WxH] -- CMD...      temporary screen, destroyed when CMD exits
launchvs start [-s WxH]              persistent screen, prints: export DISPLAY=:N
launchvs stop [:N|all]
launchvs shot OUT.png [x y w h]      whole screen, or a cropped area
launchvs click X Y | type TEXT | key KEY
launchvs chrome [--extension DIR] [--url URL] [--scenario FILE.mjs] [--out DIR] [-s WxH] [--locale xx-XX]
```

Take a screenshot of any program:

```bash
launchvs run -s 800x600 -- sh -c 'my-app & sleep 2; launchvs shot out.png'
```

### Screenshots of an extension in a real Chromium window

`launchvs chrome` opens a visible Chromium (disposable profile, optional unpacked extension) on a virtual screen, then runs your scenario. A scenario is an ES module whose default export receives:

| Property | Description |
| --- | --- |
| `page`, `context` | Playwright objects |
| `worker`, `extensionId` | the extension's service worker and id (when `--extension` is used) |
| `shot(name, crop?)` | writes `OUT/name.png`; `crop` is `[x, y, w, h]` |
| `click(x, y)`, `key(...keys)`, `type(text)` | native input events, so browser UI such as the extensions menu works |
| `sleep(ms)` | wait |

```js
// shots.mjs
export default async ({ page, extensionId, shot, click, sleep }) => {
  await page.goto(`chrome-extension://${extensionId}/sidepanel/index.html`)
  await shot('01-panel')                      // whole virtual screen
  await click(1166, 62)                       // the browser's extensions menu
  await sleep(500)
  await shot('02-menu', [900, 0, 380, 300])   // cropped area
}
```

```bash
launchvs chrome --extension dist/chrome --scenario shots.mjs --out _tmp/screenshots/run1
```

Without `--scenario`, it takes one screenshot (`01-initial.png`) of the page given by `--url`. Either way, `capture-manifest.json` is written next to the images (Chromium version, screen size, files, timestamp).

## How the bootstrap works

Xvfb has two paths compiled in: `/usr/bin` (to find `xkbcomp`) and `/usr/share/X11/xkb` (keyboard data). Extracted anywhere else, it fails with "Failed to compile keymap". `setup.sh` therefore patches a **copy** of the binary, replacing those two strings with `/tmp/xb` and `/tmp/xk`, and `launchvs` recreates these symlinks at every start. The libraries are found through `LD_LIBRARY_PATH`, only for the processes launched by `launchvs`.

This is a pragmatic trick: it depends on the Xvfb build and may break on another distribution release. When you have root, prefer the apt install.

## Troubleshooting

- `Xvfb not found`: run `launchvs setup`.
- `Playwright is missing`: run `launchvs setup` with `node` and `npm` on the PATH.
- Emoji or fonts look wrong: make sure `fonts-noto-color-emoji` is installed (it is part of `packages.txt`).
- A start failure leaves its output in `${TMPDIR:-/tmp}/launchvs-<uid>/xvfb.log`.

## Use with an AI agent

[`skill-snippet.md`](skill-snippet.md) is a short block to paste into an agent skill or instructions file, so the agent calls `launchvs` instead of rebuilding a virtual screen on its own.

## License

[MIT](LICENSE)
