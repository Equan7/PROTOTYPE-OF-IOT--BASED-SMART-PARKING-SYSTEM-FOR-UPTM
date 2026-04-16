#include <Arduino.h> // Core Arduino library containing fundamental functions
#include <HTTPClient.h> // Library used to send HTTP requests to the Firebase database
#include <LiquidCrystal_I2C.h> // Library to control the I2C LCD screen
#include <WiFi.h> // Library that enables the ESP32 to connect to a Wi-Fi network
#include <Wire.h> // Library for I2C communication (used by the LCD screen)

#include <ArduinoJson.h> // Library to format and read JSON data (used for sending Wi-Fi lists and reading Firebase)
#include <BLEDevice.h> // Library to use the ESP32's built-in Bluetooth Low Energy (BLE)
#include <BLEServer.h>   // Allows the ESP32 to act as a BLE Server
#include <BLEUtils.h>    // Utility functions for BLE
#include <Preferences.h> // Library to save data permanently in the ESP32's memory (like a mini hard drive)

// ---------------------------------------------------------------------------
// 1. CONFIGURATION & GLOBAL VARIABLES
// ---------------------------------------------------------------------------
// The URL of our Firebase Realtime Database where we store all parking statuses
String DATABASE_URL =
    "https://testing-c978d-default-rtdb.asia-southeast1.firebasedatabase.app";

// BLE UUIDs (Slightly like "phone numbers" for Bluetooth services so the
// Flutter app can find them)
#define SERVICE_UUID                                                           \
  "4fafc201-1fb5-459e-8fcc-c5c9c331914b" // The main ID of our Bluetooth service
#define CHARACTERISTIC_UUID                                                    \
  "beb5483e-36e1-4688-b7f5-ea07361b26a8" // ID for receiving Wi-Fi passwords
                                         // from the app
#define SCAN_CHRCT_UUID                                                        \
  "f81014ab-5dd5-485e-aa20-9bf7239bd01a" // ID for sending the list of scanned
                                         // Wi-Fis to the app

Preferences
    preferences;  // Object used to save and load Wi-Fi credentials permanently
String ssid = ""; // Variable to store the Wi-Fi Name (SSID)
String password = "";           // Variable to store the Wi-Fi Password
bool shouldConnectWiFi = false; // Flag used to tell the main loop we just
                                // received new Wi-Fi credentials
bool isProvisioning = false;    // Flag that is true when we are waiting for the
                                // admin to configure Wi-Fi via Bluetooth
String wifiScanResultsJSON = "[]"; // Variable to store the list of scanned
                                   // Wi-Fi networks in JSON text format

// We define our two types of alarm sounds here
enum AlarmType {
  ALARM_UNKNOWN, // Used when a car parks without booking first
  ALARM_STOLEN   // Used when a car leaves without confirming exit in the app
};

// A structured template to organize information for each physical parking spot
struct ParkingSpot {
  int id;        // The number of the parking spot (1, 2, 3...)
  int trigPin;   // The pin connected to the ultrasonic sensor's Trigger (sends
                 // sound)
  int echoPin;   // The pin connected to the ultrasonic sensor's Echo (receives
                 // sound)
  int buzzerPin; // The pin connected to the buzzer to sound alarms
  bool
      isOccupied; // True if the sensor physically detects a car, False if empty
  int emptyCount; // A counter used to "debounce" or double-check before
                  // deciding a spot is truly empty
};

// PIN MAPPING: We create 5 ParkingSpot objects, assigning the specific wiring
// pins for each sensor and buzzer
ParkingSpot spots[5] = {{1, 16, 36, 23, false, 0},
                        {2, 17, 39, 25, false, 0},
                        {3, 18, 32, 26, false, 0},
                        {4, 13, 34, 27, false, 0},
                        {5, 14, 35, 33, false, 0}};

// LCD SCREEN SETTINGS
#define I2C_ADDR 0x27  // The physical I2C address of the LCD screen module
#define LCD_COLUMNS 16 // The screen has 16 characters per row
#define LCD_LINES 2    // The screen has 2 rows
// Create an LCD object using the settings above
LiquidCrystal_I2C lcd(I2C_ADDR, LCD_COLUMNS, LCD_LINES);

