import 'package:flutter/material.dart';

import 'core.dart';
import 'theme/tokens.dart';
import 'widgets.dart';

// Komponen target docs/ui-v4/COMPONENTS.md. Semua angka dari Store/model;
// komponen di sini hanya menampilkan + meneruskan aksi pemanggil.

/// Saldo + pemasukan/pengeluaran. Show/hide saldo adalah state lokal
/// tampilan ini saja (tidak mengubah nilai, clipboard, atau Store).
class BalanceSummary extends StatefulWidget {
  const BalanceSummary({super.key, required this.store, this.onCopy});
  final Store store;
  final VoidCallback? onCopy;
  @override
  State<BalanceSummary> createState() => _BalanceSummaryState();
}

class _BalanceSummaryState extends State<BalanceSummary> {
  var _hidden = false;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final b = Theme.of(context).brightness;
    final s = widget.store;
    // Referensi 01/02: label + mata, nominal 24/700, garis pemisah,
    // lalu Pemasukan | Pengeluaran dua kolom dengan panah arah.
    final amountStyle = tt.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return CpiCard(
      padding: const EdgeInsets.all(CpiTokens.panelPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Saldo saat ini',
                style: tt.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              IconButton(
                tooltip: _hidden ? 'Tampilkan saldo' : 'Sembunyikan saldo',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: Icon(
                  _hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _hidden = !_hidden),
              ),
              const Spacer(),
              if (widget.onCopy != null)
                IconButton(
                  tooltip: 'Salin ringkasan',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.copy_outlined, size: 19),
                  onPressed: widget.onCopy,
                ),
            ],
          ),
          Semantics(
            label: _hidden ? 'Saldo disembunyikan' : null,
            child: _hidden
                ? Text('Rp••••••', style: amountStyle)
                : AnimatedMoney(s.balance, style: amountStyle),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          CpiReflow(
            breakpoint: 300,
            children: [
              _FlowMini(
                label: 'Pemasukan',
                value: s.income,
                color: CpiTokens.income(b),
                prefix: '+',
                icon: Icons.arrow_upward,
              ),
              _FlowMini(
                label: 'Pengeluaran',
                value: s.expense,
                color: CpiTokens.expense(b),
                prefix: '-',
                icon: Icons.arrow_downward,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowMini extends StatelessWidget {
  const _FlowMini({
    required this.label,
    required this.value,
    required this.color,
    required this.prefix,
    required this.icon,
  });
  final String label, prefix;
  final double value;
  final Color color;
  final IconData icon;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Flexible(child: Text(label, style: tt.bodySmall)),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          '$prefix${rp(value.abs())}',
          style: tt.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

/// '24 Okt' — tanggal pendek referensi 01/02 (tanpa hari/tahun).
String shortDate(DateTime d) {
  const bln = [
    'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
    'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des',
  ];
  return '${d.day} ${bln[d.month - 1]}';
}

/// '24–25 Okt 2026' / '24 Okt – 2 Nov 2026' / '24 Okt 2026'.
String planRangeLabel(Plan p) {
  final end = p.lastDay;
  if (end == DateTime(p.date.year, p.date.month, p.date.day) ||
      (end.year == p.date.year && end.month == p.date.month && end.day == p.date.day)) {
    return '${shortDate(p.date)} ${p.date.year}';
  }
  if (end.year == p.date.year && end.month == p.date.month) {
    return '${p.date.day}–${end.day} ${shortDate(end).split(' ').last} ${end.year}';
  }
  if (end.year == p.date.year) {
    return '${shortDate(p.date)} – ${shortDate(end)} ${end.year}';
  }
  return '${shortDate(p.date)} ${p.date.year} – ${shortDate(end)} ${end.year}';
}

/// Progress anggaran LINEAR (bukan ring): Terpakai/Sisa dari ledger.
/// Sisa negatif ditampilkan negatif; budget 0 tidak membagi nol.
class BudgetProgress extends StatelessWidget {
  const BudgetProgress({
    super.key,
    required this.budget,
    required this.spent,
    this.showLabels = true,
  });
  final double budget, spent;
  final bool showLabels;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final ratio = BudgetCalc.ratio(budget, spent);
    final sisa = BudgetCalc.sisa(budget, spent);
    final over = sisa < 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          label: 'Terpakai ${(ratio * 100).round()} persen dari anggaran',
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: ratio),
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 300),
            builder: (_, v, __) => LinearProgressIndicator(
              value: v.clamp(0, 1),
              minHeight: 8,
              borderRadius: BorderRadius.circular(8),
              color: over ? cs.error : cs.primary,
            ),
          ),
        ),
        if (showLabels) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              Text('Anggaran ${rp(budget)}', style: tt.bodySmall),
              Text('Terpakai ${rp(spent)}', style: tt.bodySmall),
              Text(
                'Sisa ${rp(sisa)}',
                style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: over ? cs.error : null,
                ),
              ),
              Text('${(ratio * 100).round()}%', style: tt.bodySmall),
            ],
          ),
        ],
      ],
    );
  }
}

/// Ikon kategori (padanan Material Symbols di referensi HTML).
IconData categoryIcon(String category, {required bool income}) {
  if (income) return Icons.payments_outlined;
  return switch (category) {
    'Makan' || 'Makanan' => Icons.restaurant_outlined,
    'Transport' => Icons.train_outlined,
    'Hotel' || 'Akomodasi' => Icons.hotel_outlined,
    'Belanja' => Icons.shopping_bag_outlined,
    'Hiburan' => Icons.confirmation_number_outlined,
    'Kesehatan' => Icons.health_and_safety_outlined,
    'Pendapatan' => Icons.payments_outlined,
    _ => Icons.more_horiz,
  };
}

