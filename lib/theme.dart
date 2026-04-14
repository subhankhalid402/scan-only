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
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navyMid,
        primary: AppColors.navyMid,
        secondary: AppColors.gold,
      ),
      textTheme: GoogleFonts.nunitoTextTheme(),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.cardWhite,
      canvasColor: AppColors.background,
      dividerColor: AppColors.navyDark.withValues(alpha: 0.12),
      iconTheme: const IconThemeData(color: AppColors.navyDark),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 18,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.cardWhite,
        titleTextStyle: GoogleFonts.nunito(
          color: AppColors.navyDark,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: GoogleFonts.nunito(
          color: AppColors.textDark,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.navyDark,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.cardWhite,
        textStyle: GoogleFonts.nunito(
          color: AppColors.navyDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.navyDark.withValues(alpha: 0.06),
        selectedColor: AppColors.gold.withValues(alpha: 0.24),
        side: BorderSide(color: AppColors.navyDark.withValues(alpha: 0.14)),
        labelStyle: GoogleFonts.nunito(
          color: AppColors.navyDark,
          fontWeight: FontWeight.w700,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: AppColors.navyDark.withValues(alpha: 0.2),
        thumbColor: AppColors.gold,
        overlayColor: AppColors.gold.withValues(alpha: 0.15),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        hintStyle: GoogleFonts.nunito(
          color: AppColors.textMuted.withValues(alpha: 0.92),
          fontWeight: FontWeight.w600,
        ),
        labelStyle: GoogleFonts.nunito(
          color: AppColors.navyMid,
          fontWeight: FontWeight.w700,
        ),
        floatingLabelStyle: GoogleFonts.nunito(
          color: AppColors.navyDark,
          fontWeight: FontWeight.w800,
        ),
        helperStyle: GoogleFonts.nunito(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.navyDark.withValues(alpha: 0.38)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: AppColors.navyDark.withValues(alpha: 0.22)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.gold, width: 1.8),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.red, width: 1.4),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: AppColors.red, width: 1.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDark,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyDark,
          side: BorderSide(color: AppColors.navyDark.withValues(alpha: 0.2)),
          minimumSize: const Size(0, 38),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navyMid,
          textStyle: GoogleFonts.nunito(fontWeight: FontWeight.w800),
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
