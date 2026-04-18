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

/// 8dp-style spacing (Material layout).
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;

  /// Default horizontal inset for screen bodies.
  static const double screenHorizontal = 16;
}

/// Corner radii used across cards, sheets, and inputs.
class AppRadii {
  AppRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const BorderRadius card =
      BorderRadius.all(Radius.circular(14));
}

/// Light form styling for OCR / scan result screens on [AppColors.background].
class ScanResultFormStyle {
  ScanResultFormStyle._();

  static BoxDecoration insightCardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: AppColors.cardWhite,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: borderColor ?? AppColors.navyDark.withValues(alpha: 0.12),
      ),
    );
  }

  static TextStyle cardTitle({double fontSize = 16}) => GoogleFonts.nunito(
        color: AppColors.navyDark,
        fontWeight: FontWeight.w800,
        fontSize: fontSize,
      );

  static TextStyle label({double fontSize = 14}) => GoogleFonts.nunito(
        color: AppColors.navyMid,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
      );

  static TextStyle inputText({double fontSize = 14}) => GoogleFonts.nunito(
        color: AppColors.textDark,
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
      );

  static TextStyle muted({double fontSize = 13}) => GoogleFonts.nunito(
        color: AppColors.textMuted,
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
      );

  static TextStyle bodyLine({double fontSize = 13}) => GoogleFonts.nunito(
        color: AppColors.textDark,
        fontWeight: FontWeight.w600,
        fontSize: fontSize,
      );

  /// Labels next to inputs inside dark-tinted panels (e.g. receipt blocks).
  static TextStyle labelOnDarkPanel({double fontSize = 12}) => GoogleFonts.nunito(
        color: Colors.white.withValues(alpha: 0.88),
        fontWeight: FontWeight.w700,
        fontSize: fontSize,
      );

  static InputDecoration textFieldDecoration({
    double radius = 12,
    String? errorText,
  }) {
    final br = BorderRadius.circular(radius);
    final subtle =
        BorderSide(color: AppColors.navyDark.withValues(alpha: 0.22));
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.cardWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      errorText: errorText,
      border: OutlineInputBorder(borderRadius: br, borderSide: subtle),
      enabledBorder: OutlineInputBorder(borderRadius: br, borderSide: subtle),
      focusedBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: BorderSide(color: AppColors.red.withValues(alpha: 0.9)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: const BorderSide(color: AppColors.red, width: 1.8),
      ),
    );
  }

  /// White input on dark panels (receipt / medicine rows).
  static InputDecoration textFieldOnDarkPanel({double radius = 8}) {
    final br = BorderRadius.circular(radius);
    final subtle =
        BorderSide(color: AppColors.navyDark.withValues(alpha: 0.18));
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColors.cardWhite,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      border: OutlineInputBorder(borderRadius: br, borderSide: subtle),
      enabledBorder: OutlineInputBorder(borderRadius: br, borderSide: subtle),
      focusedBorder: OutlineInputBorder(
        borderRadius: br,
        borderSide: const BorderSide(color: AppColors.gold, width: 1.6),
      ),
    );
  }
}

/// Shared layout for primary actions (Material 3 / common app patterns).
class AppButtonSizes {
  AppButtonSizes._();

  /// Minimum tap height (48dp) — matches Material accessibility guidance.
  static const double height = 48;

  /// Horizontal padding for label + icon.
  static const double paddingH = 20;

  static const double paddingV = 12;

  /// Corner radius for filled / outlined actions.
  static const double radius = 12;

  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: paddingH,
    vertical: paddingV,
  );

  static const BorderRadius borderRadius =
      BorderRadius.all(Radius.circular(radius));

  static const Size minimumSize = Size(64, height);
}

class AppTheme {
  static ThemeData get theme {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navyMid,
      brightness: Brightness.light,
      primary: AppColors.navyMid,
      onPrimary: Colors.white,
      secondary: AppColors.gold,
      onSecondary: AppColors.navyDark,
      surface: AppColors.cardWhite,
      onSurface: AppColors.textDark,
      error: AppColors.red,
    );

