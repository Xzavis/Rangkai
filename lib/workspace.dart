import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------- Model ----------
enum WsRole { owner, admin, member }

WsRole parseWsRole(String s) => switch (s) {
      'owner' => WsRole.owner,
      'admin' => WsRole.admin,
      _ => WsRole.member,
    };

class Workspace {
  Workspace({required this.id, required this.name, required this.type});
  final String id, name, type;
  bool get personal => type == 'personal';

  static Workspace from(Map<String, dynamic> m) =>
      Workspace(id: m['id'] as String, name: m['name'] as String, type: m['type'] as String);
}

class Membership {
  Membership({required this.userId, required this.role, this.email});
  final String userId;
  final WsRole role;
  final String? email;

  static Membership from(Map<String, dynamic> m) => Membership(
        userId: m['user_id'] as String,
        role: parseWsRole(m['role'] as String),
      );
}

// ---------- Matrix izin (murni, dites) ----------
// owner > admin > member. Aturan diringkas di satu tempat agar UI dan
// RLS tidak mengarang sendiri.
enum WsAction {
  deleteWorkspace,
  manageMembers, // tambah/hapus/ubah role
  managePlan, // buat/hapus/ubah budget plan
  manageCheckpoints, // atur titik absen + tunjuk perwakilan
  addRundown, // siapapun anggota boleh isi rundown
  addTransaction,
  submitAttendance, // hanya perwakilan (dicek terpisah via repId)
}

class Permissions {
  static bool can(WsAction a, WsRole role) {
    return switch (a) {
      WsAction.deleteWorkspace => role == WsRole.owner,
      WsAction.manageMembers => role != WsRole.member,
      WsAction.managePlan => role != WsRole.member,
      WsAction.manageCheckpoints => role != WsRole.member,
      WsAction.addRundown || WsAction.addTransaction => true,
      WsAction.submitAttendance => true, // + cek perwakilan di service
    };
  }
}

String _friendlyWs(Object e, String fallback) {
  if (e is PostgrestException) {
    if (e.code == '42501') return 'Tidak punya izin (cek role workspace).';
    return fallback;
  }
  return fallback;
}

// ---------- Service ----------
class WorkspaceService extends ChangeNotifier {
  WorkspaceService(this._client);
  final SupabaseClient _client;
  SupabaseClient get client => _client;

  var _spaces = <Workspace>[];
  var _roles = <String, WsRole>{};
  String? _activeId;
  var _loading = false;
  String? _error;

  List<Workspace> get spaces => _spaces;
  bool get loading => _loading;
  String? get error => _error;
  Workspace? get active {
    for (final w in _spaces) {
      if (w.id == _activeId) return w;
    }
    return _spaces.isEmpty ? null : _spaces.first;
  }

  WsRole roleOfActive() => roleOf(_activeId ?? '');
  WsRole roleOf(String workspaceId) => _roles[workspaceId] ?? WsRole.member;
  String? get myId => _client.auth.currentUser?.id;

