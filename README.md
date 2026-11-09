# ClasSync

Weekly class routine with silent, vibrating alerts on Android, synced with a web dashboard.

- 5 minutes before each class: the screen wakes and shows `COURSE · TEACHER · ROOM`.
- 8:00 AM on class days with empty periods: a gap period reminder.
- CT (class test) reminders at times you choose. A CT deletes itself once its time passes.

One Flutter codebase builds both the Android app and the dashboard. Firebase handles sign-in and sync. Design and plan are in `docs/superpowers/`.

## Phone setup

1. Install `app-release.apk` on the phone and sign in with Google.
2. Tap **Continue** on the "Allow class alerts" dialog and allow each request: notifications, alarms, and no battery limits.
3. On Xiaomi, Oppo, Samsung and similar phones, also allow the app to run in the background in the phone's battery settings.
4. In **Settings**, tap **Send test alert in 10 s**, lock the phone, and check that it wakes and vibrates.

Phone on full silent? Some phones only vibrate in **vibrate** mode, so test with your usual setting.

## New semester

A new account starts with the routine in [assets/default_routine.json](assets/default_routine.json).

In **Settings → Import JSON**, paste or upload a file in the format of [assets/default_routine.json](assets/default_routine.json). This replaces the routine. CTs are not affected.

## Development

Needs Flutter stable, Android Studio, and the Firebase CLI.

```bash
flutter test
flutter run -d chrome
flutter run
```

## Build and deploy

```bash
flutter build apk --release
flutter build web --release
firebase deploy --only hosting,firestore:rules
```

The APK is written to `build/app/outputs/flutter-apk/app-release.apk`.

The release APK is signed with the debug key, which is fine for installing directly. Its SHA-1 and SHA-256 are registered in Firebase, and Google sign-in depends on them. On a new computer, register that computer's debug key or copy `~/.android/debug.keystore` over. Publishing to the Play Store would need a real signing key.

### Changing the icon

Every icon asset is generated from [assets/icon/clasSync-icon.svg](assets/icon/clasSync-icon.svg); do not hand-edit the PNGs. Replace that SVG, then:

```bash
npm install @resvg/resvg-js pngjs
node tool/generate_icons.js
```

That rewrites the Android launcher and adaptive layers, the notification silhouette, the web icons and `assets/icon/icon-1024.png`.

Release builds shrink resources they cannot see referenced from code, so the notification icon `drawable/ic_status` is pinned in `android/app/src/main/res/raw/keep.xml`. Any drawable named only inside Dart needs the same treatment, or it disappears from release APKs while debug keeps working.

## Firebase

Project: `classync-214da`. Firestore rules are in `firestore.rules`: each user can only read and write their own `routines/{uid}` doc and its `cts` subcollection.
