# Publish on itch.io

The game is a static web build, so itch.io just needs the exported files
zipped and uploaded. Everything below can be done from the local machine or
from CI.

## 1. Export the web build

```bash
# From the repository root
godot --headless --editor --path . --import --quit   # import assets once
godot --headless --export-release "Web" build/web/index.html
```

The build lands in `build/web/` and contains:

```
index.html
index.js
index.wasm
index.pck
index.icon.png
index.apple-touch-icon.png
index.audio.worklet.js
index.audio.position.worklet.js
index.offline.html
favicon.png
```

## 2. Add the itch embed shell

itch.io serves the game in an iframe, so the exported `index.html` must be
renamed and wrapped in the itch shell. The repo ships a ready-made wrapper:

```
web/itch/itch.html   -> the itch.io embed page
web/itch/index.html  -> a placeholder that points at the exported build
```

Copy the exported build next to the wrapper and rename the exported entry
point:

```bash
cp build/web/* build/itch/
mv build/itch/index.html build/itch/game.html
```

The wrapper then loads `game.html` in a full-viewport iframe.

## 3. Upload

1. Go to <https://itch.io/jam> or create a project of your own.
2. **Upload a new build** → **HTML** → drag the `build/itch/` folder zipped.
3. Set:
   - **Kind of project**: HTML / Play in browser
   - **This file will be played in the browser**: `index.html`
   - **Viewport size**: `1280x720` (the game scales to the window)
   - **Fullscreen button**: on
   - **Orientation**: landscape
   - **Enable cooperative / mobile controls**: the game has its own touch
     controls, so leave the itch overlay off
4. Set the pricing to **Free** (or name-your-price) and publish.

## 4. PWA / offline

The exported build already registers a service worker, so the game can be
installed on mobile from the itch page. Do not upload the `sw.js` from the
repository root — CI stamps a per-deploy cache name into it, and the itch
build does not need a service worker at all. Exclude it from the zip.

## 5. Landing page

itch.io uses the game's own page for the description. Suggested copy:

> **HordeSurvival 3D** — a third-person survival roguelite. Weapons fire
> automatically; you dodge, dash and choose upgrades. Survive 15 minutes to
> win, or go endless.
>
> - Desktop: WASD + mouse, `F` to dash, `Q`/`E` for abilities
> - Mobile: touch joystick on the left, camera drag on the right
> - 14 weapons, 6 evolutions, 7 characters, 8 campaign missions
>
> Feedback: <https://github.com/mohsen-niksirat/Horde_Survival_3D_Godot/issues/new>

## 6. Automating it (optional)

`itch.io` has a CLI (`butler`) that can push a build from CI:

```bash
# Requires BUTLER_API_KEY in the CI secrets
butler push build/itch/ <your-itch-user>/horde-survival-3d:html
```

Add it as a separate workflow step guarded by the `butler` secret — the
upload is a side effect, so keep it out of the Pages deploy job.
