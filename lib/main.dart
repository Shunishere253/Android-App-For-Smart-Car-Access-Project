import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/app_localizations.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'theme_manager.dart';

Future<void> main() async {
  // Bắt buộc trước khi dùng bất kỳ plugin nào
  WidgetsFlutterBinding.ensureInitialized();

  // Load config đã lưu từ lần trước (theme, màu, ngôn ngữ)
  // Chạy song song để giảm startup time
  await Future.wait([
    ThemeManager.loadFromStorage(),
    AppLocalizations.loadFromStorage(),
    NotificationService.initialize(),
  ]);

  runApp(const SmartCarAccessApp());
}

class SmartCarAccessApp extends StatelessWidget {
  const SmartCarAccessApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: AppLocalizations.language,
      builder: (context, language, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: AppLocalizations.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const HomeScreen(),
        );
      },
    );
  }
}
