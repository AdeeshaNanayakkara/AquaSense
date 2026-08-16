#include <ESP8266WiFi.h>
#include <ESP8266Firebase.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>

// ================= WIFI =================
#define WIFI_SSID "iPhone"
#define WIFI_PASSWORD "12345689"

// ================= FIREBASE =================
#define FIREBASE_URL "https://aquasense-6b25f-default-rtdb.firebaseio.com/"
Firebase firebase(FIREBASE_URL);

// ================= LCD =================
LiquidCrystal_I2C lcd(0x27, 16, 2);

// ================= I2C PINS (IMPORTANT) =================
#define I2C_SDA D2   // GPIO4
#define I2C_SCL D1   // GPIO5

// ================= PINS =================
#define TRIG_TANK D5
#define ECHO_TANK D6

#define TRIG_WELL D7
#define ECHO_WELL D8

#define RELAY1 D0
#define BUZZER D3

// ================= TIMERS =================
unsigned long lastSensorUpdate = 0;
const unsigned long sensorInterval = 5000;

unsigned long lastModeRead = 0;
const unsigned long modeInterval = 10000;

unsigned long lastHistoryUpdate = 0;
const unsigned long historyInterval = 3600000;

// ================= VARIABLES =================
bool pumpState = false;
bool buzzerTriggered = false;
unsigned long buzzerStart = 0;

String mode = "MANUAL";

// Config
float tankEmpty = 100;
float tankFull = 10;

float wellEmpty = 200;
float wellFull = 20;

// ================= ULTRASONIC =================
long readDistance(int trigPin, int echoPin) {

  digitalWrite(trigPin, LOW);
  delayMicroseconds(2);

  digitalWrite(trigPin, HIGH);
  delayMicroseconds(10);

  digitalWrite(trigPin, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000);

  long distance = duration * 0.034 / 2;

  if (distance <= 0 || distance > 400)
    return 0;

  return distance;
}

// ================= PERCENTAGE =================
int calculatePercentage(float distance, float emptyD, float fullD) {

  if (emptyD == fullD) return 0;

  float p = ((emptyD - distance) * 100.0) / (emptyD - fullD);

  return constrain((int)p, 0, 100);
}

// ================= LOAD CONFIG (FIXED FOR INTEGERS) =================
void loadConfiguration() {
  int val;

  val = firebase.getInt("Configuration/tank/emptyDistance");
  if (val > 0) tankEmpty = val;

  val = firebase.getInt("Configuration/tank/fullDistance");
  if (val > 0) tankFull = val;

  val = firebase.getInt("Configuration/well/emptyDistance");
  if (val > 0) wellEmpty = val;

  val = firebase.getInt("Configuration/well/fullDistance");
  if (val > 0) wellFull = val;

  Serial.println("Config Loaded: Tank(" + String(tankEmpty) + "-" + String(tankFull) + ") Well(" + String(wellEmpty) + "-" + String(wellFull) + ")");
}

// ================= SETUP =================
void setup() {

  Serial.begin(115200);

  pinMode(TRIG_TANK, OUTPUT);
  pinMode(ECHO_TANK, INPUT);

  pinMode(TRIG_WELL, OUTPUT);
  pinMode(ECHO_WELL, INPUT);

  pinMode(RELAY1, OUTPUT);
  pinMode(BUZZER, OUTPUT);

  digitalWrite(RELAY1, LOW);
  digitalWrite(BUZZER, LOW);

  // ================= I2C INIT (IMPORTANT FIX) =================
  Wire.begin(I2C_SDA, I2C_SCL);

  lcd.init();
  lcd.backlight();

  lcd.setCursor(0, 0);
  lcd.print("Connecting WiFi");

  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }

  lcd.clear();
  lcd.print("WiFi Connected");

  Serial.println("\nWiFi Connected! IP: " + WiFi.localIP().toString());

  delay(1000);   // IMPORTANT for LCD stability

  loadConfiguration();
}

