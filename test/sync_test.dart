import 'package:cpi/core.dart';
import 'package:cpi/sync.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('konversi plan bolak-balik utuh', () {
    final p = Plan(
      id: 'uuid-1',
      title: 'Trip',
      place: 'Bandung',
      date: DateTime(2026, 5, 9),
      budget: 1000000,
      lat: -6.9,
      lng: 107.6,
    );
    final row = CloudSync.planRow(p, 'ws-1');
    expect(row['id'], isNot(contains('uuid-1'))); // id milik server
    expect(row['date'], '2026-05-09');
    final back = CloudSync.planFrom({...row, 'id': 'uuid-1'});
    expect(back.title, 'Trip');
    expect(back.date, DateTime(2026, 5, 9));
    expect(back.lat, -6.9);
  });

  test('rundown ikut tanggal plan bila day null', () {
    final r = Rundown(id: 'x', time: '07:00', title: 'a', cost: 5000);
    final row = CloudSync.rundownRow(r, 'p1', DateTime(2026, 5, 9));
    expect(row['day'], '2026-05-09');
    expect(row['plan_id'], 'p1');
    final back = CloudSync.rundownFrom({...row, 'id': 'r1'});
    expect(back.day, DateTime(2026, 5, 9));
  });

  test('removePlan melepas transaksi, bukan menghapus', () async {
    final s = Store();
    final p = Plan(
      id: 'p9',
      title: 'Trip',
      place: 'X',
      date: DateTime(2026),
      budget: 1000,
    );
    s.plans.add(p);
    s.txs.add(
      Tx(id: 't', title: 'tiket', amount: -100, date: DateTime(2026), planId: 'p9'),
    );
    final err = await s.removePlan('p9');
    expect(err, isNull);
    expect(s.plans, isEmpty);
    expect(s.txs.single.planId, isNull); // riwayat uang tetap ada
    expect(s.balance, -100); // expense 100 tetap tercatat
  });

  test('tx kategori/catatan + plan endDate bolak-balik utuh', () {
    final t = Tx(
      id: 'x',
      title: 'Makan',
      amount: -150000,
      date: DateTime(2026, 10, 24),
      category: 'Makanan',
      note: 'di Braga',
    );
    final back = CloudSync.txFrom({...CloudSync.txRow(t, 'ws'), 'id': 'x'});
    expect(back.category, 'Makanan');
    expect(back.note, 'di Braga');
    expect(back.date, DateTime(2026, 10, 24));

    final p = Plan(
      id: 'p',
      title: 'Trip',
      place: 'Bandung',
      date: DateTime(2026, 10, 24),
      endDate: DateTime(2026, 10, 26),
      budget: 100,
    );
    final pb = CloudSync.planFrom({...CloudSync.planRow(p, 'ws'), 'id': 'p'});
    expect(pb.endDate, DateTime(2026, 10, 26));
    expect(pb.lastDay, DateTime(2026, 10, 26));
  });

  test('baris lama tanpa kolom baru tetap terbaca', () {
    final t = CloudSync.txFrom({
      'id': 'old',
      'title': 'lama',
      'amount': 10,
      'date': '2026-01-01T00:00:00',
    });
    expect(t.category, 'Umum');
    expect(t.note, '');
    final p = CloudSync.planFrom({
      'id': 'old',
      'title': 'lama',
      'place': '',
      'date': '2026-01-01',
      'budget': 5,
    });
    expect(p.endDate, isNull);
    expect(p.lastDay, DateTime(2026, 1, 1));
  });

  test('addPlan menyalin rundown awal & menolak rentang terbalik', () async {
    final s = Store();
    final err = await s.addPlan(
      Plan(
        id: 'p1',
        title: 'Trip',
        place: 'X',
        date: DateTime(2026, 10, 24),
        endDate: DateTime(2026, 10, 26),
        budget: 100,
        rundown: [Rundown(id: 'r', time: '07:00', title: 'Berangkat')],
      ),
    );
    expect(err, isNull);
    expect(s.plans.single.rundown.single.title, 'Berangkat');
    expect(s.plans.single.endDate, DateTime(2026, 10, 26));

    final err2 = await s.addPlan(
      Plan(
        id: 'p2',
        title: 'Salah',
        place: 'X',
        date: DateTime(2026, 10, 26),
        endDate: DateTime(2026, 10, 24),
        budget: 100,
      ),
    );
    expect(err2, isNotNull);
    expect(s.plans.length, 1);
  });

  test('add lokal tanpa cloud tetap jalan', () async {
    final s = Store();
    expect(s.cloud, isNull);
    final err = await s.addTx(
      Tx(id: 't1', title: 'gaji', amount: 5000, date: DateTime(2026)),
    );
    expect(err, isNull);
    expect(s.balance, 5000);
    expect(await s.pull(), isNull);
  });
}
