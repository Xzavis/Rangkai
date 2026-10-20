part of 'theme.dart';

FStyle _style({
  required FColors colors,
  required FTypography typography,
  required bool touch,
}) => FStyle.inherit(colors: colors, typography: typography, touch: touch)
    .copyWith(
      borderRadius: const FBorderRadius(
        xs2: BorderRadius.all(Radius.circular(2)),
        xs: BorderRadius.all(Radius.circular(4)),
        sm: BorderRadius.all(Radius.circular(6)),
        md: BorderRadius.all(Radius.circular(6)),
        lg: BorderRadius.all(Radius.circular(12)),
      ),
      shadow: const [],
    );
