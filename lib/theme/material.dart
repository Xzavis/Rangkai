import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData cpiMaterialTheme(Brightness brightness) {
  final t = CpiTokens.of(brightness);
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(6));
  final scheme = ColorScheme(
    brightness: brightness,
    primary: t['primary']!,
    onPrimary: t['primary-foreground']!,
    primaryContainer: t['accent'],
    onPrimaryContainer: t['accent-foreground'],
    secondary: t['secondary']!,
    onSecondary: t['secondary-foreground']!,
    secondaryContainer: t['accent'],
    onSecondaryContainer: t['accent-foreground'],
    tertiary: t['chart-3'],
    onTertiary: t['primary-foreground'],
    error: brightness == Brightness.light
        ? const Color(0xffb91c1c)
        : const Color(0xfffca5a5),
    onError: t['destructive-foreground']!,
    surface: t['background']!,
    onSurface: t['foreground']!,
    surfaceContainerLowest: t['background'],
    surfaceContainerLow: t['muted'],
    surfaceContainer: t['card'],
    surfaceContainerHigh: t['secondary'],
    surfaceContainerHighest: t['input'],
    onSurfaceVariant: t['muted-foreground'],
    outline: t['muted-foreground'],
    outlineVariant: t['border'],
    surfaceTint: Colors.transparent,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: CpiTokens.sans,
  );
  const label = TextStyle(fontSize: 19, fontWeight: FontWeight.w700);
  return base.copyWith(
    scaffoldBackgroundColor: t['background'],
    cardColor: t['card'],
    focusColor: t['ring']!.withValues(alpha: .2),
    cardTheme: CardThemeData(
      color: t['card'],
      elevation: 0,
      shape: shape.copyWith(side: BorderSide(color: t['border']!)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t['background'],
      foregroundColor: t['foreground'],
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t['sidebar'],
      indicatorColor: t['sidebar-accent'],
      height: 72,
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t['sidebar'],
      indicatorColor: t['sidebar-accent'],
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: shape,
        minimumSize: const Size(44, 48),
        textStyle: label,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: shape,
        minimumSize: const Size(44, 48),
        foregroundColor: t['accent-foreground'],
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: t['accent-foreground'],
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: t['primary'],
      foregroundColor: t['primary-foreground'],
      extendedTextStyle: label,
      shape: shape,
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: shape,
      selectedColor: t['accent'],
      labelStyle: TextStyle(color: t['foreground']),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t['background'],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: t['input']!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: t['input']!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(6),
        borderSide: BorderSide(color: t['ring']!, width: 2),
      ),
    ),
    dialogTheme: DialogThemeData(backgroundColor: t['popover']),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t['popover'],
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
    ),
  );
}
