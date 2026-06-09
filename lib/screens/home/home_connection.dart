part of '../home_screen.dart';

mixin _HomeConnection on State<HomeScreen>, _HomeStateAccess {
  Future<void> _startBackgroundServiceOnce() async {
    if (!backgroundBleServiceEnabled) {
      unawaited(stopBackgroundServiceIfRunning());
      return;
    }

    if (backgroundStarted) {
      pauseBackgroundBleService();
      return;
    }

    try {
      await initializeBackgroundService();
      backgroundStarted = true;

      // Service đã start, nhưng app đang foreground nên background phải đứng yên.
      pauseBackgroundBleService();

      debugPrint(
        "Background service started, BLE paused because app is foreground",
      );
    } catch (e) {
      debugPrint("Start background service error: $e");
    }
  }

  @override
  Future<void> connectToCar({bool isAutoReconnect = false}) async {
    if (!isSystemReady) {
      await checkSystemOnLaunch();
      return;
    }

    if (!isAutoReconnect) {
      stopAutoReconnect();
    }

    pauseBackgroundBleService();

    if (isAutoReconnect) {
      isAutoReconnectAttempting = true;

      // Auto reconnect chạy ngầm.
      // KHÔNG set isScanning = true.
      // KHÔNG đổi statusText ở đây.
      // UI sẽ giữ "Mất kết nối với xe" cho tới khi kết nối thật sự thành công.
    } else {
      setState(() {
        isScanning = true;
        isConnected = false;
        isAuthenticating = false;
        isAccessAuthenticated = false;
        isWaitingForCarSignal = false;
        authRetryTimer?.cancel();
        authRetryTimer = null;
        bleRssi = null;

        statusText = "Đang kết nối với xe...";
        statusColor = Colors.orangeAccent;

        challengeHex = "-";
        plaintextHex = "-";
        cipherHex = "-";
        aesResult = "Chưa xác thực";
        aesResultColor = Colors.grey;
        uartLastMessage = "-";
      });
    }

    BleController.scanAndConnect(
      onStatus: (s) {
        if (!mounted) return;

        // QUAN TRỌNG:
        // Auto reconnect không được cập nhật UI bằng onStatus,
        // vì onStatus có thể báo "Đã tìm thấy xe" nhưng connect vẫn fail.
        // Chỉ khi onResult(device != null) mới đổi UI.
        if (isAutoReconnect) {
          return;
        }

        setState(() {
          statusText = mapUserFriendlyStatus(s);
          statusColor = Colors.orangeAccent;
        });
      },
      onResult: (device) {
        if (!mounted) return;

        isAutoReconnectAttempting = false;

        if (device != null) {
          setState(() {
            isScanning = false;
            isConnected = true;
            bleRssi = BleController.currentRssi;
            isWaitingForCarSignal = true;
            isAccessAuthenticated = false;

            statusText =
                "Đã kết nối, chờ sóng BLE đủ mạnh để xác thực (${bleRssi ?? '--'} dBm)";
            statusColor = Colors.orangeAccent;
            aesResult = "Chờ RSSI >= ${BleController.authMinimumRssi} dBm";
            aesResultColor = Colors.orangeAccent;
          });

          Future.delayed(const Duration(milliseconds: 250), () {
            if (!mounted) return;

            tryRunAutoAuthWhenSignalReady();
          });

          return;
        }

        if (isAutoReconnect) {
          // Auto reconnect thất bại thì giữ nguyên UI hiện tại.
          // Không đổi sang "Đang tìm xe", không đổi sang "Đang thiết lập...".
          // Timer reconnect vẫn chạy tiếp.
          return;
        }

        setState(() {
          isScanning = false;
          isConnected = false;
          isAccessAuthenticated = false;
          isWaitingForCarSignal = false;
          authRetryTimer?.cancel();
          authRetryTimer = null;
          bleRssi = null;

          statusText = "Không tìm thấy xe";
          statusColor = Colors.redAccent;
        });

        scheduleAutoReconnect();
      },
    );
  }

  @override
  String mapUserFriendlyStatus(String rawStatus) {
    final s = rawStatus.toLowerCase();

    if (s.contains("không tìm thấy")) {
      return "Không tìm thấy xe";
    }

    if (s.contains("không thể") || s.contains("fail") || s.contains("lỗi")) {
      return "Không thể kết nối với xe";
    }

    if (s.contains("đã tìm thấy")) {
      return "Đã tìm thấy xe, đang thiết lập kết nối...";
    }

    if (s.contains("bảo mật")) {
      return "Đang chuẩn bị kết nối bảo mật...";
    }

    if (s.contains("notify") ||
        s.contains("subscribe") ||
        s.contains("uart") ||
        s.contains("ffe1") ||
        s.contains("giao tiếp")) {
      return "Đang mở kênh giao tiếp với xe...";
    }

    if (s.contains("sẵn sàng") || s.contains("ready")) {
      return "Kết nối với xe đã sẵn sàng";
    }

    if (s.contains("đang bật")) {
      return "Đang chuẩn bị kết nối...";
    }

    if (s.contains("tìm") ||
        s.contains("scan") ||
        s.contains("quét") ||
        s.contains("search") ||
        s.contains("đang kết nối")) {
      return "Đang tìm xe...";
    }

    if (s.contains("connect") || s.contains("kết nối")) {
      return "Đang thiết lập kết nối với xe...";
    }

    return rawStatus;
  }

  @override
  void scheduleAutoReconnect() {
    if (autoReconnectTimer?.isActive == true) return;

    autoReconnectTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (!isSystemReady) return;

      if (FlutterBluePlus.adapterStateNow != BluetoothAdapterState.on) {
        return;
      }

      // Chỉ dừng auto reconnect khi đã kết nối thật.
      if (isConnected) {
        timer.cancel();
        autoReconnectTimer = null;
        return;
      }

      // Nếu đang scan thủ công, đang auth, hoặc đang có 1 lượt scan ngầm
      // thì chờ vòng sau. Không cancel timer.
      if (isScanning || isAuthenticating || isAutoReconnectAttempting) {
        return;
      }

      connectToCar(isAutoReconnect: true);
    });
  }

  @override
  void stopAutoReconnect() {
    autoReconnectTimer?.cancel();
    autoReconnectTimer = null;
    isAutoReconnectAttempting = false;
  }

  Future<void> startBackgroundServiceOnceForAuth() async {
    await _startBackgroundServiceOnce();
  }
}
