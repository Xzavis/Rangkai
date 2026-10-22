import 'package:flutter/material.dart';

/// Flutter counterpart of assets/theme.css, including tokens not used by Forui.
/// Nilai light = docs/ui-v4/tokens.json (UI v4). Dark = baseline lama.
abstract final class CpiTokens {
  /// Radius kontrol (field/tombol/chip). Panel memakai [panelRadius].
  static const radius = 12.0;
  static const panelRadius = 16.0;
  static const controlRadius = 12.0;
  static const pagePadding = 20.0;
  static const panelPadding = 20.0;
  static const minTouchTarget = 44.0;
  static const minFieldHeight = 48.0;

  // Token semantik v4 (light). Adapter gelap memakai pasangan di [dark].
  static const brand = Color(0xff3b82f6);
  static const action = Color(0xff1d4ed8);
  static const actionPressed = Color(0xff1e40af);
  static const onAction = Color(0xffffffff);
  static const positive = Color(0xff03664a);
  static const negative = Color(0xffb42318);

  /// Warna arus kas per tema (bukan warna saja: selalu disertai teks +/-).
  static Color income(Brightness b) =>
      b == Brightness.dark ? const Color(0xff34d399) : positive;
  static Color expense(Brightness b) =>
      b == Brightness.dark ? const Color(0xfffca5a5) : negative;

  static const sans = 'Inter';
  static const mono = 'JetBrains Mono';
  static const serif = 'Source Serif 4';
  static const light = <String, Color>{
    'card': Color(0xffffffff),
    'ring': Color(0xff3b82f6),
    'input': Color(0xffe2e7ee),
    'muted': Color(0xfff1f5f9),
    'accent': Color(0xffdbeafe),
    'border': Color(0xffe2e7ee),
    'chart-1': Color(0xff3b82f6),
    'chart-2': Color(0xff2563eb),
    'chart-3': Color(0xff03664a),
    'chart-4': Color(0xff1e40af),
    'chart-5': Color(0xff596577),
    'popover': Color(0xffffffff),
    'primary': Color(0xff1d4ed8),
    'sidebar': Color(0xffffffff),
    'secondary': Color(0xffeef2f7),
    'background': Color(0xfff7f8fa),
    'foreground': Color(0xff182333),
    'destructive': Color(0xffb42318),
    'sidebar-ring': Color(0xff3b82f6),
    'sidebar-accent': Color(0xffdbeafe),
    'sidebar-border': Color(0xffe2e7ee),
    'card-foreground': Color(0xff182333),
    'sidebar-primary': Color(0xff1d4ed8),
    'muted-foreground': Color(0xff596577),
    'accent-foreground': Color(0xff1e40af),
    'popover-foreground': Color(0xff182333),
    'primary-foreground': Color(0xffffffff),
    'sidebar-foreground': Color(0xff182333),
    'secondary-foreground': Color(0xff334155),
    'destructive-foreground': Color(0xffffffff),
    'sidebar-accent-foreground': Color(0xff1e40af),
    'sidebar-primary-foreground': Color(0xffffffff),
  };
  static const dark = <String, Color>{
    'card': Color(0xff262626),
    'ring': Color(0xff3b82f6),
    'input': Color(0xff404040),
    'muted': Color(0xff1f1f1f),
    'accent': Color(0xff1e3a8a),
    'border': Color(0xff404040),
    'chart-1': Color(0xff60a5fa),
    'chart-2': Color(0xff3b82f6),
    'chart-3': Color(0xff2563eb),
    'chart-4': Color(0xff1d4ed8),
    'chart-5': Color(0xff1e40af),
    'popover': Color(0xff262626),
    'primary': Color(0xff3b82f6),
    'sidebar': Color(0xff171717),
    'secondary': Color(0xff262626),
    'background': Color(0xff171717),
    'foreground': Color(0xffe5e5e5),
    'destructive': Color(0xffef4444),
    'sidebar-ring': Color(0xff3b82f6),
    'sidebar-accent': Color(0xff1e3a8a),
    'sidebar-border': Color(0xff404040),
    'card-foreground': Color(0xffe5e5e5),
    'sidebar-primary': Color(0xff3b82f6),
    'muted-foreground': Color(0xffa3a3a3),
    'accent-foreground': Color(0xffbfdbfe),
    'popover-foreground': Color(0xffe5e5e5),
    'primary-foreground': Color(0xffffffff),
    'sidebar-foreground': Color(0xffe5e5e5),
    'secondary-foreground': Color(0xffe5e5e5),
    'destructive-foreground': Color(0xffffffff),
    'sidebar-accent-foreground': Color(0xffbfdbfe),
    'sidebar-primary-foreground': Color(0xffffffff),
  };
  static Map<String, Color> of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;
}
