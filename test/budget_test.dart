import 'package:cpi/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('budget: spent counts only linked expenses', () {
    final txs = [
      Tx(
        id: '1',
        title: 'tiket',
        amount: -150000,
        date: DateTime(2026),
        planId: 'p1',
      ),
      Tx(
        id: '2',
        title: 'gaji',
        amount: 5000000,
        date: DateTime(2026),
        planId: 'p1',
      ),
      Tx(id: '3', title: 'kopi', amount: -50000, date: DateTime(2026)),
    ];
    expect(BudgetCalc.spentOf(txs, 'p1'), 150000);
    expect(BudgetCalc.sisa(1000000, 150000), 850000);
    expect(BudgetCalc.ratio(1000000, 150000), 0.15);
    expect(BudgetCalc.ratio(0, 100), 0); // no budget = no crash
  });

  test('sampai tujuan: GPS <= 150 meter dan progres rute', () {
    expect(isArrived(140), isTrue);
    expect(isArrived(151), isFalse);
    expect(isArrived(null), isFalse);
    expect(tripProgress(1000, 250), 0.75);
    expect(tripProgress(0, 0), 0);
  });

  test(
    'selesai otomatis: rencana terhapus, transaksi dilepas bukan dihapus',
    () async {
      final s = Store();
      final p = Plan(
        id: 'p9',
        title: 'Trip',
        place: 'X',
        date: DateTime(2026),
        budget: 1000,
        rundown: [Rundown(id: 'r', time: '07:00', title: 'a')],
      );
      s.plans.add(p);
      s.txs.add(
        Tx(
          id: 't',
          title: 'tiket',
          amount: -100,
          date: DateTime(2026),
          planId: 'p9',
        ),
      );
      await s.completeAndRemove(p);
      expect(s.plans, isEmpty);
      expect(s.txs.single.planId, isNull);
      expect(p.semuaSelesai, isTrue);
    },
  );

  test('tracking: indeks rundown aktif dari jam', () {
    final r = [
      Rundown(id: '1', time: '07:00', title: 'a'),
      Rundown(id: '2', time: '10:00', title: 'b'),
      Rundown(id: '3', time: '13:00', title: 'c'),
    ];
    expect(activeRundown(r, 6 * 60), -1); // belum mulai
    expect(activeRundown(r, 8 * 60), 0);
    expect(activeRundown(r, 11 * 60), 1);
    expect(activeRundown(r, 20 * 60), 3); // semua lewat
  });

  test('format rupiah', () {
    expect(rp(1500000), 'Rp1.500.000');
    expect(rp(0), 'Rp0');
  });
}
