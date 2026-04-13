import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Core brand blues (matched with Home header gradient)
  static const Color navyDark = Color(0xFF0B1740);
  static const Color navyMid = Color(0xFF162460);
  static const Color navyLight = Color(0xFF1E3A8A);
  static const Color gold = Color(0xFFF5C518);
  static const Color goldLight = Color(0xFFFFF3CD);
  static const Color white = Colors.white;
  static const Color background = Color(0xFFF5F6FA);
  // Brand accent — use these instead of random colors
  static const Color accent = Color(0xFFF5C518); // same as gold
  static const Color surface = Color(0xFFF5F6FA); // same as background
  static const Color brandBlue = Color(0xFF162460); // same as navyMid
  static const Color cardWhite = Colors.white;
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMuted = Color(0xFF888888);
  static const Color red = Color(0xFFFF4757);
  static const Color blue = Color(0xFF2196F3);
  static const Color green = Color(0xFF4CAF50);
  static const Color orange = Color(0xFFFF9800);
  static const Color purple = Color(0xFF9C27B0);

  /// Dark editor chrome (dock / bars).
  static const Color editorBarTop = Color(0xFF1C1C1E);
  static const Color editorBarBottom = Color(0xFF0E0E0F);
  static const Color editorIconBg = Color(0xFF2C2C2E);
  static const Color editorIconBorder = Color(0x26FFFFFF);
}

class AppTheme {
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navyMid,
        primary: AppColors.navyMid,
        secondary: AppColors.gold,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navyMid,
        brightness: Brightness.dark,
        primary: AppColors.gold,
        secondary: AppColors.gold,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(ThemeData.dark().textTheme),
      scaffoldBackgroundColor: const Color(0xFF121212),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0D1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
