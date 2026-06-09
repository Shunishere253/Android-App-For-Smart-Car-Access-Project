part of '../bluetooth_service.dart';

Future<void> _bleStartNotifyListener() async {
  if (BleController._notifyChar == null) {
    throw Exception("Kênh nhận dữ liệu chưa sẵn sàng");
  }

  await BleController._notifySubscription?.cancel();
  BleController._notifySubscription = null;

  BleController._notifySubscription =
      BleController._notifyChar!.onValueReceived.listen((data) {
    final rawData = List<int>.from(data);

    final rawHex = CryptoService.bytesToHex(
      rawData,
      withSpace: true,
      withPrefix: false,
    );

    final ascii = _bleTryDecodeAscii(rawData);

    debugPrint("NOTIFY UUID: ${BleController._notifyChar!.uuid}");
    debugPrint("CAR -> APP raw  : $rawHex");
    debugPrint("CAR -> APP ascii: $ascii");

    BleController._rawRxController.add(rawData);

    if (ascii.trim().isEmpty) {
      BleController._uartTextController.add("[DỮ LIỆU BẢO MẬT] $rawHex");
    } else {
      BleController._uartTextController.add(ascii.trim());
    }
  });

  await BleController._notifyChar!.setNotifyValue(true);

  // FFE1 notify đã bật xong thì chỉ cần delay ngắn.
  await Future.delayed(const Duration(milliseconds: 100));

  debugPrint(
    "Notify subscribed successfully on ${BleController._notifyChar!.uuid}",
  );
}