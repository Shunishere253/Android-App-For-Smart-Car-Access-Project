import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// ============================================================
// NotificationService – quản lý thông báo hệ thống tập trung
//
// Dùng cho CẢ foreground app (main isolate) VÀ background
// service (background isolate) – mỗi isolate gọi initialize()
// riêng trước khi dùng.
//
// 4 loại thông báo:
//   1. showConnected     – Đã kết nối với xe
//   2. showAuthSuccess   – Xác thực thành công
//   3. showDisconnected  – Đã ngắt kết nối
//   4. showInsideCar     – Đã vào trong xe
// ============================================================

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  // Channel IDs
  static const String _channelCarEvent = 'car_event_channel';
  static const String _channelAuthSuccess = 'auth_success_channel';
  static const String _channelAuthFail = 'auth_fail_channel';
  static const String _channelForeground = 'smart_car_key_channel';

  // Notification IDs (cố định để không bị chồng chất)
  static const int _idConnected = 901;
  static const int _idAuthSuccess = 902;
  static const int _idDisconnected = 903;
  static const int _idInsideCar = 904;

  /// Khởi tạo plugin + tạo các notification channels.
  /// Phải gọi trước khi show() bất kỳ thông báo nào.
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      await android?.requestNotificationsPermission();

      // Channel cho foreground service (Importance.low để không rung)
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelForeground,
          'Smart Car Key Service',
          description: 'Dịch vụ chạy ngầm để tự động xác thực xe',
          importance: Importance.low,
        ),
      );

      // Channel chung cho sự kiện xe (kết nối, ngắt, vào xe)
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelCarEvent,
          'Sự kiện xe',
          description: 'Thông báo kết nối, ngắt kết nối, vào trong xe',
          importance: Importance.high,
        ),
      );

      // Channel xác thực thành công
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelAuthSuccess,
          'Xác thực thành công',
          description: 'Thông báo khi xe cho phép truy cập',
          importance: Importance.high,
        ),
      );

      // Channel xác thực thất bại
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _channelAuthFail,
          'Xác thực thất bại',
          description: 'Thông báo khi xe từ chối truy cập',
          importance: Importance.defaultImportance,
        ),
      );

      _initialized = true;
      debugPrint("NotificationService: initialized");
    } catch (e) {
      debugPrint("NotificationService init error: $e");
    }
  }

  // ── 4 loại thông báo ──────────────────────────────────────────

  /// 🔗 Đã kết nối với xe
  static Future<void> showConnected() => _show(
    id: _idConnected,
    channelId: _channelCarEvent,
    channelName: 'Sự kiện xe',
    title: '🔗 Đã kết nối với xe',
    body: 'Xe JDY-23 đã sẵn sàng – đang xác thực quyền truy cập...',
    importance: Importance.high,
  );

  /// 🔓 Xác thực thành công
  static Future<void> showAuthSuccess() => _show(
    id: _idAuthSuccess,
    channelId: _channelAuthSuccess,
    channelName: 'Xác thực thành công',
    title: '🔓 Xác thực thành công',
    body: 'Quyền truy cập xe đã được cấp',
    importance: Importance.high,
  );

  /// ❌ Xác thực thất bại
  static Future<void> showAuthFail(String mcuResult) => _show(
    id: _idAuthSuccess, // Dùng cùng ID để thay thế nếu thành công trước đó
    channelId: _channelAuthFail,
    channelName: 'Xác thực thất bại',
    title: '❌ Xác thực thất bại',
    body: 'MCU phản hồi: $mcuResult',
    importance: Importance.defaultImportance,
  );

  /// 🔌 Đã ngắt kết nối
  static Future<void> showDisconnected() => _show(
    id: _idDisconnected,
    channelId: _channelCarEvent,
    channelName: 'Sự kiện xe',
    title: '🔌 Đã ngắt kết nối',
    body: 'Xa xe hoặc Bluetooth bị gián đoạn',
    importance: Importance.high,
  );

  /// 🚗 Đã vào trong xe
  static Future<void> showInsideCar() => _show(
    id: _idInsideCar,
    channelId: _channelCarEvent,
    channelName: 'Sự kiện xe',
    title: '🚗 Đã vào trong xe',
    body: 'Phát hiện bạn đang ở trong xe',
    importance: Importance.high,
  );

  // ── Private helper ────────────────────────────────────────────

  static Future<void> _show({
    required int id,
    required String channelId,
    required String channelName,
    required String title,
    required String body,
    required Importance importance,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    try {
      await _plugin.show(
        id,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelName,
            importance: importance,
            priority:
                importance == Importance.high ? Priority.high : Priority.defaultPriority,
          ),
        ),
      );
    } catch (e) {
      debugPrint("NotificationService show error: $e");
    }
  }
}
