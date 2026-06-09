import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../theme_manager.dart';

class AesInfoCard extends StatelessWidget {
  final Color primaryColor;

  final String uartLastMessage;
  final String plaintextHex;
  final String cipherHex;
  final String aesResult;
  final Color aesResultColor;

  final bool isAuthenticating;
  final bool isAccessAuthenticated;
  final VoidCallback onAuthPressed;

  const AesInfoCard({
    super.key,
    required this.primaryColor,
    required this.uartLastMessage,
    required this.plaintextHex,
    required this.cipherHex,
    required this.aesResult,
    required this.aesResultColor,
    required this.isAuthenticating,
    required this.isAccessAuthenticated,
    required this.onAuthPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool authButtonDisabled = isAuthenticating || isAccessAuthenticated;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ThemeManager.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: ThemeManager.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: primaryColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  AppLocalizations.t("authCardTitle"),
                  style: TextStyle(
                    color: ThemeManager.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AesLine(
            AppLocalizations.t("latestVehicleResponse"),
            AppLocalizations.dynamicText(uartLastMessage),
          ),
          _AesLine(
            AppLocalizations.t("authDataFromVehicle"),
            AppLocalizations.dynamicText(plaintextHex),
          ),
          _AesLine(
            AppLocalizations.t("encryptedAuthData"),
            AppLocalizations.dynamicText(cipherHex),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${AppLocalizations.t("accessResult")} ",
                style: TextStyle(color: ThemeManager.textSecondary),
              ),
              Expanded(
                child: Text(
                  AppLocalizations.dynamicText(aesResult),
                  style: TextStyle(
                    color: aesResultColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: authButtonDisabled ? null : onAuthPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: isAuthenticating
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    )
                  : Icon(isAccessAuthenticated ? Icons.verified : Icons.sync),
              label: Text(
                isAuthenticating
                    ? AppLocalizations.t("authenticating")
                    : isAccessAuthenticated
                    ? AppLocalizations.t("authenticated")
                    : AppLocalizations.t("authAgain"),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AesLine extends StatelessWidget {
  final String label;
  final String value;

  const _AesLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: ThemeManager.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: TextStyle(
              color: ThemeManager.textPrimary,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
