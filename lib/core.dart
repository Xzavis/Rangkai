import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'sync.dart';

// ---------- Format ----------
String rp(num v) {
  final neg = v < 0;
  final digits = v.abs().round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write('.');
    buf.write(digits[i]);
  }
  return '${neg ? '-' : ''}Rp$buf';
}

String tgl(DateTime d) {
  const bln = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  const hr = ['Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
  return '${hr[d.weekday - 1]}, ${d.day} ${bln[d.month - 1]} ${d.year}';
}

String jam(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';

// ---------- Models ----------
/// Nilai stabil yang tersimpan (bukan label terjemahan sesaat).
const txCategories = <String>[
  'Umum',
  'Makan',
  'Transport',
  'Hotel',
  'Belanja',
  'Hiburan',
  'Kesehatan',
  'Pendapatan',
  'Lainnya',
];

/// Label hari relatif untuk grup transaksi (referensi 02).
String dayLabel(DateTime day, DateTime now) {
  final d = DateTime(day.year, day.month, day.day);
  final today = DateTime(now.year, now.month, now.day);
  if (d == today) return 'Hari ini — ${tgl(day)}';
  if (d == today.subtract(const Duration(days: 1))) {
    return 'Kemarin — ${tgl(day)}';
  }
  return tgl(day);
}

/// "2 Hari 1 Malam" dari rentang rencana (referensi 04).
String planDurationLabel(Plan p) {
  final days = p.lastDay.difference(DateTime(p.date.year, p.date.month, p.date.day)).inDays + 1;
  if (days <= 1) return '1 Hari';
  return '$days Hari ${days - 1} Malam';
}

/// Status rencana dari tanggal (referensi 01/03/04).
String planStatusLabel(Plan p, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final start = DateTime(p.date.year, p.date.month, p.date.day);
  final end = DateTime(p.lastDay.year, p.lastDay.month, p.lastDay.day);
  if (today.isBefore(start)) return 'Mendatang';
  if (today.isAfter(end)) return 'Sudah lewat';
  return 'Sedang Berlangsung';
}

class Tx {
  Tx({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    this.planId,
    this.category = 'Umum',
    this.note = '',
  });
  final String id, title;
  final double amount; // + income, - expense
  final DateTime date;
  final String category;
  final String note;
  String?
  planId; // dilepas (jadi null) saat rencana selesai dan dihapus otomatis
  bool get isIncome => amount > 0;
}

class Rundown {
  Rundown({
    required this.id,
    required this.time,
    required this.title,
    this.cost = 0,
    this.done = false,
    this.day,
  });
  final String id, time, title; // time "HH:mm" sorts correctly as text
  double cost;
  bool done;
  /// Tanggal pelaksanaan. null = ikut tanggal plan (data lama).
  DateTime? day;
}

class Plan {
  Plan({
    required this.id,
    required this.title,
    required this.place,
    required this.date,
    required this.budget,
    this.endDate,
    this.lat,
    this.lng,
    List<Rundown>? rundown,
  }) : rundown = rundown ?? [];
  final String id, title, place;
  final DateTime date;

  /// Tanggal akhir opsional. null (data lama) = satu hari, ikut [date].
  final DateTime? endDate;
  DateTime get lastDay => endDate ?? date;
  final double budget;
  final double? lat,
      lng; // koordinat tujuan dari pencarian tempat, dipakai GPS tracking
  final List<Rundown> rundown;
  double get estimasi => rundown.fold(0, (s, r) => s + r.cost);
  bool get semuaSelesai => rundown.isNotEmpty && rundown.every((r) => r.done);
}

class Offer {
  Offer({
    required this.kind,
    required this.name,
    required this.from,
    required this.to,
    required this.price,
    required this.meta,
    this.lat,
    this.lng,
  });
  final String kind, name, from, to, meta; // kind: 'kereta' | 'hotel'

  /// Koordinat hasil OSM yang nyata (null hanya pada contoh awal).
  final double? lat, lng;
  double price;
  double delta = 0;
}

class Place {
  Place(this.name, this.lat, this.lng, [this.detail = '']);
  final String name, detail;
  final double lat, lng;
}

// ---------- Tracking math (dites) ----------
int _menit(String hhmm) =>
    int.parse(hhmm.substring(0, 2)) * 60 + int.parse(hhmm.substring(3, 5));

/// -1 = belum mulai, 0..n-1 = indeks yang sedang jalan, n = semua lewat.
int activeRundown(List<Rundown> r, int nowMinutes) {
  if (r.isEmpty || nowMinutes < _menit(r.first.time)) return -1;
  var idx = r.length - 1;
  for (var i = 0; i < r.length; i++) {
    if (nowMinutes < _menit(r[i].time)) {
      idx = i - 1;
      break;
    }
    if (i == r.length - 1) idx = r.length;
  }
  if (idx == r.length && nowMinutes < _menit(r.last.time) + 120)
    return r.length - 1;
  return idx;
}

/// Sampai tujuan kalau GPS membaca jarak <= 150 meter.
bool isArrived(double? remainingMeters) =>
    remainingMeters != null && remainingMeters <= 150;
double tripProgress(double startMeters, double remainingMeters) =>
    startMeters <= 0
    ? 0
    : (1 - remainingMeters / startMeters).clamp(0, 1).toDouble();

// ---------- Budget math (dites) ----------
class BudgetCalc {
  static double spentOf(List<Tx> txs, String planId) => txs
      .where((t) => t.planId == planId && t.amount < 0)
      .fold(0, (s, t) => s - t.amount);
  static double sisa(double budget, double spent) => budget - spent;
  static double ratio(double budget, double spent) =>
      budget <= 0 ? 0 : (spent / budget).clamp(0, 1).toDouble();

  /// Patungan rata dalam rupiah bulat. [per] = floor bagi, [remainder] =
  /// rupiah tersisa yang tidak habis dibagi (ditampilkan apa adanya,
  /// tidak diam-diam dibulatkan). people<1 dianggap 1. Bukan transfer.
  static ({int per, int remainder}) splitEqual(num total, int people) {
    final n = people < 1 ? 1 : people;
    final t = total < 0 ? 0 : total.round();
    return (per: t ~/ n, remainder: t % n);
  }
}

enum TxFilter { all, income, expense }

/// Filter daftar Keuangan (murni, dites): teks pada judul/kategori/catatan,
/// bulan dari [month] (null = semua bulan), dan jenis dari tanda amount.
/// Hasil terurut tanggal transaksi terbaru dulu, bukan urutan insert.
List<Tx> filterTxs(
  List<Tx> txs, {
  String query = '',
  DateTime? month,
  TxFilter type = TxFilter.all,
}) {
  final q = query.trim().toLowerCase();
  final out = txs.where((t) {
    if (month != null &&
        (t.date.year != month.year || t.date.month != month.month)) {
      return false;
    }
    if (type == TxFilter.income && t.amount <= 0) return false;
    if (type == TxFilter.expense && t.amount >= 0) return false;
    if (q.isNotEmpty &&
        !t.title.toLowerCase().contains(q) &&
        !t.category.toLowerCase().contains(q) &&
        !t.note.toLowerCase().contains(q)) {
      return false;
    }
    return true;
  }).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// Kelompokkan transaksi per hari (tanggal transaksi), hari terbaru dulu.
List<({DateTime day, List<Tx> items, double subtotal})> groupTxsByDay(
  List<Tx> txs,
) {
  final byDay = <DateTime, List<Tx>>{};
  for (final t in txs) {
    final k = DateTime(t.date.year, t.date.month, t.date.day);
    (byDay[k] ??= []).add(t);
  }
  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final d in days)
      (
        day: d,
        items: byDay[d]!,
        subtotal: byDay[d]!.fold<double>(0, (s, t) => s + t.amount),
      ),
  ];
}

// ---------- Store: in-memory ----------
// shortcut: data resets on restart; add shared_preferences/hive when persistence is needed.
class Store extends ChangeNotifier {
  final txs = <Tx>[];
  final plans = <Plan>[];

  /// null = mode lokal (offline). Terisi saat user login + pilih workspace.
  CloudSync? cloud;

  double get income =>
      txs.where((t) => t.amount > 0).fold(0, (s, t) => s + t.amount);
  double get expense =>
      txs.where((t) => t.amount < 0).fold(0, (s, t) => s - t.amount);
  double get balance => income - expense;
  double spentOf(Plan p) => BudgetCalc.spentOf(txs, p.id);

  /// Transaksi terurut tanggal aktual terbaru dulu (untuk daftar ringkas).
  List<Tx> get recentTxs =>
      [...txs]..sort((a, b) => b.date.compareTo(a.date));

  /// null = sukses, string = pesan error (perubahan lokal dibatalkan).
  Future<String?> reset() async {
    txs.clear();
    plans.clear();
    if (cloud != null) return pull();
    seed();
    notifyListeners();
    return null;
  }

  /// Tarik ulang dari cloud (remote menang). Tanpa cloud = no-op.
  Future<String?> pull() async {
    if (cloud == null) return null;
    return cloud!.pull(this);
  }

  /// Ganti seluruh isi dari cloud (dipanggil CloudSync setelah fetch).
  void replaceAll(List<Plan> newPlans, List<Tx> newTxs) {
    plans
      ..clear()
      ..addAll(newPlans);
    txs
      ..clear()
      ..addAll(newTxs);
    notifyListeners();
  }

  Future<String?> addTx(Tx t) async {
    var id = t.id;
    if (cloud != null) {
      final res = await cloud!.insertTx(t);
      if (res.error != null) return res.error;
      id = res.id!;
    }
    txs.insert(
      0,
      Tx(
        id: id,
        title: t.title,
        amount: t.amount,
        date: t.date,
        planId: t.planId,
        category: t.category,
        note: t.note,
      ),
    );
    notifyListeners();
    return null;
  }

  Future<String?> removeTx(String id) async {
    if (cloud != null) {
      final err = await cloud!.deleteTx(id);
      if (err != null) return err;
    }
    txs.removeWhere((t) => t.id == id);
    notifyListeners();
    return null;
  }

  Future<String?> addPlan(Plan p) async {
    if (p.endDate != null && p.endDate!.isBefore(DateTime(p.date.year, p.date.month, p.date.day))) {
      return 'Tanggal akhir tidak boleh sebelum tanggal mulai.';
    }
    var id = p.id;
    if (cloud != null) {
      final res = await cloud!.insertPlan(p);
      if (res.error != null) return res.error;
      id = res.id!;
    }
    // Rundown awal ikut tersimpan; bentuk ulang tanpa menyalinnya adalah
    // bug lama (field diam-diam terbuang).
    final saved = Plan(
      id: id,
      title: p.title,
      place: p.place,
      date: p.date,
      budget: p.budget,
      endDate: p.endDate,
      lat: p.lat,
      lng: p.lng,
      rundown: [...p.rundown],
    );
    plans.insert(0, saved);
    if (cloud != null) {
      for (final r in p.rundown) {
        final res = await cloud!.insertRundown(id, r, p.date);
        if (res.error != null) {
          notifyListeners();
          return 'Rencana tersimpan, tapi rundown "${r.title}" gagal: ${res.error}';
        }
      }
    }
    notifyListeners();
    return null;
  }

  /// Hapus rencana tapi riwayat uang TETAP (kaitan dilepas).
  /// Samakan dengan completeAndRemove + FK on delete set null di cloud.
  Future<String?> removePlan(String id) async {
    if (cloud != null) {
      final err = await cloud!.deletePlan(id);
      if (err != null) return err;
    }
    for (final t in txs.where((t) => t.planId == id)) {
      t.planId = null;
    }
    plans.removeWhere((p) => p.id == id);
    notifyListeners();
    return null;
  }

  Future<String?> addRundown(Plan p, Rundown r) async {
    var id = r.id;
    if (cloud != null) {
      final res = await cloud!.insertRundown(p.id, r, p.date);
      if (res.error != null) return res.error;
      id = res.id!;
    }
    p.rundown
      ..add(
        Rundown(
          id: id,
          time: r.time,
          title: r.title,
          cost: r.cost,
          done: r.done,
          day: r.day ?? p.date,
        ),
      )
      ..sort((a, b) => a.time.compareTo(b.time));
    notifyListeners();
    return null;
  }

  Future<String?> removeRundown(Plan p, Rundown r) async {
    if (cloud != null) {
      final err = await cloud!.deleteRundown(r.id);
      if (err != null) return err;
    }
    p.rundown.remove(r);
    notifyListeners();
    return null;
  }

  Future<String?> toggleRundown(Plan p, Rundown r) async {
    if (cloud != null) {
      final err = await cloud!.setRundownDone(r.id, !r.done);
      if (err != null) return err;
    }
    r.done = !r.done;
    notifyListeners();
    return null;
  }

  /// Selesai otomatis: centang semua rundown, lepas kaitan transaksi (riwayat uang tetap ada), hapus rencana.
  Future<String?> completeAndRemove(Plan p) async {
    if (cloud != null) {
      final err = await cloud!.completePlan(p.id);
      if (err != null) return err;
    }
    for (final r in p.rundown) {
      r.done = true;
    }
    for (final t in txs.where((t) => t.planId == p.id)) {
      t.planId = null;
    }
    plans.removeWhere((e) => e.id == p.id);
    notifyListeners();
    return null;
  }

  /// ID lokal tidak bisa ditebak dari jam dinding (Random.secure).
  static String newId() {
    final r = Random.secure();
    final bytes = List.generate(9, (_) => r.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  void seed() {
    if (plans.isNotEmpty) return;
    final p = Plan(
      id: 'p1',
      title: 'Trip Bandung',
      place: 'Bandung, Jawa Barat',
      lat: -6.9175,
      lng: 107.6191,
      date: DateTime.now().add(const Duration(days: 6)),
      budget: 2500000,
      rundown: [
        Rundown(
          id: 'r1',
          time: '07:00',
          title: 'Berangkat dari Stasiun Gambir',
          cost: 150000,
        ),
        Rundown(id: 'r2', time: '10:30', title: 'Check-in hotel', cost: 450000),
        Rundown(id: 'r3', time: '13:00', title: 'Kuliner Braga', cost: 200000),
        Rundown(
          id: 'r4',
          time: '19:00',
          title: 'Makan malam dan kopi',
          cost: 180000,
        ),
      ],
    );
    plans.add(p);
    txs.addAll([
      Tx(
        id: 't1',
        title: 'Gaji bulan ini',
        amount: 7500000,
        date: DateTime.now(),
      ),
      Tx(
        id: 't2',
        title: 'Tiket kereta Bandung',
        amount: -150000,
        date: DateTime.now(),
        planId: 'p1',
      ),
      Tx(
        id: 't3',
        title: 'Booking hotel 1 malam',
        amount: -450000,
        date: DateTime.now(),
        planId: 'p1',
      ),
      Tx(
        id: 't4',
        title: 'Kopi dan transport',
        amount: -85000,
        date: DateTime.now(),
      ),
    ]);
  }
}

// ---------- GPS wajib ----------
enum GpsState { checking, serviceOff, denied, foreverDenied, ready }

class LocationService extends ChangeNotifier {
  GpsState state = GpsState.checking;
  Position? pos;
  StreamSubscription<Position>? _sub;

  bool get ready => state == GpsState.ready && pos != null;

  Future<void> check() async {
    state = GpsState.checking;
    notifyListeners();
    if (!await Geolocator.isLocationServiceEnabled()) {
      state = GpsState.serviceOff;
      notifyListeners();
      return;
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied)
      perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.deniedForever) {
      state = GpsState.foreverDenied;
      notifyListeners();
      return;
    }
    if (perm == LocationPermission.denied) {
      state = GpsState.denied;
      notifyListeners();
      return;
    }
    state = GpsState.ready;
    notifyListeners();
    _sub ??=
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen(
          (p) {
            pos = p;
            notifyListeners();
          },
          onError: (_) {
            state = GpsState.serviceOff;
            notifyListeners();
          },
        );
    try {
      pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (_) {}
    notifyListeners();
  }

  double? distanceTo(double? lat, double? lng) =>
      (pos == null || lat == null || lng == null)
      ? null
      : Geolocator.distanceBetween(pos!.latitude, pos!.longitude, lat, lng);

  Future<void> openGpsSettings() => Geolocator.openLocationSettings();
  Future<void> openAppSettings() => Geolocator.openAppSettings();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

// ---------- Realtime clock + timezone ----------
class Zone {
  const Zone(this.city, this.label, this.utcOffset);
  final String city, label;
  final int utcOffset;
  static const zones = [
    Zone('Jakarta', 'WIB', 7),
    Zone('Makassar', 'WITA', 8),
    Zone('Jayapura', 'WIT', 9),
    Zone('Singapura', 'SGT', 8),
    Zone('Tokyo', 'JST', 9),
    Zone('Dubai', 'GST', 4),
    Zone('London', 'GMT', 0),
  ];
  DateTime at(DateTime nowUtc) => nowUtc.add(Duration(hours: utcOffset));
}

// ---------- Data live dari OpenStreetMap (gratis, tanpa API key) ----------
// Nama hotel dan stasiun asli dari peta. Harga tidak tersedia di data peta,
// jadi harga adalah estimasi yang bergerak live. Itu ditulis apa adanya di UI.
class GeoApi {
  static Future<dynamic> _get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final req = await client.getUrl(uri);
      req.headers.set(
        HttpHeaders.userAgentHeader,
        'Rangkai/4.0 travel app',
      );
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      return jsonDecode(await res.transform(utf8.decoder).join());
    } finally {
      client.close();
    }
  }

  static Future<List<Place>> searchPlace(String q) async {
    final query = q.trim();
    if (query.isEmpty || query.length > 120) return [];
    final data = await _get(
      Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': query,
        'format': 'json',
        'limit': '8',
        'addressdetails': '0',
      }),
    ) as List;
    return [
      for (final e in data)
        Place(
          (e['display_name'] as String).split(',').first,
          double.parse(e['lat']),
          double.parse(e['lon']),
          (e['display_name'] as String)
              .split(',')
              .skip(1)
              .take(2)
              .join(',')
              .trim(),
        ),
    ];
  }

  static Future<List<Place>> _overpass(
    Place c,
    String filter,
    int radius,
  ) async {
    final query =
        '[out:json][timeout:25];node[$filter](around:$radius,${c.lat},${c.lng});out body 20;';
    final data = await _get(
      Uri.https('overpass-api.de', '/api/interpreter', {'data': query}),
    ) as Map<String, dynamic>;
    final out = <Place>[];
    for (final e in (data['elements'] as List? ?? [])) {
      final tags = (e['tags'] as Map?) ?? {};
      final name = tags['name']?.toString();
      if (name == null || name.isEmpty) continue;
      final detail = [
        tags['addr:street'],
        tags['stars'] != null ? 'Bintang ${tags['stars']}' : null,
      ].whereType<String>().join(' · ');
      out.add(
        Place(
          name,
          (e['lat'] as num).toDouble(),
          (e['lon'] as num).toDouble(),
          detail,
        ),
      );
    }
    return out;
  }

  static Future<List<Place>> hotelsNear(Place c) =>
      _overpass(c, '"tourism"~"hotel|hostel|apartment"', 6000);
  static Future<List<Place>> stationsNear(Place c) =>
      _overpass(c, '"railway"="station"', 12000);
}

