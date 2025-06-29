# iot-eye-tracking

A Flutter application for real-time eye movement and blink detection, communicating with an ESP32 over Bluetooth for assistive control.

## What This Project Does
- Detects face and eyes using Google ML Kit and OpenCV (native plugin)
- Tracks pupil position and blinks in real time
- Sends commands to an ESP32 via Bluetooth to control a motor
- Supports calibration and sensitive eye movement detection

## What We Did
- Implemented face and eye detection using Google ML Kit
- Added native OpenCV-based pupil tracking for robust detection
- Blink and eye movement detection logic (up, down, neutral, blinking)
- Bluetooth communication with ESP32 for motor control
- APK build and device installation
- GitHub integration for code versioning

## What Needs to be Fixed / Next Steps
- **Add a menu screen** to choose the communication mode:
  - Number mode
  - Keyword mode
  - Letter mode
- After mode selection, show the present section (current UI)
- **Update command logic:**
  - Left eye close → motor down
  - Right eye close → motor up
  - Both eyes close → stop
- Refactor and clean up command handling for reliability

## ESP32 Setup (Summary)
- ESP32 should advertise over Bluetooth and accept commands
- Commands expected:
  - Motor up, down, stop (based on eye blinks)
  - Mode selection (future)

## How to Build and Run
1. Clone this repo
2. Run `flutter pub get`
3. Build the APK: `flutter build apk --release`
4. Install on device: `adb install -r build/app/outputs/flutter-apk/app-release.apk`

---

For more details, see the code and comments in the repository.