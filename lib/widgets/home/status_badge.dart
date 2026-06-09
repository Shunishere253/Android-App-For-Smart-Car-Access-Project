import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';

class StatusBadge extends StatelessWidget {
  final String statusText;
  final Color statusColor;
  final Color primaryColor;
  final bool isConnected;

  const StatusBadge({
    super.key,
    required this.statusText,
    required this.statusColor,
    required this.primaryColor,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isConnected ? primaryColor : statusColor;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: activeColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: activeColor.withValues(alpha: 0.25)),
      ),
      child: Text(
        AppLocalizations.dynamicText(statusText),
        textAlign: TextAlign.center,
        style: TextStyle(
          color: activeColor,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
