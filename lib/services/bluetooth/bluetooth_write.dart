part of '../bluetooth_service.dart';

Future<void> _bleWriteBytes(List<int> data) async {
  if (BleController.connectedDevice == null) {
    throw Exception("Xe đã mất kết nối");
  }

  final state = await BleController.connectedDevice!.connectionState.first;

  if (state != BluetoothConnectionState.connected) {
    BleController._connectionStateController.add(false);
    throw Exception("Xe đã mất kết nối");
  }

  if (BleController._writeChar == null) {
    throw Exception("Kênh gửi dữ liệu chưa sẵn sàng");
  }

  final rawHex = CryptoService.bytesToHex(
    data,
    withSpace: true,
    withPrefix: false,
  );

  debugPrint("APP -> CAR raw: $rawHex");
  debugPrint("APP -> CAR decimal: $data");

  if (BleController._writeChar!.properties.write) {
    await BleController._writeChar!.write(data, withoutResponse: false);
  } else if (BleController._writeChar!.properties.writeWithoutResponse) {
    await BleController._writeChar!.write(data, withoutResponse: true);
  } else {
    throw Exception("Kênh gửi dữ liệu không khả dụng");
  }
}