  static String newCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // tanpa 0/O/1/I
    final r = Random.secure();
    return List.generate(6, (_) => chars[r.nextInt(chars.length)]).join();
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _loading = false;
        notifyListeners();
        return;
      }
      final rows = await _client
          .from('memberships')
          .select('role, workspaces(id, name, type)')
          .eq('user_id', user.id)
          .timeout(const Duration(seconds: 15));
      _spaces = [];
      _roles = {};
      for (final r in rows as List) {
        final rawWs = r['workspaces'];
        if (rawWs == null) continue;
        final w = Workspace.from((rawWs as Map).cast<String, dynamic>());
        _spaces.add(w);
        _roles[w.id] = parseWsRole(r['role'] as String);
      }
      if (_spaces.isEmpty) {
        await create('Pribadi');
        return;
      }
      _activeId ??= _spaces.first.id;
      if (!_roles.containsKey(_activeId)) {
        _activeId = _spaces.first.id;
      }
    } catch (e) {
      _error = 'Gagal memuat workspace. Cek koneksi internet.';
    }
    _loading = false;
    notifyListeners();
  }

  void select(String id) {
    _activeId = id;
    notifyListeners();
  }

  Future<String?> create(String name) async {
    final clean = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.isEmpty || clean.length > 80) {
      return 'Nama workspace harus 1-80 karakter.';
    }
    try {
      // RPC security definer (migrasi 006): insert langsung ke workspaces +
      // memberships kena chicken-and-egg RLS 001 (selalu 42501).
      final wid = await _client.rpc(
        'create_workspace',
        params: {'ws_name': clean, 'ws_type': 'community'},
      );
      await load();
      _activeId = wid as String;
      try {
        await makeInvite();
      } catch (_) {}
      notifyListeners();
      return null;
    } catch (e) {
      return _friendlyWs(e, 'Gagal bikin workspace. Cek koneksi lalu coba lagi.');
    }
  }

  /// null = sukses (langsung gabung).
  Future<String?> join(String code) async {
    final normalized = code.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (!RegExp(r'^[A-Z0-9]{6}$').hasMatch(normalized)) {
      return 'Kode invite harus 6 huruf/angka.';
    }
    try {
      final wid = await _client.rpc('join_with_code', params: {'invite_code': normalized});
      await load();
      if (wid != null) _activeId = wid as String;
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      return e.message.contains('tidak dikenal')
          ? 'Kode tidak dikenal. Cek lagi.'
          : 'Gagal gabung. Kode mungkin sudah kedaluwarsa atau koneksi bermasalah.';
    } catch (e) {
      return _friendlyWs(e, 'Gagal gabung. Cek koneksi lalu coba lagi.');
    }
  }

  /// Kode undangan aktif terbaru (belum kedaluwarsa), bila ada.
  Future<String?> currentInvite({bool autoCreateIfMissing = false}) async {
    final a = active;
    if (a == null) return null;
    try {
      var q = _client
          .from('invites')
          .select('code')
          .eq('workspace_id', a.id)
          .order('created_at', ascending: false)
          .limit(1);
      final rows = await q.timeout(const Duration(seconds: 15));
      if ((rows as List).isNotEmpty) {
        return rows.first['code'] as String?;
      }
      if (autoCreateIfMissing) {
        return await makeInvite();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// null = gagal (pesan di [error]); tidak lagi melempar ke UI.
  Future<String?> makeInvite() async {
    final a = active;
    if (a == null) {
      _error = 'Belum ada workspace aktif.';
      notifyListeners();
      return null;
    }
    try {
      final code = newCode();
      await _client.from('invites').insert({
        'code': code,
        'workspace_id': a.id,
        'created_by': _client.auth.currentUser!.id,
      }).timeout(const Duration(seconds: 15));
      return code;
    } catch (e) {
      _error = _friendlyWs(e, 'Gagal bikin kode invite.');
      notifyListeners();
      return null;
    }
  }

  Future<List<Membership>> members() async {
    final rows = await _client
        .from('memberships')
        .select('user_id, role')
        .eq('workspace_id', active!.id);
    return [for (final r in rows as List) Membership.from((r as Map).cast<String, dynamic>())];
  }

  Future<String?> setRole(String userId, WsRole role) async {
    try {
      await _client.from('memberships').update({'role': role.name}).match({
        'workspace_id': active!.id,
        'user_id': userId,
      });
      await load();
      return null;
    } catch (e) {
      return _friendlyWs(e, 'Gagal ubah role.');
    }
  }

  Future<String?> removeMember(String userId) async {
    try {
      await _client.from('memberships').delete().match({
        'workspace_id': active!.id,
        'user_id': userId,
      });
      await load();
      return null;
    } catch (e) {
      return _friendlyWs(e, 'Gagal keluarkan anggota.');
    }
  }
}
