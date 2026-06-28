import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'crypto_service.dart';

// ============================================================
// Background BLE Service
//
// Kiến trúc: BLE chỉ thuộc về 1 chủ tại một thời điểm.
//
//   App FOREGROUND → Main app sở hữu BLE, service PAUSE
//   App BACKGROUND → Service sở hữu BLE, main app timers STOP
//
// Phối hợp qua SharedPreferences key "fg_owns_ble":
//   true  = foreground app đang active
//   false = app ở background / killed
//
// Tránh xung đột BLE:
//   1. Kiểm tra fg_owns_ble trước khi scan
//   2. Kiểm tra FlutterBluePlus.connectedDevices trước khi connect
//   3. Không disconnect nếu device đang được hold bởi main app
//   4. Cooldown 60s sau mỗi lần auth thành công
// ============================================================

bool get backgroundBleServiceEnabled => false;

// ── SharedPreferences keys (đồng bộ với StorageService) ──────
const _keyFgOwns = 'fg_owns_ble';
const _keyBgCooldown = 'bg_auth_cooldown_until';

Future<void> stopBackgroundServiceIfRunning() async {
  try {
    final service = FlutterBackgroundService();

    if (await service.isRunning()) {
      service.invoke('stop_service');
      debugPrint("BG: requested service stop");
    }
  } catch (e) {
    debugPrint("BG: stop service warning: $e");
  }
}

void pauseBackgroundBleService() {
  if (!backgroundBleServiceEnabled) return;

  FlutterBackgroundService().invoke('pause_ble');
}

void resumeBackgroundBleService() {
  if (!backgroundBleServiceEnabled) return;

  FlutterBackgroundService().invoke('resume_ble');
}

Future<void> initializeBackgroundService() async {
  if (!backgroundBleServiceEnabled) {
    await stopBackgroundServiceIfRunning();
    return;
  }

  final service = FlutterBackgroundService();

  // Khởi tạo channels qua NotificationService-compatible approach
  // (phải tạo channel trước khi configure service)
  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();

  for (final channel in _allNotificationChannels) {
    await notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'smart_car_key_channel',
      initialNotificationTitle: 'Smart Key Đang Hoạt Động',
      initialNotificationContent: 'Đang chờ...',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  final isRunning = await service.isRunning();

  if (!isRunning) {
    await service.startService();
  }
}

// Tất cả notification channels (để tạo cả trong main isolate và BG isolate)
const _allNotificationChannels = [
  AndroidNotificationChannel(
    'smart_car_key_channel',
    'Smart Car Key Service',
    description: 'Dịch vụ chạy ngầm để tự động xác thực xe',
    importance: Importance.low,
  ),
  AndroidNotificationChannel(
    'car_event_channel',
    'Sự kiện xe',
    description: 'Thông báo kết nối, ngắt kết nối, vào trong xe',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'auth_success_channel',
    'Xác thực thành công',
    description: 'Thông báo khi xe cho phép truy cập',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'auth_fail_channel',
    'Xác thực thất bại',
    description: 'Thông báo khi xe từ chối truy cập',
    importance: Importance.defaultImportance,
  ),
];

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  // Khởi tạo notification trong background isolate (BẮT BUỘC)
  final notificationsPlugin = FlutterLocalNotificationsPlugin();
  await notificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  bool isProcessing = false;

  // Mặc định pause – foreground app sẽ gọi resume_ble khi xuống nền
  bool isPausedByForeground = true;

  // ── Lắng nghe lệnh từ main isolate ───────────────────────────

  service.on('pause_ble').listen((_) {
    isPausedByForeground = true;
    debugPrint("BG: paused by foreground");
  });

  service.on('resume_ble').listen((_) {
    isPausedByForeground = false;
    debugPrint("BG: resumed – will scan on next tick");
  });

  service.on('stop_service').listen((_) {
    debugPrint("BG: stopping service");
    service.stopSelf();
  });

  // ── Vòng lặp scan chính (20 giây / lần) ──────────────────────

  Timer.periodic(const Duration(seconds: 20), (timer) async {
    // Guard 1: Foreground app đang điều khiển
    if (isPausedByForeground) {
      debugPrint("BG: paused, skip");
      return;
    }

    // Guard 2: Đang xử lý vòng trước
    if (isProcessing) {
      debugPrint("BG: busy, skip");
      return;
    }

    // Guard 3: Bluetooth tắt
    final btState = await FlutterBluePlus.adapterState.first;
    if (btState != BluetoothAdapterState.on) {
      debugPrint("BG: Bluetooth off");
      return;
    }

    // Guard 4: Kiểm tra flag SharedPreferences (backup guard)
    // Tránh trường hợp pause_ble bị miss do timing
    try {
      final prefs = await SharedPreferences.getInstance();
      final fgOwns = prefs.getBool(_keyFgOwns) ?? true;
      if (fgOwns) {
        debugPrint("BG: fg_owns_ble=true, skip");
        return;
      }
    } catch (_) {}

    // Guard 5: Cooldown sau auth thành công
    try {
      final prefs = await SharedPreferences.getInstance();
      final cooldown = prefs.getInt(_keyBgCooldown) ?? 0;
      if (DateTime.now().millisecondsSinceEpoch < cooldown) {
        debugPrint("BG: in cooldown, skip");
        return;
      }
    } catch (_) {}

    // Guard 6: Có device đang connected (main app vẫn hold connection)
    // → Không cố kết nối lại để tránh xung đột BLE GATT
    final connectedDevices = FlutterBluePlus.connectedDevices;
    if (connectedDevices.isNotEmpty) {
      debugPrint("BG: device already connected by main app, skip");
      return;
    }

    isProcessing = true;

    try {
      // Scan tìm xe
      final scanResult = await _scanNearestJdy();

      if (scanResult == null) {
        debugPrint("BG: JDY-23 not found");
        return;
      }

      if (scanResult.rssi <= -65) {
        debugPrint("BG: JDY-23 too far (RSSI=${scanResult.rssi})");
        return;
      }

      debugPrint("BG: JDY-23 found, RSSI=${scanResult.rssi}");

      // Thông báo: đã kết nối
      await _bgShowNotification(
        plugin: notificationsPlugin,
        id: 901,
        channelId: 'car_event_channel',
        channelName: 'Sự kiện xe',
        title: '🔗 Đã kết nối với xe',
        body: 'Xe JDY-23 đã sẵn sàng – đang xác thực...',
        importance: Importance.high,
      );

      // Xác thực
      final authResult = await _backgroundAuthenticate(scanResult.device);
      final scanRssi = scanResult.rssi;
      debugPrint("BG AUTH: ${authResult.mcuResult}");

      if (authResult.isPass) {
        // Thông báo: xác thực thành công
        await _bgShowNotification(
          plugin: notificationsPlugin,
          id: 902,
          channelId: 'auth_success_channel',
          channelName: 'Xác thực thành công',
          title: '🔓 Xác thực thành công',
          body: 'Quyền truy cập xe đã được cấp',
          importance: Importance.high,
        );

        // Đặt cooldown 60 giây
        try {
          final prefs = await SharedPreferences.getInstance();
          final until = DateTime.now()
              .add(const Duration(seconds: 60))
              .millisecondsSinceEpoch;
          await prefs.setInt(_keyBgCooldown, until);
        } catch (_) {}

        // Kiểm tra RSSI để thông báo "vào trong xe"
        if (scanRssi >= -52) {
          await _bgShowNotification(
            plugin: notificationsPlugin,
            id: 904,
            channelId: 'car_event_channel',
            channelName: 'Sự kiện xe',
            title: '🚗 Đã vào trong xe',
            body: 'Phát hiện bạn đang ở trong xe',
            importance: Importance.high,
          );
        }
      } else {
        // Thông báo: xác thực thất bại
        await _bgShowNotification(
          plugin: notificationsPlugin,
          id: 902,
          channelId: 'auth_fail_channel',
          channelName: 'Xác thực thất bại',
          title: '❌ Xác thực thất bại',
          body: 'MCU phản hồi: ${authResult.mcuResult}',
          importance: Importance.defaultImportance,
        );
      }
    } catch (e) {
      debugPrint("BG service error: $e");
    } finally {
      isProcessing = false;
    }
  });
}

