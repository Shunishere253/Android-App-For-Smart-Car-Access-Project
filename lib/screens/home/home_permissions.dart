part of '../home_screen.dart';

// ============================================================
// Luồng kiểm tra hệ thống khi app khởi động:
//
//  checkSystemOnLaunch()
//    └─ checkAndRequestPermissions()   [service layer]
//         ├─ PERMISSION_DENIED            → dialog xin quyền
//         ├─ PERMISSION_PERMANENTLY_DENIED → dialog mở Settings
//         ├─ BLUETOOTH_OFF               → dialog bật Bluetooth ngay (như Grab)
//         ├─ LOCATION_SERVICE_OFF        → dialog bật GPS ngay
//         ├─ BG_LOCATION_DENIED          → dialog mở Settings location
//         └─ OK                          → connectToCar()
// ============================================================

mixin _HomePermissions on State<HomeScreen>, _HomeStateAccess {
  @override
  Future<void> checkSystemOnLaunch() async {
    if (!mounted) return;

    setState(() {
      statusText = AppLocalizations.t("checkingSystem");
      statusColor = Colors.grey;
    });

    final String status = await BleController.checkAndRequestPermissions();

    if (!mounted) return;

    switch (status) {
      case "OK":
        setState(() {
          isSystemReady = true;
          statusText = AppLocalizations.t("systemReady");
          statusColor = Colors.grey;
        });

        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          if (!isConnected && !isScanning) {
            connectToCar();
          }
        });

      case "BLUETOOTH_OFF":
        // Hiện dialog bật Bluetooth ngay (như Grab, ShopeeFood)
        // FlutterBluePlus.turnOn() sẽ hiện system dialog của Android
        _showEnableBluetoothDialog();

      case "LOCATION_SERVICE_OFF":
        // Hiện dialog bật GPS ngay dùng system intent
        _showEnableGpsDialog();

      case "BG_LOCATION_DENIED":
        setState(() {
          isSystemReady = false;
          statusText = AppLocalizations.t("bgLocationRequired");
          statusColor = Colors.orangeAccent;
        });
        _showSettingsDialog(
          icon: Icons.location_on,
          iconColor: Colors.orangeAccent,
          title: AppLocalizations.t("bgLocationRequired"),
          message: AppLocalizations.t("bgLocationSettingsPrompt"),
          settingType: AppSettingsType.settings,
          retryOnBack: true,
        );

      case "PERMISSION_PERMANENTLY_DENIED":
        setState(() {
          isSystemReady = false;
          statusText = AppLocalizations.t("permissionsPermanentlyDenied");
          statusColor = Colors.redAccent;
        });
        _showSettingsDialog(
          icon: Icons.security,
          iconColor: Colors.redAccent,
          title: AppLocalizations.t("permissionsPermanentlyDeniedTitle"),
          message: AppLocalizations.t("permissionsPermanentlyDeniedMessage"),
          settingType: AppSettingsType.settings,
          retryOnBack: true,
        );

      default: // PERMISSION_DENIED
        setState(() {
          isSystemReady = false;
          statusText = AppLocalizations.t("permissionsMissing");
          statusColor = Colors.redAccent;
        });
        _showSettingsDialog(
          icon: Icons.security,
          iconColor: Colors.redAccent,
          title: AppLocalizations.t("missingAccessRights"),
          message: AppLocalizations.t("permissionsPrompt"),
          settingType: AppSettingsType.settings,
          retryOnBack: true,
        );
    }
  }

  // ──────────────────────────────────────────────────────────────
  // Dialog bật Bluetooth ngay (hiện system dialog của Android)
  // Giống Grab / ShopeeFood: bấm "BẬT NGAY" → system popup → OK là bật
  // ──────────────────────────────────────────────────────────────
  void _showEnableBluetoothDialog() {
    if (!mounted) return;

    setState(() {
      isSystemReady = false;
      statusText = AppLocalizations.t("bluetoothOffTitle");
      statusColor = Colors.redAccent;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _SystemRequestDialog(
          icon: Icons.bluetooth_disabled,
          iconColor: Colors.blueAccent,
          title: AppLocalizations.t("bluetoothOffTitle"),
          message: AppLocalizations.t("bluetoothEnablePrompt"),
          primaryLabel: AppLocalizations.t("enableBluetoothBtn"),
          primaryColor: Colors.blueAccent,
          secondaryLabel: AppLocalizations.t("openSettingsBtn"),
          onPrimary: () async {
            Navigator.pop(ctx);

            // Hiện system dialog bật Bluetooth (giống Grab)
            setState(() {
              statusText = AppLocalizations.t("turningOnBluetooth");
              statusColor = Colors.blueAccent;
            });

            final enabled = await BleController.tryEnableBluetoothDirectly();

            if (!mounted) return;

            if (enabled) {
              // Bluetooth đã bật → tiếp tục kiểm tra
              await checkSystemOnLaunch();
            } else {
              // User từ chối → hướng vào Settings
              _showSettingsDialog(
                icon: Icons.bluetooth_disabled,
                iconColor: Colors.redAccent,
                title: AppLocalizations.t("bluetoothStillOff"),
                message: AppLocalizations.t("bluetoothSettingsPrompt"),
                settingType: AppSettingsType.bluetooth,
                retryOnBack: true,
              );
            }
          },
          onSecondary: () {
            Navigator.pop(ctx);
            AppSettings.openAppSettings(type: AppSettingsType.bluetooth);
            // Khi user quay lại app → didChangeAppLifecycleState sẽ trigger checkSystem
            _scheduleCheckOnResume();
          },
          onRetry: () {
            Navigator.pop(ctx);
            checkSystemOnLaunch();
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Dialog bật GPS ngay
  // Android không cho phép bật GPS tự động, nhưng có thể mở system
  // location dialog thông qua intent → user bấm OK là bật luôn
  // ──────────────────────────────────────────────────────────────
  void _showEnableGpsDialog() {
    if (!mounted) return;

    setState(() {
      isSystemReady = false;
      statusText = AppLocalizations.t("gpsOffTitle");
      statusColor = Colors.orangeAccent;
    });

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _SystemRequestDialog(
          icon: Icons.location_off,
          iconColor: Colors.orangeAccent,
          title: AppLocalizations.t("gpsOffTitle"),
          message: AppLocalizations.t("gpsEnablePrompt"),
          primaryLabel: AppLocalizations.t("enableGpsBtn"),
          primaryColor: Colors.orangeAccent,
          secondaryLabel: AppLocalizations.t("openSettingsBtn"),
          onPrimary: () async {
            Navigator.pop(ctx);

            final enabled = await BleController.tryEnableLocationDirectly();

            if (!mounted) return;

            if (enabled) {
              // GPS đã bật → tiếp tục kiểm tra
              await checkSystemOnLaunch();
            } else {
              // Mở system settings location nếu không bật được trực tiếp
              await AppSettings.openAppSettings(type: AppSettingsType.location);
              if (!mounted) return;
              _scheduleCheckOnResume();
            }
          },
          onSecondary: () {
            Navigator.pop(ctx);
            AppSettings.openAppSettings(type: AppSettingsType.location);
            _scheduleCheckOnResume();
          },
          onRetry: () {
            Navigator.pop(ctx);
            checkSystemOnLaunch();
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────────
  // Dialog mở Settings (fallback khi không bật được trực tiếp)
  // ──────────────────────────────────────────────────────────────
  void _showSettingsDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required AppSettingsType settingType,
    bool retryOnBack = false,
  }) {
    if (!mounted) return;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return _SystemRequestDialog(
          icon: icon,
          iconColor: iconColor,
          title: title,
          message: message,
          primaryLabel: AppLocalizations.t("openSettingsBtn"),
          primaryColor: Colors.orangeAccent,
          secondaryLabel: AppLocalizations.t("retryBtn"),
          onPrimary: () {
            Navigator.pop(ctx);
            AppSettings.openAppSettings(type: settingType);
            if (retryOnBack) _scheduleCheckOnResume();
          },
          onSecondary: () {
            Navigator.pop(ctx);
            checkSystemOnLaunch();
          },
          onRetry: null,
        );
      },
    );
  }

  // Lên lịch kiểm tra lại khi app resume (user quay lại từ Settings)
  void _scheduleCheckOnResume() {
    // Đặt isSystemReady = false để didChangeAppLifecycleState (resumed)
    // sẽ tự động gọi checkSystemOnLaunch() khi user quay lại app.
    if (mounted) {
      setState(() {
        isSystemReady = false;
        statusText = AppLocalizations.t("returnToAppToContinue");
        statusColor = Colors.orangeAccent;
      });
    }
  }
}

// ================================================================
// Widget dialog dùng chung cho tất cả các loại request hệ thống
// Giao diện như Grab/ShopeeFood: icon lớn ở giữa, 2 nút hành động
// ================================================================
class _SystemRequestDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String primaryLabel;
  final Color primaryColor;
  final String secondaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final VoidCallback? onRetry;

  const _SystemRequestDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.primaryColor,
    required this.secondaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: ThemeManager.cardColor.withAlpha(250),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: iconColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: iconColor.withValues(alpha: 0.18),
              blurRadius: 28,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.4),
                    width: 2,
                  ),
                ),
                child: Icon(icon, color: iconColor, size: 36),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ThemeManager.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 10),

              // Message
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ThemeManager.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Primary button (action)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPrimary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.black87,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    primaryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Secondary button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onSecondary,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ThemeManager.textSecondary,
                    side: BorderSide(
                      color: ThemeManager.borderColor,
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    secondaryLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),

              // Retry button (optional)
              if (onRetry != null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: onRetry,
                  child: Text(
                    "Kiểm tra lại",
                    style: TextStyle(
                      color: ThemeManager.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}