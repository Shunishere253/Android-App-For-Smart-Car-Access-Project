part of '../bluetooth_service.dart';

Future<void> _bleScanAndConnect({
  required Function(String) onStatus,
  required Function(BluetoothDevice?) onResult,
}) async {
  if (Platform.isAndroid &&
      FlutterBluePlus.adapterStateNow == BluetoothAdapterState.off) {
    try {
      onStatus("Đang chuẩn bị kết nối...");
      await FlutterBluePlus.turnOn();
      await Future.delayed(const Duration(milliseconds: 800));
    } catch (e) {
      debugPrint("turnOn warning: $e");
      onStatus("Vui lòng bật Bluetooth để kết nối với xe");
      onResult(null);
      return;
    }
  }

  StreamSubscription<List<ScanResult>>? scanSub;
  final completer = Completer<BluetoothDevice?>();

  Future<void> completeOnce(BluetoothDevice? device) async {
    if (completer.isCompleted) return;
    completer.complete(device);
  }

  try {
    BleController._emitRssi(null);
    onStatus("Đang kết nối với xe...");

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    final connectedDevices = FlutterBluePlus.connectedDevices;
    for (final device in connectedDevices) {
      final name = device.platformName.trim();
      final upperName = name.toUpperCase();

      if (_bleIsTargetCarDeviceName(upperName)) {
        debugPrint("Found car in already connected devices: ${device.remoteId}");
        await completeOnce(device);
        break;
      }
    }

    if (!completer.isCompleted) {
      try {
        // Fallback cho systemDevices (khi OS đã kết nối ngầm nhưng app chưa biết)
        final systemDevices = await FlutterBluePlus.systemDevices(const []);
        for (final device in systemDevices) {
          final name = device.platformName.trim();
          final upperName = name.toUpperCase();

          if (_bleIsTargetCarDeviceName(upperName)) {
            debugPrint("Found car in system devices: ${device.remoteId}");
            await completeOnce(device);
            break;
          }
        }
      } catch (e) {
        debugPrint("systemDevices check failed: $e");
      }
    }

    // Only start scan if we didn't find it in connected devices
    if (!completer.isCompleted) {
      scanSub = FlutterBluePlus.scanResults.listen((results) async {
        if (completer.isCompleted) return;

        for (final r in results) {
          final name = r.device.platformName.trim();
          final upperName = name.toUpperCase();

          if (!_bleIsTargetCarDeviceName(upperName)) {
            continue;
          }

          BleController._emitRssi(r.rssi);
          await completeOnce(r.device);
          return;
        }
      });

      await FlutterBluePlus.startScan(
        timeout: const Duration(milliseconds: 2500),
      );
    }

    final foundDevice = await completer.future.timeout(
      const Duration(milliseconds: 2800),
      onTimeout: () => null,
    );

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    await scanSub?.cancel();

    if (foundDevice == null) {
      onStatus(AppLocalizations.t("carNotFound"));
      onResult(null);
      return;
    }

    onStatus(AppLocalizations.t("carFoundConnecting"));

    try {
      await _bleConnectPrepareAndSubscribe(foundDevice, onStatus);
      onStatus(AppLocalizations.t("carConnectionReady"));
      onResult(foundDevice);
    } catch (e) {
      debugPrint("Connect/prepare error: $e");
      await _bleDisconnect(silent: true);
      onStatus(AppLocalizations.t("cannotConnectToCar"));
      onResult(null);
    }
  } catch (e) {
    debugPrint("scanAndConnect error: $e");

    try {
      if (FlutterBluePlus.isScanningNow) {
        await FlutterBluePlus.stopScan();
      }
    } catch (_) {}

    await scanSub?.cancel();

    onStatus("Không thể kết nối với xe");
    onResult(null);
  }
}

Future<void> _bleStartConnectionStateListener(BluetoothDevice device) async {
  await BleController._connectionSub?.cancel();

  BleController._connectionSub = device.connectionState.listen((state) async {
    debugPrint("Car connection state: $state");

    if (state == BluetoothConnectionState.connected) {
      BleController._connectionStateController.add(true);
      return;
    }

    if (state == BluetoothConnectionState.disconnected) {
      debugPrint("Car disconnected");
      await _bleHandleUnexpectedDisconnect();
    }
  });
}

