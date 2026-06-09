import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'localization/app_localizations.dart';
import 'screens/home_screen.dart';

void main() {
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
