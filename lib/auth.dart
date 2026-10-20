import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------- Konfigurasi backend (tidak di-commit) ----------
// Jalanin dengan:
//   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co
//               --dart-define=SUPABASE_ANON_KEY=eyJ...
// Tanpa dua nilai ini aplikasi tetap jalan lokal (mode offline) dan
// menampilkan halaman petunjuk, bukan crash.
class BackendConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static bool get configured => url.isNotEmpty && anonKey.isNotEmpty;
}

// ---------- Auth: email + password via Supabase ----------
class AuthService extends ChangeNotifier {
  AuthService._(this._client) {
    _user = _client.auth.currentUser;
    _sub = _client.auth.onAuthStateChange.listen((data) {
      _user = data.session?.user;
      notifyListeners();
    });
  }

  final SupabaseClient _client;
  User? _user;
  StreamSubscription<AuthState>? _sub;

  /// Error init terakhir (null = belum pernah gagal). Tidak pernah throw:
  /// gagal init = kembali null agar runApp tetap jalan.
  static String? lastError;

  static Future<AuthService?> init() async {
    if (!BackendConfig.configured) return null;
    lastError = null;
    try {
      await Supabase.initialize(
        url: BackendConfig.url,
        publishableKey: BackendConfig.anonKey,
      ).timeout(const Duration(seconds: 15));
      return AuthService._(Supabase.instance.client);
    } catch (e) {
      lastError = e.toString().replaceFirst('Exception: ', '');
      return null;
    }
  }

  SupabaseClient get client => _client;
  bool get signedIn => _user != null;
  String? get email => _user?.email;

  /// null = sukses, string = pesan error untuk ditampilkan.
  Future<String?> signIn(String email, String password) async {
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal masuk. Cek koneksi internet kamu.';
    }
  }

  Future<String?> signUp(String email, String password) async {
    try {
      await _client.auth.signUp(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal daftar. Cek koneksi internet kamu.';
    }
  }

  Future<void> signOut() => _client.auth.signOut();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
