import 'dart:io';
import 'dart:ui' as ui;

import 'package:cpi/core.dart';
import 'package:cpi/main.dart';
import 'package:cpi/login_page.dart';
import 'package:cpi/pages.dart';
import 'package:cpi/workspace_page.dart';
import 'package:cpi/theme/material.dart';
import 'package:cpi/theme/theme.dart' as cpi;
import 'package:cpi/theme/tokens.dart';
import 'package:cpi/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart' show FTheme;

Widget harness(Widget child, Brightness brightness, {double scale = 1}) =>
    MaterialApp(
      theme: cpiMaterialTheme(brightness),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: FTheme(
          data: brightness == Brightness.dark ? cpi.darkTheme : cpi.lightTheme,
          child: child!,
        ),
      ),
      home: child,
    );

void main() {
  setUpAll(() async {
    for (final font in [
      ('Inter', 'Inter'),
      ('JetBrains Mono', 'JetBrainsMono'),
      ('Source Serif 4', 'SourceSerif4'),
    ]) {
      await (FontLoader(
        font.$1,
      )..addFont(rootBundle.load('assets/fonts/${font.$2}.ttf'))).load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  test('UI v4 foundation tokens and shell geometry', () {
    // docs/ui-v4/tokens.json: geometri + warna light semantik.
    expect(CpiTokens.pagePadding, 20);
    expect(CpiTokens.panelPadding, 20);
    expect(CpiTokens.panelRadius, 16);
    expect(CpiTokens.controlRadius, 12);
    expect(CpiTokens.minTouchTarget, 44);
    expect(CpiTokens.minFieldHeight, 48);
    expect(CpiTokens.brand, const Color(0xff3b82f6));
    expect(CpiTokens.action, const Color(0xff1d4ed8));
    expect(CpiTokens.actionPressed, const Color(0xff1e40af));
    expect(CpiTokens.positive, const Color(0xff03664a));
    expect(CpiTokens.negative, const Color(0xffb42318));
    expect(CpiTokens.light['background'], const Color(0xfff7f8fa));
    expect(CpiTokens.light['foreground'], const Color(0xff182333));
    expect(CpiTokens.light['muted-foreground'], const Color(0xff596577));
    expect(CpiTokens.light['border'], const Color(0xffe2e7ee));
    final theme = cpiMaterialTheme(Brightness.light);
    expect(theme.navigationBarTheme.height, 76);
    final cardShape = theme.cardTheme.shape! as RoundedRectangleBorder;
    expect(cardShape.borderRadius, BorderRadius.circular(16));
    expect(theme.textTheme.headlineSmall?.fontSize, 24);
    expect(theme.textTheme.titleLarge?.fontSize, 18);
    expect(theme.textTheme.bodyMedium?.fontSize, 14);
  });

  test('CSS light/dark color tokens match Flutter exactly', () {
    final css = File('assets/theme.css').readAsStringSync();
    final blocks = css.split('@theme').first.split('.dark');
    for (final pair in [
      (blocks.first, CpiTokens.light),
      (blocks.last, CpiTokens.dark),
    ]) {
      final colors = RegExp(r'--([a-z0-9-]+): #([a-f0-9]{6});')
          .allMatches(pair.$1);
      expect(colors.length, pair.$2.length);
      for (final color in colors) {
        expect(
          pair.$2[color[1]],
          Color(int.parse('ff${color[2]}', radix: 16)),
          reason: color[1],
        );
      }
    }
  });

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0, 768.0, 1280.0]) {
      testWidgets('${brightness.name} pages fit $width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final store = Store()..seed();
        final travel = TravelService();
        final location = LocationService();
        final pages = [
          HomePage(
            store: store,
            travel: travel,
            zone: Zone.zones.first,
            onZone: (_) {},
            location: location,
          ),
          FinancePage(store: store),
          PlansPage(store: store, location: location, travel: travel),
          CalendarPage(store: store, location: location),
          TravelPage(travel: travel, store: store),
          SplitPage(store: store),
          const WorkspaceOfflineTab(),
          const ConfigMissingPage(),
          PlanDetailPage(
            store: store,
            plan: store.plans.first,
            location: location,
          ),
          SettingsPage(store: store, mode: ThemeMode.system, onMode: (_) {}),
          GpsGatePage(location: location),
        ];
        for (final page in pages) {
          await tester.pumpWidget(
            harness(
              Scaffold(body: CpiContent(child: page)),
              brightness,
              scale: width == 320 ? 1.3 : 1,
            ),
          );
          await tester.pump(const Duration(milliseconds: 400));
          expect(
            tester.takeException(),
            isNull,
            reason: '${page.runtimeType} $width',
          );
        }
        await tester.pumpWidget(const SizedBox());
        store.dispose();
        travel.dispose();
        location.dispose();
      });
    }
  }

  testWidgets('Beranda v4 structure, grids and empty states', (tester) async {
    tester.view.physicalSize = const Size(390, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = Store();
    final travel = TravelService();
    final location = LocationService();
    int? openedTab;
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: HomePage(
            store: store,
            travel: travel,
            zone: Zone.zones.first,
            onZone: (_) {},
            location: location,
            displayName: 'Tester',
            onOpenFinance: () {},
            onOpenTab: (i) => openedTab = i,
          ),
        ),
        Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Halo, Tester'), findsOneWidget);
    expect(find.text('Saldo saat ini'), findsOneWidget);
    expect(find.text('Rp0'), findsOneWidget);
    expect(find.text('Pemasukan'), findsOneWidget);
    expect(find.text('Pengeluaran'), findsOneWidget);
    expect(find.text('Aksi cepat'), findsOneWidget);
    expect(find.text('Cari kereta'), findsOneWidget);
    expect(find.text('Cari hotel'), findsOneWidget);
    expect(find.text('Budget & Split'), findsOneWidget);
    expect(find.text('Salin ringkasan'), findsOneWidget);
    expect(find.text('Layanan'), findsOneWidget);
    expect(find.text('Transaksi Terakhir'), findsOneWidget);
    expect(
      find.text('Belum ada rencana. Buat rencana pertama kamu.'),
      findsOneWidget,
    );
    expect(find.text('Menunggu posisi GPS pertama'), findsOneWidget);
    // Sembunyikan saldo: state tampilan lokal, nilai Store tidak berubah.
    await tester.tap(find.byTooltip('Sembunyikan saldo'));
    await tester.pump();
    expect(find.text('Rp••••••'), findsOneWidget);
    expect(store.balance, 0);
    // Grid Layanan benar-benar memanggil perpindahan tab shell.
    await tester.ensureVisible(find.text('Kalender'));
    await tester.tap(find.text('Kalender'));
    await tester.pump();
    expect(openedTab, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    travel.dispose();
    location.dispose();
  });

  // Regresi E2E device 22 Okt: label tile 2 baris overflow 4px di sel
  // grid rasio tetap. Tile harus tumbuh mengikuti teks, bukan luber.
  testWidgets('Beranda tiles reflow at narrow width and large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = Store();
    final travel = TravelService();
    final location = LocationService();
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: HomePage(
            store: store,
            travel: travel,
            zone: Zone.zones.first,
            onZone: (_) {},
            location: location,
            displayName: 'Tester',
            onOpenFinance: () {},
            onOpenTab: (_) {},
          ),
        ),
        Brightness.light,
        scale: 1.3,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    // Bangun semua tile dengan menggeser daftar; label boleh muncul >1x
    // di halaman, jadi jangan pakai scrollUntilVisible (butuh target tunggal).
    for (var i = 0; i < 4; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('Budget & Split'), findsWidgets);
    expect(find.text('Salin ringkasan'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    store.dispose();
    travel.dispose();
    location.dispose();
  });

  testWidgets('theme switches while settings route stays open', (tester) async {
    final store = Store();
    var mode = ThemeMode.light;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) => MaterialApp(
          theme: cpiMaterialTheme(Brightness.light),
          darkTheme: cpiMaterialTheme(Brightness.dark),
          themeMode: mode,
          builder: (context, child) => FTheme(
            data: Theme.of(context).brightness == Brightness.dark
                ? cpi.darkTheme
                : cpi.lightTheme,
            child: child!,
          ),
          home: SettingsPage(
            store: store,
            mode: mode,
            onMode: (value) => setState(() => mode = value),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Tampilan'))).brightness,
      Brightness.dark,
    );
    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    expect(
      Theme.of(tester.element(find.text('Tampilan'))).brightness,
      Brightness.light,
    );
    store.dispose();
  });

  testWidgets('transaction sheet scrolls above keyboard and saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = Store();
    await tester.pumpWidget(
      harness(
        Builder(
          builder: (context) => Scaffold(
            body: CpiButton(
              onPressed: () => showTxSheet(context, store),
              child: const Text('Tambah'),
            ),
          ),
        ),
        Brightness.light,
      ),
    );
    await tester.tap(find.text('Tambah'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText).at(0), '12000');
    await tester.enterText(find.byType(EditableText).at(1), 'Transportasi');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan transaksi'));
    await tester.tap(find.text('Simpan transaksi'));
    await tester.pumpAndSettle();
    expect(store.txs.single.title, 'Transportasi');
    expect(store.txs.single.amount, -12000);
    expect(tester.takeException(), isNull);
    tester.view.resetViewInsets();
    store.dispose();
  });

  testWidgets('Forui action supports keyboard activation', (tester) async {
    var activated = false;
    await tester.pumpWidget(
      harness(
        Scaffold(
          body: CpiButton(
            onPressed: () => activated = true,
            child: const Text('Simpan'),
          ),
        ),
        Brightness.light,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus?.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(activated, isTrue);
  });

  testWidgets('Stage 3 v4: finance, detail and calendar structure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = Store()..seed();
    final travel = TravelService();
    final location = LocationService();

    // 02 Keuangan: CTA selebar konten + Budget & Split | Salin Ringkasan.
    await tester.pumpWidget(
      harness(Scaffold(body: FinancePage(store: store)), Brightness.light),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Tambah transaksi'), findsOneWidget);
    expect(find.text('Budget & Split'), findsOneWidget);
    expect(find.text('Salin Ringkasan'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 04 Detail: tambah rundown in-flow + destruktif di akhir, tanpa FAB.
    await tester.pumpWidget(
      harness(
        PlanDetailPage(
          store: store,
          plan: store.plans.first,
          location: location,
        ),
        Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Susunan acara (rundown)'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Selesaikan dan hapus rencana'),
      200,
    );
    await tester.pump();
    expect(find.text('Selesaikan dan hapus rencana'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // 08 Kalender: 'Rencana mendatang' menyembunyikan rencana lampau.
    final past = Plan(
      id: 'past',
      title: 'Trip Lampau',
      place: 'Kemarin',
      date: DateTime.now().subtract(const Duration(days: 30)),
      budget: 100000,
    );
    store.plans.add(past);
    await tester.pumpWidget(
      harness(
        Scaffold(body: CalendarPage(store: store, location: location)),
        Brightness.light,
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Rencana mendatang'), findsOneWidget);
    expect(find.text(past.title), findsNothing);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    store.dispose();
    travel.dispose();
    location.dispose();
  });

  testWidgets('render settings previews', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = Store();
    for (final brightness in Brightness.values) {
      final key = GlobalKey();
      await tester.pumpWidget(
        harness(
          RepaintBoundary(
            key: key,
            child: SettingsPage(
              store: store,
              mode: ThemeMode.system,
              onMode: (_) {},
            ),
          ),
          brightness,
        ),
      );
      await tester.pumpAndSettle();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await Directory('outputs').create(recursive: true);
        await File('outputs/settings-${brightness.name}.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    store.dispose();
  });
}