// ---------------------------------------------------------------------------
// 2. BLUETOOTH (BLE) SETUP & CALLBACKS
// ---------------------------------------------------------------------------

// This class listens for messages sent from the Flutter app to the ESP32 via
// Bluetooth
class MyCallbacks : public BLECharacteristicCallbacks {
  // This specific function triggers automatically whenever the phone sends Data
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rxValue =
        pCharacteristic->getValue(); // Grab the text sent by the phone
    if (rxValue.length() > 0) {
      Serial.println("Received Over BLE: ");
      Serial.println(rxValue); // Print it to the computer screen for debugging

      // The phone sends data in JSON format like: {"ssid":"MyWifi",
      // "pass":"12345"} We create a temporary JSON document to parse
      // (understand) this text
      StaticJsonDocument<200> doc;
      DeserializationError error = deserializeJson(doc, rxValue);

      if (!error) {
        // If it successfully read the JSON, we extract the Wi-Fi name and
        // password
        const char *newSsid = doc["ssid"];
        const char *newPass = doc["pass"];

        if (newSsid && newPass) {
          ssid = String(newSsid); // Store it in our global string variable
          password =
              String(newPass); // Store it in our global password variable

          // Save these new credentials permanently into the ESP32's memory
          // (NVM) so it remembers them even after being unplugged and restarted
          preferences.begin("wifi-creds", false);
          preferences.putString("ssid", ssid);
          preferences.putString("pass", password);
          preferences.end();

          Serial.println("Credentials Saved! Attempting Connection...");
          shouldConnectWiFi = true; // Tell the main code loop to try connecting
                                    // to this new Wi-Fi
        }
      } else {
        Serial.println("Failed to parse JSON.");
      }
    }
  }
};

// This class handles the actual Bluetooth connection events (When someone
// connects or disconnects)
class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) {
    Serial.println(
        "BLE Device Connected."); // Someone opened the app and connected
  }

  void onDisconnect(BLEServer *pServer) {
    Serial.println("BLE Device Disconnected."); // Someone closed the app or
                                                // walked too far away

    // If they disconnect while we are still trying to set up Wi-Fi,
    // we want to turn the Bluetooth advertising back on so they can reconnect
    // and try again.
    if (isProvisioning) {
      Serial.println("Restarting Advertising...");
      delay(
          500); // Give the bluetooth hardware half a second to catch its breath
      pServer->startAdvertising(); // Tell the world "I am here, ready to pair!"
    }
  }
};

// ---------------------------------------------------------------------------
// 3. WI-FI & PROVISIONING FUNCTIONS
// ---------------------------------------------------------------------------

// A function to try and connect to the internet using the saved Wi-Fi details
void connectToWiFi() {
  lcd.clear();                  // Wipe the LCD screen
  lcd.setCursor(0, 0);          // Go to the first row (Top)
  lcd.print("Connecting WiFi"); // Show a message
  lcd.setCursor(0, 1);          // Go to the second row (Bottom)
  lcd.print(ssid);              // Show the name of the Wi-Fi being connected to

  WiFi.disconnect(); // Disconnect from any strange previous networks just in
                     // case
  WiFi.begin(ssid.c_str(), password.c_str()); // Give the ESP32 the password and
                                              // tell it to go connect

  int attempts = 0;
  // While we are NOT connected, and we haven't tried 20 times yet... keep
  // waiting
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500); // Wait half a second
    Serial.print(
        ".");   // Print a dot to the computer screen so we know it's trying
    attempts++; // Add 1 to our attempt counter
  }

  if (WiFi.status() == WL_CONNECTED) {
    // We successfully connected to the internet!
    Serial.println("\nWiFi Connected!");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Connected!");
    isProvisioning =
        false; // We are no longer setting up Wi-Fi, we are good to go!

    // Turn off Bluetooth entirely. We don't need it right now and turning it
    // off saves RAM and power.
    BLEDevice::deinit(true);
  } else {
    // We failed to connect (Maybe wrong password entered by Admin)
    Serial.println("\nWiFi Connection Failed!");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Failed!");
    delay(2000); // Wait 2 seconds so the user can read the failure message

    // Connection failed, so we go back into "Provisioning" mode.
    // We show the BLE message on screen and start broadcasting our Bluetooth
    // signal again
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("BLE Provisioning");
    isProvisioning = true;

    // Start advertising our Bluetooth signal so the Admin can configure Wi-Fi
    // again
    BLEDevice::startAdvertising();
  }
}

