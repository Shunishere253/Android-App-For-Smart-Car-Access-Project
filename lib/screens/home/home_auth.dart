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
        SnackBar(
          content: Text(AppLocalizations.t("pleaseConnectFirst")),
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
        aesResult = AppLocalizations.t("waitingForRssi")
            .replaceAll("{rssi}", "${BleController.authMinimumRssi}");
        aesResultColor = Colors.orangeAccent;
        statusText = AppLocalizations.t("connectedWaitSignal")
            .replaceAll("{rssi}", "${currentRssi ?? '--'}");
        statusColor = Colors.orangeAccent;
      });

      if (!autoRun) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.t("rssiTooLowForAuth")
                  .replaceAll("{current}", "${currentRssi ?? '--'}")
                  .replaceAll("{min}", "${BleController.authMinimumRssi}"),
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
          ? AppLocalizations.t("authenticatingAccess")
          : AppLocalizations.t("reAuthenticating");
      aesResultColor = Colors.orangeAccent;

      challengeHex = CryptoService.fixedChallengeAsHexString;
      plaintextHex = AppLocalizations.t("waitingForCarResponse");
      cipherHex = "-";

      statusText = AppLocalizations.t("authenticatingAccess");
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

        aesResult = result.isPass ? AppLocalizations.t("authSuccessAes128") : AppLocalizations.t("authFailAes128");
        aesResultColor = result.isPass ? Colors.greenAccent : Colors.redAccent;
        isAuthenticating = false;
        isAccessAuthenticated = result.isPass;

        statusText = result.isPass
            ? AppLocalizations.t("authSuccessFull")
            : AppLocalizations.t("authFailFull");
        statusColor = result.isPass ? Colors.greenAccent : Colors.redAccent;
      });

      // ── Thêm vào lịch sử ─────────────────────────────────────
      final newEntry = AuthHistoryEntry(
        authenticatedAt: DateTime.now(),
        challengeHex: challengeHex,
        plaintextHex: plaintextHex,
        cipherHex: cipherHex,
        mcuResult: result.mcuResult,
        rssi: result.rssi,
        userInsideCarNotified: result.userInsideCarNotified,
      );

      setState(() {
        history.insert(0, newEntry);
      });

      // Lưu lịch sử vào storage
      unawaited(StorageService.saveHistory(history));

      // ── Thông báo hệ thống ────────────────────────────────────
      if (result.isPass) {
        unawaited(NotificationService.showAuthSuccess());

        // Đặt cooldown cho background service
        unawaited(StorageService.setAuthCooldown());
      }

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

      setState(() {
        aesResult = AppLocalizations.t("authError").replaceAll("{error}", e.toString());
        aesResultColor = Colors.redAccent;
        isAuthenticating = false;
        isAccessAuthenticated = false;
        isWaitingForCarSignal = false;

        statusText = AppLocalizations.t("authFailed");
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
