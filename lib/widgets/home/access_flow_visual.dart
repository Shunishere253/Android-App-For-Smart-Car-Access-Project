import 'package:flutter/material.dart';

import '../../localization/app_localizations.dart';
import '../../services/bluetooth_service.dart';
import '../../theme_manager.dart';

class AccessFlowVisual extends StatelessWidget {
  final bool isAccessGranted;
  final int? rssi;
  final Color primaryColor;

  const AccessFlowVisual({
    super.key,
    required this.isAccessGranted,
    required this.rssi,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final isInsideCar = isAccessGranted && BleController.hasSentUserInsideCar;

    String currentTitle;
    String currentSubtitle;
    Color currentColor;
    Widget currentIllustration;

    if (isInsideCar) {
      currentTitle = AppLocalizations.t("flowInsideCar");
      currentSubtitle = AppLocalizations.t("flowInsideCarSubtitle");
      currentColor = Colors.greenAccent;
      currentIllustration = Stack(
        alignment: Alignment.center,
        children: [
          CarDoorIllustration(
            isDoorOpen: true,
            activeColor: currentColor,
            muted: false,
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: _DriverAvatar(active: true, color: currentColor),
          ),
        ],
      );
    } else if (isAccessGranted) {
      currentTitle = AppLocalizations.t("flowUnlockedCar");
      currentSubtitle = AppLocalizations.t("flowUnlockedCarSubtitle");
      currentColor = primaryColor;
      currentIllustration = CarDoorIllustration(
        isDoorOpen: true,
        activeColor: currentColor,
        muted: false,
      );
    } else {
      currentTitle = AppLocalizations.t("flowClosedCar");
      currentSubtitle = AppLocalizations.t("flowClosedCarSubtitle");
      currentColor = ThemeManager.textSecondary.withValues(alpha: 0.5);
      currentIllustration = CarDoorIllustration(
        isDoorOpen: false,
        activeColor: primaryColor,
        muted: true,
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: ThemeManager.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isInsideCar ? Colors.greenAccent.withValues(alpha: 0.6) : (isAccessGranted ? primaryColor.withValues(alpha: 0.6) : ThemeManager.borderColor),
          width: isAccessGranted ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: (isInsideCar ? Colors.greenAccent : (isAccessGranted ? primaryColor : Colors.black)).withValues(alpha: isAccessGranted ? 0.2 : 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_rounded, color: isAccessGranted ? currentColor : ThemeManager.textSecondary.withValues(alpha: 0.5), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.t("accessStatus"),
                    style: TextStyle(
                      color: ThemeManager.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  _SignalChip(rssi: rssi, primaryColor: primaryColor),
                  const SizedBox(width: 6),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showFlowDetailsDialog(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: ThemeManager.borderColor.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          color: ThemeManager.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                width: 90,
                height: 70,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: currentColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: currentColor.withValues(alpha: 0.3)),
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(width: 76, height: 58, child: currentIllustration),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentTitle,
                      style: TextStyle(
                        color: isAccessGranted ? currentColor : ThemeManager.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentSubtitle,
                      style: TextStyle(
                        color: ThemeManager.textSecondary,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showFlowDetailsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isInsideCar = isAccessGranted && BleController.hasSentUserInsideCar;

        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            decoration: BoxDecoration(
              color: ThemeManager.isLight ? Colors.white : const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppLocalizations.t("flowDetails"),
                      style: TextStyle(
                        color: ThemeManager.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close, color: ThemeManager.textSecondary),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _FlowStep(
                        title: AppLocalizations.t("flowClosedCar"),
                        subtitle: AppLocalizations.t("flowClosedCarSubtitle"),
                        active: !isAccessGranted,
                        completed: isAccessGranted,
                        color: primaryColor,
                        child: CarDoorIllustration(
                          isDoorOpen: false,
                          activeColor: primaryColor,
                          muted: isAccessGranted,
                        ),
                      ),
                    ),
                    _FlowConnector(active: isAccessGranted, color: primaryColor),
                    Expanded(
                      child: _FlowStep(
                        title: AppLocalizations.t("flowUnlockedCar"),
                        subtitle: AppLocalizations.t("flowUnlockedCarSubtitle"),
                        active: isAccessGranted && !isInsideCar,
                        completed: isAccessGranted,
                        color: primaryColor,
                        child: CarDoorIllustration(
                          isDoorOpen: true,
                          activeColor: primaryColor,
                          muted: !isAccessGranted,
                        ),
                      ),
                    ),
                    _FlowConnector(
                      active: isAccessGranted || isInsideCar,
                      color: primaryColor,
                    ),
                    Expanded(
                      child: _FlowStep(
                        title: AppLocalizations.t("flowInsideCar"),
                        subtitle: AppLocalizations.t("flowInsideCarSubtitle"),
                        active: isInsideCar || isAccessGranted,
                        completed: isInsideCar && isAccessGranted,
                        color: isInsideCar ? Colors.greenAccent : primaryColor,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CarDoorIllustration(
                              isDoorOpen: true,
                              activeColor: isInsideCar
                                  ? Colors.greenAccent
                                  : primaryColor,
                              muted: !isAccessGranted && !isInsideCar,
                            ),
                            Positioned(
                              right: 4,
                              bottom: 4,
                              child: _DriverAvatar(
                                active: isInsideCar || isAccessGranted,
                                color: isInsideCar
                                    ? Colors.greenAccent
                                    : primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }
}

class _SignalChip extends StatelessWidget {
  final int? rssi;
  final Color primaryColor;

  const _SignalChip({required this.rssi, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final strongEnough = BleController.canAuthenticateWithRssi(rssi);
    final color = strongEnough ? primaryColor : Colors.orangeAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.26)),
      ),
      child: Text(
        rssi == null ? "-- dBm" : "$rssi dBm",
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool active;
  final bool completed;
  final Color color;
  final Widget child;

  const _FlowStep({
    required this.title,
    required this.subtitle,
    required this.active,
    required this.completed,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = completed || active ? color : ThemeManager.borderColor;
    final textColor = completed || active
        ? ThemeManager.textPrimary
        : ThemeManager.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      constraints: const BoxConstraints(minHeight: 172),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: completed || active ? 0.10 : 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 58,
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(width: 76, height: 58, child: child),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: ThemeManager.textSecondary,
              fontSize: 10.5,
              height: 1.18,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlowConnector extends StatelessWidget {
  final bool active;
  final Color color;

  const _FlowConnector({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 172,
      alignment: Alignment.center,
      child: Icon(
        Icons.chevron_right,
        color: active
            ? color
            : ThemeManager.textSecondary.withValues(alpha: 0.35),
        size: 20,
      ),
    );
  }
}

class _DriverAvatar extends StatelessWidget {
  final bool active;
  final Color color;

  const _DriverAvatar({required this.active, required this.color});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: active ? 1 : 0.35,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.55)),
        ),
        child: Icon(Icons.person, color: color, size: 17),
      ),
    );
  }
}

class CarDoorIllustration extends StatelessWidget {
  final bool isDoorOpen;
  final Color activeColor;
  final bool muted;

  const CarDoorIllustration({
    super.key,
    required this.isDoorOpen,
    required this.activeColor,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CarDoorPainter(
        isDoorOpen: isDoorOpen,
        activeColor: activeColor,
        muted: muted,
        isLight: ThemeManager.isLight,
      ),
    );
  }
}

class _CarDoorPainter extends CustomPainter {
  final bool isDoorOpen;
  final Color activeColor;
  final bool muted;
  final bool isLight;

  const _CarDoorPainter({
    required this.isDoorOpen,
    required this.activeColor,
    required this.muted,
    required this.isLight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final opacity = muted ? 0.48 : 1.0;
    final bodyPaint = Paint()
      ..color = activeColor.withValues(alpha: 0.72 * opacity)
      ..style = PaintingStyle.fill;
    final detailPaint = Paint()
      ..color = (isLight ? Colors.black87 : Colors.white).withValues(
        alpha: 0.82 * opacity,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final glassPaint = Paint()
      ..color = Colors.white.withValues(alpha: isLight ? 0.62 : 0.30)
      ..style = PaintingStyle.fill;
    final wheelPaint = Paint()
      ..color = (isLight ? Colors.black87 : Colors.white).withValues(
        alpha: 0.82 * opacity,
      )
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.10, h * 0.38, w * 0.78, h * 0.30),
      Radius.circular(w * 0.10),
    );

    final roof = Path()
      ..moveTo(w * 0.25, h * 0.39)
      ..quadraticBezierTo(w * 0.38, h * 0.13, w * 0.61, h * 0.27)
      ..quadraticBezierTo(w * 0.72, h * 0.32, w * 0.78, h * 0.39)
      ..close();

    canvas.drawPath(roof, bodyPaint);
    canvas.drawRRect(body, bodyPaint);

    final window = Path()
      ..moveTo(w * 0.34, h * 0.37)
      ..quadraticBezierTo(w * 0.43, h * 0.22, w * 0.58, h * 0.31)
      ..lineTo(w * 0.66, h * 0.38)
      ..close();
    canvas.drawPath(window, glassPaint);

    canvas.drawLine(
      Offset(w * 0.48, h * 0.43),
      Offset(w * 0.48, h * 0.66),
      detailPaint,
    );

    if (isDoorOpen) {
      final doorPaint = Paint()
        ..color = activeColor.withValues(alpha: 0.50 * opacity)
        ..style = PaintingStyle.fill;
      final door = Path()
        ..moveTo(w * 0.50, h * 0.42)
        ..lineTo(w * 0.90, h * 0.24)
        ..lineTo(w * 0.96, h * 0.58)
        ..lineTo(w * 0.54, h * 0.67)
        ..close();

      canvas.drawPath(door, doorPaint);
      canvas.drawPath(door, detailPaint);
    } else {
      canvas.drawLine(
        Offset(w * 0.66, h * 0.46),
        Offset(w * 0.73, h * 0.46),
        detailPaint,
      );
    }

    canvas.drawCircle(Offset(w * 0.27, h * 0.70), w * 0.08, wheelPaint);
    canvas.drawCircle(Offset(w * 0.72, h * 0.70), w * 0.08, wheelPaint);
    canvas.drawLine(
      Offset(w * 0.12, h * 0.82),
      Offset(w * 0.88, h * 0.82),
      detailPaint..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _CarDoorPainter oldDelegate) {
    return oldDelegate.isDoorOpen != isDoorOpen ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.muted != muted ||
        oldDelegate.isLight != isLight;
  }
}
