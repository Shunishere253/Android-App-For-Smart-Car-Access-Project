import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../services/crypto_service.dart';
import '../theme_manager.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _keyController;

  bool _isObscured = true;

  @override
  void initState() {
    super.initState();

    _keyController = TextEditingController(text: CryptoService.keyAsHexString);
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

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
                      AppLocalizations.t("settingsTitle"),
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(
                            Icons.info_outline,
                            AppLocalizations.t("appInfo"),
                          ),
                          _buildAppInfoCard(primaryColor),
                          const SizedBox(height: 30),

                          _buildSectionTitle(
                            Icons.language,
                            AppLocalizations.t("language"),
                          ),
                          _buildLanguageCard(),
                          const SizedBox(height: 30),

                          _buildSectionTitle(
                            Icons.color_lens,
                            AppLocalizations.t("accentColor"),
                          ),
                          _buildAccentColorCard(),
                          const SizedBox(height: 30),

                          _buildSectionTitle(
                            Icons.dark_mode,
                            AppLocalizations.t("themeMode"),
                          ),
                          _buildThemeModeCard(),
                          const SizedBox(height: 30),

                          _buildSectionTitle(
                            Icons.security,
                            AppLocalizations.t("securityAes"),
                          ),
                          _buildAesKeyCard(primaryColor),
                          const SizedBox(height: 30),
                        ],
                      ),
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

  Widget _buildAppInfoCard(Color primaryColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Text(
            "SMART CAR ACCESS",
            style: TextStyle(
              color: primaryColor,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            AppLocalizations.t("version"),
            style: TextStyle(color: ThemeManager.textSecondary, fontSize: 12),
          ),
          Divider(color: ThemeManager.borderColor, height: 30),
          _buildDevInfo(
            AppLocalizations.t("author"),
            "Lê Đình Bảo Tín",
            Icons.person,
            Colors.orangeAccent,
          ),
          const SizedBox(height: 15),
          _buildDevInfo(
            AppLocalizations.t("supporters"),
            "Nguyễn Thế Nhân\nPhan Bá Nguyễn Bảo",
            Icons.group,
            Colors.greenAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _languageOption(
            language: AppLanguage.vi,
            title: AppLocalizations.t("vietnamese"),
            subtitle: AppLocalizations.t("languageSubtitle"),
          ),
          Divider(color: ThemeManager.borderColor, height: 1),
          _languageOption(
            language: AppLanguage.en,
            title: AppLocalizations.t("english"),
            subtitle: AppLocalizations.t("languageSubtitle"),
          ),
        ],
      ),
    );
  }

  Widget _languageOption({
    required AppLanguage language,
    required String title,
    required String subtitle,
  }) {
    final selected = AppLocalizations.language.value == language;

    return ListTile(
      onTap: () {
        AppLocalizations.language.value = language;
      },
      leading: Icon(
        Icons.translate,
        color: selected
            ? ThemeManager.appColor.value
            : ThemeManager.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: ThemeManager.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: ThemeManager.textSecondary, fontSize: 12),
      ),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected
            ? ThemeManager.appColor.value
            : ThemeManager.textSecondary,
      ),
    );
  }

  Widget _buildAccentColorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ThemeManager.availableColors.map((color) {
          final bool selected = ThemeManager.appColor.value == color;

          return GestureDetector(
            onTap: () {
              ThemeManager.appColor.value = color;
              setState(() {});
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: selected ? 48 : 40,
              height: selected ? 48 : 40,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected
                      ? ThemeManager.textPrimary
                      : Colors.transparent,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.45),
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.black87, size: 22)
                  : null,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildThemeModeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _themeOption(
            title: "Dark Blue",
            subtitle: AppLocalizations.t("darkBlueSubtitle"),
            icon: Icons.nightlight_round,
            style: AppThemeStyle.darkBlue,
          ),
          _themeOption(
            title: "Light",
            subtitle: AppLocalizations.t("lightSubtitle"),
            icon: Icons.light_mode,
            style: AppThemeStyle.light,
          ),
          _themeOption(
            title: "Black",
            subtitle: AppLocalizations.t("blackSubtitle"),
            icon: Icons.dark_mode,
            style: AppThemeStyle.black,
          ),
          _themeOption(
            title: "White",
            subtitle: AppLocalizations.t("whiteSubtitle"),
            icon: Icons.wb_sunny,
            style: AppThemeStyle.white,
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required AppThemeStyle style,
  }) {
    final bool selected = ThemeManager.themeStyle.value == style;

    return ListTile(
      onTap: () {
        ThemeManager.themeStyle.value = style;
        setState(() {});
      },
      leading: Icon(
        icon,
        color: selected
            ? ThemeManager.appColor.value
            : ThemeManager.textSecondary,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: ThemeManager.textPrimary,
          fontWeight: selected ? FontWeight.bold : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: ThemeManager.textSecondary, fontSize: 12),
      ),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected
            ? ThemeManager.appColor.value
            : ThemeManager.textSecondary,
      ),
    );
  }

  Widget _buildAesKeyCard(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppLocalizations.t("appSecretKey"),
            style: TextStyle(color: ThemeManager.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _keyController,
            obscureText: _isObscured,
            readOnly: true,
            style: TextStyle(
              color: ThemeManager.textPrimary,
              fontFamily: 'monospace',
              fontSize: 14,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: ThemeManager.isLight
                  ? Colors.black.withValues(alpha: 0.04)
                  : Colors.black.withValues(alpha: 0.25),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _isObscured ? Icons.visibility : Icons.visibility_off,
                  color: primaryColor,
                ),
                onPressed: () {
                  setState(() {
                    _isObscured = !_isObscured;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            "Key HEX: ${CryptoService.keyAsHexString}",
            style: TextStyle(
              color: ThemeManager.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          SelectableText(
            "${AppLocalizations.t("accessStartCode")}: ${CryptoService.fixedChallengeAsHexString}",
            style: TextStyle(
              color: ThemeManager.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            "${AppLocalizations.t("insideCarMessage")}: ${CryptoService.userInsideCarCommandAsHexString}",
            style: TextStyle(
              color: ThemeManager.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.t("aesNote"),
            style: const TextStyle(
              color: Colors.redAccent,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 5),
      child: Row(
        children: [
          Icon(icon, color: ThemeManager.textSecondary, size: 20),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              color: ThemeManager.textSecondary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: ThemeManager.cardColor,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: ThemeManager.borderColor),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.15),
          blurRadius: 10,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _buildDevInfo(
    String role,
    String name,
    IconData icon,
    Color iconColor,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                role,
                style: TextStyle(
                  color: ThemeManager.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                style: TextStyle(
                  color: ThemeManager.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
