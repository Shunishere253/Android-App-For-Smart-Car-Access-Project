part of '../bluetooth_service.dart';

Future<String> _bleCheckAndRequestPermissions() async {
  if (!Platform.isAndroid) return "OK";

  final androidInfo = await DeviceInfoPlugin().androidInfo;
  final int sdkInt = androidInfo.version.sdkInt;

  Map<Permission, PermissionStatus> statuses;

  if (sdkInt <= 30) {
    statuses = await [Permission.location].request();

    if (statuses[Permission.location]!.isDenied ||
        statuses[Permission.location]!.isPermanentlyDenied) {
      return "PERMISSION_DENIED";
    }
  } else {
    statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    if (statuses[Permission.bluetoothScan]!.isDenied ||
        statuses[Permission.bluetoothConnect]!.isDenied ||
        statuses[Permission.location]!.isDenied) {
      return "PERMISSION_DENIED";
    }
  }

  final bgLocationStatus = await Permission.locationAlways.request();

  if (!bgLocationStatus.isGranted) {
    return "BG_LOCATION_DENIED";
  }

  final locationStatus = await Permission.location.serviceStatus;

  if (!locationStatus.isEnabled) {
    return "LOCATION_SERVICE_OFF";
  }

  final btState = await FlutterBluePlus.adapterState
      .firstWhere((state) => state != BluetoothAdapterState.unknown)
      .timeout(
        const Duration(seconds: 2),
        onTimeout: () => BluetoothAdapterState.unknown,
      );

  if (btState == BluetoothAdapterState.off) {
    return "BLUETOOTH_OFF";
  }

  return "OK";
}