    return ThemeData(
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      applyElevationOverlayColor: false,
      colorScheme: baseScheme,
      textTheme: GoogleFonts.nunitoTextTheme().apply(
        bodyColor: AppColors.textDark,
        displayColor: AppColors.navyDark,
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardColor: AppColors.cardWhite,
      canvasColor: AppColors.background,
      dividerColor: AppColors.navyDark.withValues(alpha: 0.12),
      iconTheme: const IconThemeData(color: AppColors.navyDark, size: 22),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.navyMid,
        circularTrackColor: Color(0x1A162460),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        contentTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: const Duration(milliseconds: 400),
        textStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        decoration: BoxDecoration(
          color: AppColors.navyDark.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
        titleTextStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: AppColors.textDark,
        ),
        subtitleTextStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: AppColors.textMuted,
        ),
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.navyDark.withValues(alpha: 0.1),
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.cardWhite,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: AppColors.cardWhite,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        dragHandleColor: AppColors.textMuted.withValues(alpha: 0.5),
        dragHandleSize: const Size(40, 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardWhite,
        indicatorColor: AppColors.gold.withValues(alpha: 0.35),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            color: selected ? AppColors.navyDark : AppColors.textMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.navyDark : AppColors.textMuted,
            size: 24,
          );
        }),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.navyDark,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
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
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
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
          elevation: 1,
          shadowColor: AppColors.navyDark.withValues(alpha: 0.18),
          minimumSize: AppButtonSizes.minimumSize,
          padding: AppButtonSizes.padding,
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.navyMid,
          foregroundColor: Colors.white,
          minimumSize: AppButtonSizes.minimumSize,
          padding: AppButtonSizes.padding,
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navyDark,
          side: BorderSide(
            color: AppColors.navyDark.withValues(alpha: 0.28),
            width: 1.2,
          ),
          minimumSize: AppButtonSizes.minimumSize,
          padding: AppButtonSizes.padding,
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.navyMid,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final darkScheme = ColorScheme.fromSeed(
      seedColor: AppColors.navyMid,
      brightness: Brightness.dark,
      primary: AppColors.gold,
      secondary: AppColors.gold,
      surface: const Color(0xFF1E1E1E),
    ).copyWith(
      onSurface: const Color(0xFFE8EAED),
      onSurfaceVariant: const Color(0xFFB0B8C4),
      outline: Colors.white.withValues(alpha: 0.14),
      surfaceContainerHighest: const Color(0xFF2C2C2C),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      applyElevationOverlayColor: false,
      colorScheme: darkScheme,
      textTheme: GoogleFonts.nunitoTextTheme(
        ThemeData(brightness: Brightness.dark, useMaterial3: true).textTheme,
      ).apply(
        bodyColor: darkScheme.onSurface,
        displayColor: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212),
      canvasColor: const Color(0xFF121212),
      cardColor: const Color(0xFF1E1E1E),
      iconTheme: IconThemeData(color: darkScheme.onSurface, size: 22),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.gold,
        circularTrackColor: AppColors.gold.withValues(alpha: 0.2),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: darkScheme.onSurfaceVariant,
        textColor: darkScheme.onSurface,
        titleTextStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w700,
          fontSize: 16,
          color: darkScheme.onSurface,
        ),
        subtitleTextStyle: GoogleFonts.nunito(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: darkScheme.onSurfaceVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: GoogleFonts.nunito(
          color: darkScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF2A2A2A),
        textStyle: GoogleFonts.nunito(
          color: darkScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: GoogleFonts.nunito(
          color: darkScheme.onSurfaceVariant.withValues(alpha: 0.85),
          fontWeight: FontWeight.w600,
        ),
        labelStyle: GoogleFonts.nunito(
          color: AppColors.gold,
          fontWeight: FontWeight.w700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: darkScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
        contentTextStyle: GoogleFonts.nunito(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.card),
      ),
      dividerTheme: DividerThemeData(
        color: Colors.white.withValues(alpha: 0.08),
        thickness: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF1E1E1E),
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF0D1B4B),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDark,
          elevation: 1,
          minimumSize: AppButtonSizes.minimumSize,
          padding: AppButtonSizes.padding,
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.navyDark,
          minimumSize: AppButtonSizes.minimumSize,
          padding: AppButtonSizes.padding,
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
          minimumSize: AppButtonSizes.minimumSize,
          padding: AppButtonSizes.padding,
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: AppButtonSizes.borderRadius,
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
