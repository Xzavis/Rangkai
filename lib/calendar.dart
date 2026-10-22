import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'components.dart';
import 'core.dart';
import 'theme/tokens.dart';
import 'workspace.dart';
import 'widgets.dart';
import 'pages.dart' show PlanDetailPage;

// ---------- Agenda per hari (murni, dites) ----------
typedef AgendaItem = ({Plan plan, Rundown rundown});

DateTime dayKey(DateTime d) => DateTime(d.year, d.month, d.day);

/// Kelompokkan semua rundown semua plan per tanggal.
/// Rundown tanpa day ikut tanggal plan-nya.
Map<DateTime, List<AgendaItem>> groupByDay(List<Plan> plans) {
  final out = <DateTime, List<AgendaItem>>{};
  for (final p in plans) {
    for (final r in p.rundown) {
      final k = dayKey(r.day ?? p.date);
      (out[k] ??= []).add((plan: p, rundown: r));
    }
  }
  for (final list in out.values) {
    list.sort((a, b) => a.rundown.time.compareTo(b.rundown.time));
  }
  return out;
}

// ---------- Kalender rundown ----------
class PlanCalendar extends StatefulWidget {
  const PlanCalendar({
    super.key,
    required this.store,
    required this.location,
    required this.ws,
  });
  final Store store;
  final LocationService location;
  final WorkspaceService? ws;
  @override
  State<PlanCalendar> createState() => _PlanCalendarState();
}

class _PlanCalendarState extends State<PlanCalendar> {
  var _focused = DateTime.now();
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        final agenda = groupByDay(widget.store.plans);
        final sel = _selected ?? DateTime.now();
        final items = agenda[dayKey(sel)] ?? [];
        final live = isSameDay(sel, DateTime.now()) && items.isNotEmpty;
        final aktif = live
            ? activeRundown(
                [for (final i in items) i.rundown],
                DateTime.now().hour * 60 + DateTime.now().minute,
              )
            : -2;
        return CpiCard(
          child: Padding(
            padding: const EdgeInsets.all(CpiTokens.panelPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.store.plans.where((p) => p.date.month == _focused.month && p.date.year == _focused.year).length} rencana bulan ini',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                TableCalendar<AgendaItem>(
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  firstDay: DateTime.now().subtract(const Duration(days: 365)),
                  lastDay: DateTime.now().add(const Duration(days: 730)),
                  focusedDay: _focused,
                  selectedDayPredicate: (d) => isSameDay(d, sel),
                  onDaySelected: (selected, focused) => setState(() {
                    _selected = selected;
                    _focused = focused;
                  }),
                  eventLoader: (d) => agenda[dayKey(d)] ?? [],
                  calendarStyle: const CalendarStyle(
                    markersMaxCount: 3,
                  ),
                ),
                const Divider(height: 20),
                Text(
                  live && aktif >= 0 && aktif < items.length
                      ? 'Berlangsung: ${items[aktif].rundown.title}'
                      : items.isEmpty
                          ? 'Tidak ada rundown ${tgl(sel)}.'
                          : 'Rundown ${tgl(sel)} (${items.length})',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                if (items.isEmpty)
                  const EmptyState(
                    icon: 'calendar',
                    text: 'Pilih tanggal bertitik untuk lihat acara.',
                  )
                else
                  for (var idx = 0; idx < items.length; idx++)
                    AgendaRow(
                      rundown: items[idx].rundown,
                      subtitle: items[idx].plan.title,
                      stateLabel: items[idx].rundown.done
                          ? 'Selesai'
                          : (live && idx == aktif)
                              ? 'Berlangsung'
                              : 'Belum mulai',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlanDetailPage(
                            store: widget.store,
                            plan: items[idx].plan,
                            location: widget.location,
                            ws: widget.ws,
                          ),
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
