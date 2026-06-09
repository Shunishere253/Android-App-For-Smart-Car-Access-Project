import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

import 'crypto_service.dart';

part 'bluetooth/bluetooth_permissions.dart';
part 'bluetooth/bluetooth_connection.dart';
part 'bluetooth/bluetooth_characteristics.dart';
part 'bluetooth/bluetooth_notify.dart';
part 'bluetooth/bluetooth_write.dart';
part 'bluetooth/bluetooth_auth.dart';
part 'bluetooth/bluetooth_disconnect.dart';
part 'bluetooth/bluetooth_recovery.dart';
part 'bluetooth/bluetooth_helpers.dart';

class AesAuthResult {
  final List<int> challenge;
  final List<int> plaintext;
  final List<int> ciphertext;
  final String mcuResult;
  final int? rssi;
  final bool userInsideCarNotified;

  AesAuthResult({
    required this.challenge,
    required this.plaintext,
    required this.ciphertext,
    required this.mcuResult,
    required this.rssi,
    required this.userInsideCarNotified,
  });

  bool get isPass => mcuResult.toUpperCase().contains("PASS");
}

class AuthRssiNotReadyException implements Exception {
  final int? currentRssi;
  final int minimumRssi;
  final int stableSampleCount;

  const AuthRssiNotReadyException({
    required this.currentRssi,
    required this.minimumRssi,
    required this.stableSampleCount,
  });

  @override
  String toString() {
    return "RSSI BLE chưa đủ mạnh và ổn định để xác thực "
        "(hiện tại ${currentRssi == null ? '--' : '$currentRssi'} dBm, "
        "yêu cầu >= $minimumRssi dBm trong $stableSampleCount lần đo liên tiếp)";
  }
}

class BleController {
  static BluetoothDevice? connectedDevice;

  static BluetoothCharacteristic? _writeChar;
  static BluetoothCharacteristic? _notifyChar;

  static Timer? _connectionWatchdogTimer;

  static StreamSubscription<List<int>>? _notifySubscription;
  static StreamSubscription<BluetoothConnectionState>? _connectionSub;

  static DateTime? _lastAuthStartTime;
  static bool _authInProgress = false;
  static bool _accessAuthenticated = false;
  static bool _userInsideCarNotificationSent = false;
  static bool _userInsideCarNotificationInProgress = false;
  static int? _currentRssi;
  static int? _latestRawRssi;
  static int? _lastEmittedRssi;
  static double? _smoothedRssi;

  static const int authMinimumRssi = -63;
  static const int userInsideCarMinimumRssi = -52;
  static const int rssiStableSampleCount = 3;
  static const int _rssiUiDeadbandDb = 1;
  static const double _rssiSmoothingAlpha = 0.3;

  static final StreamController<String> _uartTextController =
      StreamController<String>.broadcast();

  static Stream<String> get uartTextStream => _uartTextController.stream;

  static final StreamController<List<int>> _rawRxController =
      StreamController<List<int>>.broadcast();

  static Stream<List<int>> get rawRxStream => _rawRxController.stream;

  static final StreamController<bool> _connectionStateController =
      StreamController<bool>.broadcast();

  static Stream<bool> get connectionStateStream =>
      _connectionStateController.stream;

  static final StreamController<int?> _rssiController =
      StreamController<int?>.broadcast();

  static Stream<int?> get rssiStream => _rssiController.stream;

  static final StreamController<bool> _userInsideCarNotificationController =
      StreamController<bool>.broadcast();

  static Stream<bool> get userInsideCarNotificationStream =>
      _userInsideCarNotificationController.stream;

  static int? get currentRssi => _currentRssi;

  static int? get latestRawRssi => _latestRawRssi;

  static bool canAuthenticateWithRssi(int? rssi) {
    return rssi != null && rssi >= authMinimumRssi;
  }

  static bool isUserInsideCarRssi(int? rssi) {
    return rssi != null && rssi >= userInsideCarMinimumRssi;
  }

  static void _emitRssi(int? rssi) {
    if (rssi == null) {
      if (_currentRssi == null && _lastEmittedRssi == null) return;

      _resetRssiFilter(clearCurrent: true);
      _rssiController.add(null);
      return;
    }

    _latestRawRssi = rssi;
    _smoothedRssi = _smoothedRssi == null
        ? rssi.toDouble()
        : (_smoothedRssi! * (1 - _rssiSmoothingAlpha)) +
              (rssi * _rssiSmoothingAlpha);

    final displayRssi = _smoothedRssi!.round();
    _currentRssi = displayRssi;

    final lastEmittedRssi = _lastEmittedRssi;

    if (lastEmittedRssi != null &&
        (displayRssi - lastEmittedRssi).abs() < _rssiUiDeadbandDb &&
        !_crossedRssiThreshold(lastEmittedRssi, displayRssi)) {
      return;
    }

    _lastEmittedRssi = displayRssi;
    _rssiController.add(displayRssi);
  }

  static void _resetRssiFilter({required bool clearCurrent}) {
    _latestRawRssi = null;
    _smoothedRssi = null;

    if (clearCurrent) {
      _currentRssi = null;
      _lastEmittedRssi = null;
    }
  }

  static bool _crossedRssiThreshold(int previousRssi, int currentRssi) {
    return _crossedThreshold(previousRssi, currentRssi, authMinimumRssi) ||
        _crossedThreshold(previousRssi, currentRssi, userInsideCarMinimumRssi);
  }

  static bool _crossedThreshold(
    int previousRssi,
    int currentRssi,
    int threshold,
  ) {
    return (previousRssi < threshold && currentRssi >= threshold) ||
        (previousRssi >= threshold && currentRssi < threshold);
  }

  static void _emitUserInsideCarNotification() {
    _userInsideCarNotificationController.add(true);
  }

  static Future<String> checkAndRequestPermissions() {
    return _bleCheckAndRequestPermissions();
  }

  static Future<void> scanAndConnect({
    required Function(String) onStatus,
    required Function(BluetoothDevice?) onResult,
  }) {
    return _bleScanAndConnect(onStatus: onStatus, onResult: onResult);
  }

  static Future<void> writeBytes(List<int> data) {
    return _bleWriteBytes(data);
  }

  static Future<AesAuthResult> runAesAuthentication() {
    return _bleRunAesAuthentication();
  }

  static Future<void> disconnect({bool silent = false}) {
    return _bleDisconnect(silent: silent);
  }

  static Future<int?> refreshRssi() {
    return _bleRefreshConnectedRssi();
  }

  static Future<void> releaseMcuVerifyState() {
    return _bleReleaseMcuVerifyState();
  }
}
