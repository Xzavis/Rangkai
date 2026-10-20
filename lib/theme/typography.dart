part of 'theme.dart';

FTypography _typography({required FColors colors, required bool touch}) {
  final face = FTypeface.inherit(
    colors: colors,
    touch: touch,
    fontFamily: CpiTokens.sans,
  );
  return FTypography(display: face, body: face);
}
