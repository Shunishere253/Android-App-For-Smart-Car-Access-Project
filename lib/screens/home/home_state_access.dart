part of '../home_screen.dart';

mixin _HomeStateAccess on State<HomeScreen> {
  String get statusText;
  set statusText(String value);

  Color get statusColor;
  set statusColor(Color value);

  Timer? get autoReconnectTimer;
  set autoReconnectTimer(Timer? value);

  Timer? get authRetryTimer;
  set authRetryTimer(Timer? value);

  bool get isConnected;
  set isConnected(bool value);

  bool get isScanning;
  set isScanning(bool value);

  bool get isSystemReady;
  set isSystemReady(bool value);

  bool get isAuthenticating;
  set isAuthenticating(bool value);

  bool get isAccessAuthenticated;
  set isAccessAuthenticated(bool value);

  bool get isAutoReconnectScheduled;
  set isAutoReconnectScheduled(bool value);

  bool get isAutoReconnectAttempting;
  set isAutoReconnectAttempting(bool value);

  bool get isWaitingForCarSignal;
  set isWaitingForCarSignal(bool value);

  bool get backgroundStarted;
  set backgroundStarted(bool value);

  int? get bleRssi;
  set bleRssi(int? value);

  List<AuthHistoryEntry> get history;

  String get challengeHex;
  set challengeHex(String value);

  String get plaintextHex;
  set plaintextHex(String value);

  String get cipherHex;
  set cipherHex(String value);

  String get aesResult;
  set aesResult(String value);

  Color get aesResultColor;
  set aesResultColor(Color value);

  String get uartLastMessage;
  set uartLastMessage(String value);

  StreamSubscription<String>? get uartSub;
  set uartSub(StreamSubscription<String>? value);

  StreamSubscription<bool>? get bleConnectionSub;
  set bleConnectionSub(StreamSubscription<bool>? value);

  StreamSubscription<int?>? get rssiSub;
  set rssiSub(StreamSubscription<int?>? value);

  StreamSubscription<bool>? get userInsideCarNotificationSub;
  set userInsideCarNotificationSub(StreamSubscription<bool>? value);

  StreamSubscription<BluetoothAdapterState>? get btStateSub;
  set btStateSub(StreamSubscription<BluetoothAdapterState>? value);

  Future<void> checkSystemOnLaunch();
  Future<void> connectToCar({bool isAutoReconnect = false});
  Future<void> runAesHandshake({bool autoRun = false});

  void openSettingsScreen();
  void openHistoryScreen();
  void tryRunAutoAuthWhenSignalReady();
  void scheduleAutoReconnect();
  void stopAutoReconnect();

  String mapUserFriendlyStatus(String rawStatus);
}
