import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../theme_manager.dart';

class HomeHeader extends StatelessWidget {
  final VoidCallback onSettingsPressed;
  final VoidCallback onHistoryPressed;

  const HomeHeader({
    super.key,
    required this.onSettingsPressed,
    required this.onHistoryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.t("welcomeBack"),
                  style: TextStyle(
                    color: ThemeManager.textSecondary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  AppLocalizations.t("appName"),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ThemeManager.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: AppLocalizations.t("authHistory"),
                icon: Icon(
                  Icons.history,
                  color: ThemeManager.textPrimary,
                  size: 26,
                ),
                onPressed: onHistoryPressed,
              ),
              IconButton(
                tooltip: AppLocalizations.t("settings"),
                icon: Icon(
                  Icons.settings,
                  color: ThemeManager.textPrimary,
                  size: 28,
                ),
                onPressed: onSettingsPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
