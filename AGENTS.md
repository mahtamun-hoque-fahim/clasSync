# ClasSync

Weekly class routine for Android and web, with a silent lock-screen alert before each class and gap period.

## Current State

- Updated: 2026-11-10
- Status: Beta — single user, installed on one phone (Redmi `25078RA3EA`)
- Works: Google sign-in; routine sync through Firestore; routine and teacher editing; CT (class test) add/edit/delete with custom reminders; CT auto-delete once its time passes; scheduling and delivery of exact alarms; a one-line **lock-screen alert** that wakes the screen, sits over the keyguard and closes itself after 20 s; a 250 x 180dp **home-screen widget** showing the class now and the next one, kept fresh by its own exact alarms; the class running right now filled with the accent in today's list; gap-period reminder at 08:00 on class days; settings (accent, theme mode, class days, reminder offsets, JSON import) with switchable System/Light/Dark theme synced in the routine doc; newly generated app icon on the launcher; notification small icon; web dashboard build.
- In progress: nothing half-built in code. The widget is built and compile-verified, but not yet observed on the launcher.
- Next: (1) re-run the release APK build and confirm the alert screen there, since everything so far was verified with a debug build; (2) decide whether the alert should also cancel the notification instead of leaving it in the shade.
- Watch out: `flutter_local_notifications` builds its pending intent from `getLaunchIntentForPackage()`, so **`RouterActivity` must keep the `MAIN`/`LAUNCHER` filter**. Move that filter back to `MainActivity` and every alert silently opens the dashboard again with no error anywhere. `AlertActivity` is `exported="false"`, so only that router can start it.
- Watch out: firing the test alert twice in a row without clearing the notification does **not** re-trigger the full-screen intent. The second post has the same id and is treated as an update, so the screen stays off and it looks as if the alert is broken. Force-stop the app (or dismiss the notification) between test runs.


## Git Identity (Session Start — run before any commit, every session)

```
git config user.name "mahtamun-hoque-fahim"
git config user.email "mahtamunhoquefahim@gmail.com"
```

Execute automatically at the start of every session, before the first commit — never ask, never skip, never commit as Claude. This applies across every Claude account/session working this repo.

## Setup & Commands

- Install: `flutter pub get`
- Analyze: `flutter analyze`
- Tests: `flutter test`
- Run on device: `flutter run`
- Run web dashboard: `flutter run -d chrome`
- Build APK: `flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk`
- Build web: `flutter build web --release`
- Deploy: `firebase deploy --only hosting,firestore:rules`
- Regenerate icons: `npm install @resvg/resvg-js pngjs` then `node tool/generate_icons.js`

## Conventions & Non-Negotiables

- No emojis anywhere in code or UI — Material icons or inline SVG only
- One concern per commit. Every small change gets its own commit with a `type(scope): summary` message; never mix a fix, a feature and a doc update in one commit, and never batch unrelated edits because they were finished at the same time.
- Every Session Log entry starts with a `- By:` line naming the agent that did the work (`DeepSeek V4.1 Flash Free (OpenCode)`, and so on). Several agents work this repo, often at the same time, so an unattributed entry is useless when two sessions touch the same files.
- The notification small icon is passed as a **bare** drawable name: `AndroidInitializationSettings('ic_status')`. `flutter_local_notifications` 22.x resolves it with `getIdentifier(name, "drawable", pkg)` and throws `invalid_icon` on any `@drawable/` or `@mipmap/` prefix.
- Any drawable referenced only from a Dart string must be pinned in `android/app/src/main/res/raw/keep.xml` with `tools:keep`. Flutter release builds enable `shrinkResources`, which cannot see Dart-only references and silently drops them — debug builds keep working, so the breakage only shows up in a release APK.
- `AlertScheduler.init()` runs before `runApp()`. It must never throw; a failure there means a blank screen instead of an error.
- Accents come from `lib/theme.dart` `swatches`. The default `teal` seed `0xFF009688` produces M3 primary `#006A60`, used for the icon background and web theme colour.
- The icon source of truth is `assets/icon/clasSync-icon.svg`. Never hand-edit the generated PNGs; edit the SVG and re-run the generator.
- A CT is time-bound data, not a schedule: it deletes itself once its time passes, and alerts are only built for CTs whose reminder time is still in the future.

## Security Gotchas

- `firebase_options.dart` values are public by design; `firestore.rules` is the real gate. Each user may only read and write their own `routines/{uid}` document and its `cts` subcollection.
- The release APK is signed with the debug key, and its SHA-1/SHA-256 are registered in Firebase. Replacing that keystore breaks Google sign-in. A Play Store release needs a real signing key.
- `showWhenLocked` + `turnScreenOn` mean the alert activity is visible and interactive while the device is locked. Nothing behind it is exempt from the lock, but anything rendered there can be read without unlocking — keep the alert screen to the minimum class detail.