// This function turns the ESP32 into a temporary Bluetooth beacon so the Admin
// can send Wi-Fi settings
void startBLEProvisioning() {
  isProvisioning = true; // Tell the rest of the code we are in setup mode
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Scanning WiFi..."); // Show on screen what we are doing

  // Phase 1: Scan for Wi-Fi Networks
  Serial.println("Scanning Wi-Fi...");
  WiFi.mode(
      WIFI_STA); // Set Wi-Fi to "Station" mode (like a normal phone or laptop)
  WiFi.disconnect(); // Disconnect first to get a clean scan
  delay(100);
  int n = WiFi.scanNetworks(); // Tell the Wi-Fi chip to look for nearby
                               // networks, n = number found
  Serial.println("Scan complete.");

  // We create a JSON document to hold the list of Wi-Fi names
  StaticJsonDocument<512> scanDoc;
  JsonArray array = scanDoc.to<JsonArray>();

  // Limit to top 10 networks to make sure the data isn't too big to send over
  // Bluetooth
  int limit = (n > 10) ? 10 : n;
  for (int i = 0; i < limit; ++i) {
    array.add(WiFi.SSID(i)); // Add each Wi-Fi name (SSID) to our list
  }

  // Convert the list into a single text string
  serializeJson(scanDoc, wifiScanResultsJSON);
  Serial.println("Scan Results JSON:");
  Serial.println(wifiScanResultsJSON);

  // Free up RAM by deleting the scan results from the Wi-Fi chip's memory
  WiFi.scanDelete();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("BLE Provisioning");
  lcd.setCursor(0, 1);
  lcd.print("Ready to connect");

  // Phase 2: Start Bluetooth
  BLEDevice::init("UPTM_Sensor_Node"); // Turn on Bluetooth hardware and name it
  BLEServer *pServer = BLEDevice::createServer(); // Create the server
  pServer->setCallbacks(
      new MyServerCallbacks()); // Attach the connect/disconnect listeners
  BLEService *pService =
      pServer->createService(SERVICE_UUID); // Create our main service

  // Create the "mailbox" where the phone will WRITE the Wi-Fi password
  BLECharacteristic *pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_WRITE);
  pCharacteristic->setCallbacks(
      new MyCallbacks()); // Tell it what to do when data arrives

  // Create the "noticeboard" where the phone can READ the list of scanned Wi-Fi
  // names
  BLECharacteristic *pScanResultsCharacteristic =
      pService->createCharacteristic(SCAN_CHRCT_UUID,
                                     BLECharacteristic::PROPERTY_READ);
  pScanResultsCharacteristic->setValue(
      wifiScanResultsJSON); // Put the array text on the noticeboard

  pService->start(); // Start the service

  // Configure the advertising (broadcasting) settings so phones can find us
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(
      0x06); // Settings to help iPhones connect faster
  pAdvertising->setMinPreferred(0x12);

  BLEDevice::startAdvertising(); // Start broadcasting!
  Serial.println("BLE Provisioning Started.");
}

// ---------------------------------------------------------------------------
// 4. MAIN SETUP AND LOOP
// ---------------------------------------------------------------------------

