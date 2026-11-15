# ClasSync

![Version](https://img.shields.io/github/v/release/mahtamun-hoque-fahim/clasSync?style=flat-square&color=009688)
![License](https://img.shields.io/github/license/mahtamun-hoque-fahim/clasSync?style=flat-square)
![Stars](https://img.shields.io/github/stars/mahtamun-hoque-fahim/clasSync?style=flat-square)

Your weekly class routine, always one glance away — on your home screen and on your lock screen.

ClasSync is for students who live by a fixed weekly timetable. Set it up once at the start of the semester, and your phone quietly keeps track of everything from then on: when the next class starts, where it is, which room to walk to, and when an exam is coming.

## What it does

**Knows where you are in the day.** The Now card at the top of the app tells you the moment you're in: the class running right now with its room, what's coming next, when you're heading home, how many days are left before an exam, or that tomorrow is a day off. No counting periods in your head.

**Wakes your screen before class.** A few minutes before each class, the phone lights up and shows one clean line — `COURSE · TEACHER · ROOM` — right over the lock screen. No unlock, no dig through notifications. It closes itself after twenty seconds if you don't touch it.

**Lives on your home screen.** A widget mirrors the Now card, so the next class, the running one, or the exam countdown is visible without opening the app. It updates itself on its own — the app doesn't need to be open or even alive.

**Keeps track of the things due.** Class tests, assignments, lab reports, presentations — add any of them with a date, room and note. Pick the course straight from the courses already in your routine; no typing the same name twice. Reminders fire at the times you choose (an hour before, a day before, whatever you set), and a task deletes itself once its time has passed.

**Reminds you about free periods.** On a class day where a slot is empty, a reminder at 8:00 AM tells you about the gap — sleep in, or plan around it.

**Counts down your exams.** Set exam dates in settings and the Now card and widget count down to them — days out, then hours, then "Today". Exams never land on Friday or Saturday; the app won't let you schedule one there.

**Follows your colour.** Seven accent colours. Pick one and the whole app matches — cards, highlights, even the launcher icon's background changes to your colour.

**Syncs across your devices.** Sign in with Google and the routine lives in your account: edit it on your phone, and the web dashboard reads the same routine from any browser. Works offline too — the last routine is kept on the device.

## Getting started

1. Install `app-release.apk` from the [releases page](https://github.com/mahtamun-hoque-fahim/clasSync/releases) and sign in with Google.
2. Tap **Continue** on the "Allow class alerts" dialog and allow each request: notifications, exact alarms, and no battery limits.
3. On Xiaomi, Oppo, Samsung and similar phones, also allow the app to run in the background in the battery settings — this is what keeps the pre-class alerts on time.
4. In **Settings**, tap **Send test alert in 10 s**, lock the phone, and check that it wakes up.

On full silent? Some phones only vibrate in **vibrate** mode — test with your usual setting.

## A new semester

In **Settings → Import JSON**, paste or upload a routine in the format of [assets/default_routine.json](assets/default_routine.json). This replaces the whole routine; your tasks (CTs, assignments and so on) are kept.

## Privacy

Your routine lives in your own Firebase account and nowhere else — the rules in `firestore.rules` let each signed-in user read and write only their own data. No analytics, no third-party trackers.

## Building it yourself

Needs Flutter stable, Android Studio and the Firebase CLI.

```bash
flutter test
flutter run            # Android app
flutter run -d chrome  # web dashboard
```

Release builds:

```bash
flutter build apk --release
flutter build web --release
firebase deploy --only hosting,firestore:rules
```

The release APK is signed with the debug key (fine for installing directly; its SHA-1/SHA-256 are registered in the Firebase project for Google sign-in). A Play Store release would need a real signing key.

### Changing the icon

Every icon asset is generated from [assets/icon/clasSync-icon.svg](assets/icon/clasSync-icon.svg); do not hand-edit the PNGs. Replace the SVG, then:

```bash
npm install @resvg/resvg-js pngjs
node tool/generate_icons.js
```

The cap's share of the canvas is the `CAP` fraction at the top of `tool/generate_icons.js`. The launcher icon's background follows the chosen accent through one activity alias per colour — see `android/app/src/main/kotlin/com/classync/classync/LauncherIcon.kt`.

Release builds shrink resources they cannot see referenced from code, so any drawable named only inside Dart must be pinned in `android/app/src/main/res/raw/keep.xml`, or it disappears from release APKs while debug keeps working.

## Firebase

Project: `classync-214da`. Firestore rules are in `firestore.rules`: each user can only read and write their own `routines/{uid}` doc and its `cts` subcollection.
