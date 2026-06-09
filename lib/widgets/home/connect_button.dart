import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';

class ConnectButton extends StatelessWidget {
  final bool isConnected;
  final bool isScanning;
  final Color primaryColor;
  final VoidCallback onPressed;

  const ConnectButton({
    super.key,
    required this.isConnected,
    required this.isScanning,
    required this.primaryColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bool disabled = isConnected || isScanning;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: InkWell(
        onTap: disabled ? null : onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: disabled
                  ? [Colors.grey.shade800, Colors.grey.shade600]
                  : [primaryColor.withValues(alpha: 0.8), primaryColor],
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: disabled
                ? []
                : [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Center(
            child: isScanning
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(
                    isConnected
                        ? AppLocalizations.t("connectedVehicle")
                        : AppLocalizations.t("connectVehicle"),
                    style: TextStyle(
                      color: disabled ? Colors.white54 : Colors.black87,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
