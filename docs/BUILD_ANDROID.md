# BUILD ANDROID

The project is Android-export-ready:
- Compatibility (GL) renderer works on GLES3 devices
- Touch input fully abstracted (floating joystick + right-half look +
  zoom buttons — all via InputManager)
- PerformanceManager defaults to **Very Low** graphics on first run (fast load);
  players raise to Low/Medium/High/Ultra/Auto in Settings. Touch devices still
  auto-detect; Auto steps quality down under FPS/horde stress.
- No native-only plugins or GDExtensions

## Export preset

The `Android` preset already lives in `export_presets.cfg`:

| Setting | Value |
|---|---|
| Package name | `com.mohsenhorde.hordesurvival3d` |
| Architectures | ARM64 (`arm64-v8a`) enabled; ARMv7 disabled — enable it for pre-2018 devices |
| Version | `1.0.0` (code `1`) |
| Orientation | Landscape (from `project.godot`) |
| Renderer | Compatibility (GL) |
| Screen | Immersive mode on |
| Permissions | None (the game is fully offline) |

## Steps (local build)

1. **Install build tools**: Android Studio (SDK + NDK), JDK 17. In Godot: Editor → Editor Settings → Export → Android → set SDK path and debug keystore.
2. **Install Android build template**: Project → Install Android Build Template.
3. Export APK/AAB via the `Android` preset; test on a mid-range device:
   target 30+ FPS with the MEDIUM cap.

## Steps (CI build)

`.github/workflows/build-android.yml` runs on every push to `main`:

1. Installs Godot 4.7.2 + export templates + JDK 17
2. Imports assets headless and refuses to build on import errors
3. Runs the headless test suite (`tools/run_tests.py`)
4. Exports a **debug-signed** APK to `build/android/HordeSurvival3D.apk`
5. Uploads it as the `HordeSurvival3D-debug-apk` artifact (14-day retention)

Download it from the Actions run summary → Artifacts → unzip → install the APK
on a device (Android may ask to allow "install from unknown sources").

## Release APK (later)

A release build needs a keystore. The intended setup:

1. Generate a keystore locally (`keytool -keyalg RSA -genkeypair -alias horde ...`).
2. Store it in the repo as `android/keystore.tres` **or** keep it out of git and
   upload it as a CI secret. The credential file must never be committed.
3. Add a `release` build to the export preset pointing at the keystore.
4. Sign the CI secret in as `ANDROID_KEYSTORE_BASE64` + `ANDROID_KEYSTORE_PASSWORD`
   and decode it in the workflow before exporting.

Until that exists, CI only produces debug APKs.

## Mobile checklist (implemented)

- [x] Virtual floating joystick (left half)
- [x] Right-half camera look, independent of movement
- [x] Zoom +/− buttons (pinch removed by user request)
- [x] Touch-friendly pause button
- [x] Safe-area insets applied to the HUD and the touch overlay (`scripts/ui/safe_area.gd`)
- [x] Android back button: pauses in-game, steps back in sub-menus, asks for confirmation on the main menu
- [x] App lifecycle: backgrounding the app auto-pauses the run and flushes the save immediately
- [x] Touch dash/ability buttons report their state through `InputManager.set_touch_action()`
- [ ] Haptics via `Input.vibrate_handheld()` (optional, add later)

## Web-first caveat

The MVP targets Web; Android export is validated by CI and headless tests but
has not been play-tested on real hardware yet. Budget-tune after a device test
session.
