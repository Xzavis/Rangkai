import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------- Konfigurasi backend (tidak di-commit) ----------
// Jalanin dengan:
//   flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co
//               --dart-define=SUPABASE_ANON_KEY=eyJ...
// Tanpa dua nilai ini aplikasi tetap jalan lokal (mode offline) dan
// menampilkan halaman petunjuk, bukan crash.
//
// Keamanan: yang boleh masuk build HP HANYA anon/publishable key.
// service_role key menembus RLS; bila terdeteksi, init DITOLAK agar
// kunci itu tidak ikut tersebar di APK.
class BackendConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// URL harus https (http hanya untuk localhost saat debug).
  static bool urlValid(String value) {
    final u = Uri.tryParse(value.trim());
    if (u == null || u.host.isEmpty) return false;
    if (u.scheme == 'https') return true;
    return kDebugMode &&
        u.scheme == 'http' &&
        (u.host == 'localhost' || u.host == '127.0.0.1');
  }

  /// Baca klaim `role` dari JWT tanpa verifikasi signature (cukup untuk
  /// menolak service_role; bukan pengganti verifikasi server).
  static bool isServiceRoleKey(String key) {
    // Format kunci baru Supabase: sb_secret_... setara service_role,
    // wajib ditolak sama seperti JWT service_role (fail-closed).
    if (key.trim().startsWith('sb_secret_')) return true;
    final parts = key.trim().split('.');
    if (parts.length != 3) return false;
    try {
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = jsonDecode(utf8.decode(base64.decode(payload)));
      return decoded is Map && decoded['role'] == 'service_role';
    } catch (_) {
      return false;
    }
  }

  static bool get configured =>
      url.isNotEmpty &&
      anonKey.isNotEmpty &&
      urlValid(url) &&
      !isServiceRoleKey(anonKey);

  /// Ada nilai dart-define (valid atau tidak) — untuk membedakan
  /// "belum diisi" dari "diisi tapi ditolak/gagal init".
  static bool get hasValues => url.isNotEmpty && anonKey.isNotEmpty;
}

// ---------- Validasi kredensial (murni, dites) ----------
abstract final class AuthValidators {
  static String normalizeEmail(String raw) => raw.trim().toLowerCase();

  static String? emailError(String raw) {
    final email = normalizeEmail(raw);
    if (email.isEmpty) return 'Email wajib diisi.';
    if (email.length > 254) return 'Email terlalu panjang.';
    if (email.contains(RegExp(r'\s'))) return 'Email tidak boleh ada spasi.';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$').hasMatch(email);
    return ok ? null : 'Format email belum benar. Contoh: kamu@email.com';
  }

  /// Aturan daftar (login tidak memaksakan ini agar akun lama tetap masuk):
  /// 8-72 karakter (batas bcrypt), ada huruf dan angka.
  static String? signupPasswordError(String password) {
    if (password.length < 8) return 'Password minimal 8 karakter.';
    if (password.length > 72) return 'Password maksimal 72 karakter.';
    if (!password.contains(RegExp(r'[A-Za-z]')) ||
        !password.contains(RegExp(r'[0-9]'))) {
      return 'Password harus ada huruf dan angka.';
    }
    return null;
  }

  /// 0 kosong, 1 lemah, 2 sedang, 3 kuat — untuk meter di form daftar.
  static int passwordStrength(String password) {
    if (password.isEmpty) return 0;
    var score = 1;
    if (password.length >= 8 &&
        password.contains(RegExp(r'[A-Za-z]')) &&
        password.contains(RegExp(r'[0-9]'))) {
      score = 2;
    }
    if (password.length >= 12 &&
        password.contains(RegExp(r'[A-Z]')) &&
        password.contains(RegExp(r'[a-z]')) &&
        password.contains(RegExp(r'[0-9]')) &&
        password.contains(RegExp(r'[^A-Za-z0-9]'))) {
      score = 3;
    }
    return score;
  }

  static String strengthLabel(int s) => switch (s) {
        0 => '',
        1 => 'Lemah',
        2 => 'Sedang',
        _ => 'Kuat',
      };
}

