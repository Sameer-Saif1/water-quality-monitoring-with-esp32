/*
  Water Quality Monitoring — ESP32
  Sensors: pH, TDS/EC, Turbidity, DS18B20 Temperature
  Output:  16x2 I2C LCD (always works, even offline)
           Firebase Realtime Database (when WiFi/Firebase available)

  Calibration formulas for pH, TDS/EC, and turbidity are unchanged from
  the original working version. Do not edit readPH(), readTDS_EC(), or
  readTurbidity() unless you are intentionally re-calibrating.

  NOTE ON TIMING: FirebaseClient is an async library — it needs loop() to
  run frequently and without blocking delay() calls, or its background
  networking (auth refresh, sending data) will stall or time out. This
  version uses millis()-based timers everywhere instead of delay(), except
  for the one-time startup messages in setup() before the network starts.
*/

#include <WiFiManager.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <LiquidCrystal_I2C.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include <time.h>

// === Firebase (FirebaseClient by mobizt) ===
#define ENABLE_USER_AUTH
#define ENABLE_DATABASE
#include <FirebaseClient.h>

// === Credentials ===
// All secrets (WiFi captive-portal password, Firebase project keys, device
// auth email/password) live in secrets.h, which is gitignored and never
// committed. Copy secrets.example.h to secrets.h and fill in your real
// values — see SETUP_GUIDE.md.
#include "secrets.h"

// A unique ID for this device. If you ever add a 2nd unit, change this
// so its data doesn't overwrite the first device's data in Firebase.
#define DEVICE_ID "device1"

// === Pin Definitions ===
#define PH_PIN 34
#define TDS_PIN 32
#define TURBIDITY_PIN 35
#define TEMP_PIN 4

// === LCD Setup ===
LiquidCrystal_I2C lcd(0x27, 16, 2);

// === Temp Sensor ===
OneWire oneWire(TEMP_PIN);
DallasTemperature tempSensor(&oneWire);

// === Sensor Variables ===
float pH = 0.0, tds = 0.0, ec = 0.0, turbidity = 0.0, waterTemp = 25;

// === Non-blocking timers ===
unsigned long lastSensorRead = 0;
const unsigned long SENSOR_READ_INTERVAL = 1000;   // read sensors every 1s

unsigned long lastFirebaseSend = 0;
const unsigned long FIREBASE_SEND_INTERVAL = 10000; // send to Firebase every 10s

// === Firebase objects ===
void processData(AsyncResult &aResult);
UserAuth user_auth(FIREBASE_API_KEY, FIREBASE_USER_EMAIL, FIREBASE_USER_PASS);
FirebaseApp app;
WiFiClientSecure ssl_client;
using AsyncClient = AsyncClientClass;
AsyncClient aClient(ssl_client);
RealtimeDatabase Database;
bool firebaseReady = false;

// === Read Temperature ===
void readTemperature() {
  tempSensor.requestTemperatures();
  float tempC = tempSensor.getTempCByIndex(0);
  waterTemp = (tempC != DEVICE_DISCONNECTED_C) ? tempC : 25.0;
}

// === Read pH ===
void readPH() {
  int pH_Value = analogRead(PH_PIN);
  float voltage = pH_Value * (3.3 / 4095.0);
  pH = 7 + ((2.5 - voltage) / 0.05918);
  pH = constrain(pH, 0, 14);
}

// === Read TDS/EC ===
void readTDS_EC() {
  int analogValue = analogRead(TDS_PIN);
  float voltage = analogValue * (3.3 / 4095.0);
  float ecVoltage = voltage / (1.0 + 0.02 * (waterTemp - 25.0));
  ec = ecVoltage - 0.14;
  ec = max(ec, 0.0f);
  tds = (133.42 * pow(ec, 3) - 255.86 * pow(ec, 2) + 857.39 * ec) * 0.5;
}

// === Read Turbidity ===
void readTurbidity() {
  int analogValue = analogRead(TURBIDITY_PIN);
  float voltage = analogValue * (3.3 / 4095.0);

  if (voltage >= 1.90) {
    turbidity = 0;
  } else if (voltage <= 0.0) {
    turbidity = 100;
  } else {
    turbidity = ((1.90 - voltage) / 1.90) * 100.0;
  }

  turbidity = constrain(turbidity, 0, 100);
}

// === Variables to track LCD updates ===
String lastLine1 = "", lastLine2 = "";

// === Update LCD ===
void updateLCD() {
  char line1[17], line2[17];

  snprintf(line1, sizeof(line1), "pH:%1.0f T:%1.0f", pH, waterTemp);
  snprintf(line2, sizeof(line2), "TDS:%1.0f NTU:%1.0f", tds, turbidity);

  String currentLine1 = String(line1);
  String currentLine2 = String(line2);

  if (currentLine1 != lastLine1 || currentLine2 != lastLine2) {
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print(currentLine1);
    lcd.setCursor(0, 1);
    lcd.print(currentLine2);

    // Show '!' on top-right if WiFi is not connected
    if (WiFi.status() != WL_CONNECTED) {
      lcd.setCursor(15, 0);
      lcd.print("!");
    }

    lastLine1 = currentLine1;
    lastLine2 = currentLine2;
  }
}

