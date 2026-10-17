---
name: browser-ui-screenshots
description: Take screenshots that include the browser itself (toolbar, extension badge or menu, tabs, address bar) with launchvs. Use when Playwright page screenshots are not enough because the target is browser UI or an unpacked extension.
---

# Browser UI screenshots

Playwright screenshots never include the browser UI. `launchvs` runs a visible Chromium on a virtual screen (Xvfb) and captures that screen.

## Before you start

1. Check the tool: `command -v launchvs`. If it is missing, install it once (no root needed): `git clone https://github.com/Steellgold/launchvs ~/repos/launchvs && ~/repos/launchvs/setup.sh`, then add `~/repos/launchvs/bin` to the PATH.
2. Build the extension if the target is one. You need the directory that contains its `manifest.json`.

## Steps

1. Write a scenario (about 10 lines) in a temporary location, for example `_tmp/scenario.mjs`. Start from `~/repos/launchvs/examples/scenarios/extension-toolbar.mjs` or `page-in-browser.mjs`.
   - `shot(name)` captures the whole screen, `shot(name, [x, y, w, h])` a cropped area.
   - `click(x, y)`, `key('ctrl+l')` and `type('text')` send native input, so they reach browser UI such as the extensions menu.
2. Run it: `launchvs chrome --extension <dist-dir> --scenario _tmp/scenario.mjs --out _tmp/screenshots/<task>`. Use `--url <url>` for a web page, `-s 1280x900` to change the screen size.
3. Open every PNG and check it. Coordinates depend on the screen size: take a full screenshot first, then crop.
4. Report the paths. Say these are screenshots of a real Chromium window on a virtual screen, and mention the generated `capture-manifest.json`.

## Rules

- The browser profile is disposable. Never use a personal profile or real accounts.
- Do not claim a real third-party integration works because a state was injected by the scenario.
- Do not commit the screenshots unless asked.
