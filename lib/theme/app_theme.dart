import 'package:flutter/material.dart';

/// Modern dark-mode Material 3 theme designed specifically for media consumption.
class AppTheme {
  // Palette constants
  static const Color darkBackground = Color(0xFF0C0D14);
  static const Color darkSurface = Color(0xFF141722);
  static const Color darkSurfaceVariant = Color(0xFF1E2232);
  static const Color darkSurfaceContainer = Color(0xFF252A3D);

  static const Color primaryPurple = Color(0xFF7C4DFF);
  static const Color primaryPurpleLight = Color(0xFFB388FF);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentCoral = Color(0xFFFF5252);

  static const Color textPrimary = Color(0xFFF0F2F8);
  static const Color textSecondary = Color(0xFF9E9EB8);
  static const Color textMuted = Color(0xFF656985);

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme.dark(
      primary: primaryPurple,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF311B92),
      onPrimaryContainer: primaryPurpleLight,
      secondary: accentCyan,
      onSecondary: Colors.black,
      secondaryContainer: Color(0xFF004D5A),
      onSecondaryContainer: accentCyan,
      tertiary: accentCoral,
      onTertiary: Colors.white,
      error: Color(0xFFCF6679),
      onError: Colors.black,
      surface: darkSurface,
      onSurface: textPrimary,
      surfaceContainer: darkSurfaceContainer,
      surfaceContainerHigh: darkSurfaceVariant,
      outline: Color(0xFF2E344A),
      outlineVariant: Color(0xFF1E2232),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,
      canvasColor: darkSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFF222638), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: darkSurfaceVariant,
        labelStyle: const TextStyle(
          color: textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2C3247), width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceVariant,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C3247), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2C3247), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurple, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurple,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryPurple,
        inactiveTrackColor: Color(0xFF2A2E44),
        thumbColor: accentCyan,
        overlayColor: Color(0x337C4DFF),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3.5,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF1F2335),
        thickness: 1,
        space: 1,
      ),
    );
  }
}