// === Send to Firebase Realtime Database ===
// Writes both:
//   /devices/<id>/latest  -> overwritten every send, used for a live dashboard
//   /devices/<id>/history -> a new auto-keyed node every send, used for charts
void sendToFirebase() {
  if (!firebaseReady) return;

  object_t json, obj_ph, obj_tds, obj_ec, obj_temp, obj_turb, obj_ts, obj_wifi;
  JsonWriter writer;

  writer.create(obj_ph, "pH", pH);
  writer.create(obj_tds, "tds", tds);
  writer.create(obj_ec, "ec", ec);
  writer.create(obj_temp, "waterTemp", waterTemp);
  writer.create(obj_turb, "turbidity", turbidity);
  writer.create(obj_ts, "deviceMillis", (int)millis());
  writer.create(obj_wifi, "rssi", WiFi.RSSI());

  writer.join(json, 7, obj_ph, obj_tds, obj_ec, obj_temp, obj_turb, obj_ts, obj_wifi);

  String latestPath = "/devices/" + String(DEVICE_ID) + "/latest";
  Database.set<object_t>(aClient, latestPath, json, processData, "RTDB_Send_Latest");

  // History: push() lets Firebase auto-generate a time-ordered key.
  String historyPath = "/devices/" + String(DEVICE_ID) + "/history";
  Database.push<object_t>(aClient, historyPath, json, processData, "RTDB_Send_History");
}

// === Sync system time via NTP ===
// REQUIRED for Firebase: the TLS handshake and auth token validation both
// depend on the ESP32 knowing the correct current time. Without this, the
// ESP32's clock starts at Jan 1 1970 and Firebase silently rejects requests
// (often hanging or returning 401) even though the credentials are correct.
// Using UTC (offset 0) since Firebase only needs a valid absolute time, not
// your local timezone.
//
// A short delay before starting, and a longer/more patient retry loop, are
// both deliberate: starting NTP immediately after WiFi connects (while the
// network stack is still settling) and then starting Firebase's own async
// networking immediately after NTP can race the lwIP network stack and
// trigger a low-level crash. Giving each step a moment to fully finish
// avoids that.
void syncTime() {
  delay(500); // let the network stack settle after WiFi connects

  configTime(0, 0, "pool.ntp.org", "time.nist.gov", "time.google.com");

  Serial.print("Syncing time");
  time_t now = time(nullptr);
  int retries = 0;
  // 2026-01-01 in epoch seconds — used as a sanity check that NTP actually
  // returned a real date, not just the default 1970 epoch.
  const time_t minValidTime = 1767225600;

  while (now < minValidTime && retries < 40) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
    retries++;
  }
  Serial.println();

  if (now < minValidTime) {
    Serial.println("NTP sync failed — Firebase calls may fail until time is correct.");
  } else {
    Serial.println("Time synced.");
  }
}

void setup() {
  Serial.begin(115200);
  lcd.init();
  lcd.backlight();

  // Startup greeting (one-time, before networking starts — fine to block here)
  lcd.setCursor(0, 0);
  lcd.print("Water Quality");
  lcd.setCursor(0, 1);
  lcd.print("Monitoring");
  delay(2000);
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("By Sameer Saif");
  delay(1500);
  lcd.clear();

  tempSensor.begin();

  // WiFiManager Captive Portal
  WiFiManager wm;
  if (!wm.autoConnect(WIFI_PORTAL_SSID, WIFI_PORTAL_PASSWORD)) {
    Serial.println("WiFi Failed. Restarting...");
    delay(3000);
    ESP.restart();
  }

  Serial.println("WiFi connected");
  lcd.setCursor(0, 0);
  lcd.print("WiFi Connected");
  delay(1000);
  lcd.clear();

  lcd.setCursor(0, 0);
  lcd.print("Syncing time...");
  syncTime();
  lcd.clear();
  delay(300); // brief settle gap before handing off to Firebase's async networking

  // Start Firebase
  ssl_client.setInsecure();
  // NOTE: previously this called setConnectionTimeout(1000) and
  // setHandshakeTimeout(5) here. setHandshakeTimeout() takes MILLISECONDS,
  // so 5 meant "fail the TLS handshake after 5ms" — far too short for any
  // real handshake to complete, which silently broke every Firebase
  // connection regardless of network. Removed in favor of the library's
  // built-in defaults (handshake ~120s, connect ~15s), which are sane.

  initializeApp(aClient, app, getAuth(user_auth), processData, "authTask");
  app.getApp<RealtimeDatabase>(Database);
  Database.url(FIREBASE_DATABASE_URL);
}

void loop() {
  // Keep Firebase's async auth + network tasks alive. Must run every
  // iteration with nothing blocking it, or sends will time out/stall.
  app.loop();
  firebaseReady = app.ready();

  unsigned long now = millis();

  // Read sensors + update LCD every SENSOR_READ_INTERVAL, without delay()
  if (now - lastSensorRead >= SENSOR_READ_INTERVAL) {
    lastSensorRead = now;

    readTemperature();
    readPH();
    readTDS_EC();
    readTurbidity();
    updateLCD();
  }

  // Send to Firebase every FIREBASE_SEND_INTERVAL, without delay()
  if (firebaseReady && (now - lastFirebaseSend >= FIREBASE_SEND_INTERVAL)) {
    lastFirebaseSend = now;
    sendToFirebase();
  }
}

// === Firebase async result/event/error logger ===
void processData(AsyncResult &aResult) {
  if (!aResult.isResult())
    return;

  if (aResult.isEvent())
    Serial.printf("[Firebase Event] task: %s, msg: %s, code: %d\n",
                  aResult.uid().c_str(), aResult.eventLog().message().c_str(), aResult.eventLog().code());

  if (aResult.isDebug())
    Serial.printf("[Firebase Debug] task: %s, msg: %s\n",
                  aResult.uid().c_str(), aResult.debug().c_str());

  if (aResult.isError())
    Serial.printf("[Firebase Error] task: %s, msg: %s, code: %d\n",
                  aResult.uid().c_str(), aResult.error().message().c_str(), aResult.error().code());
}
