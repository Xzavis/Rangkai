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
