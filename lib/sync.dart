import 'package:supabase_flutter/supabase_flutter.dart';

import 'core.dart';

// ---------- Cloud sync: Supabase = sumber kebenaran workspace ----------
// Kontrak fase 1: tulis gagal (offline/error) = perubahan lokal DIBATALKAN
// dan pemanggil menampilkan pesan. Tarik (pull) = remote menang penuh.
// Semua konversi baris <-> model murni (statis) agar bisa dites tanpa backend.
/// Hasil tulis: id uuid baru (insert) atau pesan error.
typedef Push = ({String? id, String? error});

class CloudSync {
  CloudSync(this._client, this.workspaceId);
  final SupabaseClient _client;
  String workspaceId;

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // ----- converters (murni) -----
  // Baris insert TANPA id: biar Postgres yang isi gen_random_uuid().
  // id uuid dikembalikan server, lalu dipakai sebagai id lokal.
  static Map<String, dynamic> planRow(Plan p, String workspaceId) => {
        'workspace_id': workspaceId,
        'title': p.title,
        'place': p.place,
        'lat': p.lat,
        'lng': p.lng,
        'budget': p.budget,
        'date': dateKey(p.date),
      };

  static Plan planFrom(Map<String, dynamic> m) => Plan(
        id: m['id'] as String,
        title: m['title'] as String,
        place: (m['place'] ?? '') as String,
        date: DateTime.parse(m['date'] as String),
        budget: (m['budget'] as num).toDouble(),
        lat: (m['lat'] as num?)?.toDouble(),
        lng: (m['lng'] as num?)?.toDouble(),
      );

  static Map<String, dynamic> rundownRow(Rundown r, String planId, DateTime fallbackDay) => {
        'plan_id': planId,
        'day': dateKey(r.day ?? fallbackDay),
        'time': r.time,
        'title': r.title,
        'cost': r.cost,
        'done': r.done,
      };

  static Rundown rundownFrom(Map<String, dynamic> m) => Rundown(
        id: m['id'] as String,
        time: m['time'] as String,
        title: m['title'] as String,
        cost: ((m['cost'] ?? 0) as num).toDouble(),
        done: (m['done'] ?? false) as bool,
        day: m['day'] == null ? null : DateTime.parse(m['day'] as String),
      );

  static Map<String, dynamic> txRow(Tx t, String workspaceId) => {
        'workspace_id': workspaceId,
        'title': t.title,
        'amount': t.amount,
        'date': t.date.toIso8601String(),
        'plan_id': t.planId,
      };

  static Tx txFrom(Map<String, dynamic> m) => Tx(
        id: m['id'] as String,
        title: m['title'] as String,
        amount: (m['amount'] as num).toDouble(),
        date: DateTime.parse(m['date'] as String),
        planId: m['plan_id'] as String?,
      );

  static String friendly(Object e) {
    if (e is PostgrestException) {
      if (e.code == '42501') return 'Tidak punya izin (cek role workspace).';
      return 'Server: ${e.message}';
    }
    return 'Gagal tersambung. Cek internet lalu coba lagi.';
  }

  // ----- pull: remote menang -----
  Future<String?> pull(Store s) async {
    try {
      final plans = await _client
          .from('plans')
          .select()
          .eq('workspace_id', workspaceId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      final rds = await _client
          .from('rundowns')
          .select()
          .order('day')
          .order('time')
          .timeout(const Duration(seconds: 15));
      final txs = await _client
          .from('transactions')
          .select()
          .eq('workspace_id', workspaceId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      final byPlan = <String, List<Rundown>>{};
      for (final r in rds as List) {
        final m = (r as Map).cast<String, dynamic>();
        (byPlan[m['plan_id'] as String] ??= []).add(rundownFrom(m));
      }
      s.replaceAll(
        [
          for (final p in plans as List)
            planFrom((p as Map).cast<String, dynamic>())
              ..rundown.addAll(byPlan[p['id']] ?? []),
        ],
        [for (final t in txs as List) txFrom((t as Map).cast<String, dynamic>())],
      );
      return null;
    } catch (e) {
      return friendly(e);
    }
  }

  // ----- tulis -----
  // Insert mengembalikan id uuid server (atau error). Update/delete pakai id.
  Future<Push> insertPlan(Plan p) async {
    try {
      final row = await _client.from('plans').insert(planRow(p, workspaceId)).select('id').single();
      return (id: row['id'] as String, error: null);
    } catch (e) {
      return (id: null, error: friendly(e));
    }
  }

  Future<Push> insertTx(Tx t) async {
    try {
      final row = await _client.from('transactions').insert(txRow(t, workspaceId)).select('id').single();
      return (id: row['id'] as String, error: null);
    } catch (e) {
      return (id: null, error: friendly(e));
    }
  }

  Future<Push> insertRundown(String planId, Rundown r, DateTime fallbackDay) async {
    try {
      final row = await _client
          .from('rundowns')
          .insert(rundownRow(r, planId, fallbackDay))
          .select('id')
          .single();
      return (id: row['id'] as String, error: null);
    } catch (e) {
      return (id: null, error: friendly(e));
    }
  }

  Future<String?> setRundownDone(String id, bool done) async {
    try {
      await _client.from('rundowns').update({'done': done}).eq('id', id);
      return null;
    } catch (e) {
      return friendly(e);
    }
  }

  /// Selesai otomatis versi cloud: tandai rundown + hapus plan.
  /// Transaksi dilepas otomatis oleh FK on delete set null.
  Future<String?> completePlan(String planId) async {
    try {
      await _client.from('rundowns').update({'done': true}).eq('plan_id', planId);
      await _client.from('plans').delete().eq('id', planId);
      return null;
    } catch (e) {
      return friendly(e);
    }
  }

  Future<String?> deletePlan(String id) async {
    try {
      await _client.from('plans').delete().eq('id', id);
      return null;
    } catch (e) {
      return friendly(e);
    }
  }

  Future<String?> deleteTx(String id) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
      return null;
    } catch (e) {
      return friendly(e);
    }
  }

  Future<String?> deleteRundown(String id) async {
    try {
      await _client.from('rundowns').delete().eq('id', id);
      return null;
    } catch (e) {
      return friendly(e);
    }
  }
}
