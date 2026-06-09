part of '../bluetooth_service.dart';

Future<AesAuthResult> _bleRunAesAuthentication() async {
  if (BleController._authInProgress) {
    throw Exception("Đang xác thực quyền truy cập");
  }

  final now = DateTime.now();

  if (BleController._lastAuthStartTime != null &&
      now.difference(BleController._lastAuthStartTime!).inMilliseconds < 500) {
    throw Exception("Vừa xác thực xong, vui lòng thử lại sau");
  }

  BleController._lastAuthStartTime = now;
  BleController._authInProgress = true;

  StreamSubscription<List<int>>? authSub;

  try {
    if (BleController.connectedDevice == null) {
      throw Exception("Chưa kết nối với xe");
    }

    final state = await BleController.connectedDevice!.connectionState.first;

    if (state != BluetoothConnectionState.connected) {
      BleController._connectionStateController.add(false);
      throw Exception("Xe đã mất kết nối");
    }

    if (BleController._writeChar == null || BleController._notifyChar == null) {
      await _bleDiscoverCharacteristics(BleController.connectedDevice!);
      await _bleStartNotifyListener();
    }

    final authRssi = await _bleWaitForMinimumRssi(
      BleController.authMinimumRssi,
    );
    int resultRssi = authRssi;
    bool userInsideCarNotified = false;

    final List<int> appStartCommand = CryptoService.fixedChallenge;
    final completer = Completer<AesAuthResult>();

    final List<int> localRawBuffer = [];
    String localAsciiBuffer = "";

    List<int>? plaintextBytes;
    List<int>? cipherBytes;

    bool startCommandSent = false;
    bool resultHandling = false;

    authSub = BleController.rawRxStream.listen((data) async {
      final rawHex = CryptoService.bytesToHex(
        data,
        withSpace: true,
        withPrefix: false,
      );

      final ascii = _bleTryDecodeAscii(data);
      final asciiUpper = ascii.toUpperCase().trim();

      debugPrint("AUTH RX raw  : $rawHex");
      debugPrint("AUTH RX ascii: $ascii");

      try {
        if (!startCommandSent) {
          debugPrint("AUTH: bỏ qua packet trước start command");
          return;
        }

        if (plaintextBytes == null) {
          if (_bleIsStatusText(asciiUpper)) {
            debugPrint("AUTH: bỏ qua status text trước dữ liệu xác thực");
            localRawBuffer.clear();
            return;
          }

          localRawBuffer.addAll(data);

          final parsed = _bleParsePlaintextFlexible(localRawBuffer);

          if (parsed == null) {
            debugPrint(
              "AUTH: chưa đủ dữ liệu xác thực "
              "(buffer=${localRawBuffer.length} byte)",
            );
            return;
          }

          plaintextBytes = parsed;
          cipherBytes = CryptoService.encryptECB(plaintextBytes!);

          debugPrint(
            "AUTH plaintext: ${CryptoService.bytesToHex(plaintextBytes!, withSpace: false, withPrefix: true)}",
          );

          debugPrint(
            "AUTH cipher   : ${CryptoService.bytesToHex(cipherBytes!, withSpace: false, withPrefix: true)}",
          );

          await _bleWriteBytes(cipherBytes!);
          return;
        }

        localAsciiBuffer += ascii;
        final upper = localAsciiBuffer.toUpperCase();

        if (upper.contains("PASS") || upper.contains("FAIL")) {
          if (resultHandling || completer.isCompleted) {
            return;
          }

          resultHandling = true;

          final isPass = upper.contains("PASS");
          final resultText = isPass ? "PASS!" : "FAIL!";

          if (isPass) {
            BleController._accessAuthenticated = true;

            try {
              final latestRssi = await _bleRefreshConnectedRssi(
                checkUserInsideCar: false,
              );

              if (latestRssi != null) {
                resultRssi = latestRssi;
              }
            } catch (e) {
              debugPrint("AUTH refresh RSSI after PASS warning: $e");
            }

            userInsideCarNotified = await _bleSendUserInsideCarIfEligible(
              rssi: resultRssi,
            );
          } else {
            BleController._accessAuthenticated = false;
          }

          if (!completer.isCompleted) {
            completer.complete(
              AesAuthResult(
                challenge: appStartCommand,
                plaintext: plaintextBytes!,
                ciphertext: cipherBytes!,
                mcuResult: resultText,
                rssi: resultRssi,
                userInsideCarNotified: userInsideCarNotified,
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

    localRawBuffer.clear();
    localAsciiBuffer = "";

    // Notify đã bật ở bước connect; chỉ chờ rất ngắn để ổn định descriptor.
    await Future.delayed(const Duration(milliseconds: 100));

    debugPrint(
      "AUTH APP -> CAR start: ${CryptoService.bytesToHex(appStartCommand, withSpace: true, withPrefix: false)}",
    );

    startCommandSent = true;

    // Gửi raw 4 byte: 00 01 02 03
    await _bleWriteBytes(appStartCommand);

    return await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw Exception(
          "Xe không phản hồi xác thực trong 5 giây "
          "(buffer=${localRawBuffer.length} byte)",
        );
      },
    );
  } finally {
    await authSub?.cancel();
    BleController._authInProgress = false;
  }
}

Future<bool> _bleSendUserInsideCarIfEligible({int? rssi}) async {
  if (!BleController._accessAuthenticated ||
      BleController._userInsideCarNotificationSent ||
      BleController._userInsideCarNotificationInProgress) {
    return false;
  }

  final currentRssi = rssi ?? BleController.currentRssi;

  if (!BleController.isUserInsideCarRssi(currentRssi)) {
    return false;
  }

  BleController._userInsideCarNotificationInProgress = true;

  try {
    debugPrint(
      "AUTH APP -> CAR user inside: ${CryptoService.bytesToHex(CryptoService.userInsideCarCommand, withSpace: true, withPrefix: false)}",
    );

    await _bleWriteBytes(CryptoService.userInsideCarCommand);
    BleController._userInsideCarNotificationSent = true;
    BleController._emitUserInsideCarNotification();
    await Future.delayed(const Duration(milliseconds: 120));
    return true;
  } catch (e) {
    debugPrint("AUTH user inside notification warning: $e");
    return false;
  } finally {
    BleController._userInsideCarNotificationInProgress = false;
  }
}