## Session Log

### 2026-11-10 (widget session)
- By: GLM-5.3-Flash Free (OpenCode)
- Did: Built a 250dp x 180dp home-screen widget (chosen footprint: full width, ~2-2.8 in tall, Now + Next only) as **native Kotlin**, because Flutter cannot draw an Android home-screen widget. `ClassWidgetProvider` renders two rows from RemoteViews: the running class (`NOW · COURSE` + `teacher · room · 09:30–10:20`) or a free/no-classes headline, and the next class below.
- Did: Data path with no new dependencies. `lib/widget/widget_sync.dart` serializes the whole week (adjacent same-class periods merged into one slot, matching how build_alerts merges lab blocks) and hands the JSON over a `classync/widget` MethodChannel to `MainActivity`, which stores it in a dedicated `classync_widget` SharedPreferences file and redraws via `AppWidgetManager`. The provider never needs the Flutter process.
- Did: Self-refreshing without the app alive. The provider re-arms one exact alarm (`setExactAndAllowWhileIdle`, falling back to `set()` without the S+ permission) for the next class start/end, else the next class day's first period, else midnight; `BOOT_COMPLETED`/`MY_PACKAGE_REPLACED` re-render and re-arm. A 2 h `updatePeriodMillis` is the safety net.
- Did: Theming through the snapshot — the payload carries the accent seed hex plus a lightened-on-dark variant (Dart computes it, since Kotlin has no color library here); backgrounds/corner radii use `@color`-backed drawables that resolve `values-night` for dark mode. Caveat: the widget follows **system** dark mode, not the in-app theme-mode override.
- Did: Pushed on every routine-stream emission and cleared on sign-out; web is guarded with `kIsWeb` (channel silently a no-op there).
- Did: Caught a real bug in the merge loop — `row[i + 1]!` on a free period was a null check on a legitimate null; and the merged slot must keep the FIRST period's start, not the last's after advancement.
- Did: Coordinated with a parallel session (DeepSeek) that was shipping the alert screen: verified the working tree after their commits contained only widget diffs in the four shared modified files, then committed on top. No device installs from this session per the shared-phone rule; Kotlin was compile-checked with a no-install `flutter build apk --debug` instead, which also confirms the manifest/resources are valid.
- Committed: `feat(widget): 250dp x 180dp home-screen widget showing the class now and next` (a6240b4). `flutter analyze` clean, all 140 tests pass, `flutter build apk --debug` succeeds.
- Open: The widget compiles but has not yet been seen on the launcher — needs an install once the phone frees up, plus a look at boundary re-renders across a real class change and weekend roll.

### 2026-11-10 (alert-screen session)
- By: DeepSeek V4.1 Flash Free (OpenCode)
- Did: Built the dedicated alert screen as **native Kotlin**, not a Flutter route. `flutter_local_notifications` resolves its pending intent with `getLaunchIntentForPackage()`, and a full-screen intent waits for the first frame, so a Flutter screen would boot the engine with the dashboard visible underneath. `AlertActivity` renders one dark line (`COURSE · TEACHER · ROOM`) with the time, over a teal rule, and self-closes after 20 s.
- Did: Verified it end to end on the real locked screen. A scheduled CT alert woke the display, put `topResumedActivity` on `AlertActivity` in its own task (t4759) with `isKeyguardShowing=true`, `mKeyguardOccluded=true`, `deviceLocked=1` and `mWakefulness=Awake`; the screen rendered correctly, auto-dismissed at 20 s back to the lock screen with the notification preserved, and a tap dismissed it early.
- Did: Added `RouterActivity` to hold the `MAIN`/`LAUNCHER` filter and forward `SELECT_NOTIFICATION` to `AlertActivity`, everything else to `MainActivity`. `MainActivity` lost its launcher filter and its `showWhenLocked`/`turnScreenOn`, so the dashboard can no longer draw over the keyguard even by accident. Confirmed with `aapt2 dump badging` that the app still has a launchable activity.
- Did: Caught a real bug with that same `aapt2` check. `RouterActivity` was left self-closing with no `intent-filter`, which removed the app's launcher entry entirely — the APK would have installed with no way to open it.
- Did: Carried the alert text in the notification `payload` as JSON. The single pending intent serves both `contentIntent` and `fullScreenIntent`, so the payload is the only way the activity learns what to show.
- Did: Copied `intent.extras` onto the forwarded dashboard intent. `flutter run` passes `--ez enable-dart-profiling` and friends to the launcher activity and `FlutterActivity` reads them from its own intent, so the router hop would have silently dropped them.
- Did: Filled the class running right now with the accent (`primaryContainer` / `onPrimaryContainer`) instead of a hardcoded swatch, so it follows the chosen accent and stays legible in both themes. Added `isOnNow()` to the model so a double period lights up both of its rows, and refactored `today()`'s `start <= minute < end` test into one shared helper.
- Decided: Kept `MainActivity` `exported="true"` with no filter rather than tightening it, to avoid breaking `adb shell am start` tooling while that path is untestable.
- Learned: Firing the test alert twice without clearing the notification does **not** re-trigger the full-screen intent — the second post has the same id and is an update, so the screen stays off and the alert looks broken. Cost several false negatives; force-stop between runs.
- Learned: The display times out in seconds on this phone, which poisons every screenshot. `adb shell svc power stayon true` plus `screen_off_timeout 1800000` is required. `adb shell date` cannot set the clock (no root), so the live-class highlight was checked with a temporary golden render instead.
- Committed: `6e426bc` payload, `4a166cf` alert screen, `d99d959` router, `4e8d67f` keyguard fix, `276a767` extras fix, `4b014b3` `isOnNow`, `9f8f27d` accent highlight. `flutter analyze` clean, all 140 tests pass.

