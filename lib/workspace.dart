import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------- Model ----------
enum WsRole { owner, admin, member }

WsRole roleOf(String s) => switch (s) {
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
        role: roleOf(m['role'] as String),
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
      final rows = await _client
          .from('memberships')
          .select('role, workspaces(id, name, type)')
          .eq('user_id', _client.auth.currentUser!.id);
      _spaces = [];
      _roles = {};
      for (final r in rows as List) {
        final w = Workspace.from((r['workspaces'] as Map).cast<String, dynamic>());
        _spaces.add(w);
        _roles[w.id] = roleOf(r['role'] as String);
      }
      _activeId ??= _spaces.isEmpty ? null : _spaces.first.id;
      if (_activeId != null && !_roles.containsKey(_activeId)) {
        _activeId = _spaces.isEmpty ? null : _spaces.first.id;
      }
    } catch (e) {
      _error = 'Gagal memuat workspace: $e';
    }
    _loading = false;
    notifyListeners();
  }

  void select(String id) {
    _activeId = id;
    notifyListeners();
  }

  Future<String?> create(String name) async {
    try {
      final w = await _client
          .from('workspaces')
          .insert({'name': name.trim(), 'type': 'community'})
          .select()
          .single();
      await _client.from('memberships').insert({
        'workspace_id': w['id'],
        'user_id': _client.auth.currentUser!.id,
        'role': 'owner',
      });
      await load();
      _activeId = w['id'] as String;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Gagal bikin workspace: $e';
    }
  }

  /// null = sukses (langsung gabung).
  Future<String?> join(String code) async {
    try {
      final wid = await _client.rpc('join_with_code', params: {'invite_code': code.trim()});
      await load();
      if (wid != null) _activeId = wid as String;
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      return e.message.contains('tidak dikenal') ? 'Kode tidak dikenal. Cek lagi.' : 'Gagal gabung: ${e.message}';
    } catch (e) {
      return 'Gagal gabung: $e';
    }
  }

  Future<String> makeInvite() async {
    final code = newCode();
    await _client.from('invites').insert({
      'code': code,
      'workspace_id': active!.id,
    });
    return code;
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
      return 'Gagal ubah role: $e';
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
      return 'Gagal keluarkan anggota: $e';
    }
  }
}
