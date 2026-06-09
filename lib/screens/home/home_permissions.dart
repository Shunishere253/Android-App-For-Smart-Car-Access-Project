part of '../home_screen.dart';

mixin _HomePermissions on State<HomeScreen>, _HomeStateAccess {
  @override
  Future<void> checkSystemOnLaunch() async {
    final String status = await BleController.checkAndRequestPermissions();

    if (!mounted) return;

    if (status == "OK") {
      setState(() {
        isSystemReady = true;
        statusText = "Hệ thống sẵn sàng";
        statusColor = Colors.grey;
      });

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;

        if (!isConnected && !isScanning) {
          connectToCar();
        }
      });
    } else {
      setState(() {
        isSystemReady = false;
        statusText = "Hệ thống chưa sẵn sàng";
        statusColor = Colors.redAccent;
      });

      if (status == "PERMISSION_PERMANENTLY_DENIED" ||
          status == "PERMISSION_DENIED") {
        _showSettingsDialog(
          "Thiếu quyền truy cập",
          "App cần quyền Vị trí và Bluetooth để tìm xe.",
          AppSettingsType.settings,
        );
      } else if (status == "BG_LOCATION_DENIED") {
        _showSettingsDialog(
          "Thiếu quyền chạy ngầm",
          "Hãy chọn 'Luôn cho phép' trong cài đặt Vị trí.",
          AppSettingsType.settings,
        );
      } else if (status == "LOCATION_SERVICE_OFF") {
        _showSettingsDialog(
          "GPS đang tắt",
          "Vui lòng bật Vị trí/GPS để tìm xe.",
          AppSettingsType.location,
        );
      } else if (status == "BLUETOOTH_OFF") {
        _showSettingsDialog(
          "Bluetooth đang tắt",
          "Vui lòng bật Bluetooth để kết nối với xe.",
          AppSettingsType.bluetooth,
        );
      }
    }
  }

  void _showSettingsDialog(
    String title,
    String message,
    AppSettingsType settingType,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: ThemeManager.cardColor,
          title: Text(
            title,
            style: TextStyle(
              color: ThemeManager.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: TextStyle(color: ThemeManager.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                AppSettings.openAppSettings(type: settingType);
              },
              child: const Text(
                "MỞ CÀI ĐẶT",
                style: TextStyle(color: Colors.orangeAccent),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                checkSystemOnLaunch();
              },
              child: Text(
                "THỬ LẠI",
                style: TextStyle(color: ThemeManager.appColor.value),
              ),
            ),
          ],
        );
      },
    );
  }
}