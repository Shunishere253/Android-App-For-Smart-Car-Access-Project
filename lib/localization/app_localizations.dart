import 'package:flutter/material.dart';

import '../services/storage_service.dart';

enum AppLanguage { vi, en }

class AppLocalizations {
  static final ValueNotifier<AppLanguage> language = ValueNotifier<AppLanguage>(
    AppLanguage.vi,
  );

  // ── Persistent storage ────────────────────────────────────────

  /// Load ngôn ngữ từ SharedPreferences.
  /// Gọi trước runApp() trong main().
  static Future<void> loadFromStorage() async {
    language.value = await StorageService.loadLanguage();
    language.addListener(_onLanguageChanged);
  }

  static void _onLanguageChanged() {
    StorageService.saveLanguage(language.value);
  }

  static Locale get locale {
    return language.value == AppLanguage.vi
        ? const Locale('vi')
        : const Locale('en');
  }

  static List<Locale> get supportedLocales {
    return const [Locale('vi'), Locale('en')];
  }

  static bool get isVietnamese => language.value == AppLanguage.vi;

  static String get languageCode => isVietnamese ? "VN" : "EN";

  static void toggleLanguage() {
    language.value = isVietnamese ? AppLanguage.en : AppLanguage.vi;
  }

  static String t(String key) {
    final value = _localizedValues[key];

    if (value == null) return key;

    return isVietnamese ? value.vi : value.en;
  }

  static String dynamicText(String value) {
    if (isVietnamese) return value;

    final direct = _dynamicTranslations[value];
    if (direct != null) return direct;

    final lower = value.toLowerCase();

    if (lower.contains("chờ rssi")) {
      return value.replaceFirst("Chờ", "Waiting for");
    }

    if (lower.contains("đã kết nối") && lower.contains("chờ sóng")) {
      return value.replaceFirst(
        "Đã kết nối, chờ sóng BLE đủ mạnh để xác thực",
        "Connected, waiting for stronger BLE signal to authenticate",
      );
    }

    if (lower.contains("không thể xác thực")) {
      return "Unable to authenticate access";
    }

    if (lower.contains("truy cập xe thành công")) {
      return "Vehicle access granted";
    }

    if (lower.contains("xác thực") && lower.contains("thất bại")) {
      return "Access authentication failed";
    }

    if (lower.contains("đang xác thực")) {
      return "Authenticating access...";
    }

    if (lower.contains("kết nối")) {
      return value
          .replaceAll("Đang kết nối với xe", "Connecting to vehicle")
          .replaceAll("Kết nối với xe đã sẵn sàng", "Vehicle connection ready")
          .replaceAll("Không thể kết nối với xe", "Unable to connect vehicle")
          .replaceAll("Không tìm thấy xe", "Vehicle not found")
          .replaceAll("Mất kết nối với xe", "Vehicle connection lost");
    }

    if (lower.contains("bluetooth")) {
      return value
          .replaceAll("Bluetooth đã tắt", "Bluetooth is off")
          .replaceAll("Bluetooth đã bật", "Bluetooth is on");
    }

    return value;
  }

