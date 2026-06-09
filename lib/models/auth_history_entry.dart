class AuthHistoryEntry {
  final DateTime authenticatedAt;
  final String challengeHex;
  final String plaintextHex;
  final String cipherHex;
  final String mcuResult;
  final int? rssi;
  final bool userInsideCarNotified;

  const AuthHistoryEntry({
    required this.authenticatedAt,
    required this.challengeHex,
    required this.plaintextHex,
    required this.cipherHex,
    required this.mcuResult,
    required this.rssi,
    required this.userInsideCarNotified,
  });

  bool get isPass => mcuResult.toUpperCase().contains("PASS");

  AuthHistoryEntry copyWith({
    DateTime? authenticatedAt,
    String? challengeHex,
    String? plaintextHex,
    String? cipherHex,
    String? mcuResult,
    int? rssi,
    bool? userInsideCarNotified,
  }) {
    return AuthHistoryEntry(
      authenticatedAt: authenticatedAt ?? this.authenticatedAt,
      challengeHex: challengeHex ?? this.challengeHex,
      plaintextHex: plaintextHex ?? this.plaintextHex,
      cipherHex: cipherHex ?? this.cipherHex,
      mcuResult: mcuResult ?? this.mcuResult,
      rssi: rssi ?? this.rssi,
      userInsideCarNotified:
          userInsideCarNotified ?? this.userInsideCarNotified,
    );
  }
}
