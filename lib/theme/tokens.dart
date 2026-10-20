import 'package:flutter/material.dart';

/// Flutter counterpart of assets/theme.css, including tokens not used by Forui.
abstract final class CpiTokens {
  static const radius = 6.0;
  static const sans = 'Inter';
  static const mono = 'JetBrains Mono';
  static const serif = 'Source Serif 4';
  static const light = <String, Color>{
    'card': Color(0xffffffff),
    'ring': Color(0xff3b82f6),
    'input': Color(0xffe5e7eb),
    'muted': Color(0xfff9fafb),
    'accent': Color(0xffe0f2fe),
    'border': Color(0xffe5e7eb),
    'chart-1': Color(0xff3b82f6),
    'chart-2': Color(0xff2563eb),
    'chart-3': Color(0xff1d4ed8),
    'chart-4': Color(0xff1e40af),
    'chart-5': Color(0xff1e3a8a),
    'popover': Color(0xffffffff),
    'primary': Color(0xff3b82f6),
    'sidebar': Color(0xfff9fafb),
    'secondary': Color(0xfff3f4f6),
    'background': Color(0xffffffff),
    'foreground': Color(0xff333333),
    'destructive': Color(0xffef4444),
    'sidebar-ring': Color(0xff3b82f6),
    'sidebar-accent': Color(0xffe0f2fe),
    'sidebar-border': Color(0xffe5e7eb),
    'card-foreground': Color(0xff333333),
    'sidebar-primary': Color(0xff3b82f6),
    'muted-foreground': Color(0xff6b7280),
    'accent-foreground': Color(0xff1e3a8a),
    'popover-foreground': Color(0xff333333),
    'primary-foreground': Color(0xffffffff),
    'sidebar-foreground': Color(0xff333333),
    'secondary-foreground': Color(0xff4b5563),
    'destructive-foreground': Color(0xffffffff),
    'sidebar-accent-foreground': Color(0xff1e3a8a),
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
