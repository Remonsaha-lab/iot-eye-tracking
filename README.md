# Eye Movement Detection Flutter App

A Flutter application that uses the device's camera and Google ML Kit to detect eye movements and send commands to an ESP32 over Bluetooth.

## Features

- Real-time eye movement detection
- Detects looking up, looking down, and blinking
- Double-blink detection for "selection" actions
- Bluetooth connectivity to an ESP32 for motor control
- Simple, clean UI

## How It Works

1. The app uses the front-facing camera to detect your face
2. Google ML Kit's face detection API is used to track eye positions and blinking
3. When looking up, the app sends a command to rotate a motor connected to the ESP32 counterclockwise
4. When looking down, the app sends a command to rotate the motor clockwise
5. Double-blinking "selects" the current position and sends a confirmation command to the ESP32

## Setting Up the ESP32

The ESP32 needs to be programmed to:
1. Advertise itself via Bluetooth
2. Accept connections
3. Receive and parse commands in the format:
   - "ANGLE:X" (where X is an angle value)
   - "SELECT" (to confirm a selection)
4. Control a motor based on these commands

Example Arduino code for the ESP32 would look something like:

```cpp
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Servo.h>

// BLE service and characteristic UUIDs
#define SERVICE_UUID        "0000180a-0000-1000-8000-00805f9b34fb"
#define CHARACTERISTIC_UUID "00002a56-0000-1000-8000-00805f9b34fb"

// Servo setup
Servo myServo;
const int servoPin = 13;  // GPIO pin connected to servo
int currentAngle = 90;    // Starting angle

BLEServer* pServer = NULL;
BLECharacteristic* pCharacteristic = NULL;
bool deviceConnected = false;

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string value = pCharacteristic->getValue();
      
      if (value.length() > 0) {
        String command = String(value.c_str());
        Serial.print("Received: ");
        Serial.println(command);
        
        // Process ANGLE command
        if (command.startsWith("ANGLE:")) {
          int angle = command.substring(6).toInt();
          currentAngle = angle;
          myServo.write(map(currentAngle, -180, 180, 0, 180));  // Map from -180:180 to 0:180
        }
        // Process SELECT command
        else if (command.equals("SELECT")) {
          // Blink onboard LED to indicate selection
          digitalWrite(LED_BUILTIN, HIGH);
          delay(200);
          digitalWrite(LED_BUILTIN, LOW);
          // Save current position or take other action
        }
      }
    }
};

void setup() {
  Serial.begin(115200);
  
  // Initialize servo
  myServo.attach(servoPin);
  myServo.write(90);  // Set to middle position
  
  pinMode(LED_BUILTIN, OUTPUT);
  
  // Create the BLE Device
  BLEDevice::init("ESP32-EyeControl");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pCharacteristic = pService->createCharacteristic(
                      CHARACTERISTIC_UUID,
                      BLECharacteristic::PROPERTY_READ   |
                      BLECharacteristic::PROPERTY_WRITE  |
                      BLECharacteristic::PROPERTY_NOTIFY |
                      BLECharacteristic::PROPERTY_INDICATE
                    );

  pCharacteristic->setCallbacks(new MyCallbacks());
  
  // Start the service
  pService->start();

  // Start advertising
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setScanResponse(true);
  pAdvertising->setMinPreferred(0x06);  // helps with iPhone connections issue
  pAdvertising->setMinPreferred(0x12);
  BLEDevice::startAdvertising();
  
  Serial.println("BLE server ready. Waiting for connections...");
}

void loop() {
  // Put your main code here, to run repeatedly:
  delay(2000);
}
```

## Getting Started

1. Clone this repository
2. Install dependencies: `flutter pub get`
3. Connect a device and run: `flutter run`
4. Allow camera and Bluetooth permissions when prompted
5. Press "Scan for ESP32" to find your ESP32 device
6. Connect to the ESP32, then start controlling with your eyes! 