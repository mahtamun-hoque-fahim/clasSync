# ClasSync — Design

Date: 2026-11-01

## Intent

During class the phone lies face-up on the desk, on silent. Five minutes before the next class, the screen should light up and vibrate with one glanceable line: course, teacher, room (e.g. `DLD · ASD · 224`). Rooms change day to day, so the alert must read from the routine, not memory. On days with free periods, an 8:00 AM reminder says how many gaps there are.

The routine is edited from a web dashboard or the app, and both stay in sync. It is personal for now; classmates may join later.

## Goals

- Next-class alert 5 minutes before each class block: vibration, no sound, screen wakes, shows `COURSE · TEACHER · ROOM`.
- 8:00 AM gap reminder on class days that have empty periods.
- Weekly routine grid: days × periods, each cell = course, teacher initials, room, optional "tough" flag.
- Edit one cell at a time; edits apply every week.
- Import a whole routine from JSON (dashboard). Export to JSON too (free, same format).
- Days, period count and period times are editable, so a new semester is one import or a few edits.
- Same data on phone and web, synced live.
- Alerts work with no internet in class.
- CT (class test) reminders: add a CT whenever one is announced, get reminders at chosen times before it, and it deletes itself once its time has passed.

## Non-goals (for now)

- iPhone build (Android first; Flutter keeps iOS possible later).
- Sharing with classmates (data shape allows it later, no code for it now).
- One-day overrides (e.g. "room changed today only").
- Play Store publishing — install via APK first.
- Attendance, grades, notes.

## Anti-goals (failure even if it "works")

- Alert makes a sound in class.
- Alert missed or late (killed by battery saver, lost after reboot, stops after a week).
- Alerts on non-class days, or a second alert in the middle of a double-period lab.
- Alert text too long to read at a glance.

## Constraints and decisions

### Stack (my call, user agreed)

- **Flutter** for both the Android app and the web dashboard — one codebase.
- **Firebase**: Auth (Google sign-in), Firestore (live sync + offline cache).
- **flutter_local_notifications** + `timezone` for alerts scheduled on the phone. No push server.
- Time zone: Asia/Dhaka (read from device; Bangladesh has no DST).

### Data model

One Firestore doc per user: `routines/{uid}`. Security rule: read/write only when `request.auth.uid == uid`. (Later sharing = add a `members` field and change the rule.)

The JSON import format is the same shape as the doc:

```json
{
  "accent": "blue",
  "days": ["Sun", "Mon", "Tue", "Wed"],
  "periods": [
    {"start": "09:30", "end": "10:20"},
    {"start": "10:25", "end": "11:15"},
    {"start": "11:20", "end": "12:10"},
    {"start": "12:15", "end": "13:05"},
    {"start": "13:10", "end": "14:00"},
    {"start": "14:05", "end": "14:55"}
  ],
  "teachers": {
    "SJ": "Sabiha Jahan",
    "ASD": "Md Asaduzzaman",
    "SNS": "Shamsun Nahar Shoma",
    "NA": "Nurul Absar",
    "MA": "Manjur Alam",
    "AI": "Arfanul Islam"
  },
  "cells": {
    "Sun": [
      {"course": "DM", "teacher": "SJ", "room": "121"},
      {"course": "DLD Lab", "teacher": "ASD", "room": "140", "tough": true},
      {"course": "STAT", "teacher": "SNS", "room": "227"},
      null,
      {"course": "BE", "teacher": "NA", "room": "221"},
      {"course": "JAVA", "teacher": "MA", "room": "221"}
    ]
  }
}
```

