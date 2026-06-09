part of '../home_screen.dart';

mixin _HomeAuth on State<HomeScreen>, _HomeStateAccess {
  @override
  void tryRunAutoAuthWhenSignalReady() {
    if (!mounted) return;
    if (!isConnected ||
        !isWaitingForCarSignal ||
        isAuthenticating ||
        isAccessAuthenticated) {
      return;
    }

    final currentRssi = bleRssi ?? BleController.currentRssi;

    if (!BleController.canAuthenticateWithRssi(currentRssi)) {
      return;
    }

    isWaitingForCarSignal = false;
    unawaited(runAesHandshake(autoRun: true));
  }

  @override
  Future<void> runAesHandshake({bool autoRun = false}) async {
    if (isAccessAuthenticated) {
      return;
    }

    if (!isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Vui lòng kết nối xe trước"),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (isAuthenticating) return;

    pauseBackgroundBleService();

    int? currentRssi = bleRssi ?? BleController.currentRssi;

    try {
      currentRssi = await BleController.refreshRssi();
    } catch (e) {
      debugPrint("Refresh RSSI before auth warning: $e");
    }

    if (!BleController.canAuthenticateWithRssi(currentRssi)) {
      if (!mounted) return;

      setState(() {
        isWaitingForCarSignal = true;
        aesResult = "Chờ RSSI >= ${BleController.authMinimumRssi} dBm";
        aesResultColor = Colors.orangeAccent;
        statusText =
            "Đã kết nối, chờ sóng BLE đủ mạnh để xác thực (${currentRssi ?? '--'} dBm)";
        statusColor = Colors.orangeAccent;
      });

      if (!autoRun) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "RSSI hiện tại ${currentRssi ?? '--'} dBm, cần >= ${BleController.authMinimumRssi} dBm để xác thực",
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }

      _scheduleAuthRetry();
      return;
    }

    _stopAuthRetry();

    setState(() {
      isAuthenticating = true;
      isWaitingForCarSignal = false;
      aesResult = autoRun
          ? "Đang xác thực quyền truy cập..."
          : "Đang xác thực lại quyền truy cập...";
      aesResultColor = Colors.orangeAccent;

      challengeHex = CryptoService.fixedChallengeAsHexString;
      plaintextHex = "Đang chờ phản hồi từ xe...";
      cipherHex = "-";

      statusText = "Đang xác thực quyền truy cập...";
      statusColor = Colors.orangeAccent;
    });

    try {
      final result = await BleController.runAesAuthentication();

      if (!mounted) return;

      final newChallengeHex = CryptoService.bytesToHex(
        result.challenge,
        withSpace: false,
        withPrefix: true,
      );

      final newPlaintextHex = CryptoService.bytesToHex(
        result.plaintext,
        withSpace: false,
        withPrefix: true,
      );

      final newCipherHex = CryptoService.bytesToHex(
        result.ciphertext,
        withSpace: false,
        withPrefix: true,
      );

      setState(() {
        challengeHex = newChallengeHex;
        plaintextHex = newPlaintextHex;
        cipherHex = newCipherHex;

        aesResult = result.isPass ? "Truy cập thành công" : "Truy cập thất bại";
        aesResultColor = result.isPass ? Colors.greenAccent : Colors.redAccent;
        isAuthenticating = false;
        isAccessAuthenticated = result.isPass;

        statusText = result.isPass
            ? "Truy cập xe thành công"
            : "Xác thực quyền truy cập thất bại";
        statusColor = result.isPass ? Colors.greenAccent : Colors.redAccent;
      });

      history.insert(
        0,
        AuthHistoryEntry(
          authenticatedAt: DateTime.now(),
          challengeHex: challengeHex,
          plaintextHex: plaintextHex,
          cipherHex: cipherHex,
          mcuResult: result.mcuResult,
          rssi: result.rssi,
          userInsideCarNotified: result.userInsideCarNotified,
        ),
      );

      if (result.isPass) {
        _stopAuthRetry();
        stopAutoReconnect();

        if (backgroundBleServiceEnabled && this is _HomeConnection) {
          await (this as _HomeConnection).startBackgroundServiceOnceForAuth();
        }
      } else {
        _stopAuthRetry();
      }
    } catch (e) {
      if (!mounted) return;

      if (e is AuthRssiNotReadyException) {
        setState(() {
          aesResult = AppLocalizations.t("authRetrying");
          aesResultColor = Colors.orangeAccent;
          isAuthenticating = false;
          isWaitingForCarSignal = true;
          statusText =
              "Đã kết nối, chờ sóng BLE đủ mạnh để xác thực (${e.currentRssi ?? '--'} dBm)";
          statusColor = Colors.orangeAccent;
        });

        _scheduleAuthRetry();
        return;
      }

      setState(() {
        aesResult = "Lỗi: $e";
        aesResultColor = Colors.redAccent;
        isAuthenticating = false;
        isAccessAuthenticated = false;
        isWaitingForCarSignal = false;

        statusText = "Không thể xác thực quyền truy cập";
        statusColor = Colors.redAccent;
      });

      _stopAuthRetry();
    }
  }

  void _scheduleAuthRetry() {
    if (!mounted || isAccessAuthenticated || !isConnected) return;
    if (authRetryTimer?.isActive == true) return;

    authRetryTimer = Timer(const Duration(seconds: 2), () {
      authRetryTimer = null;

      if (!mounted ||
          !isConnected ||
          isAccessAuthenticated ||
          isAuthenticating) {
        return;
      }

      unawaited(runAesHandshake(autoRun: true));
    });
  }

  void _stopAuthRetry() {
    authRetryTimer?.cancel();
    authRetryTimer = null;
  }
}
