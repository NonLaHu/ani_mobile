import 'package:flutter/material.dart';

/// Modern dark and light Material 3 themes designed specifically for anime streaming and media consumption.
class AppTheme {
  // Dark Palette constants
  static const Color darkBackground = Color(0xFF0C0D14);
  static const Color darkSurface = Color(0xFF141722);
  static const Color darkSurfaceVariant = Color(0xFF1E2232);
  static const Color darkSurfaceContainer = Color(0xFF252A3D);

  // Light Palette constants
  static const Color lightBackground = Color(0xFFF6F7FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFEEF0F7);
  static const Color lightSurfaceContainer = Color(0xFFE2E6F2);

  static const Color primaryPurple = Color(0xFF7C4DFF);
  static const Color primaryPurpleLight = Color(0xFFB388FF);
  static const Color primaryPurpleDark = Color(0xFF5E35B1);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentCyanDark = Color(0xFF0097A7);
  static const Color accentCoral = Color(0xFFFF5252);
  static const Color accentGreen = Color(0xFF00E676);

  // Text Colors
  static const Color textPrimary = Color(0xFFF0F2F8);
  static const Color textSecondary = Color(0xFF9E9EB8);
  static const Color textMuted = Color(0xFF656985);

  static const Color lightTextPrimary = Color(0xFF191C24);
  static const Color lightTextSecondary = Color(0xFF505569);
  static const Color lightTextMuted = Color(0xFF868C9E);

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
      dialogTheme: DialogThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFF2C3247), width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E2232),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: accentCyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2C3247), width: 1),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme.light(
      primary: primaryPurpleDark,
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFEDE7F6),
      onPrimaryContainer: primaryPurpleDark,
      secondary: accentCyanDark,
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFE0F7FA),
      onSecondaryContainer: Color(0xFF006064),
      tertiary: accentCoral,
      onTertiary: Colors.white,
      error: Color(0xFFB00020),
      onError: Colors.white,
      surface: lightSurface,
      onSurface: lightTextPrimary,
      surfaceContainer: lightSurfaceContainer,
      surfaceContainerHigh: lightSurfaceVariant,
      outline: Color(0xFFD6DAE6),
      outlineVariant: Color(0xFFE5E8F2),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,
      canvasColor: lightSurface,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: lightTextPrimary),
        titleTextStyle: TextStyle(
          color: lightTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 1,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE3E6F0), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: lightSurfaceVariant,
        labelStyle: const TextStyle(
          color: lightTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFD3D8E5), width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        hintStyle: const TextStyle(color: lightTextMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD3D8E5), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD3D8E5), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryPurpleDark, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryPurpleDark,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: primaryPurpleDark,
        inactiveTrackColor: Color(0xFFD6DAE6),
        thumbColor: accentCyanDark,
        overlayColor: Color(0x335E35B1),
        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
        trackHeight: 3.5,
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E5EE),
        thickness: 1,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFD3D8E5), width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: lightTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: lightTextSecondary,
          fontSize: 14,
          height: 1.4,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF191C24),
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: accentCyan,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
