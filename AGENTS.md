# ClasSync

Weekly class routine for Android and web, with a silent lock-screen alert before each class and gap period.

## Current State

- Updated: 2026-11-13
- Status: Beta — single user, installed on one phone (Redmi `25078RA3EA`)
- Works: Google sign-in; routine sync through Firestore; routine and teacher editing; CT (class test) add/edit/delete with custom reminders; CT auto-delete once its time passes; scheduling and delivery of exact alarms; a one-line **lock-screen alert** that wakes the screen, sits over the keyguard and closes itself after 20 s; the **Now card state machine** (`lib/model/now_state.dart`) shared by app and widget: theory/lab, Spider-Man homecoming, Sweet Home, X Incoming, night-before day off, Day Off/Near, exam countdowns (days, hours, Today), vacation; **class/exam/vacation mode** in settings with exam editing (course, date, own or shared time, JSON paste) and the rule that exams are **never on Friday or Saturday** (enforced at parse, editor and paste); a **date-keyed 21-day state timeline** pushed with the widget snapshot, which the widget renders as the state card (title, subtitle, accent-gradient icon tile drawn as one bitmap) with a weekly-grid fallback when the timeline is missing or stale; the **Now** card filled with an accent gradient in **every** state (live, gap, tough), and the live row in today's list gradient-filled while a class runs; all accent fills are the **raw swatch** (`accentFill`), never pale containers - week-grid cells included; gap-period reminder at 08:00 on class days; settings (accent, theme mode, class days, reminder offsets, JSON import) with switchable System/Light/Dark theme synced in the routine doc; newly generated app icon on the launcher; notification small icon; web dashboard build.
- In progress: nothing half-built in code. The **release APK** on the phone (debug-key signature, data preserved; cold start 1.6 s) is the previous build — a new release APK with the state-card widget is built and waiting to be installed.
- Next: (1) install the new release APK and verify the app Now card and the widget's state card across states (live class, day off, exam countdown) on the phone; (2) decide whether the alert should also cancel the notification instead of leaving it in the shade.
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
- "Active right now" is expressed with the **full** accent: `colorScheme.primary` + `onPrimary`. Never `primaryContainer` / `surfaceVariant` for a live state — the user reads a pale tint as disabled, not as now. The only exception is a tough class, which keeps its amber.

## Security Gotchas

- `firebase_options.dart` values are public by design; `firestore.rules` is the real gate. Each user may only read and write their own `routines/{uid}` document and its `cts` subcollection.
- The release APK is signed with the debug key, and its SHA-1/SHA-256 are registered in Firebase. Replacing that keystore breaks Google sign-in. A Play Store release needs a real signing key.
- `showWhenLocked` + `turnScreenOn` mean the alert activity is visible and interactive while the device is locked. Nothing behind it is exempt from the lock, but anything rendered there can be read without unlocking — keep the alert screen to the minimum class detail.

## Session Log