typedef SignUpResult = ({String? error, bool needsConfirmation});

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

  /// Error init terakhir untuk diagnostik. UI hanya menampilkannya
  /// pada build debug; rilis cukup pesan umum.
  static String? lastError;

  static Future<AuthService?> init() async {
    if (BackendConfig.url.isEmpty || BackendConfig.anonKey.isEmpty) {
      return null;
    }
    lastError = null;
    if (BackendConfig.isServiceRoleKey(BackendConfig.anonKey)) {
      lastError = 'Kunci backend ditolak: service_role tidak boleh di aplikasi.';
      return null;
    }
    if (!BackendConfig.urlValid(BackendConfig.url)) {
      lastError = 'URL backend harus https.';
      return null;
    }
    try {
      try {
        return AuthService._(Supabase.instance.client);
      } catch (_) {
        // Belum diinisialisasi
      }
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

  /// Stream auth bisa telat; samakan _user dari SDK secara sinkron
  /// setelah operasi auth agar signedIn tidak basi bagi pemanggil.
  void _syncUser() {
    _user = _client.auth.currentUser;
    notifyListeners();
  }

  static String translateAuthError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('invalid login credentials')) {
      // Sengaja umum: tidak membocorkan email terdaftar atau tidak.
      return 'Email atau password salah.';
    }
    if (lower.contains('email not confirmed')) {
      return 'Email belum dikonfirmasi. Cek inbox email kamu.';
    }
    if (lower.contains('user already registered') ||
        lower.contains('already exists')) {
      return 'Email ini sudah terdaftar. Silakan masuk.';
    }
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Terlalu banyak percobaan. Tunggu beberapa saat.';
    }
    if (lower.contains('password should be at least') ||
        lower.contains('password is too short')) {
      return 'Password terlalu pendek. Pakai minimal 8 karakter.';
    }
    if (lower.contains('invalid email') ||
        lower.contains('unable to validate email')) {
      return 'Format email belum benar.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Gagal tersambung. Cek koneksi internet kamu.';
    }
    // Pesan server lain tidak ditampilkan mentah ke user.
    return 'Terjadi kendala saat masuk. Coba lagi sebentar.';
  }

  /// null = sukses, string = pesan error untuk ditampilkan.
  Future<String?> signIn(String email, String password) async {
    final emailErr = AuthValidators.emailError(email);
    if (emailErr != null) return emailErr;
    if (password.isEmpty) return 'Password wajib diisi.';
    try {
      await _client.auth
          .signInWithPassword(
            email: AuthValidators.normalizeEmail(email),
            password: password,
          )
          .timeout(const Duration(seconds: 15));
      _syncUser();
      return null;
    } on AuthException catch (e) {
      return translateAuthError(e.message);
    } on TimeoutException {
      return 'Koneksi timeout (15 detik). Cek internet kamu.';
    } catch (_) {
      return 'Gagal masuk. Cek koneksi internet kamu.';
    }
  }

  Future<SignUpResult> signUpDetailed(String email, String password) async {
    final emailErr = AuthValidators.emailError(email);
    if (emailErr != null) return (error: emailErr, needsConfirmation: false);
    final pwErr = AuthValidators.signupPasswordError(password);
    if (pwErr != null) return (error: pwErr, needsConfirmation: false);
    try {
      final res = await _client.auth
          .signUp(
            email: AuthValidators.normalizeEmail(email),
            password: password,
          )
          .timeout(const Duration(seconds: 15));
      // Tanpa session = menunggu konfirmasi email. identities kosong =
      // email sudah ada (Supabase menyamarkannya); perlakukan sama agar
      // tidak membocorkan akun terdaftar.
      final needs = res.session == null ||
          (res.user?.identities?.isEmpty ?? false);
      _syncUser();
      return (error: null, needsConfirmation: needs);
    } on AuthException catch (e) {
      return (error: translateAuthError(e.message), needsConfirmation: false);
    } on TimeoutException {
      return (
        error: 'Koneksi timeout (15 detik). Cek internet kamu.',
        needsConfirmation: false,
      );
    } catch (_) {
      return (
        error: 'Gagal daftar. Cek koneksi internet kamu.',
        needsConfirmation: false,
      );
    }
  }

  Future<String?> signUp(String email, String password) async =>
      (await signUpDetailed(email, password)).error;

  /// Reset password. Sukses selalu dilaporkan generik oleh pemanggil;
  /// di sini hanya rate-limit/timeout yang dibedakan.
  Future<String?> resetPassword(String email) async {
    final emailErr = AuthValidators.emailError(email);
    if (emailErr != null) return emailErr;
    try {
      await _client.auth
          .resetPasswordForEmail(AuthValidators.normalizeEmail(email))
          .timeout(const Duration(seconds: 15));
      return null;
    } on AuthException catch (e) {
      final lower = e.message.toLowerCase();
      if (lower.contains('rate limit') || lower.contains('too many')) {
        return 'Terlalu banyak percobaan. Tunggu beberapa saat.';
      }
      return null; // generik: jangan bocorkan status akun
    } on TimeoutException {
      return 'Koneksi timeout (15 detik). Cek internet kamu.';
    } catch (_) {
      return 'Gagal tersambung. Cek koneksi internet kamu.';
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Sesi lokal tetap dibersihkan SDK pada panggilan signOut;
      // kegagalan jaringan tidak boleh mengunci user di dalam sesi.
    }
    _syncUser();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
