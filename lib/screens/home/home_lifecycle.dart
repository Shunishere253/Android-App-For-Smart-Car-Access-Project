part of '../home_screen.dart';

mixin _HomeLifecycle
    on State<HomeScreen>, WidgetsBindingObserver, _HomeStateAccess {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    statusText = AppLocalizations.t("checkingSystem");
    aesResult = AppLocalizations.t("notAuthenticated");

    // ── Background service setup ──────────────────────────────
    if (backgroundBleServiceEnabled) {
      // Foreground lên → pause background, đặt flag ownership
      pauseBackgroundBleService();
      unawaited(StorageService.setForegroundOwnership(true));
    } else {
      unawaited(stopBackgroundServiceIfRunning());
    }

    // ── Load lịch sử từ storage ───────────────────────────────
    StorageService.loadHistory().then((saved) {
      if (!mounted || saved.isEmpty) return;
      setState(() {
        history.addAll(saved);
      });
    });

    // ── UART stream ───────────────────────────────────────────
    uartSub = BleController.uartTextStream.listen((msg) {
      if (!mounted) return;

      setState(() {
        uartLastMessage =
            msg.trim().isEmpty ? AppLocalizations.t("secureData") : msg.trim();
      });
    });

    // ── RSSI stream ───────────────────────────────────────────
    rssiSub = BleController.rssiStream.listen((rssi) {
      if (!mounted) return;

      setState(() {
        bleRssi = rssi;

        if (isConnected && isWaitingForCarSignal && !isAuthenticating) {
          statusText = AppLocalizations.t("connectedWaitSignal")
              .replaceAll("{rssi}", "${rssi ?? '--'}");
          statusColor = Colors.orangeAccent;
        }
      });

      // Kiểm tra mô phỏng rời khỏi xe
      if (isAccessAuthenticated && rssi != null && rssi <= -75) {
        debugPrint("Auto-disconnecting due to RSSI ($rssi) <= -75, cooldown 20s");
        setState(() {
          isAccessAuthenticated = false;
          // Đặt cooldown 20 giây — autoReconnect sẽ bỏ qua trong khoảng này
          rssiAutoDisconnectCooldownUntil = DateTime.now().add(const Duration(seconds: 20));
        });
        BleController.disconnect();
      }

      tryRunAutoAuthWhenSignalReady();
    });

    // ── User inside car stream ────────────────────────────────
    userInsideCarNotificationSub = BleController.userInsideCarNotificationStream
        .listen((sent) {
          if (!mounted || !sent) return;

          setState(() {
            final historyIndex = history.indexWhere(
              (entry) => entry.isPass && !entry.userInsideCarNotified,
            );

            if (historyIndex != -1) {
              final entry = history[historyIndex];

              history[historyIndex] = entry.copyWith(
                rssi: BleController.currentRssi,
                userInsideCarNotified: true,
              );

              // Save cập nhật vào storage
              unawaited(StorageService.saveHistory(history));
            }
          });

          // Thông báo overlay trong app
          _showUserInsideCarTopNotification();

          // Thông báo hệ thống
          unawaited(NotificationService.showInsideCar());
        });

    // ── BLE connection stream ─────────────────────────────────
    bleConnectionSub = BleController.connectionStateStream.listen((connected) {
      if (!mounted) return;

      if (connected) {
        // Thông báo hệ thống: đã kết nối
        unawaited(NotificationService.showConnected());
        return;
      }

      // Disconnected
      setState(() {
        isConnected = false;
        isScanning = false;
        isAuthenticating = false;
        isAutoReconnectAttempting = false;
        isAccessAuthenticated = false;
        isWaitingForCarSignal = false;
        authRetryTimer?.cancel();
        authRetryTimer = null;

        statusText = AppLocalizations.t("findingCar");
        statusColor = Colors.orangeAccent;

        aesResult = AppLocalizations.t("disconnected");
        aesResultColor = Colors.redAccent;

        plaintextHex = "-";
        cipherHex = "-";
        uartLastMessage = "-";
        bleRssi = null;
      });

      scheduleAutoReconnect();

      // Thông báo hệ thống: đã ngắt kết nối
      unawaited(NotificationService.showDisconnected());

      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;

        if (!isConnected && !isScanning && !isAuthenticating) {
          setState(() {
            statusText = AppLocalizations.t("lostConnection");
            statusColor = Colors.redAccent;
          });
        }
      });
    });

    // ── Bluetooth adapter state stream ────────────────────────
    btStateSub = FlutterBluePlus.adapterState.listen((state) async {
      if (!mounted) return;

      if (state == BluetoothAdapterState.off) {
        await BleController.disconnect();

        if (!mounted) return;

        setState(() {
          isConnected = false;
          isScanning = false;
          isAuthenticating = false;
          isAccessAuthenticated = false;
          isWaitingForCarSignal = false;
          authRetryTimer?.cancel();
          authRetryTimer = null;

          statusText = AppLocalizations.t("bluetoothOffCannotConnect");
          statusColor = Colors.redAccent;

          aesResult = AppLocalizations.t("disconnected");
          aesResultColor = Colors.redAccent;

          challengeHex = "-";
          plaintextHex = "-";
          cipherHex = "-";
          uartLastMessage = "-";
          bleRssi = null;
        });

        return;
      }

      if (state == BluetoothAdapterState.on) {
        if (!isSystemReady) return;
        if (isConnected || isScanning || isAutoReconnectScheduled) return;

        isAutoReconnectScheduled = true;

        setState(() {
          statusText = AppLocalizations.t("bluetoothOnReconnecting");
          statusColor = Colors.orangeAccent;
        });

        Future.delayed(const Duration(milliseconds: 500), () {
          isAutoReconnectScheduled = false;

          if (!mounted) return;

          if (!isConnected && !isScanning && isSystemReady) {
            connectToCar();
          }
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkSystemOnLaunch();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    autoReconnectTimer?.cancel();
    authRetryTimer?.cancel();
    uartSub?.cancel();
    bleConnectionSub?.cancel();
    rssiSub?.cancel();
    userInsideCarNotificationSub?.cancel();
    btStateSub?.cancel();

    super.dispose();
  }

  void _showUserInsideCarTopNotification() {
    final overlay = Overlay.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: topPadding + 14,
          left: 18,
          right: 18,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10351F),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.greenAccent.withValues(alpha: 0.9),
                  width: 1.4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.greenAccent,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      AppLocalizations.t("insideCarPacketSent"),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (backgroundBleServiceEnabled) {
        // ── App lên foreground (background mode) ─────────────
        pauseBackgroundBleService();
        unawaited(StorageService.setForegroundOwnership(true));
        debugPrint("APP foreground → pause BG, fg_owns_ble=true");
      }

      // Kiểm tra lại hệ thống nếu chưa ready (từ Settings quay lại)
      if (!isSystemReady) {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) checkSystemOnLaunch();
        });
        debugPrint("APP foreground → re-check system (was not ready)");
        return;
      }

      // Đã ready nhưng chưa kết nối → reconnect
      if (!isConnected && !isScanning) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && !isConnected && !isScanning) {
            connectToCar();
          }
        });
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (backgroundBleServiceEnabled) {
        // ── App xuống nền (background mode) ──────────────────
        stopAutoReconnect();
        authRetryTimer?.cancel();
        authRetryTimer = null;
        unawaited(StorageService.setForegroundOwnership(false));
        resumeBackgroundBleService();
        debugPrint("APP background → resume BG, fg_owns_ble=false");
      }
    }
  }
}
