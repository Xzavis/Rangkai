import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

// ---------- Foto absen di Supabase Storage (bucket `absensi`) ----------
// Tidak butuh dart-define tambahan: ikut sesi login Supabase yang sama.
class PhotoStore {
  static const bucket = 'absensi';

  /// Upload lalu kembalikan URL publik. null + error bila gagal.
  static Future<({String? url, String? error})> upload(
    SupabaseClient client, {
    required String key,
    required Uint8List bytes,
  }) async {
    try {
      await client.storage.from(bucket).uploadBinary(
            key,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return (url: client.storage.from(bucket).getPublicUrl(key), error: null);
    } on StorageException catch (e) {
      return (url: null, error: 'Upload foto gagal: ${e.message}');
    } catch (_) {
      return (url: null, error: 'Upload foto gagal. Cek internet lalu coba lagi.');
    }
  }
}

// ---------- Model ----------
class Checkpoint {
  Checkpoint({
    required this.id,
    required this.planId,
    required this.name,
    required this.required,
    this.record,
  });
  final String id, planId, name;
  final bool required;
  AttendanceRecord? record;
  bool get done => record != null;

  static Checkpoint from(Map<String, dynamic> m) => Checkpoint(
        id: m['id'] as String,
        planId: m['plan_id'] as String,
        name: m['name'] as String,
        required: (m['required'] ?? true) as bool,
      );
}

class AttendanceRecord {
  AttendanceRecord({
    required this.photoUrl,
    required this.lat,
    required this.lng,
    required this.headcount,
  });
  final String photoUrl;
  final double lat, lng;
  final int headcount;

  static AttendanceRecord from(Map<String, dynamic> m) => AttendanceRecord(
        photoUrl: m['photo_url'] as String,
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        headcount: (m['headcount'] as num).toInt(),
      );
}

// ---------- Aturan absen (murni, dites) ----------
class AttendanceRules {
  /// Foto grup wajib memuat SELURUH anggota workspace.
  static String? validateHeadcount(int headcount, int memberCount) {
    if (headcount < 1) return 'Jumlah orang minimal 1.';
    if (headcount != memberCount) {
      return 'Foto harus memuat semua $memberCount anggota (sekarang $headcount).';
    }
    return null;
  }

  static bool canSubmit({
    required bool isRep,
    required bool repSet,
    required bool isAdmin,
  }) {
    if (!repSet) return isAdmin; // belum ada perwakilan: admin/owner dulu
    return isRep;
  }
}

// ---------- Service ----------
class AttendanceService {
  AttendanceService(this._client);
  final SupabaseClient _client;

  static const defaults = [
    ('Titik kumpul', false),
    ('Stasiun awal', true),
    ('Stasiun akhir', true),
    ('Hotel', true),
  ];

  Future<List<Checkpoint>> load(String planId) async {
    final cps = await _client
        .from('checkpoints')
        .select()
        .eq('plan_id', planId)
        .order('position');
    final recs = await _client.from('attendance').select();
    final byCp = {
      for (final r in recs as List)
        (r as Map<String, dynamic>)['checkpoint_id'] as String:
            AttendanceRecord.from(r),
    };
    return [
      for (final c in cps as List)
        Checkpoint.from((c as Map).cast<String, dynamic>())
          ..record = byCp[c['id']],
    ];
  }

  /// Buat 4 titik default bila plan belum punya (admin+; RLS menjaga).
  Future<String?> ensureDefaults(String planId) async {
    try {
      final existing = await _client
          .from('checkpoints')
          .select('id')
          .eq('plan_id', planId)
          .limit(1);
      if ((existing as List).isNotEmpty) return null;
      for (var i = 0; i < defaults.length; i++) {
        await _client.from('checkpoints').insert({
          'plan_id': planId,
          'name': defaults[i].$1,
          'position': i,
          'required': defaults[i].$2,
        });
      }
      return null;
    } catch (e) {
      return 'Gagal siapkan titik absen.';
    }
  }

  Future<String?> setRep(String planId, String userId) async {
    try {
      await _client.from('plan_reps').upsert({
        'plan_id': planId,
        'user_id': userId,
        'set_by': _client.auth.currentUser!.id,
      });
      return null;
    } catch (_) {
      return 'Gagal tunjuk perwakilan.';
    }
  }

  Future<String?> getRep(String planId) async {
    try {
      final row = await _client
          .from('plan_reps')
          .select('user_id')
          .eq('plan_id', planId)
          .maybeSingle();
      return row?['user_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// Alur submit: upload foto -> catat bukti + GPS. null = sukses.
  Future<String?> submit({
    required Checkpoint cp,
    required Uint8List photo,
    required double lat,
    required double lng,
    required double? accuracy,
    required int headcount,
  }) async {
    final key = '${cp.planId}/${cp.id}.jpg';
    final up = await PhotoStore.upload(_client, key: key, bytes: photo);
    if (up.error != null) return up.error;
    try {
      await _client.from('attendance').upsert({
        'checkpoint_id': cp.id,
        'photo_url': up.url,
        'lat': lat,
        'lng': lng,
        'accuracy': accuracy,
        'headcount': headcount,
        'recorded_by': _client.auth.currentUser!.id,
      });
      return null;
    } catch (_) {
      return 'Foto terupload tapi bukti gagal dicatat. Coba lagi.';
    }
  }
}
