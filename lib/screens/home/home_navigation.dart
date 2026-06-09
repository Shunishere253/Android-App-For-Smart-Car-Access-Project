part of '../home_screen.dart';

mixin _HomeNavigation on State<HomeScreen>, _HomeStateAccess {
  @override
  void openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  @override
  void openHistoryScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HistoryScreen(history: history)),
    );
  }
}
