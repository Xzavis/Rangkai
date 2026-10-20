import 'package:cpi/calendar.dart';
import 'package:cpi/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rundown dikelompokkan per tanggal dan terurut jam', () {
    final p = Plan(
      id: 'p1',
      title: 'Trip',
      place: 'X',
      date: DateTime(2026, 5, 9),
      budget: 1000,
      rundown: [
        Rundown(id: 'r2', time: '13:00', title: 'siang'),
        Rundown(
          id: 'r1',
          time: '07:00',
          title: 'pagi',
          day: DateTime(2026, 5, 10),
        ),
      ],
    );
    final g = groupByDay([p]);
    // r tanpa day ikut tanggal plan; r ber-day ikut harinya sendiri.
    expect(g[DateTime(2026, 5, 9)]!.single.rundown.id, 'r2');
    expect(g[DateTime(2026, 5, 10)]!.single.rundown.id, 'r1');
  });

  test('multi plan satu tanggal diurut jam', () {
    Plan mk(String id, String time) => Plan(
          id: id,
          title: id,
          place: 'X',
          date: DateTime(2026, 5, 9),
          budget: 0,
          rundown: [Rundown(id: 'r$id', time: time, title: time)],
        );
    final g = groupByDay([mk('b', '10:00'), mk('a', '07:00')]);
    final items = g[DateTime(2026, 5, 9)]!;
    expect([for (final i in items) i.rundown.time], ['07:00', '10:00']);
    expect(items.first.plan.id, 'a');
  });
}
