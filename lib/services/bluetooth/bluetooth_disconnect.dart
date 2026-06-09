part of '../bluetooth_service.dart';

Future<void> _bleDisconnect({bool silent = false}) async {
  BleController._connectionWatchdogTimer?.cancel();
  BleController._connectionWatchdogTimer = null;

  await BleController._connectionSub?.cancel();
  BleController._connectionSub = null;

  await BleController._notifySubscription?.cancel();
  BleController._notifySubscription = null;

  try {
    if (BleController._notifyChar != null) {
      await BleController._notifyChar!.setNotifyValue(false);
    }
  } catch (_) {}

  try {
    await BleController.connectedDevice?.disconnect();
  } catch (_) {}

  BleController.connectedDevice = null;
  BleController._writeChar = null;
  BleController._notifyChar = null;
  BleController._authInProgress = false;
  BleController._lastAuthStartTime = null;
  BleController._accessAuthenticated = false;
  BleController._userInsideCarNotificationSent = false;
  BleController._userInsideCarNotificationInProgress = false;
  BleController._emitRssi(null);

  if (!silent) {
    BleController._connectionStateController.add(false);
  }
}
