# Water Quality Monitor — Setup Guide

This app has two parts working together:
- **Firebase Authentication + Firestore** — who can sign in, and whether
  they're an active user or an admin. No one can self-signup; every account
  is created by an admin from inside the app.
- **Firebase Realtime Database (RTDB)** — the live sensor readings from your
  ESP32, plus a small "access mirror" that lets RTDB's security rules check
  whether a signed-in user is allowed to read sensor data (RTDB can't read
  Firestore directly, so this mirror keeps the two in sync).

Total cost: $0. Firebase Auth, Firestore, and RTDB are all free at this scale
on the Spark plan.

---

## Step 1 — Create the Firebase project (skip if you already did this)

1. https://console.firebase.google.com → **Add project**.
2. Disable Google Analytics if you don't want it — not needed here.

## Step 2 — Enable Authentication

1. **Build → Authentication → Get started**.
2. **Sign-in method** tab → enable **Email/Password**. Leave "Email link"
   off — you only need password sign-in.

## Step 3 — Create Firestore (for user accounts/roles)

1. **Build → Firestore Database → Create database**.
2. Choose a location close to you.
3. Start in **production mode** — we'll paste in real rules in Step 5,
   so there's no need for test mode here.

## Step 4 — Create the Realtime Database (for sensor data) — if not already done

1. **Build → Realtime Database → Create Database**.
2. Note the **Database URL** at the top — you'll need it for both the
   ESP32 firmware and the Flutter app config.

## Step 5 — Lock down security rules

### Firestore rules
Go to **Firestore Database → Rules**, replace everything with the contents
of `firestore_rules.txt` (in this folder), then **Publish**.

This enforces: only admins can read the full user list or write any user
document; a regular user can only read their own profile (to check their
own status) and can never write to it. There is no way for a client to
grant itself access — only an existing admin can do that.

### Realtime Database rules
Go to **Realtime Database → Rules**, replace everything with the contents
of `firebase_rtdb_rules.json` (in this folder), then **Publish**.

This gates all sensor data behind an `access/{uid}` node that mirrors each
user's Firestore status. The app keeps this mirror in sync automatically
whenever an admin creates a user or changes their status/role — you don't
maintain it by hand, **except for the two bootstrap entries below**.

---

## Step 6 — Bootstrap your first admin (one-time, manual)

This is the one chicken-and-egg step in an admin-managed system: the very
first admin can't be created by tapping "Add user" in the app, because
there's no admin yet to do the tapping. You create this one account by hand,
directly in the Firebase console:

1. **Authentication → Users → Add user.** Enter your own email and a
   password you'll use to sign in.
2. Copy the **User UID** shown for that new user.
3. **Firestore Database → Data → Start collection** → collection ID `users`
   → document ID = paste the UID you copied → add these fields:
   | Field | Type | Value |
   |---|---|---|
   | `email` | string | your email |
   | `displayName` | string | your name |
   | `role` | string | `admin` |
   | `status` | string | `active` |
   | `createdAt` | timestamp | (use "now") |
4. **Realtime Database → Data** → add a node `access` → child = the same
   UID → with two fields: `granted: true` (boolean) and `role: "admin"` (string).

Now sign into the app with that email/password — you're in as the first
admin, and from here on you can create every other account (including more
admins) directly from the **Users** tab in the app.

## Step 7 — Grant the ESP32 device access to write sensor data

Your ESP32 also signs in as a Firebase Auth user (see firmware setup below)
so it can write to Realtime Database. That account needs an `access` entry
too, or its writes will be rejected by the rules from Step 5.

1. **Authentication → Users → Add user** — use the same email/password you
   plan to put in the firmware's `FIREBASE_USER_EMAIL` / `FIREBASE_USER_PASS`.
2. Copy its UID.
3. **Realtime Database → Data → `access`** → add a child node with that UID
   → `granted: true`, `role: "device"` (it doesn't need `"admin"`, anything
   other than `"admin"` works — the rules only check `granted` for sensor
   read/write).

This account does **not** need a Firestore `users` document — it never signs
into the Flutter app, so Firestore/the admin user list doesn't need to know
about it.

---

## Step 8 — Update and flash the ESP32 firmware

Credentials live in a separate `secrets.h` file (gitignored, never committed)
rather than inline in the `.ino` — this is what makes it safe to push this
project to a public GitHub repo.

1. In `firmware/Water_Quality_Monitoring/`, copy `secrets.example.h` to a
   new file named `secrets.h` (same folder):
   ```bash
   cd firmware/Water_Quality_Monitoring
   cp secrets.example.h secrets.h
   ```
2. Open `secrets.h` and fill in:
   - `WIFI_PORTAL_SSID` / `WIFI_PORTAL_PASSWORD` — the captive-portal network
     name/password shown on first boot (pick your own password here)
   - `FIREBASE_API_KEY`, `FIREBASE_DATABASE_URL` — from Steps 1–4
   - `FIREBASE_USER_EMAIL`, `FIREBASE_USER_PASS` — the device account from Step 7
3. Open `Water_Quality_Monitoring.ino` in Arduino IDE (open the `.ino` file —
   `secrets.h` will load automatically alongside it as long as both files
   stay in the same folder) and upload as usual.

