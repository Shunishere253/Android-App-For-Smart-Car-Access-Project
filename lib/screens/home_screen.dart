import 'dart:async';

import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../localization/app_localizations.dart';
import '../models/auth_history_entry.dart';
import '../services/background_service.dart';
import '../services/bluetooth_service.dart';
import '../services/crypto_service.dart';
import '../theme_manager.dart';
import '../widgets/home/access_flow_visual.dart';
import '../widgets/home/aes_info_card.dart';
import '../widgets/home/ble_rssi_badge.dart';
import '../widgets/home/car_status_circle.dart';
import '../widgets/home/connect_button.dart';
import '../widgets/home/home_header.dart';
import '../widgets/home/status_badge.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

part 'home/home_state_access.dart';
part 'home/home_lifecycle.dart';
part 'home/home_permissions.dart';
part 'home/home_connection.dart';
part 'home/home_auth.dart';
part 'home/home_navigation.dart';
part 'home/home_build.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        WidgetsBindingObserver,
        _HomeStateAccess,
        _HomeLifecycle,
        _HomePermissions,
        _HomeConnection,
        _HomeAuth,
        _HomeNavigation,
        _HomeBuild {
  @override
  String statusText = "Đang kiểm tra hệ thống...";

  @override
  Color statusColor = Colors.grey;

  @override
  Timer? autoReconnectTimer;

  @override
  Timer? authRetryTimer;

  @override
  bool isConnected = false;

  @override
  bool isScanning = false;

  @override
  bool isSystemReady = false;

  @override
  bool isAuthenticating = false;

  @override
  bool isAccessAuthenticated = false;

  @override
  bool isAutoReconnectScheduled = false;

  @override
  bool isAutoReconnectAttempting = false;

  @override
  bool isWaitingForCarSignal = false;

  @override
  bool backgroundStarted = false;

  @override
  int? bleRssi;

  @override
  final List<AuthHistoryEntry> history = [];

  @override
  String challengeHex = "-";

  @override
  String plaintextHex = "-";

  @override
  String cipherHex = "-";

  @override
  String aesResult = "Chưa xác thực";

  @override
  Color aesResultColor = Colors.grey;

  @override
  String uartLastMessage = "-";

  @override
  StreamSubscription<String>? uartSub;

  @override
  StreamSubscription<bool>? bleConnectionSub;

  @override
  StreamSubscription<int?>? rssiSub;

  @override
  StreamSubscription<bool>? userInsideCarNotificationSub;

  @override
  StreamSubscription<BluetoothAdapterState>? btStateSub;
}
