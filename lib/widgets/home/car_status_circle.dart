import 'package:flutter/material.dart';

import '../../theme_manager.dart';

class CarStatusCircle extends StatelessWidget {
  final bool isConnected;
  final Color primaryColor;
  final Color statusColor;

  const CarStatusCircle({
    super.key,
    required this.isConnected,
    required this.primaryColor,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color activeColor = isConnected ? primaryColor : statusColor;

    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ThemeManager.isLight
            ? Colors.white.withValues(alpha: 0.8)
            : Colors.black.withValues(alpha: 0.3),
        boxShadow: [
          BoxShadow(
            color: activeColor.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
        border: Border.all(
          color: activeColor.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Center(
        child: Icon(
          isConnected ? Icons.directions_car : Icons.no_crash_outlined,
          size: 100,
          color: isConnected
              ? ThemeManager.textPrimary
              : ThemeManager.iconInactive,
        ),
      ),
    );
  }
}