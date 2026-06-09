import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../models/auth_history_entry.dart';
import '../theme_manager.dart';

class HistoryScreen extends StatelessWidget {
  final List<AuthHistoryEntry> history;

  const HistoryScreen({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalizations.language,
      builder: (context, language, child) {
        return ValueListenableBuilder<AppThemeStyle>(
          valueListenable: ThemeManager.themeStyle,
          builder: (context, themeStyle, child) {
            return ValueListenableBuilder<Color>(
              valueListenable: ThemeManager.appColor,
              builder: (context, primaryColor, child) {
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  appBar: AppBar(
                    title: Text(
                      AppLocalizations.t("authHistory"),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ThemeManager.textPrimary,
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    centerTitle: true,
                    iconTheme: IconThemeData(color: ThemeManager.textPrimary),
                  ),
                  body: Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: ThemeManager.backgroundGradient,
                      ),
                    ),
                    child: history.isEmpty
                        ? _EmptyHistory(primaryColor: primaryColor)
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                            itemCount: history.length,
                            separatorBuilder: (context, index) {
                              return const SizedBox(height: 12);
                            },
                            itemBuilder: (context, index) {
                              return _HistoryCard(entry: history[index]);
                            },
                          ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  final Color primaryColor;

  const _EmptyHistory({required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(24),
        decoration: _cardDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history, color: primaryColor, size: 38),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.t("noAuthHistory"),
              style: TextStyle(
                color: ThemeManager.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              AppLocalizations.t("authHistoryHint"),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: ThemeManager.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final AuthHistoryEntry entry;

  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final resultColor = entry.isPass ? Colors.greenAccent : Colors.redAccent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: resultColor.withValues(alpha: 0.18),
                child: Icon(
                  entry.isPass ? Icons.verified : Icons.error_outline,
                  color: resultColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.isPass
                          ? AppLocalizations.t("authSuccess")
                          : AppLocalizations.t("authFail"),
                      style: TextStyle(
                        color: ThemeManager.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _formatDateTime(entry.authenticatedAt),
                      style: TextStyle(
                        color: ThemeManager.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                entry.mcuResult,
                style: TextStyle(
                  color: resultColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoRow(
            label: AppLocalizations.t("authRssi"),
            value: entry.rssi == null ? "-- dBm" : "${entry.rssi} dBm",
          ),
          _InfoRow(
            label: AppLocalizations.t("insideVehicleStatus"),
            value: entry.userInsideCarNotified
                ? AppLocalizations.t("insideVehicleDetected")
                : AppLocalizations.t("insideVehicleNotReached"),
          ),
          const SizedBox(height: 8),
          _HexBlock(
            label: AppLocalizations.t("challengeCode"),
            value: entry.challengeHex,
          ),
          _HexBlock(
            label: AppLocalizations.t("vehicleAuthData"),
            value: entry.plaintextHex,
          ),
          _HexBlock(
            label: AppLocalizations.t("encryptedData"),
            value: entry.cipherHex,
          ),
        ],
      ),
    );
  }

  static String _formatDateTime(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    final year = value.year.toString();
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    final second = value.second.toString().padLeft(2, '0');

    return "$day/$month/$year $hour:$minute:$second";
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: ThemeManager.textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: ThemeManager.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HexBlock extends StatelessWidget {
  final String label;
  final String value;

  const _HexBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: ThemeManager.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(
              color: ThemeManager.textPrimary,
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: ThemeManager.cardColor,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: ThemeManager.borderColor),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 10,
        offset: const Offset(0, 5),
      ),
    ],
  );
}
