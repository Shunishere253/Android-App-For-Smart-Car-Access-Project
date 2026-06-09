import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'crypto_service.dart';

bool get backgroundBleServiceEnabled => false;

Future<void> stopBackgroundServiceIfRunning() async {
  try {
    final service = FlutterBackgroundService();

    if (await service.isRunning()) {
      service.invoke('stop_service');
      debugPrint("BG: disabled, requested service stop");
    }
  } catch (e) {
    debugPrint("BG: stop disabled service warning: $e");
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

  const AndroidNotificationChannel foregroundChannel =
      AndroidNotificationChannel(
        'smart_car_key_channel',
        'Smart Car Key Service',
        description: 'Dịch vụ chạy ngầm để tự động xác thực JDY-23',
        importance: Importance.low,
      );

  const AndroidNotificationChannel autoUnlockChannel =
      AndroidNotificationChannel(
        'auto_unlock_channel',
        'Auto Unlock',
        description: 'Thông báo kết quả xác thực tự động',
        importance: Importance.high,
      );

  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.requestNotificationsPermission();

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(foregroundChannel);

  await notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(autoUnlockChannel);

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      notificationChannelId: 'smart_car_key_channel',
      initialNotificationTitle: 'Smart Key Đang Hoạt Động',
      initialNotificationContent: 'Đang chờ app xuống nền...',
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

  final notificationsPlugin = FlutterLocalNotificationsPlugin();

  bool isProcessing = false;

  // Mặc định pause để khi app vừa mở foreground, background không tự scan/auth.
  // HomeScreen sẽ gọi resume_ble khi app xuống nền.
  bool isPausedByForeground = true;

  service.on('pause_ble').listen((event) {
    isPausedByForeground = true;
    debugPrint("BG: paused by foreground");
  });

  service.on('resume_ble').listen((event) {
    isPausedByForeground = false;
    debugPrint("BG: resumed by background");
  });

  service.on('stop_service').listen((event) {
    debugPrint("BG: stop service");
    service.stopSelf();
  });

  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (isPausedByForeground) {
      debugPrint("BG: paused, skip BLE scan/auth");
      return;
    }

    if (isProcessing) {
      debugPrint("BG: đang xử lý, bỏ qua vòng này");
      return;
    }

    final btState = await FlutterBluePlus.adapterState.first;

    if (btState != BluetoothAdapterState.on) {
      debugPrint("BG: Bluetooth đang tắt");
      return;
    }

    isProcessing = true;

    try {
      final result = await _scanNearestJdy();

      if (result == null) {
        debugPrint("BG: Không tìm thấy JDY-23");
        return;
      }

      if (result.rssi <= -65) {
        debugPrint("BG: JDY-23 quá xa, RSSI=${result.rssi}");
        return;
      }

      debugPrint("BG: Tìm thấy JDY-23 gần, RSSI=${result.rssi}");

      final authResult = await _backgroundAuthenticate(result.device);

      debugPrint("BG AUTH RESULT: ${authResult.mcuResult}");

      await notificationsPlugin.show(
        authResult.isPass ? 999 : 1000,
        authResult.isPass
            ? '🔓 Xác thực JDY-23 thành công'
            : '❌ Xác thực thất bại',
        authResult.isPass
            ? 'MCU trả về PASS.'
            : 'MCU trả về ${authResult.mcuResult}',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'auto_unlock_channel',
            'Auto Unlock',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint("BG service error: $e");
    } finally {
      isProcessing = false;
    }
  });
}

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
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 3));
    await FlutterBluePlus.isScanning.where((v) => v == false).first;
    return bestResult;
  } finally {
    await sub.cancel();
  }
}

