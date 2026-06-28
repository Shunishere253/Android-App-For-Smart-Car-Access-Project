import 'package:flutter/material.dart';

import 'services/storage_service.dart';

enum AppThemeStyle {
  darkBlue,
  light,
  black,
  white,
}

class ThemeManager {
  static ValueNotifier<Color> appColor =
      ValueNotifier<Color>(Colors.cyanAccent);

  static ValueNotifier<AppThemeStyle> themeStyle =
      ValueNotifier<AppThemeStyle>(AppThemeStyle.darkBlue);

  static List<Color> availableColors = [
    Colors.cyanAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
    Colors.redAccent,
  ];

  // ── Persistent storage ────────────────────────────────────────

  /// Load theme config từ SharedPreferences.
  /// Gọi trước runApp() trong main().
  static Future<void> loadFromStorage() async {
    final (style, color) = await StorageService.loadTheme();
    themeStyle.value = style;
    appColor.value = color;

    // Tự động save khi user thay đổi
    themeStyle.addListener(_onThemeChanged);
    appColor.addListener(_onThemeChanged);
  }

  static void _onThemeChanged() {
    StorageService.saveTheme(themeStyle.value, appColor.value);
  }

  // ── Theme helpers ─────────────────────────────────────────────

  static bool get isLight {
    return themeStyle.value == AppThemeStyle.light ||
        themeStyle.value == AppThemeStyle.white;
  }

  static List<Color> get backgroundGradient {
    switch (themeStyle.value) {
      case AppThemeStyle.darkBlue:
        return const [
          Color(0xFF141E30),
          Color(0xFF243B55),
        ];

      case AppThemeStyle.black:
        return const [
          Colors.black,
          Color(0xFF181818),
        ];

      case AppThemeStyle.light:
        return const [
          Color(0xFFF4F7FB),
          Color(0xFFE7EEF8),
        ];

      case AppThemeStyle.white:
        return const [
          Colors.white,
          Color(0xFFF2F2F2),
        ];
    }
  }

  static Color get textPrimary {
    return isLight ? Colors.black87 : Colors.white;
  }

  static Color get textSecondary {
    return isLight ? Colors.black54 : Colors.white70;
  }

  static Color get cardColor {
    return isLight
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.black.withValues(alpha: 0.25);
  }

  static Color get borderColor {
    return isLight
        ? Colors.black.withValues(alpha: 0.08)
        : Colors.white.withValues(alpha: 0.12);
  }

  static Color get iconInactive {
    return isLight ? Colors.black45 : Colors.white54;
  }
}