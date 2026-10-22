import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

part 'colors.dart';
part 'typography.dart';
part 'style.dart';
part 'icons.dart';

/// Initialized by Forui CLI, then customized to the user's CPI palette.
FThemeData get lightTheme {
  const touch = true;

  final colors = lightColors;

  final typography = _typography(colors: colors, touch: touch);

  final icons = _icons();

  final style = _style(colors: colors, typography: typography, touch: touch);

  return FThemeData(
    colors: colors,
    typography: typography,
    icons: icons,
    style: style,
    touch: touch,
    cardStyle: FCardStyle(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(CpiTokens.panelRadius),
      ),
      titleTextStyle: typography.body.md,
      subtitleTextStyle: typography.body.sm,
    ),
  );
}

FThemeData get darkTheme {
  const touch = true;

  final colors = darkColors;

  final typography = _typography(colors: colors, touch: touch);

  final icons = _icons();

  final style = _style(colors: colors, typography: typography, touch: touch);

  return FThemeData(
    colors: colors,
    typography: typography,
    icons: icons,
    style: style,
    touch: touch,
    cardStyle: FCardStyle(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(CpiTokens.panelRadius),
      ),
      titleTextStyle: typography.body.md,
      subtitleTextStyle: typography.body.sm,
    ),
  );
}
