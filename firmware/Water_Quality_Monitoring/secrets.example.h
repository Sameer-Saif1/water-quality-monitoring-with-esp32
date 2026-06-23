// =============================================================================
// secrets.example.h — TEMPLATE, safe to commit.
//
// Copy this file to "secrets.h" (same folder) and fill in your real values.
// secrets.h is listed in .gitignore and will never be committed — that's
// the file the firmware actually includes.
//
//   cp secrets.example.h secrets.h
//
// See SETUP_GUIDE.md for where to find each value.
// =============================================================================

#ifndef SECRETS_H
#define SECRETS_H

// --- WiFiManager captive portal ---
// Shown as a WiFi network name on first boot (or after a WiFi reset) so you
// can connect a phone/laptop to it and enter your real WiFi credentials.
// Change the password to something only you know — anyone in radio range
// who knows this password could reconfigure the device's WiFi.
#define WIFI_PORTAL_SSID     "Water Quality Monitoring"
#define WIFI_PORTAL_PASSWORD "REPLACE_WITH_A_STRONG_PASSWORD"

// --- Firebase project credentials ---
// Firebase Console -> Project settings -> General -> Your apps -> Web app
// "apiKey" field
#define FIREBASE_API_KEY      "REPLACE_WITH_YOUR_FIREBASE_WEB_API_KEY"

// Firebase Console -> Realtime Database -> Data tab, URL shown at the top
#define FIREBASE_DATABASE_URL "REPLACE_WITH_YOUR_FIREBASE_DATABASE_URL"

// --- Device's own Firebase Auth account ---
// A dedicated Authentication user created just for this device (NOT your
// personal/admin login) — see SETUP_GUIDE.md, Step 7, for why and how.
// Use a strong, unique password — avoid symbols that need shell/JSON
// escaping (e.g. avoid characters like " \ ` $) since they can cause
// subtle bugs in some environments. Letters + digits + a few safe
// symbols (- _ . !) are recommended.
#define FIREBASE_USER_EMAIL   "REPLACE_WITH_YOUR_DEVICE_EMAIL"
#define FIREBASE_USER_PASS    "REPLACE_WITH_YOUR_DEVICE_PASSWORD"

#endif // SECRETS_H
