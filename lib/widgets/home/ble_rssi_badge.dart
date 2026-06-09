import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/bluetooth_service.dart';
import '../../theme_manager.dart';

class BleRssiBadge extends StatelessWidget {
  final int? rssi;
  final Color primaryColor;
  final bool isConnected;
  final bool isScanning;

  const BleRssiBadge({
    super.key,
    required this.rssi,
    required this.primaryColor,
    required this.isConnected,
    required this.isScanning,
  });

  @override
  Widget build(BuildContext context) {
    final signalColor = _signalColor();
    final valueText = rssi == null ? "-- dBm" : "$rssi dBm";
    final detailText = rssi == null
        ? (isScanning
              ? AppLocalizations.t("measuringSignal")
              : AppLocalizations.t("noSignal"))
        : _signalLabel(rssi!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: const BoxConstraints(minHeight: 64),
      decoration: BoxDecoration(
        color: ThemeManager.isLight
            ? Colors.white.withValues(alpha: 0.75)
            : Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: signalColor.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Icon(Icons.bluetooth, color: signalColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppLocalizations.t("rssiBle"),
                  style: TextStyle(
                    color: ThemeManager.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  valueText,
                  style: TextStyle(
                    color: ThemeManager.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              _RssiBars(rssi: rssi, activeColor: signalColor),
              const SizedBox(height: 4),
              Text(
                detailText,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: ThemeManager.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _signalColor() {
    if (rssi == null) {
      return isConnected ? primaryColor : Colors.grey;
    }

    if (rssi! >= BleController.userInsideCarMinimumRssi) {
      return Colors.greenAccent;
    }
    if (rssi! >= BleController.authMinimumRssi) return primaryColor;
    if (rssi! >= -70) return Colors.orangeAccent;
    if (rssi! >= -80) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  String _signalLabel(int value) {
    if (value >= BleController.userInsideCarMinimumRssi) {
      return AppLocalizations.t("insideCar");
    }

    if (value >= BleController.authMinimumRssi) {
      return AppLocalizations.t("strongEnoughAuth");
    }
    if (value >= -70) return AppLocalizations.t("stableSignal");
    if (value >= -80) return AppLocalizations.t("weakSignal");
    return AppLocalizations.t("veryWeakSignal");
  }
}

class _RssiBars extends StatelessWidget {
  final int? rssi;
  final Color activeColor;

  const _RssiBars({required this.rssi, required this.activeColor});

  @override
  Widget build(BuildContext context) {
    final activeBars = _activeBars();

    return SizedBox(
      width: 34,
      height: 24,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(4, (index) {
          final isActive = index < activeBars;

          return Container(
            width: 6,
            height: 7.0 + (index * 4),
            decoration: BoxDecoration(
              color: isActive
                  ? activeColor
                  : ThemeManager.textSecondary.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(3),
            ),
          );
        }),
      ),
    );
  }

  int _activeBars() {
    if (rssi == null) return 0;
    if (rssi! >= BleController.userInsideCarMinimumRssi) return 4;
    if (rssi! >= BleController.authMinimumRssi) return 3;
    if (rssi! >= -70) return 2;
    if (rssi! >= -80) return 1;
    return 1;
  }
}
