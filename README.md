# Smart Car BLE Access App

A Flutter application for controlling and authenticating smart car access over Bluetooth Low Energy (BLE). The app connects to the vehicle BLE controller, monitors RSSI signal strength, performs an AES-based challenge-response authentication flow, and sends an in-car presence message after successful authentication.

## Key Features

- Scans for and connects to the vehicle BLE device using `flutter_blue_plus`.
- Displays the current BLE RSSI on the Home screen.
- Smooths the displayed RSSI value to reduce noisy UI updates while keeping authentication checks based on measured signal conditions.
- Allows authentication only when the BLE signal is strong and stable enough.
- Sends the authentication start packet `00 01 02 03` to the MCU after RSSI requirements are met.
- Encrypts the 16-byte MCU challenge with AES-128 ECB and sends the encrypted response back over BLE.
- Locks the authentication button after a PASS result to prevent repeated authentication attempts in the same session.
- Automatically retries authentication every 2 seconds when RSSI is not ready yet.
- Sends `USER_IN_CAR` only after authentication has passed and the RSSI indicates that the user is inside or very close to the vehicle.
- Keeps monitoring RSSI after PASS, so `USER_IN_CAR` can still be sent later if the user approaches the vehicle gradually.
- Shows a top-screen notification when `USER_IN_CAR` is sent, making MCU-side debugging easier.
- Stores authentication history with timestamp, result, RSSI, and packet-related details.
- Keeps security details and access initialization data in the Settings screen.
- Supports Vietnamese and English UI language switching from Settings.

## RSSI Notes

BLE RSSI is measured in dBm and is usually negative. A value closer to `0` means a stronger signal.

Examples:

- `-45 dBm` is stronger than `-60 dBm`.
- `-60 dBm` is stronger than `-75 dBm`.
- A condition such as `rssi >= -63` accepts `-50`, but rejects `-70`.

Current thresholds:

| Purpose | Constant | Value |
| --- | --- | --- |
| Minimum RSSI for authentication | `BleController.authMinimumRssi` | `-63 dBm` |
| Minimum RSSI for in-car detection | `BleController.userInsideCarMinimumRssi` | `-52 dBm` |
| Required stable RSSI samples | `BleController.rssiStableSampleCount` | `3` |

## Authentication Flow

1. The user opens the app and connects to the vehicle BLE device.
2. The app reads RSSI after the BLE connection is established.
3. When RSSI is strong and stable enough, the app sends `00 01 02 03` to start the challenge-response sequence.
4. The MCU returns a 16-byte challenge.
5. The app encrypts the challenge using AES-128 ECB.
6. The encrypted response is sent back to the MCU.
7. The MCU returns a PASS or FAIL result.
8. If the result is PASS:
   - The authentication button is disabled.
   - The authentication history is updated.
   - The app continues monitoring RSSI for in-car detection.
9. When authentication has passed and RSSI reaches the in-car threshold, the app sends `USER_IN_CAR` once for the current connection session.
10. The app displays a top-screen notification confirming that `USER_IN_CAR` was sent to the MCU.

## Important BLE Packets

| Packet | Content | Source File |
| --- | --- | --- |
| Authentication start | `00 01 02 03` | `lib/services/crypto_service.dart` |
| In-car presence message | ASCII `USER_IN_CAR` | `lib/services/crypto_service.dart` |
| Authentication handling | Challenge-response, PASS/FAIL, `USER_IN_CAR` | `lib/services/bluetooth/bluetooth_auth.dart` |

`USER_IN_CAR` is sent only after PASS. The app does not send this packet just because the phone is close to the vehicle before authentication succeeds.

## Project Structure

```text
lib/
  main.dart
  localization/
    app_localizations.dart
  models/
    auth_history_entry.dart
  screens/
    home_screen.dart
    history_screen.dart
    settings_screen.dart
    home/
      home_auth.dart
      home_connection.dart
      home_lifecycle.dart
      home_build.dart
      home_state_access.dart
  services/
    bluetooth_service.dart
    background_service.dart
    crypto_service.dart
    bluetooth/
      bluetooth_auth.dart
      bluetooth_connection.dart
      bluetooth_write.dart
      bluetooth_notify.dart
      bluetooth_disconnect.dart
  widgets/
    home/
      aes_info_card.dart
      ble_rssi_badge.dart
      access_flow_visual.dart
      car_status_circle.dart
```

## Key Modules

- `lib/services/bluetooth_service.dart`: Central BLE controller state, RSSI thresholds, connection state, and notification streams.
- `lib/services/bluetooth/bluetooth_connection.dart`: BLE connection handling, RSSI reads, watchdog behavior, and session reset on disconnect.
- `lib/services/bluetooth/bluetooth_auth.dart`: Authentication start packet, challenge-response handling, PASS/FAIL processing, and `USER_IN_CAR` sending.
- `lib/services/crypto_service.dart`: AES key configuration, authentication start packet, and `USER_IN_CAR` packet definition.
- `lib/services/background_service.dart`: Background BLE service entry points. This feature is currently disabled with `backgroundBleServiceEnabled => false` because it is not stable enough yet.
- `lib/screens/home/home_auth.dart`: Manual authentication, RSSI-not-ready retry logic, and Home screen authentication state updates.
- `lib/screens/home/home_lifecycle.dart`: Stream subscriptions, lifecycle cleanup, and top-screen `USER_IN_CAR` notification display.
- `lib/screens/history_screen.dart`: Authentication audit history with timestamp, result, RSSI, and packet details.
- `lib/screens/settings_screen.dart`: Language selection and security/access configuration details.
- `lib/widgets/home/access_flow_visual.dart`: User-facing access flow visualization: locked vehicle, unlocked vehicle, and user inside the vehicle.

## Getting Started

Install dependencies:

```bash
flutter pub get
```

Run static analysis:

```bash
flutter analyze
```

Run the app:

```bash
flutter run
```

## Development Notes

- Background BLE execution is intentionally disabled for now. To revisit it, check `backgroundBleServiceEnabled` in `lib/services/background_service.dart`.
- RSSI thresholds are centralized in `BleController` and should be tuned with real vehicle-side testing.
- The AES key is currently stored in the app to match the thesis/debug firmware setup. A production system should use a stronger key management strategy.
- When debugging the MCU start buffer, first confirm that the app reaches the BLE write path by checking logs such as `AUTH APP -> CAR start` and `APP -> CAR raw: 00 01 02 03`.
