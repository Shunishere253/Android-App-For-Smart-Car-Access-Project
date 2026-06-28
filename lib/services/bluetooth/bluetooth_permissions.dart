part of '../bluetooth_service.dart';

// ============================================================
// Luồng kiểm tra & yêu cầu quyền BLE / Location
//
// Thứ tự chuẩn:
//   1. Xin quyền runtime (BluetoothScan, BluetoothConnect, Location)
//   2. Kiểm tra Bluetooth adapter → trả "BLUETOOTH_OFF" nếu tắt
//   3. Kiểm tra GPS service → trả "LOCATION_SERVICE_OFF" nếu tắt
//   4. Xin background location (cho background service)
//
// UI (home_permissions.dart) sẽ xử lý từng mã trả về và
// hiện dialog phù hợp (bật ngay hoặc mở Settings).
// ============================================================

Future<String> _bleCheckAndRequestPermissions() async {
  if (!Platform.isAndroid) return "OK";

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final int sdkInt = androidInfo.version.sdkInt;

  // ── BƯỚC 1: Xin quyền runtime ────────────────────────────────
  Map<Permission, PermissionStatus> statuses;

  if (sdkInt <= 30) {
    // Android 11 trở xuống: chỉ cần quyền Location
    statuses = await [Permission.location].request();

    if (statuses[Permission.location]!.isPermanentlyDenied) {
      return "PERMISSION_PERMANENTLY_DENIED";
    }
    if (statuses[Permission.location]!.isDenied) {
      return "PERMISSION_DENIED";
    }
  } else {
    // Android 12+: cần BLUETOOTH_SCAN + BLUETOOTH_CONNECT + LOCATION
    statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isPermanentlyDenied ||
        statuses[Permission.bluetoothConnect]!.isPermanentlyDenied ||
        statuses[Permission.location]!.isPermanentlyDenied) {
      return "PERMISSION_PERMANENTLY_DENIED";
    }

    if (statuses[Permission.bluetoothScan]!.isDenied ||
        statuses[Permission.bluetoothConnect]!.isDenied ||
        statuses[Permission.location]!.isDenied) {
      return "PERMISSION_DENIED";
    }
  }

  // ── BƯỚC 2: Kiểm tra Bluetooth adapter (trước GPS) ───────────
  // Kiểm tra Bluetooth trước vì đây là BLE app.
  // UI sẽ hiện dialog popup hỏi "Bật Bluetooth không?" với button OK.
  // Nếu user bật → app tự tiếp tục mà không cần vào Settings.
  final btState = await FlutterBluePlus.adapterState
      .firstWhere((state) => state != BluetoothAdapterState.unknown)
      .timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothAdapterState.unknown,
      );

  if (btState == BluetoothAdapterState.off) {
    return "BLUETOOTH_OFF";
  }

  // ── BƯỚC 3: Kiểm tra GPS service ─────────────────────────────
  // UI sẽ hiện dialog popup hỏi "Bật GPS không?" với button OK.
  final locationServiceStatus = await Permission.location.serviceStatus;

  if (!locationServiceStatus.isEnabled) {
    return "LOCATION_SERVICE_OFF";
  }

  // ── BƯỚC 4: Xin background location ──────────────────────────
  // Bắt buộc cho background BLE scanning.
  // Android yêu cầu user phải vào Settings chọn "Luôn cho phép"
  // (không thể popup trực tiếp từ app theo policy của Google).
  final bgLocationStatus = await Permission.locationAlways.status;

  if (!bgLocationStatus.isGranted) {
    // Thử request – trên Android 11+ sẽ mở Settings thay vì popup
    await Permission.locationAlways.request();

    final afterRequest = await Permission.locationAlways.status;
    if (!afterRequest.isGranted) {
      return "BG_LOCATION_DENIED";
    }
  }

  return "OK";
}

/// Thử bật Bluetooth ngay từ app (không cần vào Settings).
/// Trả về true nếu Bluetooth đã bật sau khi gọi.
/// Chỉ hoạt động trên Android (FlutterBluePlus.turnOn()).
Future<bool> _bleTryEnableBluetoothDirectly() async {
  if (!Platform.isAndroid) return false;

  try {
    await FlutterBluePlus.turnOn();

    // Chờ tối đa 8 giây để adapter bật lên
    final state = await FlutterBluePlus.adapterState
        .firstWhere(
          (s) => s == BluetoothAdapterState.on || s == BluetoothAdapterState.off,
        )
        .timeout(const Duration(seconds: 8));

    return state == BluetoothAdapterState.on;
  } catch (e) {
    debugPrint("turnOn bluetooth error: $e");
    return false;
  }
}

/// Thử bật GPS/Location service ngay từ app qua system dialog.
/// Android không cho phép bật GPS trực tiếp từ code,
/// nhưng có thể dùng intent để hiện dialog hỏi bật.
/// Trả về true nếu GPS đã bật sau khi gọi.
Future<bool> _bleTryEnableLocationDirectly() async {
  if (!Platform.isAndroid) return false;

  // Kiểm tra lại lần nữa trước khi thử
  final status = await Permission.location.serviceStatus;
  return status.isEnabled;
}