/// Satu kategori aktif, membungkus sesuai ruang, bisa dioperasikan
/// keyboard/screen reader lewat ChoiceChip (semantics bawaan).
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.options = txCategories,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final List<String> options;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Kategori', style: Theme.of(context).textTheme.titleSmall),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in options)
            ChoiceChip(
              label: Text(c),
              selected: value == c,
              onSelected: (_) => onChanged(c),
            ),
        ],
      ),
    ],
  );
}

/// Baris transaksi: judul boleh membungkus, nominal utuh dengan tanda,
/// kategori + label rencana bila ada. Hapus lewat tombol yang terlihat
/// (bukan hanya tekan lama) bila [onDelete] diberikan.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.tx,
    this.planTitle,
    this.onDelete,
  });
  final Tx tx;
  final String? planTitle;
  final Future<void> Function()? onDelete;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final b = Theme.of(context).brightness;
    final masuk = tx.isIncome;
    final color = masuk ? CpiTokens.income(b) : CpiTokens.expense(b);
    // Referensi 01/02: ikon kotak r12 tint, judul, meta '24 Okt • Makan'
    // + chip rencana, nominal berwarna di baris bawah.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: masuk
                      ? CpiTokens.income(b).withValues(alpha: 0.12)
                      : cs.primaryContainer,
                  borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
                ),
                child: Icon(
                  categoryIcon(tx.category, income: masuk),
                  size: 20,
                  color: masuk ? CpiTokens.income(b) : cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx.title,
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '${shortDate(tx.date)} • ${tx.category}',
                          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        if (planTitle != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              planTitle!,
                              style: tt.labelSmall?.copyWith(color: cs.primary),
                            ),
                          ),
                      ],
                    ),
                    if (tx.note.isNotEmpty)
                      Text(tx.note, style: tt.bodySmall),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Hapus transaksi ${tx.title}',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.delete_outline, size: 19),
                  onPressed: () => onDelete!(),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${masuk ? '+' : '-'}${rp(tx.amount.abs())}',
            style: tt.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Ringkasan satu rencana untuk daftar: judul, tempat/tanggal, progress
/// linear pengeluaran aktual, agenda berikutnya dari rundown.
class PlanSummary extends StatelessWidget {
  const PlanSummary({
    super.key,
    required this.plan,
    required this.spent,
    this.onTap,
    this.distanceMeters,
  });
  final Plan plan;
  final double spent;
  final VoidCallback? onTap;

  /// Jarak GPS nyata ke tujuan bila tersedia (null = tidak ditampilkan).
  final double? distanceMeters;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final status = planStatusLabel(plan, DateTime.now());
    final next = plan.rundown.where((r) => !r.done).toList()
      ..sort((a, b) {
        final d = (a.day ?? plan.date).compareTo(b.day ?? plan.date);
        return d != 0 ? d : a.time.compareTo(b.time);
      });
    final sisa = BudgetCalc.sisa(plan.budget, spent);
    final gpsText = distanceMeters == null
        ? 'Menunggu posisi GPS'
        : distanceMeters! >= 1000
            ? 'GPS Aktif • ${(distanceMeters! / 1000).toStringAsFixed(1).replaceAll('.', ',')} km menuju tujuan'
            : 'GPS Aktif • ${distanceMeters!.toStringAsFixed(0)} m menuju tujuan';
    // Referensi 01/03: chip status + rentang, judul, 'Lihat rencana ->',
    // baris GPS biru, Anggaran Rencana + sisa + progress, Berikutnya.
    return CpiCard(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(CpiTokens.panelPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    planRangeLabel(plan),
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                plan.title,
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              if (plan.place.isNotEmpty)
                Text(plan.place, style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Semantics(
                button: onTap != null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Lihat rencana',
                      style: tt.bodyMedium?.copyWith(color: cs.primary),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 16, color: cs.primary),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const LiveDot(),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      gpsText,
                      style: tt.bodySmall?.copyWith(
                        color: distanceMeters == null ? cs.onSurfaceVariant : cs.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Anggaran Rencana',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(
                'Sisa ${rp(sisa)} dari ${rp(plan.budget)}',
                style: tt.bodyMedium?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 6),
              BudgetProgress(budget: plan.budget, spent: spent, showLabels: false),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.schedule_outlined, size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      next.isNotEmpty
                          ? 'Berikutnya: ${next.first.title}, ${next.first.time.replaceAll(':', '.')}'
                          : plan.rundown.isEmpty
                              ? 'Belum ada rundown'
                              : 'Semua rundown selesai',
                      style: tt.bodyMedium,
                    ),
                  ),
                ],
              ),
              if (plan.rundown.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Rundown selesai ${plan.rundown.where((r) => r.done).length} dari ${plan.rundown.length}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Satu baris timeline rundown dengan state teks jujur.
class AgendaRow extends StatelessWidget {
  const AgendaRow({
    super.key,
    required this.rundown,
    required this.stateLabel,
    this.subtitle,
    this.onTap,
  });

  /// 'Selesai' | 'Berlangsung' | 'Belum mulai' — dari pemanggil.
  final String stateLabel;
  final Rundown rundown;
  final String? subtitle;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final tone = stateLabel == 'Selesai'
        ? StatusTone.active
        : stateLabel == 'Berlangsung'
            ? StatusTone.active
            : StatusTone.waiting;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 52,
      leading: Chip(label: Text(rundown.time)),
      title: Text(
        rundown.title,
        style: TextStyle(
          decoration: rundown.done ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subtitle != null) Text(subtitle!),
          Text(
            rundown.cost > 0 ? 'Estimasi ${rp(rundown.cost)}' : 'Tanpa estimasi biaya',
          ),
        ],
      ),
      trailing: StatusLabel(stateLabel, tone: tone),
      onTap: onTap,
    );
  }
}
