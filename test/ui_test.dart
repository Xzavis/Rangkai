import 'dart:io';
import 'dart:ui' as ui;

import 'package:cpi/core.dart';
import 'package:cpi/main.dart';
import 'package:cpi/pages.dart';
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
          PlansPage(store: store, location: location),
          TravelPage(travel: travel),
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
    await tester.enterText(find.byType(EditableText).at(0), 'Transportasi');
    await tester.enterText(find.byType(EditableText).at(1), '12000');
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Simpan'));
    await tester.tap(find.text('Simpan'));
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