Future<_BgAuthResult> _backgroundAuthenticate(BluetoothDevice device) async {
  BluetoothCharacteristic? writeChar;
  BluetoothCharacteristic? notifyChar;

  StreamSubscription<List<int>>? notifySub;
  StreamSubscription<List<int>>? authSub;

  final rawController = StreamController<List<int>>.broadcast();

  try {
    try {
      await device.disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {}

    await device.connect(
      license: License.free,
      timeout: const Duration(seconds: 8),
    );

    try {
      await device.requestMtu(512);
    } catch (e) {
      debugPrint("BG requestMtu warning: $e");
    }

    await Future.delayed(const Duration(milliseconds: 900));

    final services = await device.discoverServices();

    BluetoothCharacteristic? fallbackWrite;
    BluetoothCharacteristic? fallbackNotify;

    for (final service in services) {
      debugPrint("BG SERVICE: ${service.uuid}");

      for (final c in service.characteristics) {
        final props = c.properties;
        final uuid = c.uuid.toString().toLowerCase();

        debugPrint(
          "BG CHAR ${c.uuid} | "
          "read=${props.read} "
          "write=${props.write} "
          "writeNoResp=${props.writeWithoutResponse} "
          "notify=${props.notify} "
          "indicate=${props.indicate}",
        );

        if (props.write || props.writeWithoutResponse) {
          fallbackWrite ??= c;
        }

        if (props.notify || props.indicate) {
          fallbackNotify ??= c;
        }

        // Theo log của bạn, JDY-23 UART là FFE1:
        // ffe1: write=true, notify=true.
        if (uuid == "ffe1") {
          if (props.write || props.writeWithoutResponse) {
            writeChar = c;
          }

          if (props.notify || props.indicate) {
            notifyChar = c;
          }
        }
      }
    }

    writeChar ??= fallbackWrite;
    notifyChar ??= fallbackNotify;

    if (writeChar == null) {
      throw Exception("BG: Không tìm thấy WRITE characteristic");
    }

    if (notifyChar == null) {
      throw Exception("BG: Không tìm thấy NOTIFY characteristic");
    }

    debugPrint("BG WRITE CHAR: ${writeChar.uuid}");
    debugPrint("BG NOTIFY CHAR: ${notifyChar.uuid}");

    notifySub = notifyChar.onValueReceived.listen((data) {
      final rawData = List<int>.from(data);
      final rawHex = CryptoService.bytesToHex(
        rawData,
        withSpace: true,
        withPrefix: false,
      );
      final ascii = _tryDecodeAscii(rawData);

      debugPrint("BG MCU -> APP raw  : $rawHex");
      debugPrint("BG MCU -> APP ascii: $ascii");

      rawController.add(rawData);
    });

    await notifyChar.setNotifyValue(true);
    await Future.delayed(const Duration(milliseconds: 1200));

    final completer = Completer<_BgAuthResult>();

    final appStartCommand = CryptoService.fixedChallenge;
    final rawBuffer = <int>[];
    String asciiBuffer = "";

    List<int>? plaintext;
    List<int>? ciphertext;

    bool startCommandSent = false;

    authSub = rawController.stream.listen((data) async {
      final ascii = _tryDecodeAscii(data);
      final asciiUpper = ascii.toUpperCase().trim();

      try {
        if (!startCommandSent) {
          debugPrint("BG AUTH: bỏ qua packet trước start command");
          return;
        }

        if (plaintext == null) {
          if (_isStatusText(asciiUpper)) {
            debugPrint("BG AUTH: bỏ qua status text trước plaintext: $ascii");
            rawBuffer.clear();
            return;
          }

          rawBuffer.addAll(data);

          if (rawBuffer.length < 16) {
            debugPrint("BG AUTH: chưa đủ plaintext (${rawBuffer.length} byte)");
            return;
          }

          plaintext = rawBuffer.sublist(0, 16);
          ciphertext = CryptoService.encryptECB(plaintext!);

          debugPrint(
            "BG plaintext: ${CryptoService.bytesToHex(plaintext!, withSpace: false, withPrefix: true)}",
          );

          debugPrint(
            "BG cipher: ${CryptoService.bytesToHex(ciphertext!, withSpace: false, withPrefix: true)}",
          );

          await _bgWriteBytes(writeChar!, ciphertext!);
          return;
        }

        asciiBuffer += ascii;
        final upper = asciiBuffer.toUpperCase();

        if (upper.contains("PASS") || upper.contains("FAIL")) {
          final resultText = upper.contains("PASS") ? "PASS!" : "FAIL!";

          if (!completer.isCompleted) {
            completer.complete(
              _BgAuthResult(
                challenge: appStartCommand,
                plaintext: plaintext!,
                ciphertext: ciphertext!,
                mcuResult: resultText,
              ),
            );
          }
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    rawBuffer.clear();
    asciiBuffer = "";
    startCommandSent = true;

    debugPrint(
      "BG APP -> MCU start: ${CryptoService.bytesToHex(appStartCommand, withSpace: true, withPrefix: false)}",
    );

    await _bgWriteBytes(writeChar, appStartCommand);

    return await completer.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw Exception("BG timeout: đã gửi 01 02 03 nhưng không nhận PASS");
      },
    );
  } finally {
    await authSub?.cancel();
    await notifySub?.cancel();

    try {
      if (notifyChar != null) {
        await notifyChar.setNotifyValue(false);
      }
    } catch (_) {}

    await rawController.close();

    try {
      await device.disconnect();
    } catch (_) {}
  }
}

Future<void> _bgWriteBytes(
  BluetoothCharacteristic writeChar,
  List<int> data,
) async {
  debugPrint(
    "BG APP -> MCU raw: ${CryptoService.bytesToHex(data, withSpace: true, withPrefix: false)}",
  );
  debugPrint("BG APP -> MCU decimal: $data");

  if (writeChar.properties.write) {
    await writeChar.write(data, withoutResponse: false);
  } else if (writeChar.properties.writeWithoutResponse) {
    await writeChar.write(data, withoutResponse: true);
  } else {
    throw Exception("BG: characteristic không hỗ trợ WRITE");
  }
}

bool _isStatusText(String asciiUpper) {
  return asciiUpper.contains("PASS") ||
      asciiUpper.contains("FAIL") ||
      asciiUpper.contains("UART") ||
      asciiUpper.contains("READY") ||
      asciiUpper.contains("BOOT") ||
      asciiUpper.contains("START") ||
      asciiUpper.contains("IN_CAR") ||
      asciiUpper.contains("USER") ||
      asciiUpper.contains("OK");
}

String _tryDecodeAscii(List<int> data) {
  try {
    return utf8.decode(data, allowMalformed: true);
  } catch (_) {
    return "";
  }
}

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
