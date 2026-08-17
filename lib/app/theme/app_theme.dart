import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFFFF7A3A);
  static const primaryDark = Color(0xFFFF4D3D);
  static const primarySoft = Color(0xFFFFF1E8);
  static const accent = Color(0xFFFF8C42);
  static const danger = Color(0xFFE76F51);
  static const warning = Color(0xFFE9C46A);
  static const success = Color(0xFF22C55E);

  static const lightBackground = Color(0xFFF6F6F8);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightText = Color(0xFF1C1C1E);
  static const mutedText = Color(0xFF9A9AA0);
  static const iconMuted = Color(0xFFC5C5CA);

  static const darkBackground = Color(0xFF101114);
  static const darkSurface = Color(0xFF1C1D22);
  static const darkText = Color(0xFFF5F7FA);

  static const chartFood = Color(0xFFFF7A3A);
  static const chartDrink = Color(0xFF4C8DFF);
  static const chartSnack = Color(0xFF3EC6D9);
  static const chartDessert = Color(0xFFF5C242);
  static const chartOther = Color(0xFF9B8AFB);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9A4D), Color(0xFFFF6B3A), Color(0xFFFF4D3D)],
  );

  static Color categoryColor(String name) {
    switch (name.toLowerCase()) {
      case 'food':
        return chartFood;
      case 'drink':
      case 'drinks':
        return chartDrink;
      case 'snack':
      case 'snacks':
        return chartSnack;
      case 'dessert':
      case 'grocery':
        return chartDessert;
      default:
        return chartOther;
    }
  }
}

class AppTheme {
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final textTheme = GoogleFonts.plusJakartaSansTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: brightness,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      ),
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        margin: EdgeInsets.zero,
      ),
      dividerColor: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : const Color(0xFFEEEEF0),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? const Color(0xFF2A2B32) : const Color(0xFFF3F3F5),
        hintStyle: TextStyle(color: AppColors.mutedText.withValues(alpha: 0.9)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          textStyle: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
      chipTheme: ChipThemeData(
        selectedColor: AppColors.primary,
        backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF3F3F5),
        labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
        secondaryLabelStyle: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.iconMuted,
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        elevation: 0,
      ),
    );
  }
}