Calibration code and sensor logic are unchanged. `secrets.h` stays on your
machine only — it's excluded by `.gitignore` and will never be pushed to
GitHub, even if you commit everything else in the folder.

---

## Step 9 — Configure and run the Flutter app

`lib/firebase_options.dart` is gitignored (it holds real project keys) — only
a safe template, `lib/firebase_options.example.dart`, is committed. Generate
your real one with the FlutterFire CLI:

```bash
dart pub global activate flutterfire_cli
cd flutter_app/water_quality_app
flutterfire configure
```

Select the same Firebase project. This creates `lib/firebase_options.dart`
with your real project keys — the app won't build until this file exists.

```bash
flutter pub get
flutter run
```

This is also the point where you'll need to generate the native platform
folders if they aren't present yet:

```bash
flutter create .
```

Run this from inside `flutter_app/water_quality_app/` — it scaffolds
`android/`, `ios/`, and other platform folders without touching your
existing `lib/` code, then `flutterfire configure` and `flutter run` work
as shown above.

Sign in with the admin account from Step 6. From **Users**, tap **Add user**
to create accounts for everyone else — you set their email and a temporary
password, share those with them, and they can change their password from
the **Profile** tab after signing in.

---

## How access control actually works (so you can reason about it)

```
Admin taps "Add user" in the app
        │
        ▼
Secondary Firebase App instance creates the Auth account
(admin's own session is untouched — see auth_service.dart)
        │
        ▼
Firestore: users/{uid} = { email, role, status: "active", ... }
RTDB:      access/{uid} = { granted: true, role }
        │
        ▼
New user signs in with email + temp password
        │
        ▼
App reads users/{their uid} on every app load (live stream)
        │
   ┌────┴─────┐
   │          │
status=active  status=disabled / doc missing
   │          │
   ▼          ▼
Home Shell   "No access" screen (sign-out only)
```

Disabling a user (Users tab → ⋮ → Disable access) flips `status` to
`disabled` in Firestore AND `granted` to `false` in RTDB in the same
action — so a disabled user is locked out of both the account-status check
*and* direct sensor-data reads, even if they had the app cached or tried to
hit Realtime Database directly.

Removing a user (⋮ → Remove user) deletes their Firestore profile and RTDB
access entry, which revokes app access immediately. It does **not** delete
the underlying Firebase Auth account itself — the client SDK can't do that
for other users (only the Admin SDK on a backend can), so the email
technically still "exists" in Authentication, but it can no longer reach
anything in the app. If you want it fully gone, delete it manually from
**Authentication → Users** in the console.

---

## App structure

```
lib/
  main.dart                      # entry point, Firebase init
  firebase_options.dart          # generated by flutterfire configure
  theme/app_theme.dart           # colors, type scale, breakpoints
  models/
    app_user.dart                # Firestore user profile (role/status)
    water_reading.dart           # one sensor snapshot + status classification
    thresholds.dart              # shared alert ranges
  services/
    auth_service.dart            # sign-in, admin user creation, role/status changes
    sensor_service.dart          # all RTDB sensor reads/writes/streams
  screens/
    app_root.dart                # the auth gate — routes by auth+profile state
    auth/
      login_screen.dart
      no_access_screen.dart      # shown for disabled/missing-profile accounts
      splash_screen.dart
    admin/
      user_management_screen.dart # list, enable/disable, promote/demote, remove
      add_user_screen.dart        # admin creates account + temp password
    dashboard/
      home_shell.dart           # responsive nav: bottom bar (phone) / rail (tablet+)
      dashboard_screen.dart     # live readings + pH dial + status banner
      history_screen.dart       # line charts per metric
      alerts_screen.dart        # threshold sliders
      profile_screen.dart       # change password, sign out
  widgets/
    ph_gauge.dart
    reading_tile.dart
    status_banner.dart
    badges.dart                 # role/status pills used in the Users list
    responsive_container.dart   # width caps + column-count helpers
```

## Responsiveness

- **< 600px** (phones): single column, bottom navigation bar.
- **≥ 600px** (tablets, foldables, desktop/web): side navigation rail
  instead of a bottom bar, and content is centered with a max width so
  text and cards don't stretch edge-to-edge on large screens.
- The reading grid is 2 columns on phones, 3 on tablets, 4 on desktop-width
  screens, recalculated live with `LayoutBuilder` (handles rotation and
  window resizing, not just initial launch size).

---

## Troubleshooting

- **"Permission denied" when admin tries to create a user**: check Firestore
  rules are published (Step 5) and that your own `users/{uid}` doc really
  has `role: "admin"` and `status: "active"` — typos in those exact string
  values are the most common cause.
- **New user can sign in but sees "No access yet"**: this means Firebase
  Auth worked but the Firestore profile write failed or didn't finish —
  check the Firestore console for a `users/{their uid}` doc; if it's
  missing, something failed during `adminCreateUser` (check Flutter's debug
  console for the error).
- **ESP32 stops sending data after you publish the new RTDB rules**: you
  skipped Step 7 — the device's Auth account needs its own `access/{uid}`
  entry just like a human user.
- **Admin's own account can't be disabled/demoted from the Users list**:
  intentional — the app prevents an admin from disabling or demoting
  themselves to avoid accidentally locking everyone out.
