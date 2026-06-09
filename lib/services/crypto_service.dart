import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as encrypt;

class CryptoService {
  static final List<int> _keyBytes = [
    0x2B,
    0x7E,
    0x15,
    0x16,
    0x28,
    0xAE,
    0xD2,
    0xA6,
    0xAB,
    0xF7,
    0x15,
    0x88,
    0x09,
    0xCF,
    0x4F,
    0x3C,
  ];

  // App gửi cố định 4 byte này để MCU bắt đầu challenge-response.
  static const List<int> fixedChallenge = [0x00, 0x01, 0x02, 0x03];

  // Bản tin ASCII báo BLE biết người dùng đã ở trong xe.
  static const List<int> userInsideCarCommand = [
    0x55,
    0x53,
    0x45,
    0x52,
    0x5F,
    0x49,
    0x4E,
    0x5F,
    0x43,
    0x41,
    0x52,
  ];

  static final encrypt.Key _secretKey = encrypt.Key(
    Uint8List.fromList(_keyBytes),
  );

  static List<int> encryptECB(List<int> plainText16Bytes) {
    if (plainText16Bytes.length != 16) {
      throw Exception("Plaintext phải đúng 16 bytes");
    }

    final encrypter = encrypt.Encrypter(
      encrypt.AES(_secretKey, mode: encrypt.AESMode.ecb, padding: null),
    );

    final encrypted = encrypter.encryptBytes(plainText16Bytes);
    return encrypted.bytes;
  }

  static List<int> encryptPlaintextHex(String plaintextHex) {
    final bytes = hexToBytes(plaintextHex);

    if (bytes.length != 16) {
      throw Exception("Plaintext từ MCU phải đúng 16 bytes");
    }

    return encryptECB(bytes);
  }

  static String bytesToHex(
    List<int> bytes, {
    bool withSpace = true,
    bool withPrefix = false,
  }) {
    final hex = bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(withSpace ? ' ' : '');

    return withPrefix ? '0x$hex' : hex;
  }

  static List<int> hexToBytes(String hex) {
    String cleanHex = hex.trim();

    cleanHex = cleanHex.replaceAll('0x', '');
    cleanHex = cleanHex.replaceAll('0X', '');

    cleanHex = cleanHex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    if (cleanHex.isEmpty) {
      throw Exception("Chuỗi hex rỗng");
    }

    if (cleanHex.length % 2 != 0) {
      throw Exception("Chuỗi hex không hợp lệ: $hex");
    }

    return List.generate(
      cleanHex.length ~/ 2,
      (i) => int.parse(cleanHex.substring(i * 2, i * 2 + 2), radix: 16),
    );
  }

  static String get keyAsHexString {
    return bytesToHex(_keyBytes, withSpace: false, withPrefix: true);
  }

  static String get fixedChallengeAsHexString {
    return bytesToHex(fixedChallenge, withSpace: false, withPrefix: true);
  }

  static String get userInsideCarCommandAsHexString {
    return bytesToHex(userInsideCarCommand, withSpace: false, withPrefix: true);
  }
}
