part of '../home_screen.dart';

mixin _HomeBuild on State<HomeScreen>, _HomeStateAccess {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppThemeStyle>(
      valueListenable: ThemeManager.themeStyle,
      builder: (context, themeStyle, child) {
        return ValueListenableBuilder<Color>(
          valueListenable: ThemeManager.appColor,
          builder: (context, primaryColor, child) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: SizedBox.expand(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: ThemeManager.backgroundGradient,
                    ),
                  ),
                  child: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(bottom: 30),
                      child: Column(
                        children: [
                          HomeHeader(
                            onSettingsPressed: openSettingsScreen,
                            onHistoryPressed: openHistoryScreen,
                          ),
                          const SizedBox(height: 8),
                          AccessFlowVisual(
                            isAccessGranted: isAccessAuthenticated,
                            rssi: bleRssi,
                            primaryColor: primaryColor,
                          ),
                          const SizedBox(height: 24),
                          CarStatusCircle(
                            isConnected: isConnected,
                            primaryColor: primaryColor,
                            statusColor: statusColor,
                          ),
                          const SizedBox(height: 28),
                          StatusBadge(
                            statusText: statusText,
                            statusColor: statusColor,
                            primaryColor: primaryColor,
                            isConnected: isConnected,
                          ),
                          const SizedBox(height: 12),
                          BleRssiBadge(
                            rssi: bleRssi,
                            primaryColor: primaryColor,
                            isConnected: isConnected,
                            isScanning: isScanning,
                          ),
                          const SizedBox(height: 20),
                          AesInfoCard(
                            primaryColor: primaryColor,
                            uartLastMessage: uartLastMessage,
                            plaintextHex: plaintextHex,
                            cipherHex: cipherHex,
                            aesResult: aesResult,
                            aesResultColor: aesResultColor,
                            isAuthenticating: isAuthenticating,
                            isAccessAuthenticated: isAccessAuthenticated,
                            onAuthPressed: () =>
                                runAesHandshake(autoRun: false),
                          ),
                          const SizedBox(height: 28),

                          // Tạm thời ẩn các tính năng khóa xe / mở xe / tìm xe.
                          // Khi cần bật lại, import CommandButtons và thêm lại widget ở đây.
                          ConnectButton(
                            isConnected: isConnected,
                            isScanning: isScanning,
                            primaryColor: primaryColor,
                            onPressed: () => connectToCar(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
