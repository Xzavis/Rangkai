import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'absen.dart';
import 'calendar.dart';
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
  });
  final Store store;
  final TravelService travel;
  final Zone zone;
  final ValueChanged<Zone> onZone;
  final LocationService location;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final Stream<DateTime> _clock = Stream.periodic(
    const Duration(seconds: 1),
    (_) => DateTime.now().toUtc(),
  );
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme, tt = Theme.of(context).textTheme;
    final s = widget.store;
    final plan = s.plans.isEmpty ? null : s.plans.first;
    return ListView(
      padding: cpiPagePadding(context),
      children: [
        // Hero: realtime clock, synced to selected place
        StreamBuilder<DateTime>(
          stream: _clock,
          initialData: DateTime.now().toUtc(),
          builder: (_, snap) {
            final t = widget.zone.at(snap.data!);
            return Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(6),
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
                          'LIVE · ${widget.zone.city} (${widget.zone.label})',
                          style: tt.labelLarge?.copyWith(
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const CPIcon('clock', size: 20),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    jam(t),
                    style: tt.headlineLarge?.copyWith(
                      fontFamily: CpiTokens.mono,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  Text(
                    tgl(DateTime(t.year, t.month, t.day)),
                    style: tt.bodyLarge?.copyWith(color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(height: 14),
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
        const SizedBox(height: 12),
        if (widget.location.pos != null)
          Row(
            children: [
              const LiveDot(),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'GPS realtime: ${widget.location.pos!.latitude.toStringAsFixed(5)}, ${widget.location.pos!.longitude.toStringAsFixed(5)} (akurasi ${widget.location.pos!.accuracy.toStringAsFixed(0)} m)',
                  style: tt.bodySmall,
                ),
              ),
            ],
          ),
        const SizedBox(height: 16),
        // Saldo
        CpiCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CPIcon('wallet', size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Saldo saat ini', style: tt.titleSmall),
                    ),
                    IconButton(
                      tooltip: 'Salin ringkasan',
                      icon: const Icon(Icons.copy_outlined, size: 19),
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(
                            text:
                                'Rangkai: saldo ${rp(s.balance)}, masuk ${rp(s.income)}, keluar ${rp(s.expense)} per ${tgl(DateTime.now())}.',
                          ),
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Ringkasan disalin. Tinggal paste ke chat atau catatan.',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                AnimatedMoney(
                  s.balance,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                CpiReflow(
                  children: [
                    _Mini(
                      label: 'Pemasukan',
                      value: s.income,
                      color: cs.onSurface,
                    ),
                    _Mini(
                      label: 'Pengeluaran',
                      value: s.expense,
                      color: cs.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (plan != null) ...[
          const SizedBox(height: 16),
          CpiCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: CpiReflow(
                children: [
                  BudgetRing(
                    ratio: BudgetCalc.ratio(plan.budget, s.spentOf(plan)),
                    center: Text(
                      '${(BudgetCalc.ratio(plan.budget, s.spentOf(plan)) * 100).round()}%',
                      style: tt.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.title,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${plan.place} · ${tgl(plan.date)}',
                        style: tt.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      Text('Budget ${rp(plan.budget)}', style: tt.bodyMedium),
                      Text(
                        'Terpakai ${rp(s.spentOf(plan))}',
                        style: tt.bodyMedium,
                      ),
                      Text(
                        'Sisa ${rp(BudgetCalc.sisa(plan.budget, s.spentOf(plan)))}',
                        style: tt.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              BudgetCalc.sisa(plan.budget, s.spentOf(plan)) < 0
                              ? cs.error
                              : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          'Transaksi terakhir',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (s.txs.isEmpty)
          const EmptyState(icon: 'chart', text: 'Belum ada transaksi')
        else
          for (final t in s.txs.take(3)) TxTile(tx: t),
      ],
    );
  }
}

class _Mini extends StatelessWidget {
  const _Mini({required this.label, required this.value, required this.color});
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      AnimatedMoney(
        value,
        style: Theme.of(context).textTheme.titleSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    ],
  );
}

class TxTile extends StatelessWidget {
  const TxTile({super.key, required this.tx, this.onDelete});
  final Tx tx;
  final Future<void> Function()? onDelete;
  @override
  Widget build(BuildContext context) {
    final masuk = tx.amount > 0;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: CPIcon(masuk ? 'chart' : 'wallet', size: 18),
      ),
      title: Text(tx.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(tgl(tx.date)),
      onLongPress: onDelete == null ? null : () => onDelete!(),
      trailing: Text(
        '${masuk ? '+' : '-'}${rp(tx.amount.abs())}',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: masuk
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.error,
        ),
      ),
    );
  }
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
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final tt = Theme.of(context).textTheme;
    final filtered = store.txs
        .where((t) => t.title.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return ListView(
      padding: cpiPagePadding(context),
      children: [
        CpiField(
          onChanged: (v) => setState(() => _q = v),
          label: 'Cari transaksi',
          hint: 'Nama transaksi',
        ),
        const SizedBox(height: 14),
        CpiCard(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text('Total saldo', style: tt.bodySmall),
                AnimatedMoney(
                  store.balance,
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                CpiReflow(
                  children: [
                    _Mini(
                      label: 'Pemasukan',
                      value: store.income,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    _Mini(
                      label: 'Pengeluaran',
                      value: store.expense,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Semua transaksi',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text('Tekan lama untuk hapus', style: tt.bodySmall),
        if (filtered.isEmpty)
          EmptyState(
            icon: 'wallet',
            text: _q.isEmpty
                ? 'Belum ada transaksi. Tap + buat mulai.'
                : 'Tidak ada transaksi yang cocok dengan "$_q".',
          )
        else
          for (final t in filtered)
            TxTile(
              tx: t,
              onDelete: () async {
                final err = await store.removeTx(t.id);
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(err)));
                }
              },
            ),
      ],
    );
  }
}

// ================= RENCANA & RUNDOWN =================
class PlansPage extends StatelessWidget {
  const PlansPage({super.key, required this.store, required this.location, this.ws});
  final Store store;
  final LocationService location;
  final WorkspaceService? ws;
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PlanCalendar(store: store, location: location, ws: ws),
        Expanded(
          child: store.plans.isEmpty
              ? const Center(
                  child: EmptyState(
                    icon: 'calendar',
                    text: 'Belum ada rencana. Tap + buat bikin acara.',
                  ),
                )
              : _PlanList(store: store, location: location, ws: ws),
        ),
      ],
    );
  }
}

class _PlanList extends StatelessWidget {
  const _PlanList({required this.store, required this.location, required this.ws});
  final Store store;
  final LocationService location;
  final WorkspaceService? ws;
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: cpiPagePadding(context),
      itemCount: store.plans.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) {
        final p = store.plans[i],
            spent = store.spentOf(p),
            ratio = BudgetCalc.ratio(p.budget, spent);
        return Hero(
          tag: 'plan-${p.id}',
          child: Material(
            type: MaterialType.transparency,
            child: CpiCard(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
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
                onLongPress: () async {
                  final err = await store.removePlan(p.id);
                  if (err != null && context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(err)));
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const CPIcon('calendar', size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              p.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            '${(ratio * 100).round()}%',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${p.place} · ${tgl(p.date)} · ${p.rundown.length} rundown',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: ratio),
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 300),
                        builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(8),
                          color: ratio >= 1
                              ? Theme.of(context).colorScheme.error
                              : null,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Budget\n${rp(p.budget)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Terpakai\n${rp(spent)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Sisa\n${rp(BudgetCalc.sisa(p.budget, spent))}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showRundownSheet(context, store, plan),
            icon: const Icon(Icons.add),
            label: const Text('Rundown'),
          ),
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
                            '${plan.place} · ${tgl(plan.date)}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 10),
                          CpiReflow(
                            children: [
                              _Mini(
                                label: 'Budget',
                                value: plan.budget,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              _Mini(
                                label: 'Terpakai',
                                value: spent,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              _Mini(
                                label: 'Estimasi rundown',
                                value: plan.estimasi,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Sisa budget: ${rp(BudgetCalc.sisa(plan.budget, spent))}',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: BudgetCalc.sisa(plan.budget, spent) < 0
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
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
                  padding: const EdgeInsets.all(18),
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
                          Text(
                            _tracking ? 'LIVE' : 'Mati',
                            style: Theme.of(context).textTheme.labelSmall,
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
                          OutlinedButton(
                            onPressed: () => _selesaiOtomatis(
                              'Perjalanan ${plan.title} ditandai selesai. Rencana otomatis dihapus.',
                            ),
                            child: const Text('Selesaikan dan hapus'),
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
              Text(
                'Rundown acara',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              if (plan.rundown.isEmpty)
                const EmptyState(
                  icon: 'clock',
                  text: 'Rundown kosong. Tap + Rundown.',
                )
              else
                for (final r in plan.rundown)
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    margin: const EdgeInsets.only(bottom: 8),
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
                        r.cost > 0 ? 'Estimasi ${rp(r.cost)}' : 'Tanpa biaya',
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
            ],
          ),
        );
      },
    );
  }
}

// ================= TRAVEL LIVE =================
class TravelPage extends StatefulWidget {
  const TravelPage({super.key, required this.travel});
  final TravelService travel;
  @override
  State<TravelPage> createState() => _TravelPageState();
}

class _TravelPageState extends State<TravelPage> {
  var _filter = 'semua';
  var _murahDulu = false;
  final _search = TextEditingController();
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
        for (final o in ofKind(kind))
          CpiCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                        o.delta == 0
                            ? 'Estimasi stabil'
                            : 'Perubahan estimasi ${o.delta > 0 ? '+' : '-'}${rp(o.delta.abs())}',
                        style: tt.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
    return RefreshIndicator(
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
        ],
      ),
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
      16,
      8,
      16,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: child,
  ),
);

InputDecoration _dec(String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());
double? _amount(String s) {
  final v = double.tryParse(s.replaceAll(RegExp(r'[^0-9]'), ''));
  return (v == null || v <= 0) ? null : v;
}

void showTxSheet(BuildContext context, Store store) {
  final title = TextEditingController(), amount = TextEditingController();
  var income = false;
  String? planId;
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
            onSelectionChanged: (v) => setS(() => income = v.first),
          ),
          const SizedBox(height: 12),
          CpiField(
            controller: title,
            label: 'Nama transaksi',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          CpiField(
            controller: amount,
            label: 'Jumlah (Rp)',
            keyboardType: TextInputType.number,
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
              onChanged: (v) => setS(() => planId = v),
            ),
          ],
          const SizedBox(height: 16),
          CpiButton(
            onPressed: () async {
              final a = _amount(amount.text);
              if (title.text.trim().isEmpty || a == null) {
                ScaffoldMessenger.of(c).showSnackBar(
                  const SnackBar(
                    content: Text('Isi nama dan jumlah yang valid dulu bro.'),
                  ),
                );
                return;
              }
              final err = await store.addTx(
                Tx(
                  id: Store.newId(),
                  title: title.text.trim(),
                  amount: income ? a : -a,
                  date: DateTime.now(),
                  planId: income ? null : planId,
                ),
              );
              if (!c.mounted) return;
              if (err != null) {
                ScaffoldMessenger.of(
                  c,
                ).showSnackBar(SnackBar(content: Text(err)));
                return;
              }
              Navigator.pop(c);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    ),
  );
}

void showPlanSheet(BuildContext context, Store store) {
  final title = TextEditingController(),
      place = TextEditingController(),
      budget = TextEditingController();
  var date = DateTime.now().add(const Duration(days: 7));
  Place? picked;
  List<Place> results = [];
  var searching = false;
  String? searchError;
  _sheet(
    context,
    StatefulBuilder(
      builder: (c, setS) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Buat rencana manual', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Atur sendiri semuanya. Pilih hasil pencarian tempat supaya GPS bisa membaca kedatangan kamu.',
            style: Theme.of(c).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          CpiField(controller: title, label: 'Nama acara atau trip'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: CpiField(
                  controller: place,
                  label: 'Cari tempat tujuan',
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setS(() => picked = null),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: 'Cari tempat',
                icon: const Icon(Icons.search),
                onPressed: searching
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
                            if (r.isEmpty) searchError = 'Tempat tidak ditemukan. Coba nama kota atau daerah lain.';
                          });
                        } catch (_) {
                          setS(() {
                            searching = false;
                            searchError = 'Pencarian gagal. Cek internet kamu lalu coba lagi.';
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
                      onTap: () => setS(() {
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
            Text(
              'Koordinat tujuan terkunci: ${picked!.lat.toStringAsFixed(5)}, ${picked!.lng.toStringAsFixed(5)}',
              style: Theme.of(c).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          CpiField(
            controller: budget,
            label: 'Budget (Rp)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const CPIcon('calendar', size: 18),
            label: Text(tgl(date)),
            onPressed: () async {
              final d = await showDatePicker(
                context: c,
                initialDate: date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 730)),
              );
              if (d != null) setS(() => date = d);
            },
          ),
          const SizedBox(height: 16),
          CpiButton(
            onPressed: () async {
              final b = _amount(budget.text);
              if (title.text.trim().isEmpty || b == null || picked == null) {
                ScaffoldMessenger.of(c).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Isi nama dan budget, lalu pilih satu hasil pencarian tempat dulu bro.',
                    ),
                  ),
                );
                return;
              }
              final err = await store.addPlan(
                Plan(
                  id: Store.newId(),
                  title: title.text.trim(),
                  place: picked!.name,
                  date: date,
                  budget: b,
                  lat: picked!.lat,
                  lng: picked!.lng,
                ),
              );
              if (!c.mounted) return;
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
        ],
      ),
    ),
  );
}

void showRundownSheet(BuildContext context, Store store, Plan plan) {
  final title = TextEditingController(), cost = TextEditingController();
  var time = '09:00';
  _sheet(
    context,
    StatefulBuilder(
      builder: (c, setS) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tambah rundown', style: Theme.of(c).textTheme.titleLarge),
          const SizedBox(height: 14),
          CpiField(controller: title, label: 'Kegiatan'),
          const SizedBox(height: 12),
          CpiField(
            controller: cost,
            label: 'Estimasi biaya (Rp, boleh 0)',
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const CPIcon('clock', size: 18),
            label: Text('Jam $time'),
            onPressed: () async {
              final t = await showTimePicker(
                context: c,
                initialTime: const TimeOfDay(hour: 9, minute: 0),
              );
              if (t != null)
                setS(
                  () => time =
                      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
                );
            },
          ),
          const SizedBox(height: 16),
          CpiButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) {
                ScaffoldMessenger.of(c).showSnackBar(
                  const SnackBar(content: Text('Isi nama kegiatan dulu bro.')),
                );
                return;
              }
              final err = await store.addRundown(
                plan,
                Rundown(
                  id: Store.newId(),
                  time: time,
                  title: title.text.trim(),
                  cost: _amount(cost.text) ?? 0,
                  day: plan.date,
                ),
              );
              if (!c.mounted) return;
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
        ],
      ),
    ),
  );
}
