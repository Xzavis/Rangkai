part of 'theme.dart';

FColors _colors(Brightness brightness) {
  final t = CpiTokens.of(brightness);
  return FColors(
    brightness: brightness,
    systemOverlayStyle: brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark,
    barrier: const Color(0x66000000),
    background: t['background']!,
    foreground: t['foreground']!,
    primary: t['primary']!,
    primaryForeground: t['primary-foreground']!,
    secondary: t['secondary']!,
    secondaryForeground: t['secondary-foreground']!,
    muted: t['muted']!,
    mutedForeground: t['muted-foreground']!,
    destructive: t['destructive']!,
    destructiveForeground: t['destructive-foreground']!,
    error: brightness == Brightness.light
        ? const Color(0xffb91c1c)
        : const Color(0xfffca5a5),
    errorForeground: t['destructive-foreground']!,
    card: t['card']!,
    border: t['border']!,
  );
}

final lightColors = _colors(Brightness.light);
final darkColors = _colors(Brightness.dark);
