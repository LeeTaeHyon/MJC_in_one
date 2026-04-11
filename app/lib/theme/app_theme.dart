import "package:flutter/material.dart";

import "app_colors.dart";

ThemeData buildMjcTheme() {
  const primary = AppColors.primary;

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.scaffoldMuted,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xDE000000),
      error: Color(0xFFD4183D),
      onError: Colors.white,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 6,
      shadowColor: Colors.black26,
      height: 56,
      indicatorColor: primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: selected ? primary : AppColors.mutedForeground,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return IconThemeData(
          color: selected ? primary : AppColors.mutedForeground,
        );
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return primary;
        return null;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primary.withValues(alpha: 0.45);
        }
        return null;
      }),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
  );
}