Future<void> _bleConnectPrepareAndSubscribe(
  BluetoothDevice device,
  Function(String) onStatus,
) async {
  await _bleDisconnect(silent: true);

  await device.connect(
    license: License.free,
    timeout: const Duration(seconds: 6),
  );

  BleController.connectedDevice = device;
  BleController._connectionStateController.add(true);

  await _bleStartConnectionStateListener(device);

  // Rất quan trọng:
  // Sau khi Android báo connected, GATT đôi khi chưa ổn định ngay.
  // Nếu discover/notify hoặc watchdog chạy quá sớm sẽ gây fail ngẫu nhiên
  // ở lần connect đầu tiên.
  await Future.delayed(const Duration(milliseconds: 350));

  onStatus("Đang chuẩn bị kết nối bảo mật...");

  try {
    await _bleDiscoverCharacteristics(device);

    onStatus("Đang mở kênh giao tiếp với xe...");
    await _bleStartNotifyListener();
  } catch (e) {
    debugPrint("Prepare connection first attempt failed: $e");

    // Retry nhẹ 1 lần, không disconnect ngay.
    // Trường hợp thường gặp: connect đã thành công nhưng service/notify chưa sẵn.
    await Future.delayed(const Duration(milliseconds: 500));

    onStatus("Đang chuẩn bị kết nối bảo mật...");
    await _bleDiscoverCharacteristics(device);

    onStatus("Đang mở kênh giao tiếp với xe...");
    await _bleStartNotifyListener();
  }

  // Chỉ bật watchdog sau khi service + notify đã sẵn sàng.
  // Không bật watchdog ngay sau connect để tránh readRssi fail giả.
  _bleStartConnectionWatchdog(device);
}

void _bleStartConnectionWatchdog(BluetoothDevice device) {
  BleController._connectionWatchdogTimer?.cancel();

  bool isChecking = false;
  int failCount = 0;
  int stableTick = 0;

  BleController._connectionWatchdogTimer = Timer.periodic(
    const Duration(milliseconds: 700),
    (timer) async {
      if (isChecking) return;

      if (BleController.connectedDevice == null) {
        timer.cancel();
        return;
      }

      // Chờ connection ổn định trước khi readRssi.
      // Nếu kiểm tra quá sớm, Android dễ trả lỗi giả sau khi vừa connect.
      stableTick++;

      if (stableTick < 3) {
        return;
      }

      isChecking = true;

      try {
        final state = await device.connectionState.first.timeout(
          const Duration(milliseconds: 500),
        );

        if (state != BluetoothConnectionState.connected) {
          failCount++;
        } else {
          final rssi = await device.readRssi().timeout(
            const Duration(milliseconds: 700),
          );
          BleController._emitRssi(rssi);
          unawaited(_bleSendUserInsideCarIfEligible());

          failCount = 0;
        }

        if (failCount >= 3) {
          debugPrint("Connection watchdog detected lost car connection");
          await _bleHandleUnexpectedDisconnect();
        }
      } catch (e) {
        failCount++;

        debugPrint("Connection watchdog warning $failCount: $e");

        if (failCount >= 3) {
          debugPrint("Connection watchdog detected lost car connection");
          await _bleHandleUnexpectedDisconnect();
        }
      } finally {
        isChecking = false;
      }
    },
  );
}

Future<int?> _bleRefreshConnectedRssi({bool checkUserInsideCar = true}) async {
  final device = BleController.connectedDevice;

  if (device == null) {
    return BleController.currentRssi;
  }

  final state = await device.connectionState.first.timeout(
    const Duration(milliseconds: 500),
  );

  if (state != BluetoothConnectionState.connected) {
    BleController._connectionStateController.add(false);
    return BleController.currentRssi;
  }

  final rawRssi = await device.readRssi().timeout(
    const Duration(milliseconds: 700),
  );

  BleController._emitRssi(rawRssi);

  if (checkUserInsideCar) {
    unawaited(_bleSendUserInsideCarIfEligible());
  }

  return BleController.currentRssi;
}


Future<void> _bleHandleUnexpectedDisconnect() async {
  if (BleController.connectedDevice == null &&
      BleController._writeChar == null &&
      BleController._notifyChar == null) {
    return;
  }

  BleController._connectionWatchdogTimer?.cancel();
  BleController._connectionWatchdogTimer = null;

  await BleController._connectionSub?.cancel();
  BleController._connectionSub = null;

  await BleController._notifySubscription?.cancel();
  BleController._notifySubscription = null;

  try {
    await BleController.connectedDevice?.disconnect();
  } catch (_) {}

  BleController.connectedDevice = null;
  BleController._writeChar = null;
  BleController._notifyChar = null;
  BleController._authInProgress = false;
  BleController._lastAuthStartTime = null;
  BleController._accessAuthenticated = false;
  BleController._userInsideCarNotificationSent = false;
  BleController._userInsideCarNotificationInProgress = false;
  BleController._emitRssi(null);

  BleController._connectionStateController.add(false);
}
