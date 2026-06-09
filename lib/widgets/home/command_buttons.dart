import 'package:flutter/material.dart';

import '../../theme_manager.dart';

class CommandButtons extends StatelessWidget {
  final VoidCallback onLockPressed;
  final VoidCallback onUnlockPressed;
  final VoidCallback onHornPressed;

  const CommandButtons({
    super.key,
    required this.onLockPressed,
    required this.onUnlockPressed,
    required this.onHornPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ControlButton(
            icon: Icons.lock_outline,
            label: "Khóa xe",
            color: Colors.redAccent,
            onTap: onLockPressed,
          ),
          _ControlButton(
            icon: Icons.lock_open,
            label: "Mở xe",
            color: Colors.greenAccent,
            onTap: onUnlockPressed,
          ),
          _ControlButton(
            icon: Icons.campaign,
            label: "Tìm xe",
            color: Colors.amber,
            onTap: onHornPressed,
          ),
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: ThemeManager.cardColor,
              shape: BoxShape.circle,
              border: Border.all(color: ThemeManager.borderColor),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.12),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 32),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: TextStyle(
            color: ThemeManager.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}