### 2026-11-13 (widget state-card session)
- By: GLM-5.3-Flash Free (OpenCode)
- Did: Finished the native widget's migration to the state card. `ClassWidgetProvider.buildViews` now parses the snapshot's `timeline` (date-keyed points of minute/title/subtitle/icon) and renders the state card: `NOW` label, state title as the headline, subtitle in the dim tone, and the state's gradient icon tile drawn as one bitmap (`iconTile`: 70% accent top -> full accent bottom rounded square with the white glyph over it). While a class runs it keeps the `NEXT` row from the weekly grid; the non-running states already carry "Next - ..." in their subtitle, so the row hides there. Falls back to the old weekly rendering (and hides icon/sub lines) whenever the timeline is missing or stale past its 21 days.
- Did: Rewrote `scheduleNext` to arm exact alarms from the timeline when it exists: today's next change point, else each later date's first (midnight) point, out to day 21; the weekly-grid logic remains as fallback, and the midnight+2 min re-render covers the day roll when both are exhausted.
- Did: Rewrote `class_widget.xml` as the reference layout: text column (`nowLine`/`nowMain`/`stateSub`/`nextLine`) plus a 64dp `stateIcon` ImageView; added the `widget_state_icon` string.
- Did: Pinned all 11 `state_*` drawables in `res/raw/keep.xml` (referenced from Kotlin via `getIdentifier`, so `shrinkResources` cannot see them); verified in the release APK with `aapt2 dump resources`.
- Did: Renamed every camelCase state icon key to snake_case (`gradCap`->`grad_cap`, `testTube`->`test_tube`, `homeAlert`->`home_alert`, `planeTakeOff`->`plane_take_off(1)`, `clipboardArrow`->`clipboard_arrow`, `clipboardCheck`->`clipboard_check`) and regenerated the PNGs: Android resource names allow only lowercase a-z/0-9/underscore, and the resource merger rejects `state_clipboardArrow.png` outright. Keys now live in `now_state.dart`, the generator's KEYS map, `keep.xml` and the state tests.
- Did: Fixed the build break that surfaced mid-session: `JAVA_HOME` on this machine points at JDK 26 (`H:\file source java`), whose jlink refuses the SDK's `core-for-system-modules.jar` ("cannot find the build signature"), killing every `compileDebugJavaWithJavac` under Gradle 9.3.1/AGP 9.1. Pinned `org.gradle.java.home` to the Android Studio JBR (25) in `android/gradle.properties`; builds work again.
- Learned: When Gradle fails inside an Android transform (`JdkImageTransform`), the real cause is one `Caused by:` deeper than the summary line - running the exact failing tool (`jlink.exe ... --disable-plugin system-modules`) by hand names the actual problem in one line.
- Learned: `androidx.appcompat` is not a direct dependency of the app module - the icon tile uses the platform `context.getDrawable()` instead of `AppCompatResources` (the glyphs are plain PNGs; no AppCompat inflation needed).
- Committed: `3af865c` snake_case icon keys, `986f551` widget renders the state card, `91617ec` gradle daemon pinned to the Studio JBR. `flutter analyze` clean, all 179 tests pass, debug and release APKs build, state drawables confirmed present in the shrunken release APK.
- Open: On-device verification of the app Now card and the widget state card across states; the alert-screen notification-cancel decision from 2026-11-12.

### 2026-11-12 (startup + no-pale session)
- By: GLM-5.3-Flash Free (OpenCode)
- Did: Made the **Now** card gradient-highlighted in every state (live, gap, tough), per "regardless of any state". The amber exception now belongs to the week-grid cells and the live-row dot only, never the Now card.
- Did: Killed every pale accent, per the user's reference sketch. New `theme.dart` helpers: `accentFill` (the raw swatch, in both themes - containers never touch live fills), `inkOnAccent` (black ink on light accents like orange, white on the rest, chosen by luminance), and `liveGradient` (swatch plus/minus one HSL lightness step, so the ramp is saturated end to end with no white lerp). Applied to the Now card, today's live row, the week-grid cells (which still used `primaryContainer`), and the widget snapshot (now ships the raw swatch hex instead of the scheme-derived primary). For the blue swatch that renders #378FE7 -> #1561AE, matching the reference.
- Did: Root-caused the ~10 s cold start. The installed APK was `DEBUGGABLE` - a debug build. Instrumented probes (removed after measuring) showed: Firebase init 693-763 ms, scheduler init +215-241 ms, first frame 6.5-8.3 s in debug. An airplane-mode rerun measured 6.7 s - the same as online - so the network is not a factor; Firestore's cache still delivered the routine in ~1.2 s offline. The release build measured **+1 s584 ms** on the device and is now installed (same debug-key signature, data preserved).
- Learned: `adb exec-out screencap` through a PowerShell redirect corrupts the PNG; use `adb shell screencap /sdcard/...` plus `adb pull` instead.
- Committed: `f44516c` Now card always gradient, `963530c` raw swatch everywhere, and the probe-removal change (tree returned byte-identical to HEAD, so no commit). `flutter analyze` clean, all 140 tests pass, release APK installed and cold start verified at 1.6 s.
- Open: the installed release APK still carries three timing `debugPrint`s (built before the probes were removed); they are inert in release and drop out of the next build. Alert screen and widget behavior in the release build still need the manual locked-screen pass.

