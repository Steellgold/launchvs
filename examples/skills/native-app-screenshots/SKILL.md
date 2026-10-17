---
name: native-app-screenshots
description: Run any X11 or GUI program headless and screenshot it with launchvs (virtual screen, native clicks and typing). Use for desktop apps, Electron or GTK/Qt windows, or any program that needs a DISPLAY.
---

# Native app screenshots

`launchvs` provides a virtual X11 screen, so GUI programs can run on a server with no monitor.

## Before you start

`command -v launchvs`. If missing: `git clone https://github.com/Steellgold/launchvs ~/repos/launchvs && ~/repos/launchvs/setup.sh` (no root needed), then add `~/repos/launchvs/bin` to the PATH.

## One-shot: start, capture, clean up

```bash
launchvs run -s 1024x768 -- sh -c 'my-app & sleep 3; launchvs shot _tmp/shots/home.png'
```

The screen exists only while the command runs. Wait for the app to be ready (a fixed `sleep` is acceptable, a readiness check is better).

## Several steps on one screen

```bash
eval "$(launchvs start -s 1280x800)"     # prints and applies: export DISPLAY=:N
launchvs exec my-app &                  # "exec" gives the app the libraries launchvs installed
sleep 3
launchvs shot _tmp/shots/01-home.png
launchvs click 640 400                    # native mouse click
launchvs type "hello"                     # native typing
launchvs key Return
launchvs shot _tmp/shots/02-after.png 0 0 640 400   # cropped area: x y w h
launchvs stop all                         # always clean up
```

## Rules

- Open and inspect every PNG before reporting it.
- Always stop screens created with `launchvs start` (`launchvs stop all`), and kill the app you started.
- For a browser or an extension, use the `browser-ui-screenshots` skill instead.
