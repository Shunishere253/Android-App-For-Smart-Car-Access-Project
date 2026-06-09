part of '../bluetooth_service.dart';

Future<void> _bleDiscoverCharacteristics(BluetoothDevice device) async {
  final services = await device.discoverServices();

  BleController._writeChar = null;
  BleController._notifyChar = null;

  for (final service in services) {
    debugPrint("========== SERVICE ==========");
    debugPrint("SERVICE UUID: ${service.uuid}");

    for (final c in service.characteristics) {
      final props = c.properties;
      final uuid = c.uuid.toString().toLowerCase();

      debugPrint(
        "CHAR UUID: ${c.uuid} | "
        "read=${props.read} | "
        "write=${props.write} | "
        "writeNoResp=${props.writeWithoutResponse} | "
        "notify=${props.notify} | "
        "indicate=${props.indicate}",
      );

      // JDY-23 UART data channel theo log thực tế:
      // SERVICE ffe0
      // CHAR ffe1 | write=true | notify=true
      //
      // Không chọn 2a05 vì đó là Generic Attribute Service Changed,
      // không phải kênh dữ liệu của xe.
      if (uuid == "ffe1") {
        if (props.write || props.writeWithoutResponse) {
          BleController._writeChar = c;
        }

        if (props.notify || props.indicate) {
          BleController._notifyChar = c;
        }
      }
    }
  }

  if (BleController._writeChar == null) {
    throw Exception("Không tìm thấy kênh gửi dữ liệu");
  }

  if (BleController._notifyChar == null) {
    throw Exception("Không tìm thấy kênh nhận dữ liệu");
  }

  debugPrint("========== SELECTED CAR CHANNEL ==========");
  debugPrint("WRITE CHAR: ${BleController._writeChar!.uuid}");
  debugPrint("NOTIFY CHAR: ${BleController._notifyChar!.uuid}");
}