// ================= LOOP =================
void loop() {

  // ================= MODE =================
  if (millis() - lastModeRead >= modeInterval) {
    lastModeRead = millis();
    String rawMode = firebase.getString("Controls/mode");
    rawMode.replace("\"", "");
    rawMode.trim();
    if (rawMode.equalsIgnoreCase("AUTO")) {
      mode = "AUTO";
    } else if (rawMode.equalsIgnoreCase("MANUAL")) {
      mode = "MANUAL";
    }
  }

  // ================= SENSOR UPDATE =================
  if (millis() - lastSensorUpdate >= sensorInterval) {

    lastSensorUpdate = millis();

    long tankDistance = readDistance(TRIG_TANK, ECHO_TANK);
    long wellDistance = readDistance(TRIG_WELL, ECHO_WELL);

    int tankPercent = calculatePercentage(tankDistance, tankEmpty, tankFull);
    int wellPercent = calculatePercentage(wellDistance, wellEmpty, wellFull);

    // ================= CONTROL =================
    if (mode == "AUTO") {

      if (tankPercent <= 10 && wellPercent > 10) {
        pumpState = true;
      }

      if (tankPercent >= 90) {
        pumpState = false;
      }

      // Write 1 or 0 to Firebase
      firebase.setInt("Controls/pump", pumpState ? 1 : 0);

    } else {

      // Read pump state (handles "true", "1", 1, "false", "0", 0)
      String rawPump = firebase.getString("Controls/pump");
      rawPump.replace("\"", "");
      rawPump.trim();

      if (rawPump.equalsIgnoreCase("true") || rawPump == "1" || rawPump.equalsIgnoreCase("ON")) {
        pumpState = true;
      } else if (rawPump.equalsIgnoreCase("false") || rawPump == "0" || rawPump.equalsIgnoreCase("OFF")) {
        pumpState = false;
      }
    }

    digitalWrite(RELAY1, pumpState ? HIGH : LOW);

    // ================= FIREBASE =================
    firebase.setFloat("Sensors/tank/distance", tankDistance);
    firebase.setFloat("Sensors/well/distance", wellDistance);

    firebase.setInt("percentage/tank", tankPercent);
    firebase.setInt("percentage/well", wellPercent);

    // ================= BUZZER =================
    if (tankPercent >= 90) {

      if (!buzzerTriggered) {
        buzzerTriggered = true;
        buzzerStart = millis();
      }

      digitalWrite(BUZZER, millis() - buzzerStart < 3000 ? HIGH : LOW);

    } else {
      buzzerTriggered = false;
      digitalWrite(BUZZER, LOW);
    }

        // ================= SERIAL MONITOR =================
    Serial.println();
    Serial.println("========================================");
    Serial.print("Mode          : ");
    Serial.println(mode);

    Serial.print("Tank Distance : ");
    Serial.print(tankDistance);
    Serial.println(" cm");

    Serial.print("Tank Level    : ");
    Serial.print(tankPercent);
    Serial.println("%");

    Serial.print("Well Distance : ");
    Serial.print(wellDistance);
    Serial.println(" cm");

    Serial.print("Well Level    : ");
    Serial.print(wellPercent);
    Serial.println("%");

    Serial.print("Pump Status   : ");
    Serial.println(pumpState ? "ON" : "OFF");

    Serial.print("Relay Output  : ");
    Serial.println(digitalRead(RELAY1) ? "HIGH" : "LOW");

    Serial.print("Buzzer        : ");
    Serial.println((tankPercent >= 90) ? "ON" : "OFF");

    Serial.println("========================================");

    // ================= LCD =================
    lcd.setCursor(0, 0);
    lcd.print("                "); // clear line
    lcd.setCursor(0, 0);
    lcd.print("T:");
    lcd.print(tankPercent);
    lcd.print("% W:");
    lcd.print(wellPercent);
    lcd.print("%");

    lcd.setCursor(0, 1);
    lcd.print("                ");
    lcd.setCursor(0, 1);
    lcd.print("P:");
    lcd.print(pumpState ? "ON " : "OFF ");
    lcd.print(mode);
  }

  // ================= HISTORY =================
  if (millis() - lastHistoryUpdate >= historyInterval) {

    lastHistoryUpdate = millis();

    int tankPercent = calculatePercentage(
      readDistance(TRIG_TANK, ECHO_TANK),
      tankEmpty,
      tankFull
    );

    String id = String(millis());

    firebase.setInt("TankHistory/" + id + "/percentage", tankPercent);
    firebase.setString("TankHistory/" + id + "/timestamp", "AUTO");

    Serial.println("History Updated");
  }
}