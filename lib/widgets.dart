import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:forui/forui.dart'
    show FButton, FButtonVariant, FCard, FTextField;

import 'core.dart';
import 'theme/tokens.dart';

EdgeInsets cpiPagePadding(BuildContext context) => EdgeInsets.fromLTRB(
  MediaQuery.sizeOf(context).width < 600
      ? CpiTokens.pagePadding
      : 24,
  12,
  MediaQuery.sizeOf(context).width < 600
      ? CpiTokens.pagePadding
      : 24,
  96,
);

class CpiContent extends StatelessWidget {
  const CpiContent({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width < 960 ? 880 : 1120,
      ),
      child: child,
    ),
  );
}

/// Panel v4: radius 16, border tipis, tanpa shadow (gaya dari FTheme).
/// [padding] opsional: bila diisi, isi dibungkus satu lapis padding 20
/// supaya pemanggil tidak menumpuk padding sendiri-sendiri.
class CpiCard extends StatelessWidget {
  const CpiCard({
    super.key,
    required this.child,
    this.clipBehavior = Clip.none,
    this.padding,
  });
  final Widget child;
  final Clip clipBehavior;
  final EdgeInsetsGeometry? padding;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: FCard(
      clipBehavior: clipBehavior,
      child: Material(
        type: MaterialType.transparency,
        child: padding == null
            ? child
            : Padding(padding: padding!, child: child),
      ),
    ),
  );
}

/// Nama target di COMPONENTS.md; kelas yang sama dengan [CpiCard].
typedef RangkaiCard = CpiCard;

/// Aksi v4: radius 12 (dari tema), sentuh >=44, utama 48, label 15px.
/// [busy] menonaktifkan tombol + menampilkan indikator agar tekan ganda
/// tidak membuat transaksi/absen ganda. [destructive] untuk aksi hapus.
class CpiButton extends StatelessWidget {
  const CpiButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.secondary = false,
    this.selected = false,
    this.busy = false,
    this.destructive = false,
  });
  final VoidCallback? onPressed;
  final Widget child;
  final bool secondary, selected, busy, destructive;
  @override
  Widget build(BuildContext context) => ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
      child: FButton(
        onPress: busy ? null : onPressed,
        selected: selected,
        mainAxisSize: MainAxisSize.min,
        variant: destructive
            ? FButtonVariant.destructive
            : secondary
                ? FButtonVariant.secondary
                : FButtonVariant.primary,
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          child: busy
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    child,
                  ],
                )
              : child,
        ),
      ),
  );
}

/// Field berlabel permanen v4: helper/error tampil di dekat field,
/// tinggi minimum 48 dari tema, autofill + batas panjang diteruskan.
class CpiField extends StatelessWidget {
  const CpiField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.error,
    this.onChanged,
    this.keyboardType,
    this.textInputAction,
    this.onSubmitted,
    this.autofillHints,
    this.enabled = true,
    this.maxLength,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.autocorrect = true,
  });
  final TextEditingController? controller;
  final String? label, hint, helper, error;
  final ValueChanged<String>? onChanged, onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool enabled, autocorrect;
  final int? maxLength;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  @override
  Widget build(BuildContext context) => FTextField(
    control: .managed(
      controller: controller,
      onChange: (value) => onChanged?.call(value.text),
    ),
    label: label == null ? null : Text(label!),
    hint: hint,
    description: helper == null ? null : Text(helper!),
    error: error == null
        ? null
        : Semantics(liveRegion: true, child: Text(error!)),
    keyboardType: keyboardType,
    textInputAction: textInputAction,
    onSubmit: onSubmitted,
    autofillHints: autofillHints,
    enabled: enabled,
    maxLength: maxLength,
    textCapitalization: textCapitalization,
    inputFormatters: inputFormatters,
    autocorrect: autocorrect,
    enableSuggestions: autocorrect,
  );
}

/// Reflows related totals and budget content before text runs out of space.
class CpiReflow extends StatelessWidget {
  const CpiReflow({super.key, required this.children, this.breakpoint = 440});
  final List<Widget> children;
  final double breakpoint;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint ||
          MediaQuery.textScalerOf(context).scale(16) > 22) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              children[i],
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: children[i]),
          ],
        ],
      );
    },
  );
}

/// Custom SVG icon. All CPI icons live in assets/icons/ (stroke style, currentColor).
class CPIcon extends StatelessWidget {
  const CPIcon(this.name, {super.key, this.size = 22, this.color});
  final String name;
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      semanticsLabel: name,
    );
  }
}

/// Count-up money text.
class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney(this.value, {super.key, this.style});
  final double value;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value),
    duration: MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
    builder: (_, v, __) => Text(
      rp(v),
      style: (style ?? Theme.of(context).textTheme.titleMedium)?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    ),
  );
}

/// Animated budget ring: one painter, tweened ratio.
class BudgetRing extends StatelessWidget {
  const BudgetRing({
    super.key,
    required this.ratio,
    required this.center,
    this.size = 132,
  });
  final double ratio, size;
  final Widget center;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final over = ratio >= 1;
    return TweenAnimationBuilder<double>(
      tween: Tween(end: ratio),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.square(size),
              painter: _Ring(
                v,
                cs.surfaceContainerHighest,
                over ? cs.error : cs.primary,
              ),
            ),
            center,
          ],
        ),
      ),
    );
  }
}

class _Ring extends CustomPainter {
  _Ring(this.ratio, this.track, this.color);
  final double ratio;
  final Color track, color;
  @override
  void paint(Canvas c, Size s) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;
    final rect = Offset.zero & s;
    paint.color = track;
    c.drawArc(rect.deflate(7), 0, pi * 2, false, paint);
    paint.color = color;
    c.drawArc(
      rect.deflate(7),
      -pi / 2,
      pi * 2 * ratio.clamp(0, 1),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_Ring o) =>
      o.ratio != ratio || o.color != color || o.track != track;
}

/// Marks live clock, GPS or estimate updates without a looping animation.
class LiveDot extends StatelessWidget {
  const LiveDot({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary,
      shape: BoxShape.circle,
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.actionLabel,
    this.onAction,
  });
  final String icon, text;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40),
    child: Column(
      children: [
        CPIcon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(
          text,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: Theme.of(context).colorScheme.outline),
        ),
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 16),
          CpiButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

enum StatusTone { active, waiting, error, neutral }

/// Status jujur: ikon + teks (bukan warna/dot saja), statis tanpa pulse.
/// Teks wajib dari state nyata pemanggil, bukan hardcode siap/berhasil.
class StatusLabel extends StatelessWidget {
  const StatusLabel(this.text, {super.key, this.tone = StatusTone.neutral});
  final String text;
  final StatusTone tone;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (tone) {
      StatusTone.active => (Icons.check_circle_outline, cs.primary),
      StatusTone.waiting => (Icons.schedule_outlined, cs.onSurfaceVariant),
      StatusTone.error => (Icons.error_outline, cs.error),
      StatusTone.neutral => (Icons.info_outline, cs.onSurfaceVariant),
    };
    return Semantics(
      label: 'Status: $text',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Judul bagian konsisten (18/titleLarge) + aksi opsional sejajar.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action});
  final String title;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      if (action != null) action!,
    ],
  );
}