// ---------- Harga travel live + pencarian ----------
class TravelService extends ChangeNotifier {
  TravelService() {
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _tick());
  }
  late final Timer _timer;
  final _rnd = Random();
  DateTime lastSync = DateTime.now();
  bool syncing = false;
  String? error;
  String lastQuery = '';

  final offers = <Offer>[
    Offer(
      kind: 'kereta',
      name: 'Argo Parahyangan',
      from: 'Gambir',
      to: 'Bandung',
      price: 150000,
      meta: 'Contoh awal. Cari kota tujuan untuk data stasiun asli.',
    ),
    Offer(
      kind: 'hotel',
      name: 'Hotel Savoy Homann',
      from: 'Bandung',
      to: 'Asia Afrika',
      price: 485000,
      meta: 'Contoh awal. Cari kota untuk hotel asli dari peta.',
    ),
  ];

  double _estimasi(String nama, double min, double sebaran) =>
      min + (nama.codeUnits.fold(0, (s, c) => s + c) % 100) / 100 * sebaran;

  /// Cari stasiun atau hotel asli di sekitar tempat yang dicari user.
  Future<void> search(String query, String kind) async {
    if (query.trim().isEmpty || syncing) return;
    syncing = true;
    error = null;
    lastQuery = query.trim();
    notifyListeners();
    try {
      final places = await GeoApi.searchPlace(query);
      if (places.isEmpty) {
        error = 'Tempat "$query" tidak ditemukan di peta.';
        return;
      }
      final center = places.first;
      final found = kind == 'hotel'
          ? await GeoApi.hotelsNear(center)
          : await GeoApi.stationsNear(center);
      if (found.isEmpty) {
        error = kind == 'hotel'
            ? 'Tidak ada hotel terdata di peta sekitar ${center.name}.'
            : 'Tidak ada stasiun terdata di peta sekitar ${center.name}.';
        return;
      }
      offers.removeWhere((o) => o.kind == kind);
      for (final p in found.take(15)) {
        offers.add(
          kind == 'hotel'
              ? Offer(
                  kind: kind,
                  name: p.name,
                  from: center.name,
                  to: p.detail.isEmpty ? 'Dekat pusat area' : p.detail,
                  price: _estimasi(p.name, 185000, 900000),
                  meta: 'Nama asli dari OpenStreetMap. Harga estimasi live per malam.',
                  lat: p.lat,
                  lng: p.lng,
                )
              : Offer(
                  kind: kind,
                  name: 'Kereta ke ${p.name}',
                  from: 'Stasiun terdekat kamu',
                  to: p.name,
                  price: _estimasi(p.name, 85000, 420000),
                  meta: 'Stasiun asli dari OpenStreetMap. Harga estimasi live, bukan tarif resmi KAI.',
                  lat: p.lat,
                  lng: p.lng,
                ),
        );
      }
      lastSync = DateTime.now();
    } catch (_) {
      error = 'Gagal mengambil data live. Cek koneksi internet kamu lalu coba lagi.';
    } finally {
      syncing = false;
      notifyListeners();
    }
  }

  void _tick() {
    if (offers.isEmpty) return;
    for (final o in offers) {
      final d = o.price * (_rnd.nextDouble() * 0.06 - 0.03);
      o.delta = d;
      o.price = max(10000, o.price + d);
    }
    lastSync = DateTime.now();
    notifyListeners();
  }

  Future<void> refresh() async {
    if (syncing) return;
    if (lastQuery.isNotEmpty) {
      await search(lastQuery, 'hotel');
      await search(lastQuery, 'kereta');
      return;
    }
    syncing = true;
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));
    _tick();
    syncing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
