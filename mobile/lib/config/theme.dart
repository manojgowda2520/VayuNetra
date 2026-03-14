import 'package:flutter/material.dart';

class VNColors {
  static const Color bg       = Color(0xFF020B18);
  static const Color bgCard   = Color(0xFF0D1F35);
  static const Color bgCard2  = Color(0xFF122840);
  static const Color cyan     = Color(0xFF00D4FF);
  static const Color saffron  = Color(0xFFFF9933);
  static const Color green    = Color(0xFF00E676);
  static const Color red      = Color(0xFFFF3D3D);
  static const Color orange   = Color(0xFFFF9933);
  static const Color yellow   = Color(0xFFFFC107);
  static const Color purple   = Color(0xFFA855F7);
  static const Color text     = Color(0xFFE8F4FD);
  static const Color muted    = Color(0xFF4A6580);
  static const Color border   = Color(0x2600D4FF);
}

Color severityColor(String severity) {
  switch (severity.toUpperCase()) {
    case 'CRITICAL': return VNColors.red;
    case 'HIGH':     return VNColors.orange;
    case 'MODERATE': return VNColors.yellow;
    case 'LOW':      return VNColors.green;
    default:         return VNColors.muted;
  }
}

String severityEmoji(String severity) {
  switch (severity.toUpperCase()) {
    case 'CRITICAL': return '🔴';
    case 'HIGH':     return '🟠';
    case 'MODERATE': return '🟡';
    case 'LOW':      return '🟢';
    default:         return '⚪';
  }
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: VNColors.bg,
    primaryColor: VNColors.cyan,
    fontFamily: 'DMSans',
    colorScheme: const ColorScheme.dark(
      primary: VNColors.cyan,
      secondary: VNColors.saffron,
      surface: VNColors.bgCard,
      background: VNColors.bg,
      error: VNColors.red,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: VNColors.bg,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Rajdhani',
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: VNColors.text,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: VNColors.bgCard,
      selectedItemColor: VNColors.cyan,
      unselectedItemColor: VNColors.muted,
      type: BottomNavigationBarType.fixed,
    ),
  );
}