### 2026-11-11 (gradient-highlight session)
- By: GLM-5.3-Flash Free (OpenCode)
- Did: Restyled the live-class highlight into a **vertical accent gradient** per the user's sketch: a lighter wash of the accent at the top melting into the full accent at the bottom, replacing the flat `colorScheme.primary` fill. Applied to both live surfaces — the **Now** card at the top and the running row in today's list. No icon was added; the user will supply artwork later, and the sketch only covers the top of the screen.
- Did: Implemented as `liveGradient(scheme, brightness)` in `home_page.dart`, derived from the user's chosen accent (`ColorScheme.primary`), so it follows every swatch in settings. `Ink` + `BoxDecoration(gradient)` inside a transparent `Material`/`Card` with `Clip.antiAlias`, because `Card`/`Material` cannot hold a gradient directly. Dark mode ramps from the scheme's (already light) primary down 15% toward black so the direction stays light-to-deep.
- Did: Kept the house rules intact — tough classes stay flat amber, on-primary ink unchanged, and the gradient only replaces the "live" fill. `GridPage`'s `primaryContainer` use was left alone (that session's context may differ; the user's sketch was about the home screen).
- Learned: `ListTile` wraps its own content in an `Ink` with a transparent `ShapeDecoration`, so a row styled with an outer `Ink` has **two** `Ink` ancestors — `find.ancestor(...).first` grabs ListTile's built-in one and the test must filter for the `BoxDecoration`-carrying Ink.
- Committed: `af7a274` `feat(home): fill the class running now with an accent gradient`. `flutter analyze` clean, all 140 tests pass (the live-highlight test now asserts the gradient).

### 2026-11-11 (accent-highlight session)
- By: DeepSeek V4.1 Flash Free (OpenCode)
- Did: Placed the widget on the launcher for real, through long-press → Widgets → search `ClasSync`, because `am start -a android.appwidget.action.APPWIDGET_PICK` does nothing on the MIUI/HyperOS launcher (it also crashes `com.android.settings`' picker). It bound to `com.miui.home` host `1024` at provider `[157]` and landed on home-screen page 5 — page 1 is already full. The user can drag it wherever they want it.
- Did: Verified the widget's data on the device, both states. With nothing live it read `Next class / DLD at 09:30 · 224`; while a period was live it re-rendered itself to `NOW / DLD / ASD · 224 · 06:50–10:20` plus `NEXT / Math-3`, proving the per-boundary exact alarm re-fires without the Flutter process.
- Did: Filled the **Now** card above the list with the accent while a class is running, so the running class is obvious at the top of the screen and not only in a row further down. It takes `colorScheme.primary` with `onPrimary` text, and falls back to the plain surface when nothing is live. A tough class keeps its amber, since amber reads the same on any accent.
- Did: Moved the live Today row from `primaryContainer` to `colorScheme.primary` as well. The user rejected the pale tint: a pale wash of the accent reads as a disabled or secondary state, not as "this is happening now".
- Did: Proved both highlights on the device without root. `adb shell date` cannot set the clock, so a period's start was temporarily moved to cover the current minute (dial picker), screenshotted with the card and the row filled, then restored to `09:30`. The routine was left exactly as the user's: period 1 `09:30 – 10:20`, periods 2-6 on the hour+5 grid, Sun/Mon/Tue/Wed, Light, blue.
- Learned: The time picker is only drivable in **dial mode** (tap the clock icon to leave text mode). In text mode the soft keyboard shifts the dialog up ~350px and every tap lands on the wrong thing; in dial mode it is stable and one tap per value.
- Learned: A test alert fired twice with the same notification id is treated as an update, so the full-screen intent does not re-fire and the alert looks broken. Force-stop between runs.
- Committed: `7bf69bf` Now card in the accent, `31519d9` live row in the full accent, `2cee07e` ignore the icon generator's local `node_modules`. `flutter analyze` clean, all 141 tests pass, debug APK installed and observed on the phone.

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
- Did: Consolidated the history. `main` was 40 commits behind and never pushed; it now carries everything, `feat/classync-app` is deleted locally and on the remote, and GitHub's default branch is switched to `main` (`gh` is not installed, so the switch went through the REST API with the stored token). One branch remains.

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