// The setup() function runs ONLY ONCE when the ESP32 is turned on
void setup() {
  Serial.begin(115200); // Start the serial monitor so we can print messages to
                        // the computer

  // Loop through all 5 parking spots and configure their pins
  for (int i = 0; i < 5; i++) {
    pinMode(spots[i].trigPin, OUTPUT); // Trigger sends a signal OUT
    pinMode(spots[i].echoPin, INPUT);  // Echo takes a signal IN
    pinMode(spots[i].buzzerPin,
            OUTPUT); // Buzzer takes a signal OUT to make sound
    digitalWrite(spots[i].buzzerPin, LOW); // Make sure buzzer is OFF initially
  }

  lcd.init();      // Turn on the LCD screen
  lcd.backlight(); // Turn on the LCD backlight so we can see the text

  // Try to load any previously saved Wi-Fi name and password from memory
  preferences.begin("wifi-creds", true); // true = read-only mode
  ssid = preferences.getString(
      "ssid", ""); // Get saved SSID, or empty text if none exists
  password =
      preferences.getString("pass", ""); // Get saved Password, or empty text
  preferences.end();                     // Close the memory reader

  // Decide what to do next based on if we have saved Wi-Fi details
  if (ssid == "" || password == "") {
    // We have no saved Wi-Fi details, so we MUST go to Bluetooth setup mode
    Serial.println("No saved WiFi credentials found.");
    startBLEProvisioning();
  } else {
    // We found saved details! Try connecting to the internet immediately.
    Serial.println("Found Saved Credentials. Connecting...");
    connectToWiFi();

    // If we failed to connect (maybe the password changed), fall back to
    // Bluetooth setup
    if (WiFi.status() != WL_CONNECTED) {
      startBLEProvisioning();
    }
  }
}

// ---------------------------------------------------------------------------
// 5. HELPER FUNCTIONS (Sensors & Sound)
// ---------------------------------------------------------------------------

// Function to calculate how far away a car is using the Ultrasonic Sensor
long getDistance(int trig, int echo) {
  // Step 1: Make sure the trigger is off for a clean start
  digitalWrite(trig, LOW);
  delayMicroseconds(2);

  // Step 2: Send a super fast 10-microsecond sound pulse
  digitalWrite(trig, HIGH);
  delayMicroseconds(10);
  digitalWrite(trig, LOW);

  // Step 3: Listen for the echo and count how many microseconds it took to
  // return
  long duration = pulseIn(echo, HIGH);

  // Step 4: Calculate distance in centimeters (Speed of sound = 0.034 cm/us)
  // We divide by 2 because the sound traveled to the car AND back to the sensor
  return duration * 0.034 / 2;
}

