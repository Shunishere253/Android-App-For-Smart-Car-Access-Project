part of '../bluetooth_service.dart';

bool _bleIsTargetCarDeviceName(String upperName) {
  return upperName == "JDY-23" ||
      upperName.contains("JDY") ||
      upperName.contains("SMART") ||
      upperName.contains("CAR");
}

bool _bleIsStatusText(String asciiUpper) {
  return asciiUpper.contains("PASS") ||
      asciiUpper.contains("FAIL") ||
      asciiUpper.contains("UART") ||
      asciiUpper.contains("READY") ||
      asciiUpper.contains("BOOT") ||
      asciiUpper.contains("START") ||
      asciiUpper.contains("IN_CAR") ||
      asciiUpper.contains("USER") ||
      asciiUpper.contains("OK");
}

List<int>? _bleParsePlaintextFlexible(List<int> buffer) {
  if (buffer.isEmpty) return null;

  final ascii = _bleTryDecodeAscii(buffer).toUpperCase().trim();

  if (_bleIsStatusText(ascii)) {
    return null;
  }

  if (buffer.length >= 16) {
    final cleanHex = ascii
        .replaceAll('0X', '')
        .replaceAll(RegExp(r'[^0-9A-F]'), '');

    if (cleanHex.length >= 32) {
      try {
        return CryptoService.hexToBytes(cleanHex.substring(0, 32));
      } catch (_) {
        // Fallback raw bên dưới.
      }
    }

    return buffer.sublist(0, 16);
  }

  return null;
}

String _bleTryDecodeAscii(List<int> data) {
  try {
    return utf8.decode(data, allowMalformed: true);
  } catch (_) {
    return "";
  }
}
