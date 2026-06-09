part of '../bluetooth_service.dart';

Future<void> _bleReleaseMcuVerifyState() async {
  if (BleController._writeChar == null) return;

  try {
    final zeros = List<int>.filled(16, 0x00);

    debugPrint(
      "APP -> CAR release verify state: ${CryptoService.bytesToHex(
        zeros,
        withSpace: true,
        withPrefix: false,
      )}",
    );

    await _bleWriteBytes(zeros);
    await Future.delayed(const Duration(milliseconds: 300));
  } catch (e) {
    debugPrint("releaseMcuVerifyState error: $e");
  }
}