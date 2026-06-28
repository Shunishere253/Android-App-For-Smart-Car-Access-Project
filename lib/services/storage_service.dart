import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../localization/app_localizations.dart';
import '../models/auth_history_entry.dart';
import '../theme_manager.dart';

// ============================================================
// StorageService – lưu trữ dữ liệu vào SharedPreferences
//
// Dùng cho:
//   • Lịch sử xác thực (tối đa 50 entries)
//   • Theme style + accent color
//   • Ngôn ngữ hiển thị
//   • Flag BLE ownership (fg/bg phối hợp)
//   • Cooldown background auth
// ============================================================

class StorageService {
  // Keys
  static const _keyHistory = 'auth_history_v1';
  static const _keyThemeStyle = 'theme_style';
  static const _keyAccentColor = 'accent_color';
  static const _keyLanguage = 'language';
  static const _keyFgOwns = 'fg_owns_ble';
  static const _keyBgCooldown = 'bg_auth_cooldown_until';

  static const int _maxHistoryEntries = 50;

  // ── Lịch sử xác thực ─────────────────────────────────────────

  static Future<void> saveHistory(List<AuthHistoryEntry> history) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final limited = history.take(_maxHistoryEntries).toList();
      final jsonList = limited.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_keyHistory, jsonList);
    } catch (e) {
      debugPrint("StorageService.saveHistory error: $e");
    }
  }

  static Future<List<AuthHistoryEntry>> loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_keyHistory) ?? [];
      return jsonList
          .map((s) => AuthHistoryEntry.fromJson(jsonDecode(s) as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint("StorageService.loadHistory error: $e");
      return [];
    }
  }

  // ── Theme ─────────────────────────────────────────────────────

  static Future<void> saveTheme(AppThemeStyle style, Color color) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyThemeStyle, style.index);
      await prefs.setInt(_keyAccentColor, color.toARGB32());
    } catch (e) {
      debugPrint("StorageService.saveTheme error: $e");
    }
  }

  static Future<(AppThemeStyle, Color)> loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final styleIdx = prefs.getInt(_keyThemeStyle);
      final colorVal = prefs.getInt(_keyAccentColor);

      final style =
          (styleIdx != null && styleIdx < AppThemeStyle.values.length)
              ? AppThemeStyle.values[styleIdx]
              : AppThemeStyle.darkBlue;

      final color =
          colorVal != null ? Color(colorVal) : Colors.cyanAccent;

      return (style, color);
    } catch (e) {
      debugPrint("StorageService.loadTheme error: $e");
      return (AppThemeStyle.darkBlue, Colors.cyanAccent);
    }
  }

  // ── Ngôn ngữ ─────────────────────────────────────────────────

  static Future<void> saveLanguage(AppLanguage lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLanguage, lang.index);
    } catch (e) {
      debugPrint("StorageService.saveLanguage error: $e");
    }
  }

  static Future<AppLanguage> loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt(_keyLanguage);
      return (idx != null && idx < AppLanguage.values.length)
          ? AppLanguage.values[idx]
          : AppLanguage.vi;
    } catch (e) {
      debugPrint("StorageService.loadLanguage error: $e");
      return AppLanguage.vi;
    }
  }

  // ── BLE Ownership flag (foreground / background phối hợp) ─────
  //
  // true  = Foreground app sở hữu BLE, background không được scan
  // false = App ở background, background service được scan
  //
  // Default = true (foreground) để tránh BG scan khi app vừa install

  static Future<void> setForegroundOwnership(bool owns) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyFgOwns, owns);
    } catch (e) {
      debugPrint("StorageService.setForegroundOwnership error: $e");
    }
  }

  static Future<bool> getForegroundOwnership() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyFgOwns) ?? true;
    } catch (e) {
      return true; // Safe default: assume foreground owns
    }
  }

  // ── Background auth cooldown ──────────────────────────────────
  //
  // Sau khi background auth thành công → đặt cooldown 60 giây
  // để tránh re-auth ngay lập tức trong vòng tiếp theo

  static Future<void> setAuthCooldown({
    Duration duration = const Duration(seconds: 60),
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.now().add(duration).millisecondsSinceEpoch;
      await prefs.setInt(_keyBgCooldown, until);
    } catch (e) {
      debugPrint("StorageService.setAuthCooldown error: $e");
    }
  }

  static Future<bool> isInAuthCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = prefs.getInt(_keyBgCooldown) ?? 0;
      return DateTime.now().millisecondsSinceEpoch < until;
    } catch (e) {
      return false;
    }
  }
}
