import 'package:flutter/material.dart';

class AppTheme {
  // Brand & High-End Luxury Fintech Color Palette
  static const Color primaryDark = Color(0xFF09090B); // Pure Onyx Black (Linear / Apple style)
  static const Color primaryBlue = Color(0xFF1D4ED8); // Deep Royal Sapphire
  static const Color trustBlue = Color(0xFF2563EB); // Refined Action Blue
  static const Color softMint = Color(0xFF059669); // Deep Emerald
  static const Color background = Color(0xFFF9FAFB); // Pure Minimalist Canvas
  static const Color cardSurface = Color(0xFFFFFFFF); // Pure White

  // Text Colors
  static const Color textPrimary = Color(0xFF09090B); // High-Contrast Deep Obsidian
  static const Color textSecondary = Color(0xFF71717A); // Refined Slate Muted
  static const Color textTertiary = Color(0xFFA1A1AA); // Titanium Muted

  // Status Indicators
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF0284C7);

  // Borders & Dividers
  static const Color borderSubtle = Color(0xFFE4E4E7); // Ultra-fine Precision Hairline
  static const Color chipBackground = Color(0xFFF4F4F5);

  // Senior High-Contrast Palette (고령자/시니어 맞춤 팔레트)
  static const Color seniorTextPrimary = Color(0xFF000000); // 100% Black for maximum contrast
  static const Color seniorTextSecondary = Color(0xFF18181B); // Dark Slate
  static const Color seniorPrimaryBlue = Color(0xFF1D4ED8); // Deep Blue (WCAG AAA contrast > 7:1 against white)
  static const Color seniorBorder = Color(0xFF71717A); // Distinct visible border
  static const Color seniorBackground = Color(0xFFFFFFFF); // Pure white background
  static const Color seniorCardSurface = Color(0xFFF8FAFC); // Clean crisp card surface

  // Micro Ambient Shadow (Clean, Crisp, Non-blurry)
  static List<BoxShadow> get cardShadow => [
        const BoxShadow(
          color: Color.fromRGBO(0, 0, 0, 0.03),
          offset: Offset(0, 2),
          blurRadius: 10,
          spreadRadius: 0,
        ),
      ];

  static List<BoxShadow> get buttonShadow => [
        BoxShadow(
          color: primaryBlue.withAlpha((255 * 0.16).round()),
          offset: const Offset(0, 4),
          blurRadius: 10,
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

  /// High-Contrast, Large-Text Theme optimized for senior/elderly small business directors
  static ThemeData get seniorTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: seniorBackground,
      primaryColor: seniorPrimaryBlue,
      colorScheme: const ColorScheme.light(
        primary: seniorPrimaryBlue,
        secondary: Color(0xFF047857), // Deep emerald green
        surface: seniorCardSurface,
        onSurface: seniorTextPrimary,
        error: Color(0xFFB91C1C), // Deep crimson
      ),
      fontFamily: 'Pretendard',
      fontFamilyFallback: const ['Pretendard', 'sans-serif'],
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w900, letterSpacing: -0.2, color: seniorTextPrimary, fontSize: 34),
        displayMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w900, letterSpacing: -0.2, color: seniorTextPrimary, fontSize: 30),
        headlineLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w900, letterSpacing: -0.2, color: seniorTextPrimary, fontSize: 26),
        headlineMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w900, letterSpacing: -0.2, color: seniorTextPrimary, fontSize: 23),
        headlineSmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w900, letterSpacing: -0.2, color: seniorTextPrimary, fontSize: 21),
        titleLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w900, letterSpacing: -0.2, color: seniorTextPrimary, fontSize: 20),
        titleMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, letterSpacing: -0.1, color: seniorTextPrimary, fontSize: 18),
        titleSmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, letterSpacing: -0.1, color: seniorTextSecondary, fontSize: 16),
        bodyLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: 0, color: seniorTextPrimary, fontSize: 18, height: 1.5),
        bodyMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w600, letterSpacing: 0, color: seniorTextPrimary, fontSize: 16, height: 1.5),
        bodySmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w600, letterSpacing: 0, color: seniorTextSecondary, fontSize: 14.5, height: 1.45),
        labelLarge: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, letterSpacing: 0, fontSize: 16),
        labelMedium: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w800, letterSpacing: 0, fontSize: 14.5),
        labelSmall: TextStyle(fontFamily: 'Pretendard', fontWeight: FontWeight.w700, letterSpacing: 0, fontSize: 13),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: seniorBackground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Pretendard',
          color: seniorTextPrimary,
          fontSize: 23,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: seniorTextPrimary, size: 28),
      ),
      cardTheme: CardThemeData(
        color: seniorCardSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: seniorBorder, width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: seniorPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          minimumSize: const Size(64, 54),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 17,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: seniorTextPrimary,
          side: const BorderSide(color: seniorBorder, width: 2.0),
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Pretendard',
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: seniorPrimaryBlue,
        unselectedItemColor: Color(0xFF475569),
        selectedLabelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 13, fontWeight: FontWeight.w800),
        unselectedLabelStyle: TextStyle(fontFamily: 'Pretendard', fontSize: 12, fontWeight: FontWeight.w700),
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }
}
