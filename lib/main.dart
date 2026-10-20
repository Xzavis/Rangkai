import 'package:flutter/material.dart';
import 'package:forui/forui.dart' show FTheme;

import 'auth.dart';
import 'core.dart';
import 'login_page.dart';
import 'pages.dart';
import 'sync.dart';
import 'widgets.dart';
import 'workspace.dart';
import 'workspace_page.dart';
import 'theme/theme.dart' as ui;
import 'theme/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(CpiApp(auth: await AuthService.init()));
}

class CpiApp extends StatefulWidget {
  const CpiApp({super.key, required this.auth});
  final AuthService? auth;
  @override
  State<CpiApp> createState() => _CpiAppState();
}

class _CpiAppState extends State<CpiApp> {
  var _mode = ThemeMode.system;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Rangkai',
    debugShowCheckedModeBanner: false,
    theme: cpiMaterialTheme(Brightness.light),
    darkTheme: cpiMaterialTheme(Brightness.dark),
    themeMode: _mode,
    builder: (context, child) => FTheme(
      data: Theme.of(context).brightness == Brightness.dark
          ? ui.darkTheme
          : ui.lightTheme,
      child: child!,
    ),
    home: AuthGate(
      auth: widget.auth,
      // State baru per user: cloud workspace lama tidak bocor ke akun lain.
      child: Shell(
        key: ValueKey(widget.auth?.email ?? 'offline'),
        mode: _mode,
        onMode: (mode) => setState(() => _mode = mode),
        auth: widget.auth,
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.mode, required this.onMode, required this.auth});
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;
  final AuthService? auth;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  final store = Store()..seed();
  final travel = TravelService();
  final location = LocationService();
  WorkspaceService? ws;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    location.check();
    final auth = widget.auth;
    if (auth != null) {
      ws = WorkspaceService(auth.client)..load();
    }
  }
  var _index = 0;
  var _zone = Zone.zones.first;
  String? _cloudFor;

  /// Tempel cloud ke store mengikuti workspace aktif. Pull sekali per ganti
  /// workspace; offline (tanpa auth) = mode lokal dengan seed.
  void _attachCloud() {
    final service = ws;
    final auth = widget.auth;
    if (service == null || auth == null) {
      store.cloud = null;
      _cloudFor = null;
      return;
    }
    final id = service.active?.id;
    if (id == null || id == _cloudFor) return;
    _cloudFor = id;
    store.cloud = CloudSync(auth.client, id);
    store.pull().then((err) {
      if (err != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(err)));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) location.check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.dispose();
    travel.dispose();
    location.dispose();
    ws?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([
      store,
      travel,
      location,
      if (ws != null) ws!,
    ]),
    builder: (context, _) {
      _attachCloud();
      if (!location.ready) return GpsGatePage(location: location);
      final pages = [
        HomePage(
          store: store,
          travel: travel,
          zone: _zone,
          onZone: (z) => setState(() => _zone = z),
          location: location,
        ),
        FinancePage(store: store),
        PlansPage(store: store, location: location, ws: ws),
        TravelPage(travel: travel),
      ];
      const titles = ['Rangkai', 'Keuangan', 'Rencana', 'Travel Live'];
      return LayoutBuilder(
        builder: (context, constraints) {
          final rail = constraints.maxWidth >= 720;
          return Scaffold(
            appBar: AppBar(
              title: Text(
                titles[_index],
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              actions: [
                if (ws != null)
                  IconButton(
                    tooltip: 'Workspace',
                    icon: const Icon(Icons.group_outlined),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => WorkspacePage(ws: ws!)),
                    ),
                  ),
                if (widget.auth != null)
                  IconButton(
                    tooltip: 'Keluar (${widget.auth!.email ?? ''})',
                    icon: const Icon(Icons.logout_outlined),
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Keluar?'),
                          content: const Text(
                              'Kamu harus masuk lagi untuk melihat workspace.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Batal'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Keluar'),
                            ),
                          ],
                        ),
                      );
                      if (ok == true) widget.auth!.signOut();
                    },
                  ),
                IconButton(
                  tooltip: 'Pengaturan tema',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () {
                    var selectedMode = widget.mode;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StatefulBuilder(
                          builder: (context, updateSettings) => SettingsPage(
                            store: store,
                            mode: selectedMode,
                            onMode: (value) {
                              widget.onMode(value);
                              updateSettings(() => selectedMode = value);
                            },
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            body: SafeArea(
              top: false,
              child: Row(
                children: [
                  if (rail)
                    NavigationRail(
                      extended: constraints.maxWidth >= 960,
                      selectedIndex: _index,
                      onDestinationSelected: (i) => setState(() => _index = i),
                      destinations: const [
                        NavigationRailDestination(
                          icon: CPIcon('home'),
                          label: Text('Beranda'),
                        ),
                        NavigationRailDestination(
                          icon: CPIcon('wallet'),
                          label: Text('Keuangan'),
                        ),
                        NavigationRailDestination(
                          icon: CPIcon('calendar'),
                          label: Text('Rencana'),
                        ),
                        NavigationRailDestination(
                          icon: CPIcon('train'),
                          label: Text('Travel'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: CpiContent(
                      child: AnimatedSwitcher(
                        duration: MediaQuery.disableAnimationsOf(context)
                            ? Duration.zero
                            : const Duration(milliseconds: 180),
                        child: KeyedSubtree(
                          key: ValueKey(_index),
                          child: pages[_index],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            floatingActionButton: _index == 3
                ? null
                : CpiButton(
                    onPressed: () => _index == 2
                        ? showPlanSheet(context, store)
                        : showTxSheet(context, store),
                    child: Text(_index == 2 ? '+ Rencana' : '+ Transaksi'),
                  ),
            bottomNavigationBar: rail
                ? null
                : NavigationBar(
                    selectedIndex: _index,
                    onDestinationSelected: (i) => setState(() => _index = i),
                    destinations: const [
                      NavigationDestination(
                        icon: CPIcon('home'),
                        label: 'Beranda',
                      ),
                      NavigationDestination(
                        icon: CPIcon('wallet'),
                        label: 'Keuangan',
                      ),
                      NavigationDestination(
                        icon: CPIcon('calendar'),
                        label: 'Rencana',
                      ),
                      NavigationDestination(
                        icon: CPIcon('train'),
                        label: 'Travel',
                      ),
                    ],
                  ),
          );
        },
      );
    },
  );
}

class GpsGatePage extends StatelessWidget {
  const GpsGatePage({super.key, required this.location});
  final LocationService location;
  @override
  Widget build(BuildContext context) {
    final (title, message) = switch (location.state) {
      GpsState.checking => (
        'Menyiapkan GPS',
        'Menghubungi layanan lokasi di perangkat kamu.',
      ),
      GpsState.serviceOff => (
        'GPS masih mati',
        'Nyalakan layanan lokasi perangkat untuk tracking perjalanan.',
      ),
      GpsState.denied => (
        'Izin lokasi belum diberikan',
        'Berikan izin lokasi agar Rangkai dapat membaca posisi kamu.',
      ),
      GpsState.foreverDenied => (
        'Izin lokasi ditolak permanen',
        'Izinkan lokasi di pengaturan aplikasi, lalu kembali ke Rangkai.',
      ),
      GpsState.ready => ('GPS aktif', 'Membaca posisi pertama kamu.'),
    };
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(message, textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  if (location.state == GpsState.checking)
                    const Center(child: CircularProgressIndicator()),
                  if (location.state == GpsState.serviceOff)
                    CpiButton(
                      onPressed: location.openGpsSettings,
                      child: const Text('Buka pengaturan lokasi'),
                    ),
                  if (location.state == GpsState.denied)
                    CpiButton(
                      onPressed: location.check,
                      child: const Text('Minta izin GPS'),
                    ),
                  if (location.state == GpsState.foreverDenied)
                    CpiButton(
                      onPressed: location.openAppSettings,
                      child: const Text('Buka pengaturan aplikasi'),
                    ),
                  const SizedBox(height: 12),
                  CpiButton(
                    secondary: true,
                    onPressed: location.check,
                    child: const Text('Cek lagi'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.mode,
    required this.onMode,
  });
  final Store store;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: CpiContent(
      child: ListView(
        padding: cpiPagePadding(context),
        children: [
          Text('Tampilan', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text(
            'Pilihan mode diterapkan ke seluruh aplikasi.',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in [
                (ThemeMode.system, 'Sistem'),
                (ThemeMode.light, 'Terang'),
                (ThemeMode.dark, 'Gelap'),
              ])
                CpiButton(
                  secondary: mode != item.$1,
                  selected: mode == item.$1,
                  onPressed: () => onMode(item.$1),
                  child: Text(item.$2),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const CpiCard(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rangkai versi 4.0.0 beta',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'GPS realtime wajib aktif. Nama hotel dan stasiun dari OpenStreetMap. Harga travel adalah estimasi.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Reset ke data contoh'),
            subtitle: const Text(
              'Hapus transaksi dan rencana, lalu isi contoh.',
            ),
            onTap: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Reset data?'),
                  content: const Text(
                    'Semua transaksi dan rencana saat ini akan dihapus.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                final err = await store.reset();
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(err)));
                }
              }
            },
          ),
        ],
      ),
    ),
  );
}
