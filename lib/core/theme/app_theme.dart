import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF68DBA9),
        brightness: Brightness.dark,
        surface: const Color(0xFF142820));
    return ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0C1B16),
        fontFamily: 'PlusJakartaSans',
        textTheme: Typography.material2021().white.apply(
            fontFamily: 'PlusJakartaSans',
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface),
        appBarTheme: AppBarTheme(
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            backgroundColor: scheme.surface,
            foregroundColor: scheme.onSurface),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: scheme.surfaceContainerHigh,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(18))),
        cardTheme: CardThemeData(
            elevation: 0,
            color: scheme.surfaceContainer,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22))),
        filledButtonTheme: light.filledButtonTheme,
        elevatedButtonTheme: light.elevatedButtonTheme,
        dividerTheme:
            DividerThemeData(color: scheme.outlineVariant, thickness: .8),
        dialogTheme:
            DialogThemeData(backgroundColor: scheme.surfaceContainerHigh),
        bottomSheetTheme: BottomSheetThemeData(
            backgroundColor: scheme.surface,
            modalBarrierColor: Colors.black54));
  }

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        error: AppColors.error);
    final border = OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2EBE4)));
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'PlusJakartaSans',
      textTheme: Typography.material2021().black.apply(
          fontFamily: 'PlusJakartaSans',
          bodyColor: AppColors.onSurface,
          displayColor: AppColors.onSurface),
      appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
              fontFamily: 'PlusJakartaSans',
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color: AppColors.onSurface)),
      inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: .8),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          border: border,
          enabledBorder: border,
          focusedBorder: border.copyWith(
              borderSide:
                  const BorderSide(color: AppColors.primary, width: 1.5))),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
              minimumSize: const Size(0, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)))),
      elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              minimumSize: const Size(0, 46))),
      cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white.withValues(alpha: .86),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22))),
      dividerTheme:
          const DividerThemeData(color: Color(0xFFE5ECE5), thickness: .8),
      bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Colors.transparent,
          modalBarrierColor: Color(0x45122C35),
          showDragHandle: false),
      tabBarTheme: const TabBarThemeData(
          dividerColor: Colors.transparent,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.onSurfaceVariant),
    );
  }
}