// Function to play different buzzer sounds depending on the situation
void playAlarm(int pin, AlarmType type) {
  if (type == ALARM_UNKNOWN) {
    // SCENARIO: A car parked in an available spot without booking first
    // SOUND: Fast beeps (like a truck reversing)

    for (int k = 0; k < 3; k++) {    // Do 3 beeps
      for (int i = 0; i < 50; i++) { // This loop creates the actual sound wave
        digitalWrite(pin, HIGH);     // Push the speaker cone out
        delayMicroseconds(200);      // Wait 200 microseconds
        digitalWrite(pin, LOW);      // Pull the speaker cone in
        delayMicroseconds(200);      // Wait 200 microseconds
      }
      delay(50); // Short pause between beeps
    }
  } else if (type == ALARM_STOLEN) {
    // SCENARIO: A car left its spot without clicking "Confirm Departure" in the
    // app SOUND: Slower, aggressive alternating pitch siren (like a car alarm)

    for (int k = 0; k < 2; k++) {
      // First Part of Siren: "High" tone
      for (int i = 0; i < 60; i++) {
        digitalWrite(pin, HIGH);
        delayMicroseconds(250); // 250us delay makes a specific pitch
        digitalWrite(pin, LOW);
        delayMicroseconds(250);
      }
      // Second Part of Siren: "Low" tone
      for (int i = 0; i < 50; i++) {
        digitalWrite(pin, HIGH);
        delayMicroseconds(400); // 400us delay makes a deeper pitch
        digitalWrite(pin, LOW);
        delayMicroseconds(400);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// 6. OPTIMIZATION: FIREBASE DATA HANDLING
// ---------------------------------------------------------------------------

// A custom "text search" function to find specific data inside a large JSON
// string Instead of using heavy JSON libraries inside the loop (which crashes
// the ESP32), we just scan the raw text for the data we need.
String extractValue(String data, String objKey, String valKey) {
  int objStart =
      data.indexOf(objKey); // Find where our specific parking spot data starts
  if (objStart == -1)
    return "";

  // Limit search to this specific spot's block of text (stops at the next spot)
  int nextObj = data.indexOf("spot_", objStart + 5);
  if (nextObj == -1)
    nextObj = data.length();
  String block = data.substring(objStart, nextObj);

  // Find the exact key we are looking for (e.g., "status")
  int valStart = block.indexOf("\"" + valKey + "\"");
  if (valStart == -1)
    return "";

  // Find the colon (:) right after the key
  int colon = block.indexOf(":", valStart);
  if (colon == -1)
    return "";

  // Check if the value is a text string (starts with quotes ")
  int startQuote = block.indexOf("\"", colon);
  if (startQuote != -1 && startQuote < colon + 5) {
    // It is a string, so grab everything between the two quotes
    int endQuote = block.indexOf("\"", startQuote + 1);
    return block.substring(startQuote + 1, endQuote);
  } else {
    // It might be a true/false boolean or a number (no quotes)
    // Grab everything up to the next comma or closing bracket }
    int comma = block.indexOf(",", colon);
    int brace = block.indexOf("}", colon);
    int end = (comma != -1 && comma < brace) ? comma : brace;
    String val = block.substring(colon + 1, end);
    val.trim(); // Remove extra spaces
    return val;
  }
}

// Function to download ALL parking data from Firebase in one single fast swoop
String getAllSpotsJSON() {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    // By adding .json to the main URL, Firebase gives us the entire database
    // tree at once
    String url = DATABASE_URL + "/parking_spots.json";
    http.begin(url);
    int httpCode = http.GET();

    if (httpCode > 0) {
      String payload = http.getString(); // Save the downloaded text
      http.end();
      return payload; // Give it back to the main loop
    }
    http.end();
  }
  return ""; // Return empty if failed
}

// Function that decides what to do for a specific parking spot based on its
// sensor and Firebase data
void updateSpotLogic(int spotId, bool physicallyOccupied, int buzzerPin,
                     String fullJson) {
  if (fullJson == "")
    return; // If we didn't receive data from Firebase, don't do anything

  // Find the current database status for *this specific spot* (e.g.,
  // "available", "booked", "occupied")
  String spotKey = "spot_" + String(spotId);
  String currentStatus = extractValue(fullJson, spotKey, "status");

  // Check if the user pressed the "Confirm Departure" button in the app
  String authStr = extractValue(fullJson, spotKey, "is_authorizing_exit");
  bool isAuthorizingExit = (authStr == "true");

  // We only talk to Firebase if we need to CHANGE something. This saves battery
  // and bandwidth.
  HTTPClient http;
  String url = DATABASE_URL + "/parking_spots/spot_" + String(spotId) + ".json";

  // SCENARIO 1: The spot is already marked as 'stolen' or 'unknown'
  if (currentStatus == "stolen") {
    playAlarm(buzzerPin, ALARM_STOLEN); // Play the loud siren
    return;
  } else if (currentStatus == "unknown" && physicallyOccupied) {
    playAlarm(buzzerPin, ALARM_UNKNOWN); // Play the warning beeps
    return;
  }

  // SCENARIO 2: The Ultrasonic Sensor DETECTS a vehicle
  if (physicallyOccupied) {
    if (currentStatus == "available") {
      // Car parked without a booking!
      Serial.println("UNAUTHORIZED!");
      playAlarm(buzzerPin, ALARM_UNKNOWN);     // Sound the warning alarm
      http.begin(url);                         // Connect to Firebase
      http.PATCH("{\"status\": \"unknown\"}"); // Tell the app this spot is
                                               // illegally occupied
      http.end();
    } else if (currentStatus == "booked") {
      // A car arrived at a booked spot. Now the admin needs to verify their
      // license plate.
      String verif = extractValue(fullJson, spotKey, "verification_needed");

      // If we haven't already asked for verification, do it now
      if (verif != "true") {
        Serial.println("Verifying Booking...");
        http.begin(url);
        http.PATCH(
            "{\"verification_needed\": true}"); // Ping the admin app to verify
        http.end();
      }
    }
  }

  // SCENARIO 3: The Ultrasonic Sensor does NOT detect a vehicle (Spot is empty)
  else {
    if (currentStatus == "occupied") {
      // A car just left a legally occupied spot. Was it authorized?
      if (isAuthorizingExit) {
        // Yes! They clicked "Leave" in the app.
        Serial.println("Auth Exit!");
        http.begin(url);
        // Reset the spot completely so someone else can book it
        http.PATCH("{\"status\": \"available\", \"is_authorizing_exit\": "
                   "false, \"verification_needed\": false, \"reservedBy\": "
                   "null, \"reservationTime\": null}");
        http.end();
      } else {
        // No! They just drove off without paying/confirming!
        Serial.println("THEFT!");
        playAlarm(buzzerPin, ALARM_STOLEN); // Sound the loud siren
        http.begin(url);
        http.PATCH("{\"status\": \"stolen\"}"); // Alert the admin app
        http.end();
      }
    } else if (currentStatus == "unknown" || currentStatus == "stolen") {
      // If the illegal car finally leaves, or the stolen car is gone, reset the
      // spot back to normal
      http.begin(url);
      http.PATCH("{\"status\": \"available\", \"verification_needed\": false}");
      http.end();
    }
  }
}

// The loop() function runs over and over again infinitely, as fast as the ESP32
// can process it
void loop() {
  // If we just got a password from Bluetooth, go connect to Wi-Fi
  if (shouldConnectWiFi) {
    shouldConnectWiFi = false;
    connectToWiFi();
  }

  // If we are still waiting for the Admin to send the Wi-Fi password, do
  // nothing else.
  if (isProvisioning) {
    delay(100);
    return;
  }

  int availableCount = 0; // Keep track of how many spots are physically empty

  // 1. FETCH ALL DATA FROM CLOUD
  // We grab the entire parking lot's data in one request so we don't have to
  // talk to Firebase 5 separate times.
  String fullJson = getAllSpotsJSON();

  // Robustness check: Did our internet drop?
  if (fullJson == "") {
    Serial.println("Fetch Error (WiFi/DB). Retrying...");

    // If Wi-Fi is actually disconnected, try to reconnect
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("WiFi Disconnected! Reconnecting...");
      WiFi.disconnect();
      WiFi.reconnect();

      // Wait for it to reconnect
      int attempts = 0;
      while (WiFi.status() != WL_CONNECTED && attempts < 20) {
        delay(100);
        attempts++;
      }
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("Reconnected!");
        lcd.setCursor(0, 1);
        lcd.print("Online & Active");
      }
    }
    delay(500); // Wait half a second before trying the loop again
    return;
  }

  // 2. PROCESS ALL 5 SENSORS
  // Now we calculate distances and check rules for every single parking spot
  for (int i = 0; i < 5; i++) {
    // Get the distance in cm from the sensor
    long dist = getDistance(spots[i].trigPin, spots[i].echoPin);

    // We assume a car is there if the distance is between 1cm and 9cm
    bool isRawOccupied = (dist > 0 && dist < 10);

    // DEBOUNCE LOGIC (Double checking to prevent false alarms)
    // Sometimes bugs fly in front of the sensor. We only agree a car LEFT
    // if the sensor says it's empty 5 times in a row.
    if (isRawOccupied) {
      spots[i].emptyCount = 0;    // Reset the counter
      spots[i].isOccupied = true; // Definitely a car there
    } else {
      spots[i].emptyCount++; // Add 1 to "empty" counter
      if (spots[i].emptyCount >= 5) {
        spots[i].isOccupied =
            false; // It's been empty 5 times, so it's truly empty
      }
    }

    // Run the main rulebook logic for this specific spot
    updateSpotLogic(spots[i].id, spots[i].isOccupied, spots[i].buzzerPin,
                    fullJson);

    // If this spot is empty, add 1 to our total count of free spots
    if (!spots[i].isOccupied)
      availableCount++;

    // Wait a tiny fraction of a second before checking the next sensor
    // so their sound waves don't crash into each other
    delay(10);
  }

  // 3. UPDATE THE PHYSICAL LCD SCREEN
  lcd.setCursor(0, 0);
  lcd.print("UPTM Smart Park "); // Top row
  lcd.setCursor(0, 1);
  lcd.print("Free: ");       // Bottom row
  lcd.print(availableCount); // Show the number of free spots
  lcd.print("/5   ");        // Show out of 5 total spots
}