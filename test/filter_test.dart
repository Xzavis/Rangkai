import 'package:cpi/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final txs = [
    Tx(id: '1', title: 'Gaji', amount: 6000000, date: DateTime(2026, 10, 1), category: 'Pendapatan'),
    Tx(id: '2', title: 'Makan', amount: -150000, date: DateTime(2026, 10, 24), category: 'Makanan', planId: 'p'),
    Tx(id: '3', title: 'Kopi', amount: -45000, date: DateTime(2026, 10, 24), category: 'Makanan', note: 'dekat kantor'),
    Tx(id: '4', title: 'Bensin', amount: -100000, date: DateTime(2026, 9, 30), category: 'Transport'),
  ];

  test('filter bulan + jenis + teks memakai tanggal transaksi', () {
    final okt = filterTxs(txs, month: DateTime(2026, 10));
    expect(okt.map((t) => t.id), ['2', '3', '1']); // terbaru dulu
    expect(filterTxs(txs, month: DateTime(2026, 10), type: TxFilter.income).single.id, '1');
    expect(filterTxs(txs, query: 'kantor').single.id, '3'); // cari di catatan
    expect(filterTxs(txs, query: 'transport').single.id, '4'); // cari di kategori
  });

  test('group per hari dengan subtotal bertanda', () {
    final groups = groupTxsByDay(filterTxs(txs, month: DateTime(2026, 10)));
    expect(groups.length, 2);
    expect(groups.first.day, DateTime(2026, 10, 24));
    expect(groups.first.subtotal, -195000);
    expect(groups.last.subtotal, 6000000);
  });

  test('split patungan: hasil & sisa pembulatan jelas', () {
    expect(BudgetCalc.splitEqual(750000, 4), (per: 187500, remainder: 0));
    expect(BudgetCalc.splitEqual(100000, 3), (per: 33333, remainder: 1));
    expect(BudgetCalc.splitEqual(50000, 0), (per: 50000, remainder: 0));
    expect(BudgetCalc.splitEqual(-5, 2), (per: 0, remainder: 0));
  });

  test('budget nol tidak membagi nol & sisa bisa negatif', () {
    expect(BudgetCalc.ratio(0, 50000), 0);
    expect(BudgetCalc.sisa(100000, 150000), -50000);
  });

  test('label hari relatif, status & durasi rencana', () {
    final now = DateTime(2026, 10, 24, 13);
    expect(dayLabel(DateTime(2026, 10, 24), now), contains('Hari ini'));
    expect(dayLabel(DateTime(2026, 10, 23), now), contains('Kemarin'));
    expect(dayLabel(DateTime(2026, 10, 20), now), contains('20 Okt 2026'));
    final p = Plan(
      id: 'p',
      title: 'Trip',
      place: 'Bandung',
      date: DateTime(2026, 10, 24),
      endDate: DateTime(2026, 10, 25),
      budget: 1,
    );
    expect(planStatusLabel(p, now), 'Sedang Berlangsung');
    expect(planDurationLabel(p), '2 Hari 1 Malam');
    expect(planStatusLabel(p, DateTime(2026, 10, 20)), 'Mendatang');
  });

  test('id lokal tidak berurutan-mudah ditebak dari jam', () {
    final ids = List.generate(50, (_) => Store.newId()).toSet();
    expect(ids.length, 50);
    expect(ids.every((e) => e.length == 18), isTrue);
  });
}
