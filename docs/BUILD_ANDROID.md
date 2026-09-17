# BUILD ANDROID (V10 guide)

The project is Android-export-ready:
- Compatibility (GL) renderer works on GLES3 devices
- Touch input fully abstracted (floating joystick + right-half look +
  zoom buttons — all via InputManager)
- PerformanceManager defaults to **Very Low** graphics on first run (fast load);
  players raise to Low/Medium/High/Ultra/Auto in Settings. Touch devices still
  auto-detect; Auto steps quality down under FPS/horde stress.
- No native-only plugins or GDExtensions

## Steps

1. **Install build tools**: Android Studio (SDK + NDK), JDK 17. In Godot: Editor → Editor Settings → Export → Android → set SDK path and debug keystore.
2. **Install Android build template**: Project → Install Android Build Template.
3. **Add preset**: Project → Export → Add → Android.
   - Package: `com.hordesurvival3d`, Orientation: Landscape, Min SDK 24+
   - Textures: ETC2/ASTC (already the project import default)
4. Export APK/AAB; test on a mid-range device: target 30+ FPS with the
   MEDIUM cap (160 enemies).

## Mobile checklist (implemented)

- [x] Virtual floating joystick (left half)
- [x] Right-half camera look, independent of movement
- [x] Zoom +/− buttons (pinch removed by user request)
- [x] Touch-friendly pause button
- [x] Safe-area-friendly HUD anchors
- [ ] Haptics via `Input.vibrate_handheld()` (optional, add later)

## Web-first caveat

The MVP targets Web; Android export is validated but untested on real hardware at this stage. Budget-tune after a device test session (Phase 11-style pass).
