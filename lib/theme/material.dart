import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData cpiMaterialTheme(Brightness brightness) {
  final t = CpiTokens.of(brightness);
  final shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
  );
  final panelShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(CpiTokens.panelRadius),
  );
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
        ? CpiTokens.negative
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
  const label = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
  return base.copyWith(
    scaffoldBackgroundColor: t['background'],
    cardColor: t['card'],
    focusColor: t['ring']!.withValues(alpha: .2),
    // Skala v4: judul 24, bagian 18, item 15, isi 14-16, label 13, metadata 12.
    textTheme: base.textTheme.copyWith(
      headlineMedium: base.textTheme.headlineMedium?.copyWith(fontSize: 28),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(fontSize: 15),
      titleSmall: base.textTheme.titleSmall?.copyWith(fontSize: 14),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14),
      bodySmall: base.textTheme.bodySmall?.copyWith(
        fontSize: 12,
        color: t['muted-foreground'],
      ),
      labelLarge: base.textTheme.labelLarge?.copyWith(fontSize: 13),
      labelMedium: base.textTheme.labelMedium?.copyWith(fontSize: 12),
    ),
    cardTheme: CardThemeData(
      color: t['card'],
      elevation: 0,
      shape: panelShape.copyWith(side: BorderSide(color: t['border']!)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: t['background'],
      foregroundColor: t['foreground'],
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: t['border']!)),
    ),
    // Dock v4: tinggi minimum 76, label 11, tujuan aktif berwarna aksi
    // (bukan hanya indikator) — rangkai-ui.css nav[aria-label].
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: t['sidebar'],
      indicatorColor: t['sidebar-accent'],
      height: 76,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          color: states.contains(WidgetState.selected)
              ? t['primary']
              : t['muted-foreground'],
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 11,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w600
              : FontWeight.w500,
          color: states.contains(WidgetState.selected)
              ? t['primary']
              : t['muted-foreground'],
        ),
      ),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: t['sidebar'],
      indicatorColor: t['sidebar-accent'],
      selectedIconTheme: IconThemeData(color: t['primary']),
      unselectedIconTheme: IconThemeData(color: t['muted-foreground']),
      selectedLabelTextStyle: TextStyle(
        color: t['primary'],
        fontWeight: FontWeight.w600,
      ),
      unselectedLabelTextStyle: TextStyle(color: t['muted-foreground']),
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
      fillColor: t['card'],
      constraints: const BoxConstraints(minHeight: CpiTokens.minFieldHeight),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
        borderSide: BorderSide(color: t['input']!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
        borderSide: BorderSide(color: t['input']!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
        borderSide: BorderSide(color: t['ring']!, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
        borderSide: BorderSide(color: scheme.error, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(color: t['border'], thickness: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: t['popover'],
      shape: panelShape,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: t['popover'],
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}
