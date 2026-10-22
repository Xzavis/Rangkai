import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'absen.dart';
import 'calendar.dart';
import 'components.dart';
import 'core.dart';
import 'widgets.dart';
import 'workspace.dart';
import 'theme/tokens.dart';

// ================= BERANDA =================
class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.store,
    required this.travel,
    required this.zone,
    required this.onZone,
    required this.location,
    this.displayName,
    this.onOpenFinance,
    this.onOpenTab,
    this.ws,
  });
  final Store store;
  final TravelService travel;
  final Zone zone;
  final ValueChanged<Zone> onZone;
  final LocationService location;

  /// Nama dari data akun nyata (mis. awalan email). null = sapaan umum.
  final String? displayName;
  final VoidCallback? onOpenFinance;

  /// Pindah tab shell (0-4) untuk grid Layanan. null = grid disembunyikan.
  final ValueChanged<int>? onOpenTab;
  final WorkspaceService? ws;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Stream<DateTime> _clock = Stream.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now().toUtc(),
  );

  void _openTravel(String kind) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TravelPage(
            travel: widget.travel,
            store: widget.store,
            initialKind: kind,
            asRoute: true,
            location: widget.location,
          ),
        ),
      );

  void _copySummary() {
    final s = widget.store;
    Clipboard.setData(
      ClipboardData(
        text:
            'Rangkai: saldo ${rp(s.balance)}, masuk ${rp(s.income)}, keluar ${rp(s.expense)} per ${tgl(DateTime.now())}.',
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ringkasan disalin. Tinggal paste ke chat atau catatan.'),
      ),
    );
  }

  /// Rencana untuk kartu Beranda: yang sedang berlangsung dulu,
  /// lalu mendatang terdekat, lalu rencana pertama apa pun.
  Plan? _featuredPlan(Store s) {
    if (s.plans.isEmpty) return null;
    final now = DateTime.now();
    final sorted = [...s.plans]..sort((a, b) => a.date.compareTo(b.date));
    for (final p in sorted) {
      if (planStatusLabel(p, now) == 'Sedang Berlangsung') return p;
    }
    for (final p in sorted) {
      if (planStatusLabel(p, now) == 'Mendatang') return p;
    }
    return sorted.first;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, tt = Theme.of(context).textTheme;
    final s = widget.store;
    final plan = _featuredPlan(s);
    final now = DateTime.now();
    return ListView(
      padding: cpiPagePadding(context),
      children: [
        // Sapaan: serif khusus Beranda, nama dari akun nyata bila ada.
        Text(
          widget.displayName == null || widget.displayName!.isEmpty
              ? 'Halo, semua terangkai hari ini.'
              : 'Halo, ${widget.displayName}',
          style: tt.headlineSmall?.copyWith(
            fontFamily: CpiTokens.serif,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${now.day} ${_monthLabel(now)}',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        // Jam live ringkas (kontrak lama dipertahankan, bukan hero besar
        // referensi 01): satu strip tint r16 + pemilih zona.
        StreamBuilder<DateTime>(
          stream: _clock,
          initialData: DateTime.now().toUtc(),
          builder: (_, snap) {
            final t = widget.zone.at(snap.data!);
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(CpiTokens.panelRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LiveDot(),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${jam(t)} · ${widget.zone.city} (${widget.zone.label}) · ${tgl(DateTime(t.year, t.month, t.day))}',
                          style: tt.bodyMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final z in Zone.zones)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(z.city),
                              selected: z.city == widget.zone.city,
                              onSelected: (_) => widget.onZone(z),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        // Status GPS mandiri hanya bila tidak ada kartu rencana
        // (di kartu rencana status+jarak GPS tampil di dalamnya).
        if (plan == null) ...[
          const SizedBox(height: 12),
          if (widget.location.pos != null)
            StatusLabel(
              'GPS aktif · akurasi ${widget.location.pos!.accuracy.toStringAsFixed(0)} m',
              tone: StatusTone.active,
            )
          else
            const StatusLabel(
              'Menunggu posisi GPS pertama',
              tone: StatusTone.waiting,
            ),
        ],
        const SizedBox(height: 16),
        BalanceSummary(store: s),
        const SizedBox(height: 12),
        // Referensi 01: dua CTA sejajar, primer + tint, r12.
        LayoutBuilder(
          builder: (context, constraints) {
            final stack = constraints.maxWidth < 340 ||
                MediaQuery.textScalerOf(context).scale(15) > 22;
            final tambah = SizedBox(
              width: double.infinity,
              child: CpiButton(
                onPressed: () => showTxSheet(context, s),
                // Label dua baris seperti PNG 01 (FButton memberi lebar
                // tak terbatas ke anak; satu baris meluap di 390px).
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18),
                    SizedBox(width: 6),
                    Text('Tambah\ntransaksi'),
                  ],
                ),
              ),
            );
            final buat = SizedBox(
              width: double.infinity,
              child: CpiButton(
                secondary: true,
                onPressed: () => showPlanSheet(context, s),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add_road_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('Buat rencana'),
                  ],
                ),
              ),
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [tambah, const SizedBox(height: 8), buat],
              );
            }
            return Row(
              children: [
                Expanded(child: tambah),
                const SizedBox(width: 12),
                Expanded(child: buat),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        // Struktur screen12 'grid aksi': hanya aksi nyata Rangkai.
        const SectionHeader('Aksi cepat'),
        const SizedBox(height: 8),
        CpiCard(
          padding: const EdgeInsets.all(CpiTokens.panelPadding),
          child: _HomeTileGrid(
            tiles: [
              (Icons.train_outlined, 'Cari kereta', () => _openTravel('kereta')),
              (Icons.hotel_outlined, 'Cari hotel', () => _openTravel('hotel')),
              (
                Icons.call_split_outlined,
                'Budget & Split',
                () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SplitPage(store: s)),
                    ),
              ),
              (Icons.copy_outlined, 'Salin ringkasan', _copySummary),
            ],
          ),
        ),
        if (widget.onOpenTab != null) ...[
          const SizedBox(height: 20),
          const SectionHeader('Layanan'),
          const SizedBox(height: 8),
          _HomeTileGrid(
            tiles: [
              (Icons.account_balance_wallet_outlined, 'Keuangan', () => widget.onOpenTab!(1)),
              (Icons.explore_outlined, 'Rencana', () => widget.onOpenTab!(2)),
              (Icons.calendar_month_outlined, 'Kalender', () => widget.onOpenTab!(3)),
              (Icons.group_outlined, 'Workspace', () => widget.onOpenTab!(4)),
            ],
          ),
        ],
        // Slot 'rekomendasi' screen12 = rencana nyata terdekat (ref 01),
        // bukan promo. Tanpa judul bagian: kartu langsung seperti ref.
        if (plan != null) ...[
          const SizedBox(height: 16),
          PlanSummary(
            plan: plan,
            spent: s.spentOf(plan),
            distanceMeters: widget.location.distanceTo(plan.lat, plan.lng),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlanDetailPage(
                  store: s,
                  plan: plan,
                  location: widget.location,
                  ws: widget.ws,
                ),
              ),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          EmptyState(
            icon: 'calendar',
            text: 'Belum ada rencana. Buat rencana pertama kamu.',
            actionLabel: 'Buat rencana',
            onAction: () => showPlanSheet(context, s),
          ),
        ],
        const SizedBox(height: 20),
        SectionHeader(
          'Transaksi Terakhir',
          action: widget.onOpenFinance == null
              ? null
              : TextButton(
                  onPressed: widget.onOpenFinance,
                  child: const Text('Lihat semua'),
                ),
        ),
        const SizedBox(height: 8),
        if (s.txs.isEmpty)
          EmptyState(
            icon: 'chart',
            text: 'Belum ada transaksi. Catat pemasukan atau pengeluaran pertama.',
            actionLabel: 'Tambah transaksi',
            onAction: () => showTxSheet(context, s),
          )
        else
          CpiCard(
            padding: const EdgeInsets.symmetric(
              horizontal: CpiTokens.panelPadding,
              vertical: 8,
            ),
            child: Column(
              children: [
                for (var i = 0; i < s.recentTxs.take(3).length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  TransactionRow(
                    tx: s.recentTxs[i],
                    planTitle: s.recentTxs[i].planId == null
                        ? null
                        : s.plans
                            .where((p) => p.id == s.recentTxs[i].planId)
                            .firstOrNull
                            ?.title,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}


/// Grid ikon+label Beranda (struktur wireframe screen12, token v4):
/// kotak ikon r12 tint di atas, label di bawah, target sentuh >=44.
class _HomeTileGrid extends StatelessWidget {
  const _HomeTileGrid({required this.tiles});
  final List<(IconData, String, VoidCallback)> tiles;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Tinggi tile mengikuti konten (ikon 44 + label bisa 2 baris / teks
    // besar), bukan rasio tetap: GridView childAspectRatio bikin label
    // 2 baris overflow 4px di sel sempit (E2E device 22 Okt).
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth < 280 ? 2 : 4;
        final rows = <List<(IconData, String, VoidCallback)>>[];
        for (var i = 0; i < tiles.length; i += cols) {
          rows.add(tiles.skip(i).take(cols).toList());
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < cols; c++) ...[
                    if (c > 0) const SizedBox(width: 8),
                    Expanded(
                      child: c < rows[r].length
                          ? _tile(cs, tt, rows[r][c])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _tile(
    ColorScheme cs,
    TextTheme tt,
    (IconData, String, VoidCallback) tile,
  ) {
    final (icon, label, onTap) = tile;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(CpiTokens.controlRadius),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius:
                      BorderRadius.circular(CpiTokens.controlRadius),
                ),
                child: Icon(icon, size: 22, color: cs.primary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                textAlign: TextAlign.center,
                style: tt.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kompat lama; implementasi sekarang [TransactionRow].
class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, this.onDelete, this.planTitle});
  final Tx tx;
  final Future<void> Function()? onDelete;
  final String? planTitle;
  @override
  Widget build(BuildContext context) =>
      TransactionRow(tx: tx, planTitle: planTitle, onDelete: onDelete);
}

String _monthLabel(DateTime d) {
  const bln = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  return '${bln[d.month - 1]} ${d.year}';
}

// ================= KEUANGAN =================
class FinancePage extends StatefulWidget {
  const FinancePage({super.key, required this.store});
  final Store store;
  @override
  State<FinancePage> createState() => _FinancePageState();
}

class _FinancePageState extends State<FinancePage> {
  var _q = '';
  var _type = TxFilter.all;
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  Future<void> _delete(Tx t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text('"${t.title}" (${rp(t.amount.abs())}) akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await widget.store.removeTx(t.id);
    if (err != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tt = Theme.of(context).textTheme;
    final filtered = filterTxs(store.txs, query: _q, month: _month, type: _type);
    final groups = groupTxsByDay(filtered);
    String? planTitle(Tx t) => t.planId == null
        ? null
        : store.plans.where((p) => p.id == t.planId).firstOrNull?.title;
    void copySummary() {
      Clipboard.setData(
        ClipboardData(
          text:
              'Rangkai: saldo ${rp(store.balance)}, masuk ${rp(store.income)}, keluar ${rp(store.expense)} per ${tgl(DateTime.now())}.',
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ringkasan disalin.')),
      );
    }

    return ListView(
      padding: cpiPagePadding(context),
      children: [
        BalanceSummary(store: store, onCopy: copySummary),
        const SizedBox(height: 12),
        // Referensi 02: Tambah transaksi selebar konten, lalu
        // [Budget & Split | Salin Ringkasan] sejajar (stack bila sempit).
        SizedBox(
          width: double.infinity,
          child: CpiButton(
            onPressed: () => showTxSheet(context, store),
            child: const Text('Tambah transaksi'),
          ),
        ),
        const SizedBox(height: 8),
        CpiReflow(
          breakpoint: 340,
          children: [
            CpiButton(
              secondary: true,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SplitPage(store: store)),
              ),
              child: const Text('Budget & Split'),
            ),
            CpiButton(
              secondary: true,
              onPressed: copySummary,
              child: const Text('Salin Ringkasan'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              tooltip: 'Bulan sebelumnya',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.chevron_left),
              onPressed: () => _shiftMonth(-1),
            ),
            Expanded(
              child: Text(
                _monthLabel(_month),
                textAlign: TextAlign.center,
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Bulan berikutnya',
              constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _shiftMonth(1),
            ),
          ],
        ),
        Text(
          'Pemilih bulan memfilter daftar di bawah. Saldo di atas tetap total workspace aktif.',
          style: tt.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        CpiField(
          onChanged: (v) => setState(() => _q = v),
          label: 'Cari transaksi',
          hint: 'Nama, kategori, atau catatan',
          textInputAction: TextInputAction.search,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final f in [
              (TxFilter.all, 'Semua'),
              (TxFilter.income, 'Pemasukan'),
              (TxFilter.expense, 'Pengeluaran'),
            ])
              ChoiceChip(
                label: Text(f.$2),
                selected: _type == f.$1,
                onSelected: (_) => setState(() => _type = f.$1),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          EmptyState(
            icon: 'wallet',
            text: store.txs.isEmpty
                ? 'Belum ada transaksi. Catat yang pertama.'
                : _q.isNotEmpty
                    ? 'Tidak ada transaksi yang cocok dengan "$_q" di ${_monthLabel(_month)}.'
                    : 'Tidak ada transaksi pada ${_monthLabel(_month)} untuk filter ini.',
            actionLabel: store.txs.isEmpty ? 'Tambah transaksi' : null,
            onAction: store.txs.isEmpty ? () => showTxSheet(context, store) : null,
          )
        else
          for (final g in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      dayLabel(g.day, DateTime.now()),
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    '${g.subtotal >= 0 ? '+' : '-'}${rp(g.subtotal.abs())}',
                    style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            for (final t in g.items)
              TransactionRow(
                tx: t,
                planTitle: planTitle(t),
                onDelete: () => _delete(t),
              ),
          ],
      ],
    );
  }
}

// ================= BUDGET & SPLIT =================
class SplitPage extends StatefulWidget {
  const SplitPage({super.key, required this.store});
  final Store store;
  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  String? _planId;
  final _total = TextEditingController();
  var _people = 2;
  @override
  void dispose() {
    _total.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tt = Theme.of(context).textTheme;
    final plan = _planId == null
        ? (store.plans.isEmpty ? null : store.plans.first)
        : store.plans.where((p) => p.id == _planId).firstOrNull;
    final manual = _amount(_total.text);
    final total = manual ?? (plan == null ? 0 : store.spentOf(plan));
    final split = BudgetCalc.splitEqual(total, _people);
    return Scaffold(
      appBar: AppBar(title: const Text('Budget & Split')),
      body: CpiContent(
        child: ListView(
          padding: cpiPagePadding(context),
          children: [
            if (store.plans.isNotEmpty) ...[
              DropdownButtonFormField<String>(
                initialValue: plan?.id,
                decoration: _dec('Rencana'),
                items: [
                  for (final p in store.plans)
                    DropdownMenuItem(value: p.id, child: Text(p.title)),
                ],
                onChanged: (v) => setState(() => _planId = v),
              ),
              const SizedBox(height: 16),
            ],
            if (plan != null) ...[
              CpiCard(
                padding: const EdgeInsets.all(CpiTokens.panelPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plan.title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    BudgetProgress(budget: plan.budget, spent: store.spentOf(plan)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            CpiField(
              controller: _total,
              label: 'Total biaya patungan (Rp)',
              hint: plan == null ? 'Misal 750000' : 'Kosong = terpakai rencana (${rp(store.spentOf(plan))})',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: Text('Jumlah orang', style: tt.titleSmall)),
                IconButton(
                  tooltip: 'Kurangi orang',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: _people <= 1 ? null : () => setState(() => _people--),
                ),
                Text('$_people', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: 'Tambah orang',
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: _people >= 99 ? null : () => setState(() => _people++),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CpiCard(
              padding: const EdgeInsets.all(CpiTokens.panelPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Per orang', style: tt.bodySmall),
                  Text(
                    rp(split.per),
                    style: tt.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  Text(
                    split.remainder == 0
                        ? 'Total ${rp(total)} habis dibagi $_people orang.'
                        : 'Total ${rp(total)} dibagi $_people orang. Sisa ${rp(split.remainder)} tidak habis dibagi (tanggung bersama/penyelenggara).',
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            CpiButton(
              onPressed: () {
                Clipboard.setData(
                  ClipboardData(
                    text: 'Patungan Rangkai${plan == null ? '' : ' (${plan.title})'}: total ${rp(total)}, $_people orang, ${rp(split.per)} per orang${split.remainder == 0 ? '.' : ', sisa ${rp(split.remainder)}.'}',
                  ),
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Hasil patungan disalin.')),
                );
              },
              child: const Text('Salin hasil'),
            ),
            const SizedBox(height: 8),
            Text(
              'Hitungan lokal saja, bukan transfer atau pembayaran. Mengedit total tidak mengubah transaksi.',
              style: tt.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ================= RENCANA & RUNDOWN =================
enum PlanFilter { all, ongoing, upcoming }

bool _isOngoing(Plan p, DateTime today) {
  final start = DateTime(p.date.year, p.date.month, p.date.day);
  final end = DateTime(p.lastDay.year, p.lastDay.month, p.lastDay.day);
  return !today.isBefore(start) && !today.isAfter(end);
}

class PlansPage extends StatefulWidget {
  const PlansPage({
    super.key,
    required this.store,
    required this.location,
    this.ws,
    this.travel,
  });
  final Store store;
  final LocationService location;
  final WorkspaceService? ws;
  final TravelService? travel;
  @override
  State<PlansPage> createState() => _PlansPageState();
}

class _PlansPageState extends State<PlansPage> {
  var _filter = PlanFilter.all;

  void _openTravel(String kind) {
    final travel = widget.travel;
    if (travel == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TravelPage(
          travel: travel,
          store: widget.store,
          initialKind: kind,
          asRoute: true,
          location: widget.location,
        ),
      ),
    );
  }

  Future<void> _deletePlan(Plan p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Hapus rencana?'),
        content: Text(
          '"${p.title}" dihapus. Transaksi yang terkait tetap tersimpan dan kaitannya dilepas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final err = await widget.store.removePlan(p.id);
    if (err != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final shown = store.plans.where((p) {
      return switch (_filter) {
        PlanFilter.all => true,
        PlanFilter.ongoing => _isOngoing(p, today),
        PlanFilter.upcoming =>
          DateTime(p.date.year, p.date.month, p.date.day).isAfter(today),
      };
    }).toList();
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) => ListView(
        padding: cpiPagePadding(context),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CpiButton(
                onPressed: () => showPlanSheet(context, store),
                child: const Text('Buat rencana'),
              ),
              if (widget.travel != null) ...[
                CpiButton(
                  secondary: true,
                  onPressed: () => _openTravel('kereta'),
                  child: const Text('Cari kereta'),
                ),
                CpiButton(
                  secondary: true,
                  onPressed: () => _openTravel('hotel'),
                  child: const Text('Cari hotel'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in [
                (PlanFilter.all, 'Semua', store.plans.length),
                (
                  PlanFilter.ongoing,
                  'Berlangsung',
                  store.plans.where((p) => _isOngoing(p, today)).length,
                ),
                (
                  PlanFilter.upcoming,
                  'Mendatang',
                  store.plans
                      .where((p) => DateTime(p.date.year, p.date.month, p.date.day).isAfter(today))
                      .length,
                ),
              ])
                ChoiceChip(
                  label: Text('${f.$2} (${f.$3})'),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Tekan lama kartu untuk hapus rencana. Transaksi tetap tersimpan.',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 8),
          if (shown.isEmpty)
            EmptyState(
              icon: 'calendar',
              text: store.plans.isEmpty
                  ? 'Belum ada rencana. Buat acara atau trip pertama kamu.'
                  : 'Tidak ada rencana untuk filter ini.',
              actionLabel: store.plans.isEmpty ? 'Buat rencana' : null,
              onAction: store.plans.isEmpty
                  ? () => showPlanSheet(context, store)
                  : null,
            )
          else
            for (final p in shown)
              GestureDetector(
                onLongPress: () => _deletePlan(p),
                child: Hero(
                  tag: 'plan-${p.id}',
                  child: Material(
                    type: MaterialType.transparency,
                    child: PlanSummary(
                      plan: p,
                      spent: store.spentOf(p),
                      distanceMeters: widget.location.distanceTo(p.lat, p.lng),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlanDetailPage(
                            store: store,
                            plan: p,
                            location: widget.location,
                            ws: widget.ws,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          if (widget.travel != null) ...[
            const SizedBox(height: 20),
            const SectionHeader('Inspirasi & Estimasi Perjalanan'),
            Text(
              'Nama tempat dari OpenStreetMap. Harga merupakan estimasi aplikasi.',
              style: tt.bodySmall,
            ),
            const SizedBox(height: 8),
            CpiCard(
              padding: const EdgeInsets.all(CpiTokens.panelPadding),
              child: Row(
                children: [
                  const CPIcon('train', size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cari Kereta', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text('Estimasi biaya perjalanan', style: tt.bodySmall),
                      ],
                    ),
                  ),
                  CpiButton(
                    secondary: true,
                    onPressed: () => _openTravel('kereta'),
                    child: const Text('Cari rute'),
                  ),
                ],
              ),
            ),
            CpiCard(
              padding: const EdgeInsets.all(CpiTokens.panelPadding),
              child: Row(
                children: [
                  const CPIcon('hotel', size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Cari Hotel', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                        Text('Estimasi penginapan sekitar destinasi', style: tt.bodySmall),
                      ],
                    ),
                  ),
                  CpiButton(
                    secondary: true,
                    onPressed: () => _openTravel('hotel'),
                    child: const Text('Cari hotel'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ================= KALENDER (tab mandiri) =================
/// Rencana yang belum berakhir (berlangsung/mendatang), terdekat dulu.
/// Bagian 'Rencana mendatang' ref 08 tidak menampilkan yang sudah lewat.
List<Plan> _upcomingPlans(List<Plan> plans, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  return plans
      .where((p) => !DateTime(p.lastDay.year, p.lastDay.month, p.lastDay.day).isBefore(today))
      .toList()
    ..sort((a, b) => a.date.compareTo(b.date));
}

class CalendarPage extends StatelessWidget {
  const CalendarPage({
    super.key,
    required this.store,
    required this.location,
    this.ws,
  });
  final Store store;
  final LocationService location;
  final WorkspaceService? ws;
  @override
  Widget build(BuildContext context) => ListView(
    padding: cpiPagePadding(context),
    children: [
      SectionHeader(
        'Agenda rundown',
        action: CpiButton(
          onPressed: () => showPlanSheet(context, store),
          child: const Text('Buat rencana'),
        ),
      ),
      const SizedBox(height: 8),
      PlanCalendar(store: store, location: location, ws: ws),
      const SizedBox(height: 16),
      const SectionHeader('Rencana mendatang'),
      if (_upcomingPlans(store.plans, DateTime.now()).isEmpty)
        const EmptyState(icon: 'calendar', text: 'Belum ada rencana mendatang.')
      else
        for (final p in _upcomingPlans(store.plans, DateTime.now()))
          PlanSummary(
            plan: p,
            spent: store.spentOf(p),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlanDetailPage(
                  store: store,
                  plan: p,
                  location: location,
                  ws: ws,
                ),
              ),
            ),
          ),
    ],
  );
}

class PlanDetailPage extends StatefulWidget {
  const PlanDetailPage({
    super.key,
    required this.store,
    required this.plan,
    required this.location,
    this.ws,
  });
  final Store store;
  final Plan plan;
  final LocationService location;
  final WorkspaceService? ws;
  @override
  State<PlanDetailPage> createState() => _PlanDetailPageState();
}

class _PlanDetailPageState extends State<PlanDetailPage> {
  var _tracking = false;
  double? _startMeters;
  var _selesaiDitangani = false;
  Store get store => widget.store;
  Plan get plan => widget.plan;

  /// Aksi manual wajib konfirmasi (kedatangan GPS/centang semua tidak).
  Future<void> _selesaiManual() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Selesaikan dan hapus?'),
        content: Text(
          'Perjalanan "${plan.title}" ditandai selesai lalu rencananya dihapus. '
          'Transaksi yang terkait tetap tersimpan dan kaitannya dilepas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Selesaikan dan hapus'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      _selesaiOtomatis(
        'Perjalanan ${plan.title} ditandai selesai. Rencana otomatis dihapus.',
      );
    }
  }

  Future<void> _selesaiOtomatis(String pesan) async {
    if (_selesaiDitangani) return;
    _selesaiDitangani = true;
    final messenger = ScaffoldMessenger.of(context);
    final err = await store.completeAndRemove(plan);
    if (!mounted) return;
    if (err != null) {
      _selesaiDitangani = false;
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(content: Text(pesan)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([store, widget.location]),
      builder: (context, _) {
        if (!store.plans.contains(plan))
          return const Scaffold(body: SizedBox.shrink());
        final spent = store.spentOf(plan);
        final now = DateTime.now();
        final aktif = activeRundown(plan.rundown, now.hour * 60 + now.minute);
        final status = plan.rundown.isEmpty
            ? 'Rundown masih kosong'
            : aktif == -1
            ? 'Belum mulai. Kegiatan pertama jam ${plan.rundown.first.time}.'
            : aktif >= plan.rundown.length
            ? 'Semua rundown sudah lewat hari ini.'
            : 'Sedang berlangsung: ${plan.rundown[aktif].title}';
        final sisaMeter = widget.location.distanceTo(plan.lat, plan.lng);
        if (_tracking && isArrived(sisaMeter)) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _selesaiOtomatis(
              'Kamu sudah sampai di ${plan.place}. Rencana otomatis selesai dan dihapus.',
            ),
          );
        }
        final progres = (_tracking && _startMeters != null && sisaMeter != null)
            ? tripProgress(_startMeters!, sisaMeter)
            : 0.0;
        final sisaTeks = sisaMeter == null
            ? 'Tujuan belum punya koordinat. Edit rencana lewat hapus lalu buat lagi dengan memilih hasil pencarian tempat.'
            : sisaMeter >= 1000
            ? '${(sisaMeter / 1000).toStringAsFixed(1)} km lagi ke ${plan.place}'
            : '${sisaMeter.toStringAsFixed(0)} meter lagi ke ${plan.place}';
        return Scaffold(
          appBar: AppBar(title: Text(plan.title)),
          body: ListView(
            padding: cpiPagePadding(context),
            children: [
              Hero(
                tag: 'plan-${plan.id}',
                child: Material(
                  type: MaterialType.transparency,
                  child: CpiCard(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            plan.endDate == null
                                ? '${plan.place} · ${tgl(plan.date)} · ${planDurationLabel(plan)}'
                                : '${plan.place} · ${tgl(plan.date)} – ${tgl(plan.endDate!)} · ${planDurationLabel(plan)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 4),
                          StatusLabel(
                            planStatusLabel(plan, DateTime.now()),
                            tone: planStatusLabel(plan, DateTime.now()) ==
                                    'Sedang Berlangsung'
                                ? StatusTone.active
                                : StatusTone.waiting,
                          ),
                          const SizedBox(height: 12),
                          BudgetProgress(budget: plan.budget, spent: spent),
                          const SizedBox(height: 8),
                          Text(
                            'Estimasi rundown ${rp(plan.estimasi)} (belum tentu pengeluaran aktual)',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Tracking GPS asli: jarak dihitung dari posisi HP ke koordinat tujuan setiap stream lokasi bergerak.
              CpiCard(
                child: Padding(
                  padding: const EdgeInsets.all(CpiTokens.panelPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (_tracking)
                            const LiveDot()
                          else
                            Icon(
                              Icons.location_on_outlined,
                              size: 18,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Tracking GPS realtime',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          StatusLabel(
                            _tracking ? 'Tracking aktif' : 'Tracking nonaktif',
                            tone: _tracking ? StatusTone.active : StatusTone.waiting,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        status,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sisaTeks,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      if (widget.location.pos != null)
                        Text(
                          'Posisi kamu: ${widget.location.pos!.latitude.toStringAsFixed(5)}, ${widget.location.pos!.longitude.toStringAsFixed(5)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: progres),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: sisaMeter == null
                                ? null
                                : () => setState(() {
                                    _tracking = !_tracking;
                                    if (_tracking) _startMeters ??= sisaMeter;
                                  }),
                            icon: Icon(
                              _tracking ? Icons.pause : Icons.play_arrow,
                            ),
                            label: Text(
                              _tracking ? 'Jeda tracking' : 'Mulai tracking',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Saat jarak GPS 150 meter atau kurang, rencana otomatis selesai dan dihapus. Transaksi yang terkait tetap tersimpan.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CheckpointSection(
                plan: plan,
                location: widget.location,
                ws: widget.ws,
              ),
              const SizedBox(height: 16),
              SectionHeader(
                'Susunan acara (rundown)',
                action: TextButton.icon(
                  onPressed: () => showRundownSheet(context, store, plan),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tambah rundown'),
                ),
              ),
              const SizedBox(height: 8),
              if (plan.rundown.isEmpty)
                const EmptyState(
                  icon: 'clock',
                  text: 'Rundown kosong. Ketuk Tambah rundown.',
                )
              else
                for (final r in plan.rundown)
                  CpiCard(
                    child: CheckboxListTile(
                      value: r.done,
                      onChanged: (_) async {
                        final err = await store.toggleRundown(plan, r);
                        if (!context.mounted) return;
                        if (err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(err)),
                          );
                          return;
                        }
                        if (plan.semuaSelesai) {
                          _selesaiOtomatis(
                            'Semua rundown ${plan.title} selesai. Rencana otomatis dihapus.',
                          );
                        }
                      },
                      title: Text(
                        r.title,
                        style: TextStyle(
                          decoration: r.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      subtitle: Text(
                        '${tgl(r.day ?? plan.date)} · ${r.cost > 0 ? 'Estimasi ${rp(r.cost)}' : 'Tanpa estimasi biaya'} · ${r.done ? 'Selesai' : 'Belum selesai'}',
                      ),
                      secondary: Wrap(
                        spacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Chip(label: Text(r.time)),
                          IconButton(
                            tooltip: 'Hapus rundown',
                            icon: const Icon(Icons.delete_outline, size: 19),
                            onPressed: () async {
                              final err = await store.removeRundown(plan, r);
                              if (err != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(err)),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: 16),
              SectionHeader('Transaksi terkait (${store.txs.where((t) => t.planId == plan.id).length})'),
              const SizedBox(height: 4),
              if (store.txs.where((t) => t.planId == plan.id).isEmpty)
                Text(
                  'Belum ada pengeluaran terkait rencana ini.',
                  style: Theme.of(context).textTheme.bodySmall,
                )
              else
                for (final t in store.txs.where((t) => t.planId == plan.id))
                  TransactionRow(tx: t),
              const SizedBox(height: 24),
              // Referensi 04: aksi destruktif di akhir alur, bukan FAB.
              SizedBox(
                width: double.infinity,
                child: CpiButton(
                  destructive: true,
                  onPressed: _selesaiManual,
                  child: const Text('Selesaikan dan hapus rencana'),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Rencana dihapus setelah konfirmasi. Transaksi tetap tersimpan di Keuangan.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ================= TRAVEL LIVE =================
class TravelPage extends StatefulWidget {
  const TravelPage({
    super.key,
    required this.travel,
    this.store,
    this.initialKind = 'semua',
    this.asRoute = false,
    this.location,
  });
  final TravelService travel;

  /// Bila ada, hasil travel bisa ditambahkan ke rundown rencana.
  final Store? store;
  final String initialKind;

  /// true = dibuka sebagai route dari Rencana (punya Scaffold sendiri).
  final bool asRoute;
  final LocationService? location;
  @override
  State<TravelPage> createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> {
  late var _filter = widget.initialKind;
  var _murahDulu = false;
  final _search = TextEditingController();

  /// Estimasi travel -> rundown rencana. Bukan checkout/pembayaran:
  /// yang disimpan hanya jadwal + biaya estimasi lewat Store.
  void _addToPlan(Offer o) {
    final store = widget.store;
    if (store == null) return;
    if (store.plans.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Buat rencana dulu, baru tambahkan hasil ini.'),
          action: SnackBarAction(
            label: 'Buat rencana',
            onPressed: () => showPlanSheet(context, store),
          ),
        ),
      );
      return;
    }
    var plan = store.plans.first;
    var day = plan.date;
    var time = '09:00';
    var qty = 1;
    var busy = false;
    final unit = o.kind == 'hotel' ? 'malam' : 'orang';
    _sheet(
      context,
      StatefulBuilder(
        builder: (c, setS) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Tambahkan ke rencana', style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${o.name} · estimasi ${rp(o.price)} per $unit. Disimpan sebagai rundown estimasi, bukan pembayaran.',
              style: Theme.of(c).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: plan.id,
              decoration: _dec('Rencana tujuan'),
              items: [
                for (final pl in store.plans)
                  DropdownMenuItem(value: pl.id, child: Text(pl.title)),
              ],
              onChanged: busy
                  ? null
                  : (v) => setS(() {
                        plan = store.plans.firstWhere((e) => e.id == v);
                        day = plan.date;
                      }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const CPIcon('calendar', size: 18),
                    label: Text(tgl(day)),
                    onPressed: busy
                        ? null
                        : () async {
                            final d = await showDatePicker(
                              context: c,
                              initialDate: day,
                              firstDate: plan.date,
                              lastDate: plan.lastDay.isAfter(plan.date)
                                  ? plan.lastDay
                                  : plan.date.add(const Duration(days: 730)),
                            );
                            if (d != null) setS(() => day = d);
                          },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const CPIcon('clock', size: 18),
                    label: Text('Jam $time'),
                    onPressed: busy
                        ? null
                        : () async {
                            final tm = await showTimePicker(
                              context: c,
                              initialTime: const TimeOfDay(hour: 9, minute: 0),
                            );
                            if (tm != null) {
                              setS(() => time =
                                  '${tm.hour.toString().padLeft(2, '0')}:${tm.minute.toString().padLeft(2, '0')}');
                            }
                          },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: Text('Jumlah ($unit)')),
                IconButton(
                  tooltip: 'Kurangi',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: busy || qty <= 1 ? null : () => setS(() => qty--),
                ),
                Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
                IconButton(
                  tooltip: 'Tambah',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: busy || qty >= 99 ? null : () => setS(() => qty++),
                ),
              ],
            ),
            Text(
              'Total estimasi ${rp(o.price * qty)} ($qty $unit × ${rp(o.price)})',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            CpiButton(
              busy: busy,
              onPressed: busy
                  ? null
                  : () async {
                      setS(() => busy = true);
                      final err = await store.addRundown(
                        plan,
                        Rundown(
                          id: Store.newId(),
                          time: time,
                          title: o.kind == 'hotel' ? 'Menginap: ${o.name}' : o.name,
                          cost: o.price * qty,
                          day: day,
                        ),
                      );
                      if (!c.mounted) return;
                      setS(() => busy = false);
                      if (err != null) {
                        ScaffoldMessenger.of(c)
                            .showSnackBar(SnackBar(content: Text(err)));
                        return;
                      }
                      Navigator.pop(c);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Ditambahkan ke rundown ${plan.title} sebagai estimasi.'),
                        ),
                      );
                    },
              child: const Text('Simpan ke rundown'),
            ),
            const SizedBox(height: 8),
            CpiButton(
              secondary: true,
              onPressed: busy ? null : () => Navigator.pop(c),
              child: const Text('Batal'),
            ),
          ],
        ),
      ),
    );
  }
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final travel = widget.travel;
    final tt = Theme.of(context).textTheme;
    List<Offer> ofKind(String kind) {
      final l = travel.offers.where((e) => e.kind == kind).toList();
      if (_murahDulu) l.sort((a, b) => a.price.compareTo(b.price));
      return l;
    }

    Widget list(String kind, String icon) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CPIcon(icon, size: 20),
            const SizedBox(width: 8),
            Text(
              kind == 'kereta' ? 'Kereta' : 'Hotel',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (ofKind(kind).isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Belum ada hasil ${kind == 'kereta' ? 'kereta' : 'hotel'}. Cari kota tujuan di atas.',
              style: tt.bodySmall,
            ),
          ),
        for (final o in ofKind(kind))
          CpiCard(
            child: Padding(
              padding: const EdgeInsets.all(CpiTokens.panelPadding),
              child: CpiReflow(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.name, style: tt.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        '${o.from} → ${o.to}\n${o.meta}',
                        style: tt.bodySmall,
                      ),
                      if (widget.location?.distanceTo(o.lat, o.lng) != null)
                        Text(
                          'Jarak dari posisi kamu: ${(widget.location!.distanceTo(o.lat, o.lng)! / 1000).toStringAsFixed(1)} km',
                          style: tt.bodySmall,
                        ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedMoney(
                        o.price,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        o.kind == 'hotel' ? 'Estimasi per malam' : 'Estimasi per orang',
                        style: tt.bodySmall,
                      ),
                      Text(
                        o.delta == 0
                            ? 'Estimasi stabil'
                            : 'Perubahan estimasi ${o.delta > 0 ? '+' : '-'}${rp(o.delta.abs())}',
                        style: tt.bodySmall,
                      ),
                      if (widget.store != null) ...[
                        const SizedBox(height: 8),
                        CpiButton(
                          secondary: true,
                          onPressed: () => _addToPlan(o),
                          child: const Text('Tambahkan'),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    final body = RefreshIndicator(
      onRefresh: travel.refresh,
      child: ListView(
        padding: cpiPagePadding(context),
        children: [
          Row(
            children: [
              const LiveDot(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Estimasi live · sync ${jam(travel.lastSync)}',
                  style: tt.bodySmall,
                ),
              ),
              if (travel.syncing)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Tarik ke bawah buat refresh. Harga bergerak tiap 8 detik.',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 12),
          CpiField(
            controller: _search,
            textInputAction: TextInputAction.search,
            label: 'Kota tujuan',
            hint: 'Cari kota tujuan',
            onSubmitted: (_) => travel.search(
              _search.text,
              _filter == 'hotel' ? 'hotel' : 'kereta',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CpiButton(
                secondary: true,
                onPressed: travel.syncing
                    ? null
                    : () => travel.search(_search.text, 'kereta'),
                child: const Text('Cari kereta'),
              ),
              CpiButton(
                secondary: true,
                onPressed: travel.syncing
                    ? null
                    : () => travel.search(_search.text, 'hotel'),
                child: const Text('Cari hotel'),
              ),
            ],
          ),
          if (travel.syncing) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (travel.error != null) ...[
            const SizedBox(height: 12),
            Text(
              travel.error!,
              style: tt.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            Text(
              'Periksa ejaan kota atau koneksi internet, lalu coba cari lagi.',
              style: tt.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final f in [
                ('semua', 'Semua'),
                ('kereta', 'Kereta'),
                ('hotel', 'Hotel'),
              ])
                ChoiceChip(
                  label: Text(f.$2),
                  selected: _filter == f.$1,
                  onSelected: (_) => setState(() => _filter = f.$1),
                ),
              FilterChip(
                label: const Text('Paling murah dulu'),
                selected: _murahDulu,
                onSelected: (v) => setState(() => _murahDulu = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_filter != 'hotel') list('kereta', 'train'),
          if (_filter == 'semua') const SizedBox(height: 12),
          if (_filter != 'kereta') list('hotel', 'hotel'),
          const SizedBox(height: 16),
          Text(
            'Nama tempat dari OpenStreetMap. Harga adalah estimasi aplikasi, bukan tarif resmi, pembayaran, atau pemesanan tiket.',
            style: tt.bodySmall,
          ),
        ],
      ),
    );
    if (!widget.asRoute) return body;
    return Scaffold(
      appBar: AppBar(
        title: Text(_filter == 'hotel' ? 'Cari hotel' : 'Cari kereta'),
      ),
      body: body,
    );
  }
}

// ================= SHEETS / FORMS =================
Future<void> _sheet(BuildContext c, Widget child) => showModalBottomSheet(
  context: c,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (context) => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      CpiTokens.pagePadding,
      8,
      CpiTokens.pagePadding,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: child,
  ),
);

InputDecoration _dec(String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());

/// Batas waras anti salah ketik/overflow: 0 < jumlah <= Rp999 miliar.
const _maxAmount = 999000000000.0;
double? _amount(String s) {
  final digits = s.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty || digits.length > 15) return null;
  final v = double.tryParse(digits);
  return (v == null || v <= 0 || v > _maxAmount) ? null : v;
}

/// Judul disimpan ringkas & aman: trim, satu baris, maks 80 karakter.
String _cleanTitle(String s) {
  final t = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.length <= 80 ? t : t.substring(0, 80).trim();
}

void showTxSheet(BuildContext context, Store store) {
  final title = TextEditingController(),
      amount = TextEditingController(),
      note = TextEditingController();
  var income = false;
  var category = 'Umum';
  var date = DateTime.now();
  var busy = false;
  String? planId, titleError, amountError;
  _sheet(
    context,
    StatefulBuilder(
      builder: (c, setS) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tambah transaksi', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 14),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Pengeluaran')),
              ButtonSegment(value: true, label: Text('Pemasukan')),
            ],
            selected: {income},
            onSelectionChanged: busy
                ? null
                : (v) => setS(() {
                      income = v.first;
                      if (income) planId = null;
                      category = income ? 'Pendapatan' : 'Umum';
                    }),
          ),
          const SizedBox(height: 12),
          CpiField(
            controller: amount,
            label: 'Jumlah (Rp)',
            error: amountError,
            helper: 'Angka saja, tanpa titik/koma.',
            enabled: !busy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          CpiField(
            controller: title,
            label: 'Nama transaksi',
            error: titleError,
            maxLength: 80,
            enabled: !busy,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const CPIcon('calendar', size: 18),
            label: Text('Tanggal: ${tgl(date)}'),
            onPressed: busy
                ? null
                : () async {
                    final d = await showDatePicker(
                      context: c,
                      initialDate: date,
                      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (d != null) setS(() => date = d);
                  },
          ),
          const SizedBox(height: 12),
          CategorySelector(
            value: category,
            onChanged: busy ? (_) {} : (v) => setS(() => category = v),
          ),
          if (!income && store.plans.isNotEmpty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: planId,
              decoration: _dec('Kaitkan ke rencana (opsional)'),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Tanpa rencana'),
                ),
                for (final p in store.plans)
                  DropdownMenuItem(value: p.id, child: Text(p.title)),
              ],
              onChanged: busy ? null : (v) => setS(() => planId = v),
            ),
          ],
          const SizedBox(height: 12),
          CpiField(
            controller: note,
            label: 'Catatan (opsional)',
            maxLength: 200,
            enabled: !busy,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 16),
          CpiButton(
            busy: busy,
            onPressed: busy
                ? null
                : () async {
                    final a = _amount(amount.text);
                    setS(() {
                      titleError = _cleanTitle(title.text).isEmpty
                          ? 'Nama transaksi wajib diisi.'
                          : null;
                      amountError = a == null
                          ? 'Jumlah harus lebih dari 0 dan masuk akal.'
                          : null;
                    });
                    if (titleError != null || amountError != null) return;
                    setS(() => busy = true);
                    final now = DateTime.now();
                    final err = await store.addTx(
                      Tx(
                        id: Store.newId(),
                        title: _cleanTitle(title.text),
                        amount: income ? a! : -a!,
                        date: DateTime(date.year, date.month, date.day, now.hour, now.minute),
                        planId: income ? null : planId,
                        category: category,
                        note: _cleanTitle(note.text).isEmpty
                            ? ''
                            : note.text.trim(),
                      ),
                    );
                    if (!c.mounted) return;
                    setS(() => busy = false);
                    if (err != null) {
                      ScaffoldMessenger.of(
                        c,
                      ).showSnackBar(SnackBar(content: Text(err)));
                      return;
                    }
                    Navigator.pop(c);
                  },
            child: const Text('Simpan transaksi'),
          ),
          const SizedBox(height: 8),
          CpiButton(
            secondary: true,
            onPressed: busy ? null : () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
        ],
      ),
    ),
  );
}

void showPlanSheet(BuildContext context, Store store) {
  final title = TextEditingController(),
      place = TextEditingController(),
      budget = TextEditingController(),
      firstActivity = TextEditingController(),
      firstCost = TextEditingController();
  var firstTime = '08:00';
  var date = DateTime.now().add(const Duration(days: 7));
  DateTime? endDate;
  Place? picked;
  List<Place> results = [];
  var searching = false;
  var busy = false;
  String? searchError, formError;
  _sheet(
    context,
    StatefulBuilder(
      builder: (c, setS) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Buat rencana', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Atur sendiri semuanya. Pilih hasil pencarian tempat supaya GPS bisa membaca kedatangan kamu.',
            style: Theme.of(c).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          CpiField(
            controller: title,
            label: 'Nama acara atau trip',
            maxLength: 80,
            enabled: !busy,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CpiField(
                  controller: place,
                  label: 'Cari tempat tujuan',
                  maxLength: 120,
                  enabled: !busy,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setS(() => picked = null),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Cari tempat',
                icon: const Icon(Icons.search),
                onPressed: searching || busy
                    ? null
                    : () async {
                        setS(() {
                          searching = true;
                          searchError = null;
                        });
                        try {
                          final r = await GeoApi.searchPlace(place.text);
                          setS(() {
                            results = r;
                            searching = false;
                            if (r.isEmpty) {
                              searchError =
                                  'Tempat tidak ditemukan. Coba nama kota atau daerah lain.';
                            }
                          });
                        } catch (_) {
                          setS(() {
                            searching = false;
                            searchError =
                                'Pencarian gagal. Cek internet kamu lalu coba lagi.';
                          });
                        }
                      },
              ),
            ],
          ),
          if (searching) ...[
            const SizedBox(height: 10),
            const LinearProgressIndicator(),
          ],
          if (searchError != null) ...[
            const SizedBox(height: 8),
            Text(
              searchError!,
              style: TextStyle(color: Theme.of(c).colorScheme.error),
            ),
          ],
          if (results.isNotEmpty) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in results)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        p.detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: picked == p
                          ? Icon(
                              Icons.check_circle,
                              color: Theme.of(c).colorScheme.primary,
                            )
                          : null,
                      selected: picked == p,
                      onTap: busy
                          ? null
                          : () => setS(() {
                                picked = p;
                                place.text = p.name;
                              }),
                    ),
                ],
              ),
            ),
          ],
          if (picked != null) ...[
            const SizedBox(height: 6),
            StatusLabel(
              'Tujuan dipilih: ${picked!.lat.toStringAsFixed(4)}, ${picked!.lng.toStringAsFixed(4)} (tersimpan saat Simpan rencana berhasil)',
              tone: StatusTone.active,
            ),
          ],
          const SizedBox(height: 12),
          CpiField(
            controller: budget,
            label: 'Anggaran (Rp)',
            enabled: !busy,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const CPIcon('calendar', size: 18),
                  label: Text('Mulai: ${tgl(date)}'),
                  onPressed: busy
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: c,
                            initialDate: date,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (d != null) {
                            setS(() {
                              date = d;
                              if (endDate != null && endDate!.isBefore(d)) {
                                endDate = d;
                              }
                            });
                          }
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const CPIcon('calendar', size: 18),
                  label: Text(
                    endDate == null ? 'Selesai: sama hari' : 'Selesai: ${tgl(endDate!)}',
                  ),
                  onPressed: busy
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: c,
                            initialDate: endDate ?? date,
                            firstDate: date,
                            lastDate: DateTime.now().add(const Duration(days: 730)),
                          );
                          if (d != null) setS(() => endDate = d);
                        },
                ),
              ),
            ],
          ),
          if (endDate != null)
            TextButton(
              onPressed: busy ? null : () => setS(() => endDate = null),
              child: const Text('Jadikan satu hari'),
            ),
          const SizedBox(height: 12),
          Text('Susunan kegiatan awal (opsional)',
              style: Theme.of(c).textTheme.titleSmall),
          const SizedBox(height: 8),
          CpiField(
            controller: firstActivity,
            label: 'Kegiatan pertama',
            hint: 'Boleh kosong, bisa ditambah nanti',
            maxLength: 120,
            enabled: !busy,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CpiField(
                  controller: firstCost,
                  label: 'Estimasi biaya (Rp)',
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                icon: const CPIcon('clock', size: 18),
                label: Text(firstTime),
                onPressed: busy
                    ? null
                    : () async {
                        final tm = await showTimePicker(
                          context: c,
                          initialTime: const TimeOfDay(hour: 8, minute: 0),
                        );
                        if (tm != null) {
                          setS(() => firstTime =
                              '${tm.hour.toString().padLeft(2, '0')}:${tm.minute.toString().padLeft(2, '0')}');
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Info radius: rencana selesai dan dihapus dalam radius 150 m dari tujuan. Transaksi tetap tersimpan.',
            style: Theme.of(c).textTheme.bodySmall,
          ),
          if (formError != null) ...[
            const SizedBox(height: 8),
            Text(
              formError!,
              style: TextStyle(color: Theme.of(c).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          CpiButton(
            busy: busy,
            onPressed: busy
                ? null
                : () async {
                    final b = _amount(budget.text);
                    setS(
                      () => formError =
                          _cleanTitle(title.text).isEmpty || b == null
                              ? 'Isi nama dan anggaran yang valid dulu.'
                              : picked == null
                                  ? 'Pilih satu hasil pencarian tempat dulu agar koordinat tersimpan.'
                                  : (endDate != null && endDate!.isBefore(date))
                                      ? 'Tanggal selesai tidak boleh sebelum tanggal mulai.'
                                      : null,
                    );
                    if (formError != null) return;
                    setS(() => busy = true);
                    final err = await store.addPlan(
                      Plan(
                        id: Store.newId(),
                        title: _cleanTitle(title.text),
                        place: picked!.name,
                        date: date,
                        endDate: endDate,
                        budget: b!,
                        lat: picked!.lat,
                        lng: picked!.lng,
                        rundown: _cleanTitle(firstActivity.text).isEmpty
                            ? []
                            : [
                                Rundown(
                                  id: Store.newId(),
                                  time: firstTime,
                                  title: _cleanTitle(firstActivity.text),
                                  cost: _amount(firstCost.text) ?? 0,
                                  day: date,
                                ),
                              ],
                      ),
                    );
                    if (!c.mounted) return;
                    setS(() => busy = false);
                    if (err != null) {
                      ScaffoldMessenger.of(
                        c,
                      ).showSnackBar(SnackBar(content: Text(err)));
                      return;
                    }
                    Navigator.pop(c);
                  },
            child: const Text('Simpan rencana'),
          ),
          const SizedBox(height: 8),
          CpiButton(
            secondary: true,
            onPressed: busy ? null : () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
        ],
      ),
    ),
  );
}

void showRundownSheet(BuildContext context, Store store, Plan plan) {
  final title = TextEditingController(), cost = TextEditingController();
  var time = '09:00';
  var day = plan.date;
  var busy = false;
  String? formError;
  _sheet(
    context,
    StatefulBuilder(
      builder: (c, setS) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tambah rundown', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 14),
          CpiField(
            controller: title,
            label: 'Kegiatan',
            maxLength: 120,
            enabled: !busy,
          ),
          const SizedBox(height: 12),
          CpiField(
            controller: cost,
            label: 'Estimasi biaya (Rp, boleh 0)',
            helper: 'Estimasi saja, bukan pengeluaran aktual.',
            enabled: !busy,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const CPIcon('calendar', size: 18),
                  label: Text(tgl(day)),
                  onPressed: busy
                      ? null
                      : () async {
                          final d = await showDatePicker(
                            context: c,
                            initialDate: day,
                            firstDate: plan.date,
                            lastDate: plan.lastDay.isAfter(plan.date)
                                ? plan.lastDay
                                : plan.date.add(const Duration(days: 730)),
                          );
                          if (d != null) setS(() => day = d);
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const CPIcon('clock', size: 18),
                  label: Text('Jam $time'),
                  onPressed: busy
                      ? null
                      : () async {
                          final t = await showTimePicker(
                            context: c,
                            initialTime: const TimeOfDay(hour: 9, minute: 0),
                          );
                          if (t != null) {
                            setS(
                              () => time =
                                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                            );
                          }
                        },
                ),
              ),
            ],
          ),
          if (formError != null) ...[
            const SizedBox(height: 8),
            Text(
              formError!,
              style: TextStyle(color: Theme.of(c).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          CpiButton(
            busy: busy,
            onPressed: busy
                ? null
                : () async {
                    setS(
                      () => formError = _cleanTitle(title.text).isEmpty
                          ? 'Isi nama kegiatan dulu.'
                          : null,
                    );
                    if (formError != null) return;
                    setS(() => busy = true);
                    final err = await store.addRundown(
                      plan,
                      Rundown(
                        id: Store.newId(),
                        time: time,
                        title: _cleanTitle(title.text),
                        cost: _amount(cost.text) ?? 0,
                        day: day,
                      ),
                    );
                    if (!c.mounted) return;
                    setS(() => busy = false);
                    if (err != null) {
                      ScaffoldMessenger.of(
                        c,
                      ).showSnackBar(SnackBar(content: Text(err)));
                      return;
                    }
                    Navigator.pop(c);
                  },
            child: const Text('Simpan rundown'),
          ),
          const SizedBox(height: 8),
          CpiButton(
            secondary: true,
            onPressed: busy ? null : () => Navigator.pop(c),
            child: const Text('Batal'),
          ),
        ],
      ),
    ),
  );
}
