import 'package:flutter/material.dart';

class AppTheme {
  // Brand & Fintech Color Palette
  static const Color primaryDark = Color(0xFF1E293B); // Slate Blue / Deep Indigo
  static const Color primaryBlue = Color(0xFF3182F6); // Toss-style Clean Blue
  static const Color trustBlue = Color(0xFF2563EB); // Accent Action Blue
  static const Color softMint = Color(0xFF10B981); // Success & Active Indicator
  static const Color background = Color(0xFFF8FAFC); // Clean Off-White
  static const Color cardSurface = Color(0xFFFFFFFF); // Pure White

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A); // High Contrast Dark
  static const Color textSecondary = Color(0xFF64748B); // Slate Muted
  static const Color textTertiary = Color(0xFF94A3B8); // Light Grey Muted

  // Status Indicators
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF0EA5E9);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFFE2E8F0);
  static const Color chipBackground = Color(0xFFF1F5F9);

  // Soft Fintech Shadow
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.04),
          offset: Offset(0, 4),
          blurRadius: 16,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: primaryBlue.withAlpha((255 * 0.25).round()),
          offset: const Offset(0, 4),
          blurRadius: 12,
          spreadRadius: 0,
        ),
      ];

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      primaryColor: primaryBlue,
      colorScheme: ColorScheme.light(
        primary: primaryBlue,
        secondary: softMint,
        surface: cardSurface,
        onSurface: textPrimary,
        error: danger,
      ),
      fontFamily: 'Pretendard',
      fontFamilyFallback: const ['Pretendard', 'sans-serif'],
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: -0.6, color: textPrimary),
        displayMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: -0.5, color: textPrimary),
        headlineLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: -0.5, color: textPrimary),
        headlineMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: -0.4, color: textPrimary),
        headlineSmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: -0.3, color: textPrimary),
        titleLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: -0.3, color: textPrimary),
        titleMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w600, letterSpacing: -0.2, color: textPrimary),
        titleSmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w600, letterSpacing: -0.2, color: textSecondary),
        bodyLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w400, letterSpacing: -0.2, color: textPrimary, height: 1.45),
        bodyMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w400, letterSpacing: -0.2, color: textPrimary, height: 1.4),
        bodySmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w400, letterSpacing: -0.1, color: textSecondary, height: 1.35),
        labelLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w600, letterSpacing: -0.2),
        labelMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w500, letterSpacing: -0.1),
        labelSmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w500, letterSpacing: -0.1),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borderSubtle, width: 0.8),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: borderSubtle, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: cardSurface,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textSecondary,
        selectedLabelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 11, fontWeight: FontWeight.w500),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}
