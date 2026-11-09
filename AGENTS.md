# ClasSync

Weekly class routine for Android and web, with a silent lock-screen alert before each class and gap period.

## Current State

- Updated: 2026-11-09
- Status: Beta — single user, installed on one phone (Redmi `25078RA3EA`)
- Works: Google sign-in; routine sync through Firestore; routine and teacher editing; CT (class test) add/edit/delete with custom reminders; CT auto-delete once its time passes; scheduling and delivery of exact alarms; gap-period reminder at 08:00 on class days; settings (accent, class days, reminder offsets, JSON import); newly generated app icon on the launcher; notification small icon; web dashboard build.
- In progress: nothing half-built in code.
- Next: (1) build the dedicated single-line alert screen and make it the `fullScreenIntent` target instead of `MainActivity`; (2) commit the icon, notification-icon, `keep.xml` and init-hardening work, which is still uncommitted on `feat/classync-app`; (3) capture the alert on a locked screen once (1) lands, since today it is only visible for about one second.
- Watch out: the alert currently opens the **whole dashboard** over the lock screen and never closes itself. `fullScreenIntent` targets `MainActivity`, which is declared `showWhenLocked` + `turnScreenOn`, so it draws over the keyguard and stays until Back, Home or screen timeout. `deviceLocked` stays `1` throughout, so nothing is bypassed — but the user sees the full timetable instead of one glanceable line. Do not describe the locked-screen behaviour as finished until this is fixed.

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
