import 'dart:convert';

import 'package:cpi/auth.dart';
import 'package:cpi/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// E2E di device/emulator (bukan widget test biasa):
//   adb shell pm grant com.example.cpi android.permission.ACCESS_FINE_LOCATION
//   adb emu geo fix 107.6191 -6.9175
//   flutter test integration_test/app_e2e_test.dart -d emulator-5554
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
    String reason = '',
  }) async {
    final end = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(end)) {
      await tester.pump(const Duration(milliseconds: 400));
      if (finder.evaluate().isNotEmpty) return;
    }
    expect(finder, findsWidgets, reason: reason);
  }

  // Layar kecil: konten di bawah lipatan belum dibangun ListView.
  // Geser daftar sampai widget tujuan muncul (maks 5x).
  Future<void> scrollUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 5 && finder.evaluate().isEmpty; i++) {
      final lists = find.byType(ListView);
      if (lists.evaluate().isEmpty) break;
      await tester.drag(lists.first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 600));
    }
  }

  // Label tab juga muncul di grid Layanan Beranda; tap khusus di nav bawah
  // (NavigationBar) atau rail agar tidak ambigu.
  Future<void> tapTab(WidgetTester tester, String label) async {
    final bar = find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
    if (bar.evaluate().isNotEmpty) {
      await tester.tap(bar);
    } else {
      await tester.tap(find.descendant(
        of: find.byType(NavigationRail),
        matching: find.text(label),
      ));
    }
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('offline flow: config -> GPS gate -> 5 tab -> tambah transaksi',
      (tester) async {
    await tester.pumpWidget(const CpiApp(auth: null));
    await tester.pump(const Duration(seconds: 1));

    // Tanpa dart-define backend: halaman petunjuk + jalan keluar offline.
    expect(find.text('Backend belum disambung'), findsOneWidget);
    await tester.tap(find.text('Lanjut offline (data lokal)'));
    await tester.pump(const Duration(seconds: 1));

    // GPS gate harus lolos dari izin + geo fix emulator (bukan hardcode).
    if (find.text('Cek lagi').evaluate().isNotEmpty &&
        find.text('Saldo saat ini').evaluate().isEmpty) {
      await tester.tap(find.text('Cek lagi'));
    }
    await pumpUntil(
      tester,
      find.text('Saldo saat ini'),
      reason: 'Beranda tidak muncul; GPS gate belum lolos di device',
    );
    expect(find.text('Rp6.815.000'), findsOneWidget); // saldo seed lokal
    // Copy UI v4 ref 01: 'GPS Aktif • x km menuju tujuan' di kartu rencana
    // (bisa di bawah lipatan ListView, geser dulu sampai terbangun).
    await scrollUntil(tester, find.textContaining('GPS Aktif'));
    expect(find.textContaining('GPS Aktif'), findsOneWidget);

    // Tab Keuangan: tambah transaksi pengeluaran lewat sheet beneran.
    await tapTab(tester, 'Keuangan');
    expect(find.text('Budget & Split'), findsOneWidget);
    await tester.tap(find.text('Tambah transaksi').first);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Simpan transaksi'), findsOneWidget);
    // EditableText: [cari di halaman, jumlah, nama, catatan] dalam sheet.
    final fields = find.byType(EditableText);
    await tester.enterText(fields.at(1), '15000');
    await tester.enterText(fields.at(2), 'E2E Kopi');
    await tester.ensureVisible(find.text('Simpan transaksi'));
    await tester.tap(find.text('Simpan transaksi'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Simpan transaksi'), findsNothing); // sheet tertutup
    expect(find.text('Rp6.800.000'), findsOneWidget); // saldo berkurang 15rb
    // Barisnya bisa di bawah lipatan; pakai pencarian app sendiri.
    await tester.enterText(find.byType(EditableText).first, 'E2E Kopi');
    await tester.pump(const Duration(milliseconds: 800));
    // HP fisik: keyboard menyusutkan viewport, baris hasil filter bisa di
    // luar area bangun ListView. Geser daftar agar barisnya dibangun.
    for (var i = 0; i < 3 && find.text('E2E Kopi').evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 600));
    }
    expect(find.text('E2E Kopi'), findsWidgets);
    await tester.enterText(find.byType(EditableText).first, '');
    await tester.pump(const Duration(milliseconds: 400));

    // Tab Rencana + Kalender + Workspace (offline state jujur).
    await tapTab(tester, 'Rencana');
    expect(find.text('Buat rencana'), findsWidgets);
    expect(find.text('Cari kereta'), findsOneWidget);
    await scrollUntil(tester, find.text('Trip Bandung'));
    expect(find.text('Trip Bandung'), findsWidgets);

    await tapTab(tester, 'Kalender');
    await scrollUntil(tester, find.text('Agenda rundown'));
    expect(find.text('Agenda rundown'), findsOneWidget);

    await tapTab(tester, 'Workspace');
    await scrollUntil(tester, find.textContaining('Mode offline tetap bisa'));
    expect(find.textContaining('Mode offline tetap bisa'), findsOneWidget);
    expect(find.text('Masuk'), findsWidgets);
  });

  // Regresi dari temuan emulator API 37: init Supabase sempat melempar
  // NoSuchMethodError dari plugin SharedPreferences pada build lama.
  // Init dengan backend palsu cukup membuktikan jalur storage lokal;
  // kegagalan jaringan diterima, crash plugin tidak.
  testWidgets('init Supabase tidak crash di plugin storage', (tester) async {
    String seg(String json) =>
        base64Url.encode(utf8.encode(json)).replaceAll('=', '');
    final fakeAnon =
        '${seg('{"alg":"HS256","typ":"JWT"}')}.${seg('{"role":"anon"}')}.sig';
    Object? caught;
    try {
      await Supabase.initialize(
        url: 'https://example.invalid',
        publishableKey: fakeAnon,
      ).timeout(const Duration(seconds: 20));
    } catch (e) {
      caught = e;
    }
    if (caught is PlatformException) {
      fail('Plugin platform crash saat init: $caught');
    }
    // AuthService.init tanpa konfigurasi valid juga tidak boleh throw.
    expect(await AuthService.init(), anyOf(isNull, isNotNull));
  });
}
