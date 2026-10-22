import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'theme/tokens.dart';

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
  AuthService? _auth;
  var _offline = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _auth = widget.auth;
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    final auth = await AuthService.init();
    if (!mounted) return;
    setState(() {
      _auth = auth;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final failed = BackendConfig.hasValues && _auth == null && !_offline;
    final email = _offline ? 'offline' : _auth?.email ?? 'anon';
    return MaterialApp(
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
        auth: _auth,
        initFailed: failed,
        offline: _offline,
        busy: _busy,
        onRetry: _retry,
        onOffline: () => setState(() => _offline = true),
        // State baru per user: cloud workspace lama tidak bocor ke akun lain.
        child: Shell(
          key: ValueKey(email),
          mode: _mode,
          onMode: (mode) => setState(() => _mode = mode),
          auth: _offline ? null : _auth,
          onRequireLogin: _offline ? () => setState(() => _offline = false) : null,
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    required this.mode,
    required this.onMode,
    required this.auth,
    this.onRequireLogin,
  });
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;
  final AuthService? auth;
  final VoidCallback? onRequireLogin;
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
      final email = widget.auth?.email;
      final displayName = (email == null || !email.contains('@'))
          ? null
          : email.split('@').first;
      final pages = [
        HomePage(
          store: store,
          travel: travel,
          zone: _zone,
          onZone: (z) => setState(() => _zone = z),
          location: location,
          displayName: displayName,
          onOpenFinance: () => setState(() => _index = 1),
          onOpenTab: (i) => setState(() => _index = i),
          ws: ws,
        ),
        FinancePage(store: store),
        PlansPage(store: store, location: location, ws: ws, travel: travel),
        CalendarPage(store: store, location: location, ws: ws),
        ws == null
            ? WorkspaceOfflineTab(onLogin: widget.onRequireLogin)
            : WorkspaceContent(
                ws: ws!,
                embedded: true,
                store: store,
                location: location,
              ),
      ];
      const titles = ['Rangkai', 'Keuangan', 'Rencana', 'Kalender', 'Workspace'];
      return LayoutBuilder(
        builder: (context, constraints) {
          final rail = constraints.maxWidth >= 720;
          return Scaffold(
            appBar: AppBar(
              // Beranda ref 01: RANGKAI / [workspace aktif v] + gear.
              // Chip membuka tab Workspace (aksi nyata, bukan dropdown palsu).
              title: _index == 0
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'RANGKAI',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '/',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: InkWell(
                            onTap: () => setState(() => _index = 4),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outlineVariant,
                                ),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: CpiTokens.income(
                                        Theme.of(context).brightness,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      ws?.active?.name ?? 'Pribadi',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const Icon(Icons.expand_more, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      titles[_index],
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
              actions: [
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
                            email: widget.auth?.email,
                            workspaceName: ws?.active?.name,
                            onOpenWorkspace: () {
                              Navigator.pop(context);
                              setState(() => _index = 4);
                            },
                            onLogout: widget.auth == null
                                ? null
                                : () async {
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
                          icon: Icon(Icons.calendar_month_outlined),
                          label: Text('Kalender'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.group_outlined),
                          label: Text('Workspace'),
                        ),
                      ],
                    ),
                  Expanded(
                    child: CpiContent(
                      child: IndexedStack(index: _index, children: pages),
                    ),
                  ),
                ],
              ),
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
                        icon: Icon(Icons.calendar_month_outlined),
                        label: 'Kalender',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.group_outlined),
                        label: 'Workspace',
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
            padding: const EdgeInsets.all(CpiTokens.pagePadding),
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
                  const SizedBox(height: 20),
                  // Referensi 13: tiga langkah status di dalam satu kartu r16.
                  CpiCard(
                    padding: const EdgeInsets.all(CpiTokens.panelPadding),
                    child: Column(
                      children: [
                  _GpsStep(
                    icon: Icons.security_outlined,
                    title: 'Izinkan akses lokasi',
                    subtitle: 'Akses GPS saat aplikasi aktif',
                    status: switch (location.state) {
                      GpsState.denied => 'Belum diizinkan',
                      GpsState.foreverDenied => 'Ditolak permanen',
                      GpsState.ready => 'Diizinkan',
                      _ => 'Menunggu izin',
                    },
                    done: location.state == GpsState.ready,
                  ),
                  _GpsStep(
                    icon: Icons.my_location_outlined,
                    title: 'Nyalakan GPS',
                    subtitle: 'Diperlukan saat tracking aktif',
                    status: location.state == GpsState.serviceOff
                        ? 'GPS mati'
                        : location.state == GpsState.ready
                            ? 'GPS menyala'
                            : 'Menunggu',
                    done: location.state == GpsState.ready,
                  ),
                  _GpsStep(
                    icon: Icons.explore_outlined,
                    title: 'Baca posisi perangkat',
                    subtitle: 'Untuk tracking & bukti absen',
                    status: location.pos != null
                        ? 'Posisi terbaca'
                        : 'Belum tersedia',
                    done: location.pos != null,
                  ),
                      ],
                    ),
                  ),
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

class _GpsStep extends StatelessWidget {
  const _GpsStep({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.done,
  });
  final IconData icon;
  final String title, subtitle, status;
  final bool done;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: StatusLabel(
          status,
          tone: done ? StatusTone.active : StatusTone.waiting,
        ),
      );
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({
    super.key,
    required this.store,
    required this.mode,
    required this.onMode,
    this.email,
    this.workspaceName,
    this.onOpenWorkspace,
    this.onLogout,
  });
  final Store store;
  final ThemeMode mode;
  final ValueChanged<ThemeMode> onMode;
  final String? email;
  final String? workspaceName;
  final VoidCallback? onOpenWorkspace;
  final VoidCallback? onLogout;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: CpiContent(
      child: ListView(
        padding: cpiPagePadding(context),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              child: Text(
                (email == null || email!.isEmpty ? 'T' : email![0])
                    .toUpperCase(),
              ),
            ),
            title: Text(
              email == null
                  ? 'Mode offline'
                  : email!.split('@').first,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              email == null
                  ? 'Data lokal di perangkat ini'
                  : 'Tersambung · $email',
            ),
          ),
          const SizedBox(height: 16),
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
                (ThemeMode.light, 'Terang'),
                (ThemeMode.dark, 'Gelap'),
                (ThemeMode.system, 'Sistem'),
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
              padding: EdgeInsets.all(CpiTokens.panelPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rangkai versi 4.0.0',
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
          Text('Workspace', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.folder_outlined),
            title: Text('Workspace aktif: ${workspaceName ?? 'Lokal'}'),
            subtitle: Text(
              store.cloud == null
                  ? 'Data tersimpan di perangkat'
                  : 'Mode cloud. Kegagalan tulis ditampilkan sebagai error.',
            ),
            trailing: onOpenWorkspace == null
                ? null
                : TextButton(onPressed: onOpenWorkspace, child: const Text('Ganti')),
          ),
          const SizedBox(height: 16),
          Text('Data aplikasi', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Salin ringkasan'),
            subtitle: const Text('Saldo workspace aktif untuk ditempel ke chat/catatan.'),
            onTap: () {
              Clipboard.setData(
                ClipboardData(
                  text: 'Rangkai: saldo ${rp(store.balance)}, masuk ${rp(store.income)}, keluar ${rp(store.expense)} per ${tgl(DateTime.now())}.',
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Ringkasan disalin.')),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(store.cloud == null ? Icons.restore_outlined : Icons.refresh_outlined),
            title: Text(store.cloud == null ? 'Reset ke data contoh' : 'Muat ulang workspace'),
            subtitle: Text(
              store.cloud == null
                  ? 'Hapus transaksi dan rencana lokal, lalu isi contoh.'
                  : 'Tarik ulang data dari server. Tidak menghapus apa pun di server.',
            ),
            onTap: () async {
              final cloud = store.cloud != null;
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: Text(cloud ? 'Muat ulang workspace?' : 'Reset data?'),
                  content: Text(
                    cloud
                        ? 'Data lokal diganti salinan terbaru dari server.'
                        : 'Semua transaksi dan rencana lokal saat ini akan dihapus lalu diisi data contoh.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Batal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: Text(cloud ? 'Muat ulang' : 'Reset'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                final err = cloud ? await store.pull() : await store.reset();
                if (err != null && context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(err)));
                }
              }
            },
          ),
          if (onLogout != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout_outlined),
              title: const Text('Keluar akun'),
              subtitle: const Text('Kamu harus masuk lagi untuk melihat workspace.'),
              onTap: onLogout,
            ),
        ],
      ),
    ),
  );
}
