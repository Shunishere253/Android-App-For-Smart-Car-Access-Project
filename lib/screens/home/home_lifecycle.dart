part of '../home_screen.dart';

mixin _HomeLifecycle
    on State<HomeScreen>, WidgetsBindingObserver, _HomeStateAccess {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    if (backgroundBleServiceEnabled) {
      // App đang foreground thì background service không được xử lý kết nối xe.
      pauseBackgroundBleService();
    } else {
      unawaited(stopBackgroundServiceIfRunning());
    }

    uartSub = BleController.uartTextStream.listen((msg) {
      if (!mounted) return;

      setState(() {
        uartLastMessage = msg.trim().isEmpty ? "[DỮ LIỆU BẢO MẬT]" : msg.trim();
      });
    });

    rssiSub = BleController.rssiStream.listen((rssi) {
      if (!mounted) return;

      setState(() {
        bleRssi = rssi;

        if (isConnected && isWaitingForCarSignal && !isAuthenticating) {
          statusText =
              "Đã kết nối, chờ sóng BLE đủ mạnh để xác thực (${rssi ?? '--'} dBm)";
          statusColor = Colors.orangeAccent;
        }
      });

      tryRunAutoAuthWhenSignalReady();
    });

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
            }
          });

          _showUserInsideCarTopNotification();
        });

    bleConnectionSub = BleController.connectionStateStream.listen((connected) {
      if (!mounted) return;

      if (connected) {
        return;
      }

      setState(() {
        isConnected = false;
        isScanning = false;
        isAuthenticating = false;
        isAutoReconnectAttempting = false;
        isAccessAuthenticated = false;
        isWaitingForCarSignal = false;
        authRetryTimer?.cancel();
        authRetryTimer = null;

        statusText = "Đang tìm xe...";
        statusColor = Colors.orangeAccent;

        aesResult = "Đã ngắt kết nối";
        aesResultColor = Colors.redAccent;

        plaintextHex = "-";
        cipherHex = "-";
        uartLastMessage = "-";
        bleRssi = null;
      });

      scheduleAutoReconnect();

      Future.delayed(const Duration(seconds: 5), () {
        if (!mounted) return;

        if (!isConnected && !isScanning && !isAuthenticating) {
          setState(() {
            statusText = "Mất kết nối với xe";
            statusColor = Colors.redAccent;
          });
        }
      });
    });

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

          statusText = "Bluetooth đã tắt, không thể kết nối với xe";
          statusColor = Colors.redAccent;

          aesResult = "Đã ngắt kết nối";
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
          statusText = "Bluetooth đã bật, đang kết nối lại với xe...";
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
    if (!backgroundBleServiceEnabled) return;

    if (state == AppLifecycleState.resumed) {
      pauseBackgroundBleService();
      debugPrint("APP foreground -> pause background BLE");
      return;
    }

    // Chỉ resume khi app thật sự xuống nền.
    // Không dùng inactive vì inactive có thể xảy ra tạm thời khi app vẫn đang mở.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      resumeBackgroundBleService();
      debugPrint("APP background -> resume background BLE");
    }
  }
}