  static const Map<String, _LocalizedText> _localizedValues = {
    "welcomeBack": _LocalizedText("Chào mừng,", "Welcome back,"),
    "appName": _LocalizedText("SMART CAR ACCESS", "SMART CAR ACCESS"),
    "settings": _LocalizedText("Cài đặt", "Settings"),
    "settingsTitle": _LocalizedText("Cài đặt & Thông tin", "Settings & Info"),
    "history": _LocalizedText("Lịch sử", "History"),
    "authHistory": _LocalizedText("Lịch sử xác thực", "Auth History"),
    "language": _LocalizedText("Ngôn ngữ", "Language"),
    "languageSubtitle": _LocalizedText(
      "Thay đổi ngôn ngữ hiển thị của ứng dụng",
      "Change the display language for the app",
    ),
    "vietnamese": _LocalizedText("Tiếng Việt", "Vietnamese"),
    "english": _LocalizedText("Tiếng Anh", "English"),
    "appInfo": _LocalizedText("Thông tin ứng dụng", "App Info"),
    "accentColor": _LocalizedText("Đổi màu nhấn", "Accent Color"),
    "themeMode": _LocalizedText("Chế độ giao diện", "Theme Mode"),
    "securityAes": _LocalizedText(
      "Bảo mật AES-128 ECB",
      "AES-128 ECB Security",
    ),
    "version": _LocalizedText("Phiên bản v1.0.0", "Version v1.0.0"),
    "author": _LocalizedText("Tác giả / Author:", "Author:"),
    "supporters": _LocalizedText("Hỗ trợ / Supporters:", "Supporters:"),
    "darkBlueSubtitle": _LocalizedText(
      "Nền xanh đen mặc định",
      "Default deep blue background",
    ),
    "lightSubtitle": _LocalizedText("Nền sáng dịu", "Soft light background"),
    "blackSubtitle": _LocalizedText("Nền đen sâu", "Deep black background"),
    "whiteSubtitle": _LocalizedText(
      "Nền trắng tối giản",
      "Minimal white background",
    ),
    "appSecretKey": _LocalizedText(
      "Secret Key hardcode trong app:",
      "Hardcoded secret key in app:",
    ),
    "accessStartCode": _LocalizedText(
      "Mã khởi tạo truy cập",
      "Access start code",
    ),
    "insideCarMessage": _LocalizedText(
      "Bản tin đã vào trong xe",
      "Inside-vehicle message",
    ),
    "insideCarPacketSent": _LocalizedText(
      "Đã gửi USER_IN_CAR tới MCU",
      "USER_IN_CAR sent to MCU",
    ),
    "aesNote": _LocalizedText(
      "Lưu ý: Key này phải khớp 100% với key trong firmware S32K144. Nếu app mã hóa đúng nhưng MCU trả FAIL, cần kiểm tra format gửi BLE: raw bytes hay ASCII hex.",
      "Note: This key must exactly match the key in the S32K144 firmware. If encryption is correct but the MCU returns FAIL, check the BLE payload format: raw bytes or ASCII hex.",
    ),
    "flowTitle": _LocalizedText("Luồng truy cập xe", "Vehicle Access Flow"),
    "flowClosedCar": _LocalizedText("Xe đang khóa", "Locked Vehicle"),
    "flowClosedCarSubtitle": _LocalizedText(
      "Cửa đóng, chờ điện thoại lại gần",
      "Door closed, waiting for phone proximity",
    ),
    "carNotFound": _LocalizedText(
      "Không tìm thấy xe",
      "Vehicle not found",
    ),
    "carFoundConnecting": _LocalizedText(
      "Đã tìm thấy xe, đang thiết lập kết nối...",
      "Vehicle found, establishing connection...",
    ),
    "carConnectionReady": _LocalizedText(
      "Kết nối với xe đã sẵn sàng",
      "Connection to vehicle is ready",
    ),
    "cannotConnectToCar": _LocalizedText(
      "Không thể kết nối với xe",
      "Cannot connect to vehicle",
    ),
    "checkingSystem": _LocalizedText(
      "Đang kiểm tra hệ thống...",
      "Checking system...",
    ),
    "systemReady": _LocalizedText(
      "Hệ thống sẵn sàng",
      "System ready",
    ),
    "bluetoothOffTitle": _LocalizedText(
      "Bluetooth đang tắt",
      "Bluetooth is Off",
    ),
    "bluetoothEnablePrompt": _LocalizedText(
      "App cần Bluetooth để tìm và kết nối với xe.\nBật Bluetooth ngay bây giờ không?",
      "The app needs Bluetooth to find and connect to the vehicle.\nTurn on Bluetooth now?",
    ),
    "enableBluetoothBtn": _LocalizedText(
      "BẬT BLUETOOTH",
      "TURN ON BLUETOOTH",
    ),
    "openSettingsBtn": _LocalizedText(
      "MỞ CÀI ĐẶT",
      "OPEN SETTINGS",
    ),
    "turningOnBluetooth": _LocalizedText(
      "Đang bật Bluetooth...",
      "Turning on Bluetooth...",
    ),
    "bluetoothStillOff": _LocalizedText(
      "Bluetooth vẫn tắt",
      "Bluetooth is still off",
    ),
    "bluetoothSettingsPrompt": _LocalizedText(
      "Vui lòng bật Bluetooth trong Cài đặt để app có thể kết nối với xe.",
      "Please turn on Bluetooth in Settings to connect to the vehicle.",
    ),
    "gpsOffTitle": _LocalizedText(
      "GPS đang tắt",
      "GPS is Off",
    ),
    "gpsEnablePrompt": _LocalizedText(
      "App cần GPS để tìm xe qua Bluetooth.\nBật Vị trí/GPS ngay bây giờ không?",
      "The app needs Location/GPS to find the vehicle via Bluetooth.\nTurn on Location now?",
    ),
    "enableGpsBtn": _LocalizedText(
      "BẬT GPS",
      "TURN ON GPS",
    ),
    "bgLocationRequired": _LocalizedText(
      "Cần quyền vị trí nền",
      "Background Location Required",
    ),
    "bgLocationSettingsPrompt": _LocalizedText(
      "Để tự động tìm xe khi app không mở, vui lòng vào Cài đặt → Vị trí → chọn \"Luôn cho phép\".",
      "To automatically find the vehicle when the app is closed, please go to Settings → Location → Select \"Allow all the time\".",
    ),
    "permissionsPermanentlyDenied": _LocalizedText(
      "Thiếu quyền, vui lòng mở Cài đặt",
      "Permissions missing, please open Settings",
    ),
    "permissionsPermanentlyDeniedTitle": _LocalizedText(
      "Quyền bị từ chối vĩnh viễn",
      "Permissions Permanently Denied",
    ),
    "permissionsPermanentlyDeniedMessage": _LocalizedText(
      "App cần quyền Bluetooth và Vị trí. Vui lòng vào Cài đặt → Ứng dụng → SmartKey → Quyền và cấp đủ quyền.",
      "The app needs Bluetooth and Location permissions. Please go to Settings → Apps → SmartKey → Permissions and grant them.",
    ),
    "permissionsMissing": _LocalizedText(
      "Chưa cấp quyền Bluetooth / Vị trí",
      "Bluetooth / Location permissions not granted",
    ),
    "missingAccessRights": _LocalizedText(
      "Thiếu quyền truy cập",
      "Missing Access Rights",
    ),
    "permissionsPrompt": _LocalizedText(
      "App cần quyền Bluetooth và Vị trí để tìm và kết nối xe. Vui lòng cấp quyền khi được hỏi.",
      "The app needs Bluetooth and Location permissions to connect to the vehicle. Please grant them when prompted.",
    ),
    "returnToAppToContinue": _LocalizedText(
      "Quay lại app để tiếp tục...",
      "Return to the app to continue...",
    ),
    "retryBtn": _LocalizedText(
      "THỬ LẠI",
      "RETRY",
    ),
    "connectedWaitSignal": _LocalizedText(
      "Đã kết nối, chờ sóng BLE đủ mạnh để xác thực ({rssi} dBm)",
      "Connected, waiting for stronger BLE signal to authenticate ({rssi} dBm)",
    ),
    "findingCar": _LocalizedText(
      "Đang tìm xe...",
      "Searching for vehicle...",
    ),
    "disconnected": _LocalizedText(
      "Đã ngắt kết nối",
      "Disconnected",
    ),
    "lostConnection": _LocalizedText(
      "Mất kết nối với xe",
      "Lost connection to vehicle",
    ),
    "bluetoothOffCannotConnect": _LocalizedText(
      "Bluetooth đã tắt, không thể kết nối với xe",
      "Bluetooth is off, cannot connect to vehicle",
    ),
    "bluetoothOnReconnecting": _LocalizedText(
      "Bluetooth đã bật, đang kết nối lại với xe...",
      "Bluetooth is on, reconnecting to vehicle...",
    ),
    "pleaseConnectFirst": _LocalizedText(
      "Vui lòng kết nối xe trước",
      "Please connect to the vehicle first",
    ),
    "waitingForRssi": _LocalizedText(
      "Chờ RSSI >= {rssi} dBm",
      "Waiting for RSSI >= {rssi} dBm",
    ),
    "rssiTooLowForAuth": _LocalizedText(
      "RSSI hiện tại {current} dBm, cần >= {min} dBm để xác thực",
      "Current RSSI is {current} dBm, need >= {min} dBm to authenticate",
    ),
    "authenticatingAccess": _LocalizedText(
      "Đang xác thực quyền truy cập...",
      "Authenticating access...",
    ),
    "reAuthenticating": _LocalizedText(
      "Đang xác thực lại quyền truy cập...",
      "Re-authenticating access...",
    ),
    "waitingForCarResponse": _LocalizedText(
      "Đang chờ phản hồi từ xe...",
      "Waiting for vehicle response...",
    ),
    "connectedAndAuthenticated": _LocalizedText(
      "Đã kết nối & xác thực",
      "Connected & Authenticated",
    ),
    "authSuccessAes128": _LocalizedText(
      "Xác thực thành công (AES-128)",
      "Authentication successful (AES-128)",
    ),
    "authFailAes128": _LocalizedText(
      "Truy cập thất bại",
      "Authentication failed",
    ),
    "authSuccessFull": _LocalizedText(
      "Truy cập xe thành công",
      "Vehicle access successful",
    ),
    "authFailFull": _LocalizedText(
      "Xác thực quyền truy cập thất bại",
      "Access authentication failed",
    ),
    "preparingSecureConnection": _LocalizedText(
      "Đang chuẩn bị kết nối bảo mật...",
      "Preparing secure connection...",
    ),
    "openingCommunicationChannel": _LocalizedText(
      "Đang mở kênh giao tiếp với xe...",
      "Opening communication channel with vehicle...",
    ),
    "preparingConnection": _LocalizedText(
      "Đang chuẩn bị kết nối...",
      "Preparing connection...",
    ),
    "establishingConnection": _LocalizedText(
      "Đang thiết lập kết nối với xe...",
      "Establishing connection to vehicle...",
    ),
    "wrongData": _LocalizedText(
      "Dữ liệu sai",
      "Wrong data",
    ),
    "noResponseReceived": _LocalizedText(
      "Không nhận được phản hồi",
      "No response received",
    ),
    "invalidData": _LocalizedText(
      "Dữ liệu không hợp lệ",
      "Invalid data",
    ),
    "authFailed": _LocalizedText(
      "Xác thực thất bại",
      "Authentication failed",
    ),
    "timeoutWaitingForResponse": _LocalizedText(
      "Hết thời gian chờ phản hồi",
      "Timeout waiting for response",
    ),
    "authError": _LocalizedText(
      "Lỗi xác thực: {error}",
      "Auth error: {error}",
    ),
    "notAuthenticated": _LocalizedText(
      "Chưa xác thực",
      "Not authenticated",
    ),
    "secureData": _LocalizedText(
      "[DỮ LIỆU BẢO MẬT]",
      "[SECURE DATA]",
    ),
    "errorPrefix": _LocalizedText(
      "Lỗi: {error}",
      "Error: {error}",
    ),
    "flowUnlockedCar": _LocalizedText("Xe đã mở", "Vehicle Unlocked"),
    "flowUnlockedCarSubtitle": _LocalizedText(
      "Cửa mở sau khi xác thực thành công",
      "Door opens after access is approved",
    ),
    "flowInsideCar": _LocalizedText("Người ở trong xe", "Person Inside"),
    "flowInsideCarSubtitle": _LocalizedText(
      "Gửi tín hiệu chào mừng khi vào trong xe",
      "Send welcome signal when inside vehicle",
    ),
    "accessStatus": _LocalizedText("Trạng thái truy cập", "Access Status"),
    "flowDetails": _LocalizedText("Chi tiết quy trình", "Flow Details"),
    "rssiBle": _LocalizedText("RSSI BLE", "BLE RSSI"),
    "measuringSignal": _LocalizedText("Đang đo sóng...", "Measuring..."),
    "noSignal": _LocalizedText("Chưa có tín hiệu", "No signal"),
    "insideCar": _LocalizedText("Đã vào trong xe", "Inside vehicle"),
    "strongEnoughAuth": _LocalizedText(
      "Đủ mạnh để xác thực",
      "Strong enough to auth",
    ),
    "stableSignal": _LocalizedText("Sóng ổn định", "Stable signal"),
    "weakSignal": _LocalizedText("Sóng yếu", "Weak signal"),
    "veryWeakSignal": _LocalizedText("Sóng rất yếu", "Very weak signal"),
    "authCardTitle": _LocalizedText(
      "Xác thực truy cập xe",
      "Vehicle Access Authentication",
    ),
    "latestVehicleResponse": _LocalizedText(
      "Phản hồi gần nhất từ xe",
      "Latest vehicle response",
    ),
    "authDataFromVehicle": _LocalizedText(
      "Dữ liệu xác thực từ xe",
      "Auth data from vehicle",
    ),
    "encryptedAuthData": _LocalizedText(
      "Dữ liệu xác thực đã mã hóa",
      "Encrypted auth data",
    ),
    "accessResult": _LocalizedText("Kết quả truy cập:", "Access result:"),
    "authAgain": _LocalizedText("Xác thực lại", "Authenticate again"),
    "authenticating": _LocalizedText("Đang xác thực...", "Authenticating..."),
    "authenticated": _LocalizedText("Đã xác thực", "Authenticated"),
    "authRetrying": _LocalizedText(
      "RSSI chưa đủ ổn định, sẽ tự thử lại sau 2 giây",
      "RSSI is not stable enough, retrying in 2 seconds",
    ),
    "connectVehicle": _LocalizedText("KẾT NỐI XE", "CONNECT VEHICLE"),
    "connectedVehicle": _LocalizedText("ĐÃ KẾT NỐI", "CONNECTED"),
    "noAuthHistory": _LocalizedText(
      "Chưa có phiên xác thực nào",
      "No authentication sessions yet",
    ),
    "authHistoryHint": _LocalizedText(
      "Khi xe phản hồi PASS hoặc FAIL, thông tin mã hóa sẽ xuất hiện tại đây.",
      "When the vehicle returns PASS or FAIL, encryption details will appear here.",
    ),
    "authSuccess": _LocalizedText(
      "Xác thực thành công",
      "Authentication passed",
    ),
    "authFail": _LocalizedText("Xác thực thất bại", "Authentication failed"),
    "authRssi": _LocalizedText("RSSI khi xác thực", "RSSI at authentication"),
    "insideVehicleStatus": _LocalizedText(
      "Trạng thái trong xe",
      "Inside-vehicle status",
    ),
    "insideVehicleDetected": _LocalizedText(
      "Đã nhận biết người ở trong xe",
      "Person inside vehicle detected",
    ),
    "insideVehicleNotReached": _LocalizedText(
      "Chưa đủ gần để xác nhận trong xe",
      "Not close enough to confirm inside",
    ),
    "challengeCode": _LocalizedText(
      "Mã khởi tạo truy cập",
      "Access start code",
    ),
    "vehicleAuthData": _LocalizedText(
      "Dữ liệu xác thực từ xe",
      "Auth data from vehicle",
    ),
    "encryptedData": _LocalizedText(
      "Dữ liệu xác thực đã mã hóa",
      "Encrypted auth data",
    ),
  };

  static const Map<String, String> _dynamicTranslations = {
    "Chưa xác thực": "Not authenticated",
    "Đang xác thực quyền truy cập...": "Authenticating access...",
    "Đang xác thực lại quyền truy cập...": "Re-authenticating access...",
    "Đang chờ phản hồi từ xe...": "Waiting for vehicle response...",
    "Truy cập thành công": "Access granted",
    "Truy cập thất bại": "Access denied",
    "Đã ngắt kết nối": "Disconnected",
    "Đang tìm xe...": "Searching for vehicle...",
    "Không tìm thấy xe": "Vehicle not found",
    "Không thể kết nối với xe": "Unable to connect vehicle",
    "Kết nối với xe đã sẵn sàng": "Vehicle connection ready",
  };
}

class _LocalizedText {
  final String vi;
  final String en;

  const _LocalizedText(this.vi, this.en);
}