### 2026-11-09
- Did: Shipped a switchable theme — `Routine` gained a `themeMode` field (`system` / `light` / `dark`); missing or unknown values parse to `system`, so old docs and imported JSON keep working. `buildTheme` now builds a seeded dark scheme (`ColorScheme.fromSeed(brightness:)`), and `main.dart` carries `theme` + `darkTheme` + `themeMode` through a shared `ClasSyncMaterialApp`. Settings has a System/Light/Dark segmented button; the preference lives in the routine doc and syncs like accent, and signed-out users follow the system setting.
- Committed: `feat(theme): switchable system/light/dark theme stored in the routine` (e4f110c). `flutter analyze` clean, all 126 tests pass.

### 2026-11-08
- Did: Root-caused why no notification had ever arrived. The app was installed on 1 Nov, before the commit that seeds the routine, so the stored routine was empty and `buildAlerts` produced zero alerts. Permissions and MIUI battery management were never the cause.
- Did: Verified the scheduled path end to end on the device. A CT with a 5-minute custom reminder produced exactly one alarm at `Sun 08 Nov 19:00:00` (the past 1 h / 6 h / 1 d defaults were correctly skipped); it fired at `19:00:00.048`, woke the screen, launched through `fullScreenIntent` at +1.038 s, played no sound, preserved `deviceLocked=1`, and the CT auto-deleted after its 19:05 time.
- Did: Fixed a latent bug that had been failing on every launch. `AndroidInitializationSettings` was given `'@mipmap/ic_launcher'`, but plugin v22.3.3 resolves icons with `getIdentifier(name, "drawable", pkg)` and rejected it with `invalid_icon`. Now `'ic_status'`.
- Did: Fixed a release-only failure. `shrinkResources` dropped `drawable/ic_status` (`resources.txt`: "is not reachable"), so the release APK threw `invalid_icon` while debug worked. Added `res/raw/keep.xml` with `tools:keep="@drawable/ic_status"`; the shrinker now reports "reachable from keep xml file" and the resource is present in the APK.
- Did: Made `AlertScheduler.init()` non-fatal. Because it awaits before `runApp()`, a single throw produced a black screen with no visible app; it now catches and `debugPrint`s, so a notification problem degrades alerts instead of bricking the UI.
- Did: Shipped the supplied app icon. Generated legacy launcher bitmaps, adaptive foreground and monochrome layers, a notification silhouette, web favicon and maskable icons, and a 1024 master; committed the generator at `tool/generate_icons.js` with the SVG as source of truth.
- Did: Finished branding — `android:roundIcon`, an accurate web `manifest.json`, and `index.html` description plus `theme-color`.
- Did: Confirmed 21 distinct scheduled alarms with no duplicates, surviving several reinstalls and a MIUI OneKeyClean kill.
- Decided: Kept the supplied artwork as-is, including the `#D9D9D9` ring behind the cap, rather than redesigning it. The background is `#006A60`, the M3 primary of the `teal` seed, sampled from a real screenshot instead of guessed.
- Decided: Notification vibration is not an app bug and was left alone. The device cancels vibration app-wide (`cancelled_by_app_ops`, duration 0–16 ms) and WhatsApp shows the same cancellation, so it is a system setting outside the app.
- Open: The alert opens the full dashboard over the lock screen and does not self-close, leaving the lock-screen notification visible for only about one second. Classified as a UX defect to fix, not as designed behaviour.
- Next: Build the dedicated alert screen (small dark one-line `COURSE · TEACHER · ROOM` with time, auto-close around 20 s, tap or swipe to dismiss), point `fullScreenIntent` at it, then commit the icon and notification work.