- Times are 24-hour `HH:mm`.
- `cells[day]` has exactly `periods.length` entries; `null` = no class.
- `tough` is optional, default `false` (the user's yellow-underlined "painful" periods).
- Import validates: known day names, `HH:mm` times in ascending order, row length matches period count, required fields non-empty. A bad file is rejected with the reason; the current routine is untouched.

### Alert rules

All derived by one pure function `buildAlerts(routine) -> List<Alert>`, which is unit-tested.

- **Class blocks:** consecutive periods with the same course + teacher + room merge into one block (e.g. Java lab Mon P1–P2). One alert per block, at block start − 5 min.
- **Alert text:** title `COURSE · TEACHER · ROOM` (teacher initials). Body: start time.
- **Tough blocks:** highlighted in a warm accent color, both in the grid and in the notification (Android notification `color`). The alert body adds the note "Snacks before the class." No extra vibration or sound.
- **Gap periods:** every empty period on a class day, including the ones before the first class or after the last one (Tue P5–P6 count as 2). If count > 0, alert at 08:00: "N gap periods today: 12:15–13:05, …". A class day with no classes at all gets no alerts.
- **Non-class days:** days not in `days` get no alerts.

### CT reminders

- Stored as `routines/{uid}/cts/{ctId}`, separate from the routine doc, so importing a new routine never touches CTs. Same owner-only security rule.
- Fields: `course`, `at` (date and time), optional `room`, optional `note`, `remindBefore` (list of minutes, e.g. `[1440, 360, 60]`).
- Add form (phone and web): course, date, time, room, note, and reminder chips: 1 hour, 6 hours, 1 day, 2 days, 1 week, plus custom. New CTs start with 1 day, 6 hours and 1 hour ticked, changeable per CT (my call).
- CTs can be edited or deleted by hand before they happen.
- Once `at` has passed, the CT is permanently deleted, with no history. Any signed-in client (phone or web) deletes expired CTs when it receives the CT list.
- Alert: same channel as class alerts (vibration, no sound). Title `CT: COURSE · ROOM` (`CT: COURSE` without a room). Body `in 6 hours · Thu 5 Nov, 09:30`, then the note on a new line if present.
- One-off alerts, scheduled on the phone so they work offline. Reminder times already in the past are skipped.
- CT reminders are not included in JSON import/export.

### Notification delivery (Android)

- Each alert is scheduled as a weekly repeat (`matchDateTimeComponents: dayOfWeekAndTime`, `exactAllowWhileIdle`), so it keeps firing without the app being opened.
- On every routine change (Firestore snapshot), app start and device boot: cancel all, reschedule from `buildAlerts`.
- Notification channel: high importance, vibration on, sound off. `fullScreenIntent` set so the locked screen wakes.
- Permissions requested on first run with a short explanation: notifications, exact alarms ("Alarms & reminders"), full-screen intent, and a prompt to disable battery optimization for the app (needed on Xiaomi/Oppo/Samsung).
- Settings screen has a "Send test alert in 10 s" button so the user can confirm it works on their phone.

### Look and theme

- Flutter Material 3 (`useMaterial3: true`), styled to look like MUI: rounded corners everywhere (cards, dialogs, buttons, grid cells, inputs), soft elevation, clean spacing.
- Primary accent: blue by default. A settings picker offers preset swatches (e.g. blue, indigo, teal, green, orange, pink, purple); the whole theme is built from the chosen seed with `ColorScheme.fromSeed`.
- The chosen swatch is stored as `accent` (swatch name) in the routine doc, so phone and web match.
- Tough-period highlight uses a warm color that stays distinct from every swatch.
- Light theme required; dark theme follows the system if it is cheap with `fromSeed` (builder's call).

### Screens

- **Phone home:** "Now" and "Next" cards for today, then upcoming CTs (soonest first, with an add button), then today's list. Tap the grid icon for the full week.
- **Grid (phone + web):** days × periods. Tap a cell to edit course / teacher / room / tough, or clear it. Edit day list, period times and teacher names from a settings panel.
- **Web dashboard:** same grid and upcoming CTs, plus Import JSON (paste or file) and Export JSON.
- **Sign-in:** Google, same account on web and phone.

## Testing

- Unit tests for `buildAlerts`: block merging, 5-min offset, gap counting (middle and trailing), tough note, off days, period crossing noon.
- Unit tests for JSON import validation (good file, each kind of bad file).
- Unit tests for CT alerts: reminder times, past reminders skipped, title without room, note in body, which CTs count as expired.
- Manual on a real Android phone: test-alert button, phone locked on silent, after reboot, after a routine edit from web.

## Left to the builder

- Visual design, colors, state management library, folder layout.
- Exact wording of permission prompts and error messages.
- Firebase project setup steps (documented in README).
