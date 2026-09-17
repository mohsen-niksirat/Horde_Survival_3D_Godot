# BUILD WEB

## Requirements

- Godot 4.7+ (matches `config/features` in project.godot; CI uses `4.7-stable`)
- Godot Web export templates (Editor → Manage Export Templates → Download)

## Local Export

1. Open the project in Godot.
2. **Project → Export…** — the `Web` preset is pre-configured (uses `web/custom_shell.html`).
3. Export project → `build/web/index.html`.
4. Test locally: `godot --path . --remote-debug` won't serve files; instead run a static server, e.g.:
   - PowerShell: `python -m http.server -d build/web 8080` (or use the VS Code Live Server extension)
   - Open `http://localhost:8080`

Note: WebGL builds require a server (file:// won't load WASM).

## CI Deployment (GitHub Pages)

`.github/workflows/deploy-web.yml` triggers on every push to `main`:

1. Checkout
2. Install Godot 4.7-stable + export templates (`lihop/setup-godot@v2`)
3. Headless import (twice, for class cache stability)
4. `godot --headless --export-release "Web" build/web/index.html`
5. Upload + deploy `build/web` via actions/deploy-pages

One-time setup: **Repository Settings → Pages → Build and deployment → Source: GitHub Actions**.

The live URL becomes: `https://mohsen-niksirat.github.io/Horde_Survival_3D_Godot/`

## The Custom Loading Shell

`web/custom_shell.html` is Godot's custom HTML shell (placeholders `$GODOT_URL`, `$GODOT_CONFIG`, `$GODOT_HEAD_INCLUDE` are substituted at export). It provides:

- Animated progress bar wired to `engine.setProgressFunc`
- **Click-to-Play** gate: the game boots only after a user gesture (satisfies browser autoplay policies; the in-game boot scene also expects this)
- Progress bar stays visible while the engine downloads after PLAY (Phase 1 fix)
- WebGL support detection with a friendly fallback message
- Mobile-friendly viewport (no zoom, full-bleed canvas)

## PWA

The export preset enables `progressive_web_app/enabled=true` (display: standalone, landscape). Godot generates the manifest/service worker pieces alongside the build. Cross-origin isolation headers (SharedArrayBuffer/threads) are NOT required (thread_support=false), so plain Pages hosting works.

## Troubleshooting

- **Blank page after deploy**: check the browser console; ensure Pages source is "GitHub Actions", not "Deploy from a branch".
- **Class cache errors in CI**: the workflow runs `--import` twice deliberately; keep that if editing the workflow.
- **Audio doesn't start**: audio unlocks on the PLAY click; don't remove the gate.
