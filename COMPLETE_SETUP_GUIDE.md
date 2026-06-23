# Water Quality Monitor — Complete Setup Guide

**By Sameer Saif**

This guide covers the complete setup from zero to a running system:
Firebase project configuration, ESP32 firmware flashing, Flutter app
installation, and pushing the full project to GitHub. A detailed
troubleshooting section at the end covers every real error encountered
during development with exact fixes.

---

## Table of Contents

1. [Components Required](#1-components-required)
2. [Software & Tools Required](#2-software--tools-required)
3. [Firebase Project Setup](#3-firebase-project-setup)
4. [ESP32 Firmware Setup](#4-esp32-firmware-setup)
5. [Flutter App Setup](#5-flutter-app-setup)
6. [Pushing to GitHub](#6-pushing-to-github)
7. [How the System Works](#7-how-the-system-works)
8. [Troubleshooting — Real Errors with Exact Fixes](#8-troubleshooting--real-errors-with-exact-fixes)

---

## 1. Components Required

### Hardware

| Component | Specification | Notes |
|---|---|---|
| Microcontroller | ESP32 Dev Module | Any standard ESP32 dev board works |
| pH Sensor | Analog pH probe + signal board | Connected to pin 34 |
| TDS/EC Sensor | Analog TDS probe + signal board | Connected to pin 32 |
| Turbidity Sensor | Analog turbidity probe | Connected to pin 35 |
| Temperature Sensor | DS18B20 waterproof OneWire | Connected to pin 4 |
| Display | 16×2 I2C LCD (address 0x27) | Shows live readings offline |
| Power | USB or 5V regulated supply | |
| Cables | Jumper wires, breadboard | |

### Wiring Summary

```
ESP32 Pin 34  →  pH sensor analog output
ESP32 Pin 32  →  TDS/EC sensor analog output
ESP32 Pin 35  →  Turbidity sensor analog output
ESP32 Pin 4   →  DS18B20 data wire (+ 4.7kΩ pull-up to 3.3V)
ESP32 SDA/SCL →  LCD I2C (GPIO21/GPIO22 on most ESP32 boards)
```

> **Important:** All analog sensors must output 0–3.3V max.
> The ESP32's ADC is **not** 5V tolerant. Use a voltage divider
> or level shifter if your sensor outputs 5V.

---

## 2. Software & Tools Required

### For ESP32 Firmware

| Tool | Version | Download |
|---|---|---|
| Arduino IDE | 2.x recommended | https://www.arduino.cc/en/software |
| ESP32 board package (Espressif) | **3.0.7** (see note below) | Arduino IDE → Boards Manager |
| FirebaseClient library (mobizt) | Latest | Arduino IDE → Library Manager |
| WiFiManager library | Latest | Arduino IDE → Library Manager |
| LiquidCrystal_I2C library | Latest | Arduino IDE → Library Manager |
| DallasTemperature library | Latest | Arduino IDE → Library Manager |
| OneWire library | Latest | Arduino IDE → Library Manager |

> ⚠️ **ESP32 board package version note:** Version 3.1.0 of the ESP32
> board package by Espressif has a confirmed bug that causes a
> `udp_new_ip_type: Required to lock TCPIP core functionality` crash
> when NTP and Firebase networking start near-simultaneously. **Use
> version 3.0.7** to avoid this. In Arduino IDE → Boards Manager,
> find "esp32 by Espressif Systems", click the version dropdown, and
> select 3.0.7 specifically.

### For Flutter App

| Tool | Version | Download |
|---|---|---|
| Flutter SDK | 3.x stable | https://docs.flutter.dev/get-started/install |
| Android Studio | Latest | https://developer.android.com/studio |
| Android SDK | API 34+ (auto-installed by Android Studio) | |
| Node.js | 18+ | https://nodejs.org |
| Firebase CLI | Latest (via npm) | Installed in Step 3 below |
| FlutterFire CLI | Latest (via dart pub) | Installed in Step 5 below |
| Git | Latest | https://git-scm.com |

### For GitHub

| Tool | Notes |
|---|---|
| GitHub account | https://github.com |
| Git | Same as above |

---

## 3. Firebase Project Setup

### 3.1 — Create the Project

1. Go to https://console.firebase.google.com
2. Click **Add project**
3. Name it (e.g. `water-quality-monitor`)
4. Disable Google Analytics — not needed for this project
5. Click **Create project** and wait for it to finish

### 3.2 — Enable Authentication

1. In the left sidebar: **Build → Authentication → Get started**
2. Click the **Sign-in method** tab
3. Click **Email/Password → Enable** (top toggle only — leave "Email link" disabled)
4. Click **Save**

### 3.3 — Create Firestore Database

Firestore stores user accounts, roles, and access control. It is
**separate** from the sensor data (which lives in Realtime Database).

1. **Build → Firestore Database → Create database**
2. You'll see a dialog titled "Create a database" with two options:
   - **Standard edition** (select this — it's free)
   - Enterprise edition (skip)
3. Click **Next**
4. On the "Database ID & location" step:
   - **Database ID field must show `(default)`** — do NOT type anything
     custom here. Typing any other name (like `users` or `water-quality`)
     makes it a "named database" which is NOT on the free tier.
   - Select a **location** close to you
5. Click **Next**
6. Select **Production mode** (not test mode — you'll paste real rules shortly)
7. Click **Create**

> ⚠️ **Common mistake:** If you see the error *"To create a named
> (non-default) database, you must upgrade your billing plan"*, it means
> you typed a custom name in the Database ID field. Go back and leave
> that field as `(default)`.

### 3.4 — Create Realtime Database

Realtime Database stores live sensor readings from the ESP32.

1. **Build → Realtime Database → Create Database**
2. Choose the location closest to you
3. Choose **Start in test mode** for now (you'll lock it down in step 3.6)
4. Click **Enable**
5. **Note the Database URL** shown at the top — it looks like:
   `https://your-project-default-rtdb.asia-southeast1.firebasedatabase.app`
   You'll need this for both the firmware and the Flutter app.

### 3.5 — Get Your Web API Key

The ESP32 firmware needs this to authenticate with Firebase.

1. Click the ⚙️ gear icon → **Project settings**
2. Under **Your apps**, click the **`</>`** (web) icon to register a web app
3. Give it any nickname (e.g. "ESP32 access") and click **Register app**
4. Skip the SDK setup shown after registration
5. Back in **Project settings → General**, scroll to **Your apps**
6. You'll see a `firebaseConfig` block — copy the `apiKey` value:
   ```javascript
   const firebaseConfig = {
     apiKey: "AIzaSy...",        ← copy this
     databaseURL: "https://...", ← copy this too
     ...
   ```

### 3.6 — Apply Security Rules

#### Firestore Rules
1. **Firestore Database → Rules**
2. Delete everything currently there
3. Paste the full contents of `firestore_rules.txt` (in this project folder)
4. Click **Publish**

These rules enforce: only admins can read the user list or write user
documents. A regular user can only read their own profile. No one can
grant themselves access — only an existing admin can do that.

#### Realtime Database Rules
1. **Realtime Database → Rules**
2. Delete everything currently there
3. Paste the full contents of `firebase_rtdb_rules.json`
4. Click **Publish**

These rules gate all sensor data behind an `access/{uid}` mirror node
(explained in Section 7).

### 3.7 — Bootstrap Your First Admin Account

This is the one step you do manually — once. After this, all other
accounts are created from inside the app.

**Step A: Create the Auth account**
1. **Authentication → Users → Add user**
2. Enter your personal email and a strong password
3. Click **Add user**
4. In the user list, click the three dots (⋮) next to your email and
   **copy the User UID** — it looks like `3r1KgpNFibTukrFQxBkDWEAJluh1`

**Step B: Create the Firestore profile**

> ⚠️ **Critical:** Read this carefully — the most common mistake here
> is putting the UID in the wrong field, which makes the app show
> "No Access Yet" even though everything else is correct.

1. **Firestore Database → Data**
2. Click **Start collection** (you're at the root — no collection selected)
3. **Collection ID** field → type: `users` (all lowercase, exactly)
4. Click **Next**
5. **Document ID** field → paste your UID: `3r1KgpNFibTukrFQxBkDWEAJluh1`
   - The field is labeled "Document ID", not "Collection ID"
   - If you accidentally type the UID in the Collection ID field, the
     entire path will be wrong — the app looks for `users/{uid}`,
     not `{uid}/users`
6. Add these fields (click **Add field** for each):

   | Field name | Type | Value |
   |---|---|---|
   | `email` | string | your email address |
   | `displayName` | string | your name |
   | `role` | string | `admin` |
   | `status` | string | `active` |
   | `createdAt` | timestamp | (click "current time") |

7. Click **Save**

**Step C: Add the RTDB access entry**

1. **Realtime Database → Data**
2. Hover over the root node and click the **+** icon
3. Name: `access`, Value: (leave empty, click + to add a child)
4. Child name: paste your UID, Value: (leave empty, click + again)
5. Add two fields:
   - `granted` → value `true` → type **Boolean** (NOT string "true")
   - `role` → value `admin` → type String
6. Click the checkmark to save

Or if the console has an **Import JSON** option on the `access` node:
```json
{
  "YOUR_UID_HERE": {
    "granted": true,
    "role": "admin"
  }
}
```

### 3.8 — Grant the ESP32 Device Access

The ESP32 also uses a Firebase Auth account to write sensor data.

1. **Authentication → Users → Add user**
2. Use any email (e.g. `esp32@watermonitor.local`) and a strong password
   - **Use only letters, digits, and safe symbols** like `-`, `_`, `.`, `!`
   - **Avoid** `&`, `#`, `$`, `%`, `^`, `*`, backticks, or quotes in the
     password — these have special meaning in shells and JSON and caused
     authentication failures during development
3. Copy the UID of this new device user
4. **Realtime Database → Data → `access`** node → add a child:
   - Name: paste the device UID
   - Two fields: `granted: true` (Boolean), `role: "device"` (String)

> This device account does **not** need a Firestore `users` document.
> It never signs into the Flutter app — only into RTDB.

---

## 4. ESP32 Firmware Setup

### 4.1 — Install Required Libraries

In Arduino IDE → **Sketch → Include Library → Manage Libraries**, install:

- `FirebaseClient` by Mobizt
- `WiFiManager` by tzapu
- `LiquidCrystal_I2C` by Frank de Brabander
- `DallasTemperature` by Miles Burton
- `OneWire` by Jim Studt

### 4.2 — Create the Secrets File

The firmware never stores credentials in the main `.ino` file (which
is committed to GitHub). Instead they live in `secrets.h`, which is
gitignored.

1. In `firmware/Water_Quality_Monitoring/`, find `secrets.example.h`
2. Copy it to a new file named `secrets.h` in the same folder:
   ```
   Windows: copy secrets.example.h secrets.h
   Mac/Linux: cp secrets.example.h secrets.h
   ```
3. Open `secrets.h` and fill in your values:

```cpp
#define WIFI_PORTAL_SSID     "Water Quality Monitoring"
#define WIFI_PORTAL_PASSWORD "YourChosenPortalPassword"
#define FIREBASE_API_KEY      "AIzaSy..."        // from Step 3.5
#define FIREBASE_DATABASE_URL "https://..."      // from Step 3.4
#define FIREBASE_USER_EMAIL   "esp32@..."        // from Step 3.8
#define FIREBASE_USER_PASS    "DevicePassword"   // from Step 3.8
```

### 4.3 — Flash the Firmware

1. Open `firmware/Water_Quality_Monitoring/Water_Quality_Monitoring.ino`
   in Arduino IDE — `secrets.h` loads automatically from the same folder
2. Select your board: **Tools → Board → ESP32 Arduino → ESP32 Dev Module**
3. Select the correct COM port: **Tools → Port**
4. Click **Upload** (→ arrow button)
5. Open **Serial Monitor** at **115200 baud**

**Expected Serial Monitor output on success:**
```
WiFi connected
Syncing time...
Time synced.
[Firebase Event] task: authTask, msg: authenticating, code: 7
[Firebase Event] task: authTask, msg: ready, code: 10
[Firebase Debug] task: RTDB_Send_Latest, msg: Connecting to server...
```

After the first 10-second interval, check **Realtime Database → Data**
in the Firebase console — you should see a `devices/device1/latest`
node appear with live sensor values.

### 4.4 — First WiFi Setup (Captive Portal)

On first boot (or if saved WiFi credentials are cleared), the ESP32
creates its own WiFi network called **"Water Quality Monitoring"**.

1. Connect your phone or laptop to that WiFi network
2. Enter the portal password you set in `WIFI_PORTAL_PASSWORD`
3. A configuration page will open (or navigate to `192.168.4.1`)
4. Select your home/office WiFi network and enter its password
5. The ESP32 saves these credentials and connects automatically from now on

---

## 5. Flutter App Setup

### 5.1 — Prerequisites

Verify your environment before starting:

```powershell
flutter doctor -v
```

Everything should show ✓ except "Visual Studio" (only needed for Windows
desktop apps — irrelevant here). You should see your Android device listed
under "Connected devices" if your phone is plugged in with USB debugging on.

### 5.2 — Clone or Unzip the Project

If cloning from GitHub:
```bash
git clone https://github.com/YOUR_USERNAME/water-quality-monitor.git
cd water-quality-monitor/flutter_app/water_quality_app
```

If working from the downloaded zip, navigate to:
```
flutter_app/water_quality_app/
```

### 5.3 — Generate Platform Folders

The `android/`, `ios/`, and other native platform folders are gitignored
(they're machine-generated scaffolding, not source code). Generate them:

```bash
flutter create .
```

Run this from inside `flutter_app/water_quality_app/`. It generates only
the missing platform files — it does **not** touch any existing `lib/`
source code.

### 5.4 — Install Firebase CLI

```powershell
npm install -g firebase-tools
```

> **Windows note:** If `npm` gives a script execution policy error,
> first run:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```
> Then retry `npm install -g firebase-tools`.

> **After installing**, close and reopen your terminal — npm's global
> bin folder needs a fresh terminal to be on the PATH.

Verify:
```bash
firebase --version
```

Log into Firebase with your Google account:
```bash
firebase login
```

### 5.5 — Install FlutterFire CLI

```bash
dart pub global activate flutterfire_cli
```

> **Windows note:** After this, `flutterfire` may not be recognized
> until you add Dart's global bin to your PATH:
> ```powershell
> [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:LOCALAPPDATA\Pub\Cache\bin", "User")
> ```
> Close and reopen terminal, then retry.

### 5.6 — Configure Firebase for Flutter

```bash
cd flutter_app/water_quality_app
flutterfire configure
```

When prompted:
1. **Select a Firebase project** → use arrow keys to navigate, Enter to select
   → choose your `water-quality-1a7ff` (Water Quality) project
2. **Which platforms?** → use spacebar to toggle, Enter to confirm
   → select **android** at minimum (add others if needed)
3. FlutterFire registers the apps in Firebase and generates
   `lib/firebase_options.dart` with your real project keys

This file is gitignored — it lives only on your machine. The repo
contains only `firebase_options.example.dart` as a safe template.

### 5.7 — Get Dependencies

```bash
flutter pub get
```

You may see a message like "21 packages have newer versions" —
this is informational only, not an error.

### 5.8 — Enable USB Debugging on Your Phone

1. **Settings → About phone** → tap **Build number** 7 times
2. **Settings → Developer options** → enable **USB debugging**
3. **Settings → Developer options** → enable **OEM unlocking** (needed on some devices)
4. Plug your phone into the laptop via USB
5. A popup will appear on your phone: **"Allow USB debugging?"** → tap **Allow**

### 5.9 — Run the App

Find your device ID:
```bash
flutter devices
```

Your phone will appear like:
```
Infinix X678B (mobile) • 10268333AR003357 • android-arm64
```

Run targeting your device directly:
```bash
flutter run -d YOUR_DEVICE_ID
```

Or just `flutter run` — if only one device is available it will select it
automatically, otherwise you'll be shown a menu to choose from.

The first build takes **2–5 minutes** — Gradle needs to download dependencies
and compile the full Android project. Subsequent builds are much faster.

### 5.10 — Sign In as Admin

1. The app opens to a sign-in screen
2. Enter the admin email and password you created in Step 3.7
3. You should land on the **Live** dashboard showing sensor readings

> If you see "No Access Yet" instead, see the troubleshooting section
> below — Section 8.3.

---

## 6. Pushing to GitHub

### 6.1 — Create the Repository

1. Go to https://github.com → click **New repository** (+ icon)
2. Repository name: `water-quality-monitor` (or your choice)
3. Set to **Public** (so it's visible on your Upwork/LinkedIn profile)
4. **Do NOT initialize with README, .gitignore, or license** — the project
   already has all three
5. Click **Create repository**
6. GitHub shows you a URL like:
   `https://github.com/YOUR_USERNAME/water-quality-monitor.git`
   Copy this URL.

### 6.2 — Initialize and Push

Navigate to the root of the project (where `README.md` and `.gitignore` live):

```bash
cd path/to/water-quality-monitor

git init
git add .
git commit -m "Initial commit: ESP32 + Flutter water quality monitoring system"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/water-quality-monitor.git
git push -u origin main
```

### 6.3 — Verify Nothing Secret Was Pushed

After pushing, open your GitHub repo in the browser and check:

1. **`firmware/Water_Quality_Monitoring/`** should contain:
   - `Water_Quality_Monitoring.ino` ✓
   - `secrets.example.h` ✓
   - `secrets.h` ✗ (must NOT be present — if it is, see below)

2. **`flutter_app/water_quality_app/lib/`** should contain:
   - `firebase_options.example.dart` ✓
   - `firebase_options.dart` ✗ (must NOT be present)

3. **`android/`** folder should NOT exist at the repo root level
   (it's gitignored, lives only locally after `flutter create .`)

> ⚠️ **If `secrets.h` or `firebase_options.dart` appear on GitHub:**
> They were tracked before being added to `.gitignore`. Fix:
> ```bash
> git rm --cached firmware/Water_Quality_Monitoring/secrets.h
> git rm --cached flutter_app/water_quality_app/lib/firebase_options.dart
> git commit -m "Remove accidentally tracked secret files"
> git push
> ```
> Then rotate (change) your Firebase API key and device password
> immediately — treat any key that touched a public git history as
> compromised, even briefly.

### 6.4 — Add a Screenshot to the README

The `README.md` has a placeholder comment for a screenshot:
```markdown
<!-- Add a screenshot or short demo GIF here -->
```

Add a real screenshot before sharing your profile link — it's the
single highest-impact thing for how the repo looks on Upwork/LinkedIn.

1. Take a screenshot on your phone and transfer it to your laptop
2. Create a `docs/` folder in the repo root
3. Drop the screenshot(s) there (e.g. `docs/screenshot-dashboard.png`)
4. Replace the comment in `README.md` with:
   ```markdown
   ![Dashboard](docs/screenshot-dashboard.png)
   ```
5. Commit and push:
   ```bash
   git add docs/ README.md
   git commit -m "Add app screenshots to README"
   git push
   ```

### 6.5 — After Cloning (for Others / New Machine)

When someone else (or you on a new machine) clones the repo:

```bash
git clone https://github.com/YOUR_USERNAME/water-quality-monitor.git
cd water-quality-monitor/flutter_app/water_quality_app
flutter create .                    # generate android/, ios/ etc.
dart pub global activate flutterfire_cli
flutterfire configure               # generates firebase_options.dart
flutter pub get
flutter run
```

And for the firmware:
```bash
cp firmware/Water_Quality_Monitoring/secrets.example.h \
   firmware/Water_Quality_Monitoring/secrets.h
# fill in secrets.h with real credentials, then flash via Arduino IDE
```

---

## 7. How the System Works

### Data Flow

```
┌──────────────┐   sensor reads (1s)  ┌─────────────┐
│  ESP32 +     │ ──────────────────►  │  16×2 LCD   │ (offline, always)
│  sensors     │                       └─────────────┘
└──────┬───────┘
       │ Firebase auth (email/password)
       │ writes to RTDB every 10s (non-blocking)
       ▼
┌──────────────────────────────────────────┐
│         Firebase Realtime Database        │
│  /devices/device1/latest   (overwrites)  │
│  /devices/device1/history  (appends)     │
│  /access/{uid}             (access gate) │
└──────────────────┬───────────────────────┘
                   │  live stream
                   ▼
          ┌─────────────────┐
          │   Flutter App   │
          │  Live dashboard │
          │  History charts │
          │  Alert thresholds│
          │  User management│
          └────────┬────────┘
                   │ reads/writes user profiles
                   ▼
        ┌──────────────────────┐
        │  Firebase Auth +      │
        │  Firestore           │
        │  /users/{uid}        │
        │  role, status        │
        └──────────────────────┘
```

### Why Two Firebase Services?

**Realtime Database** — used for sensor data because it's purpose-built
for live, high-frequency streams and has zero latency for real-time updates.

**Firestore** — used for user accounts because it supports structured
queries (list all users, order by creation date) and has richer Security
Rules expression for the role-based access control pattern.

**The RTDB access mirror** exists because RTDB security rules cannot
query Firestore directly (they're separate services). When an admin
creates or disables a user in the app, `auth_service.dart` writes to
both Firestore (`users/{uid}`) AND RTDB (`access/{uid}`) in the same
operation, keeping them in sync automatically.

### Access Control Flow

```
Admin creates user via "Add user" in app
          │
          ▼
Secondary Firebase App instance creates Auth account
(admin stays signed in — session is untouched)
          │
          ▼
auth_service.dart writes simultaneously to:
  Firestore: users/{uid} = { role, status: "active", ... }
  RTDB:      access/{uid} = { granted: true, role }
          │
          ▼
New user signs in with temp password
          │
          ▼
app_root.dart streams users/{uid} from Firestore on every load
          │
    ┌─────┴──────────┐
    │                │
 active           disabled / doc missing
    │                │
    ▼                ▼
 Home Shell      "No Access" screen
 (full app)      (sign out only)
```

Disabling a user (⋮ → Disable access) flips `status` in Firestore
**and** `granted: false` in RTDB simultaneously — blocking both the
app UI check and any direct RTDB read attempt.

---

## 8. Troubleshooting — Real Errors with Exact Fixes

Every error below was encountered during actual development and testing
of this project. Solutions are based on what actually worked.

---

### 8.1 — Firmware: `[Firebase Error] unauthorized, code: 401`

**What it means:**
Firebase Auth is rejecting the sign-in attempt. The device authenticated
(got past TCP connection) but the credentials were rejected.

**Diagnosis:**
Test the credentials directly using curl:
```powershell
curl.exe -X POST "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=YOUR_API_KEY" -H "Content-Type: application/json" -d '{\"email\":\"YOUR_EMAIL\",\"password\":\"YOUR_PASSWORD\",\"returnSecureToken\":true}'
```
- If you get back a JSON response with `idToken` → credentials are correct,
  the issue is something else (check RTDB rules / access node)
- If you get `INVALID_PASSWORD` or `EMAIL_NOT_FOUND` → credential mismatch

**Common causes and fixes:**
| Cause | Fix |
|---|---|
| RTDB `access/{uid}` missing or wrong UID | Add the correct entry (run the curl test above to confirm the real UID — it's in the `localId` field of the response) |
| Wrong FIREBASE_API_KEY | Get it from Project Settings → Your apps → web app's `apiKey` field |
| Email/password typo in `secrets.h` | Compare character by character against what's in Authentication → Users |
| API key has restrictions | Google Cloud Console → APIs & Services → Credentials → check "Application restrictions" is "None" and Identity Toolkit API is in the allowed list |

---

### 8.2 — Firmware: Hangs forever at `Connecting to server...`

**What it means:**
The TLS handshake to Firebase's servers never completes. The connection
attempt just sits there without succeeding or erroring.

**Causes found during this project:**

**Cause A — `setHandshakeTimeout` too small (confirmed root cause)**
If the firmware calls `ssl_client.setHandshakeTimeout(N)` where N is
a small number, note that this function takes **milliseconds**, not
seconds. `setHandshakeTimeout(5)` = 5ms timeout, which kills every
TLS handshake immediately. Remove this call entirely and let the library
use its safe built-in default.

**Cause B — NTP time not synced before Firebase init**
The ESP32 starts with its clock at January 1, 1970. TLS certificate
validation requires an accurate timestamp. Without NTP sync, Firebase
TLS connections will stall or fail.

Fix: add NTP sync in `setup()` before `initializeApp()`:
```cpp
#include <time.h>
configTime(0, 0, "pool.ntp.org", "time.nist.gov", "time.google.com");
time_t now = time(nullptr);
while (now < 1767225600) { delay(500); now = time(nullptr); }
```

**Cause C — Race condition between NTP and Firebase networking**
Starting NTP sync and Firebase auth networking too close together can
cause a crash or timeout due to both accessing the ESP32's network stack
simultaneously. Fix: add a `delay(300)` after NTP sync completes and
before calling `initializeApp()`.

---

### 8.3 — App: "No Access Yet" screen after sign-in

**What it means:**
Firebase Auth succeeded (the user exists and credentials are correct)
but the app couldn't find an active Firestore profile at `users/{uid}`.

**Step-by-step diagnosis:**

**Check 1 — Verify the Firestore document path**
The most common cause is the document being at the wrong path. Go to
Firestore Database → Data and look at the URL in your browser address bar.
It should contain: `~/users~2FYOUR_UID` (where `~2F` is a `/`).

If it shows `~/YOUR_UID~2Fusers` instead — the UID and "users" are
swapped. The collection name is the UID, and "users" is the document ID.
That's backwards. Delete it and re-create with Collection ID = `users`
and Document ID = your UID.

**Check 2 — Verify field values are exact strings**
The `role` field must be the string `admin` (all lowercase).
The `status` field must be the string `active` (all lowercase).
Both must be of type **string**, not boolean or number.

**Check 3 — Verify the UID matches Authentication**
Go to Authentication → Users, find your email, copy the User UID.
Go to Firestore → Data → `users` collection, check the document ID.
They must be identical, character for character.

**Check 4 — Verify Firestore rules are published**
If Firestore rules are still in test mode or have an error, reads may
fail silently. Go to Firestore Database → Rules and confirm the rules
from `firestore_rules.txt` are active (not the default test-mode rules).

---

### 8.4 — Firmware: `udp_new_ip_type: Required to lock TCPIP core` crash

**What it means:**
A hard ESP32 crash caused by a network stack threading violation. The
device restarts immediately after this message.

**Confirmed cause:**
ESP32 board package version 3.1.0 by Espressif has a known regression
that triggers this crash when NTP and Firebase networking start near-
simultaneously.

**Fix:**
Downgrade the ESP32 board package to version 3.0.7:
1. Arduino IDE → Tools → Board → Boards Manager
2. Find "esp32 by Espressif Systems"
3. Click the version dropdown and select **3.0.7**
4. Wait for it to install
5. Re-upload the firmware

Adding settle delays around NTP and Firebase init also helps:
```cpp
// After WiFi connects, before configTime():
delay(500);
// After NTP sync completes, before initializeApp():
delay(300);
```

---

### 8.5 — Windows: `flutterfire` not recognized

**Cause:** Dart's global pub cache bin folder isn't on the Windows PATH.

**Fix:**
```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";$env:LOCALAPPDATA\Pub\Cache\bin", "User")
```
Close the terminal completely, open a new one, then retry.

---

### 8.6 — Windows: `firebase` not recognized after `npm install -g`

**Cause:** npm's global bin folder isn't on the Windows PATH.

**Fix:**
```powershell
# Find where npm installed it:
npm config get prefix
# It usually returns: C:\Users\YOUR_NAME\AppData\Roaming\npm

# Add it to PATH permanently:
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\Users\YOUR_NAME\AppData\Roaming\npm", "User")
```
Close and reopen the terminal, then retry `firebase --version`.

---

### 8.7 — Windows: `npm` gives execution policy error

**Error:**
```
File cannot be loaded because running scripts is disabled on this system.
```

**Fix:**
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Type `Y` when prompted. Then retry your npm command.

---

### 8.8 — `flutter run`: No supported device connected

**Diagnosis steps:**
1. Run `flutter devices` — check if your phone appears at all
2. If not listed: unplug/replug the USB cable, check the phone screen
   for the "Allow USB debugging?" popup (it needs to be accepted fresh
   on each computer you connect to)
3. If "unauthorized" appears: the USB debugging trust dialog wasn't
   accepted — check your phone screen and tap "Allow"
4. Run `flutter doctor -v` — look for the "Connected device" section

**If flutter doctor shows the phone but `flutter run` fails:**
- Run `flutter create .` first if this is a fresh clone — the `android/`
  folder may not exist yet
- Then run `flutterfire configure` and `flutter pub get` before `flutter run`

---

### 8.9 — Firestore: "To create a named database, you must upgrade"

**Cause:** The Database ID field had a custom name typed into it
instead of being left as `(default)`.

**Fix:** When creating the Firestore database:
- Leave the **Database ID** field exactly as `(default)` — do not type
  anything. Any custom name makes it a paid "named database."
- If you already created a named database accidentally, you'll need to
  delete the project and start fresh (named databases on the free tier
  cannot be converted to the default).

---

### 8.10 — Firestore: `flutterfire configure` finds 0 projects

**Cause:** Not logged into Firebase CLI.

**Fix:**
```bash
firebase login
```
This opens a browser. Sign in with the Google account tied to your
Firebase project. Then retry `flutterfire configure`.

If it still finds 0 projects after logging in:
- Confirm you're logging in with the correct Google account (the one
  that created the Firebase project, not a different one)
- Try `firebase projects:list` in terminal to see what the CLI sees

---

### 8.11 — ESP32 `access` entry — wrong UID

**Symptom:** Firmware auth succeeds (`ready, code: 10`) but every RTDB
write immediately shows `unauthorized` or times out.

**Diagnosis:** Run the curl test (Section 8.1) and look at the `localId`
field in the response — that's the real UID Firebase Auth assigned.
Compare it to what's in your RTDB `access` node.

**Fix:** In Realtime Database → Data → `access`, add a new child using
the **exact** UID from the curl response with `granted: true` and
`role: "device"`. Delete any existing entries with wrong UIDs.

---

## End of Setup Guide

For issues not covered here, check:
- Serial Monitor output (firmware) — all Firebase events and errors are
  printed at 115200 baud
- Flutter debug console (app) — stack traces appear here when the app
  encounters errors
- Firebase Console → Authentication → Usage — failed sign-in attempts
  are logged here
- Firebase Console → Realtime Database → Usage — read/write operations
  and denials

**GitHub:** https://github.com/YOUR_USERNAME/water-quality-monitor