// ── Scan tìm JDY-23 gần nhất ─────────────────────────────────

Future<ScanResult?> _scanNearestJdy() async {
  StreamSubscription<List<ScanResult>>? sub;
  ScanResult? bestResult;

  sub = FlutterBluePlus.scanResults.listen((results) {
    for (final r in results) {
      final name = r.device.platformName.toUpperCase();
      if (!name.contains("JDY")) continue;
      if (bestResult == null || r.rssi > bestResult!.rssi) {
        bestResult = r;
      }
    }
  });

  try {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    await FlutterBluePlus.isScanning.where((v) => v == false).first;
    return bestResult;
  } finally {
    await sub.cancel();
  }
}

// ── Background authentication ─────────────────────────────────
//
// FIX so với phiên bản cũ:
//   1. Không disconnect ngay nếu device đã trong connectedDevices
//   2. Thêm grace period trước khi disconnect
//   3. Xử lý exception rõ ràng hơn

Future<_BgAuthResult> _backgroundAuthenticate(BluetoothDevice device) async {
  BluetoothCharacteristic? writeChar;
  BluetoothCharacteristic? notifyChar;
  StreamSubscription<List<int>>? notifySub;
  StreamSubscription<List<int>>? authSub;
  final rawController = StreamController<List<int>>.broadcast();

  bool wasAlreadyConnected = false;

  try {
    // Kiểm tra xem device có đang connected không
    final connectionState = await device.connectionState.first.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => BluetoothConnectionState.disconnected,
    );

    wasAlreadyConnected =
        connectionState == BluetoothConnectionState.connected;

    if (!wasAlreadyConnected) {
      // Fresh connect
      try {
        await device.disconnect();
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (_) {}

      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 8),
      );
    }

    try {
      await device.requestMtu(512);
    } catch (e) {
      debugPrint("BG requestMtu warning: $e");
    }

    await Future.delayed(const Duration(milliseconds: 800));

    final services = await device.discoverServices();

    BluetoothCharacteristic? fallbackWrite;
    BluetoothCharacteristic? fallbackNotify;

    for (final svc in services) {
      for (final c in svc.characteristics) {
        final props = c.properties;
        final uuid = c.uuid.toString().toLowerCase();

        if (props.write || props.writeWithoutResponse) {
          fallbackWrite ??= c;
        }
        if (props.notify || props.indicate) {
          fallbackNotify ??= c;
        }
        if (uuid == "ffe1") {
          if (props.write || props.writeWithoutResponse) writeChar = c;
          if (props.notify || props.indicate) notifyChar = c;
        }
      }
    }

    writeChar ??= fallbackWrite;
    notifyChar ??= fallbackNotify;

    if (writeChar == null) throw Exception("BG: no WRITE characteristic");
    if (notifyChar == null) throw Exception("BG: no NOTIFY characteristic");

    notifySub = notifyChar.onValueReceived.listen((data) {
      rawController.add(List<int>.from(data));
    });

    await notifyChar.setNotifyValue(true);
    await Future.delayed(const Duration(milliseconds: 1000));

    final completer = Completer<_BgAuthResult>();
    final appStartCommand = CryptoService.fixedChallenge;
    final rawBuffer = <int>[];
    String asciiBuffer = "";
    List<int>? plaintext;
    List<int>? ciphertext;
    bool startCommandSent = false;

    authSub = rawController.stream.listen((data) async {
      final ascii = _bgTryDecodeAscii(data);
      final upper = ascii.toUpperCase().trim();

      try {
        if (!startCommandSent) return;

        if (plaintext == null) {
          if (_bgIsStatusText(upper)) {
            rawBuffer.clear();
            return;
          }
          rawBuffer.addAll(data);
          if (rawBuffer.length < 16) return;

          plaintext = rawBuffer.sublist(0, 16);
          ciphertext = CryptoService.encryptECB(plaintext!);
          await _bgWriteBytes(writeChar!, ciphertext!);
          return;
        }

        asciiBuffer += ascii;
        final upperBuf = asciiBuffer.toUpperCase();
        if (upperBuf.contains("PASS") || upperBuf.contains("FAIL")) {
          if (!completer.isCompleted) {
            completer.complete(
              _BgAuthResult(
                challenge: appStartCommand,
                plaintext: plaintext!,
                ciphertext: ciphertext!,
                mcuResult: upperBuf.contains("PASS") ? "PASS!" : "FAIL!",
              ),
            );
          }
        }
      } catch (e) {
        if (!completer.isCompleted) completer.completeError(e);
      }
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    rawBuffer.clear();
    asciiBuffer = "";
    startCommandSent = true;
    await _bgWriteBytes(writeChar, appStartCommand);

    return await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () => throw Exception("BG: auth timeout"),
    );
  } finally {
    await authSub?.cancel();
    await notifySub?.cancel();

    try {
      if (notifyChar != null) await notifyChar.setNotifyValue(false);
    } catch (_) {}

    await rawController.close();

    // Chỉ disconnect nếu BG tự connect (không disconnect connection của main app)
    if (!wasAlreadyConnected) {
      // Grace period ngắn trước khi disconnect
      await Future.delayed(const Duration(milliseconds: 500));
      try {
        await device.disconnect();
      } catch (_) {}
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────

Future<void> _bgWriteBytes(
  BluetoothCharacteristic writeChar,
  List<int> data,
) async {
  if (writeChar.properties.write) {
    await writeChar.write(data, withoutResponse: false);
  } else if (writeChar.properties.writeWithoutResponse) {
    await writeChar.write(data, withoutResponse: true);
  } else {
    throw Exception("BG: characteristic does not support WRITE");
  }
}

bool _bgIsStatusText(String upper) {
  return upper.contains("PASS") ||
      upper.contains("FAIL") ||
      upper.contains("UART") ||
      upper.contains("READY") ||
      upper.contains("BOOT") ||
      upper.contains("START") ||
      upper.contains("IN_CAR") ||
      upper.contains("USER") ||
      upper.contains("OK");
}

String _bgTryDecodeAscii(List<int> data) {
  try {
    return utf8.decode(data, allowMalformed: true);
  } catch (_) {
    return "";
  }
}

Future<void> _bgShowNotification({
  required FlutterLocalNotificationsPlugin plugin,
  required int id,
  required String channelId,
  required String channelName,
  required String title,
  required String body,
  required Importance importance,
}) async {
  try {
    await plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          importance: importance,
          priority:
              importance == Importance.high
                  ? Priority.high
                  : Priority.defaultPriority,
        ),
      ),
    );
  } catch (e) {
    debugPrint("BG notification error: $e");
  }
}

// ── Result model ──────────────────────────────────────────────

class _BgAuthResult {
  final List<int> challenge;
  final List<int> plaintext;
  final List<int> ciphertext;
  final String mcuResult;

  _BgAuthResult({
    required this.challenge,
    required this.plaintext,
    required this.ciphertext,
    required this.mcuResult,
  });

  bool get isPass => mcuResult.toUpperCase().contains("PASS");
}
