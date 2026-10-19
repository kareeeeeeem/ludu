import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
  static const background = Color(0xFFE6F8FF);
  static const surfaceDark = Color(0xFFFFFCF1);
  static const surfaceLight = Color(0xFFFFFFFF);
  static const glassBorder = Color(0xFFB9D9E0);
  static const ink = Color(0xFF234359);
  static const mutedInk = Color(0xFF5D7988);

  // Accent Colors
  static const gold = Color(0xFFD88A0B);
  static const goldLight = Color(0xFF895617);
  static const emerald = Color(0xFF10B981);
  static const emeraldDark = Color(0xFF059669);
  static const violet = Color(0xFF8B5CF6);
  static const ruby = Color(0xFFEF4444);

  // Player Color Palette
  static const playerRed = Color(0xFFEF4444);
  static const playerGreen = Color(0xFF10B981);
  static const playerYellow = Color(0xFFF59E0B);
  static const playerBlue = Color(0xFF3B82F6);

  // Gradients
  static const goldGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFFD700), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const emeraldGradient = LinearGradient(
    colors: [Color(0xFF059669), Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkCardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFFFF5D7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const boardBgGradient = RadialGradient(
    colors: [Color(0xFFFFF8DF), Color(0xFFFFDD9C)],
    radius: 1.2,
  );
}

class AppTheme {
  static ThemeData get brightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: const ColorScheme.light(
        primary: AppColors.ink,
        secondary: AppColors.emerald,
        surface: AppColors.surfaceDark,
        error: AppColors.ruby,
      ),
      fontFamily: 'Roboto',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
        ),
        headlineMedium: TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
        ),
        titleLarge: TextStyle(
          color: AppColors.ink,
          fontWeight: FontWeight.w900,
        ),
        bodyMedium: TextStyle(color: AppColors.ink),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.glassBorder, width: 1),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Color(0xFFFFFCF1),
        indicatorColor: Color(0xFFFFE797),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.glassBorder),
        ),
      ),
    );
  }
}
