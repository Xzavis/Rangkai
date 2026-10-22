part of 'theme.dart';

FStyle _style({
  required FColors colors,
  required FTypography typography,
  required bool touch,
}) => FStyle.inherit(colors: colors, typography: typography, touch: touch)
    .copyWith(
      borderRadius: const FBorderRadius(
        xs2: BorderRadius.all(Radius.circular(4)),
        xs: BorderRadius.all(Radius.circular(8)),
        sm: BorderRadius.all(Radius.circular(12)),
        md: BorderRadius.all(Radius.circular(12)),
        lg: BorderRadius.all(Radius.circular(16)),
      ),
      shadow: const [],
    );
