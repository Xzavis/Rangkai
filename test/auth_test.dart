import 'dart:convert';

import 'package:cpi/auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('init tidak throw dan tidak gantung saat backend belum dikonfigurasi', () async {
    // Tanpa --dart-define, configured == false dan init harus kembali null.
    expect(BackendConfig.configured, isFalse);
    final auth = await AuthService.init().timeout(const Duration(seconds: 10));
    expect(auth, isNull);
  });

  test('translateAuthError mengembalikan pesan ramah bahasa Indonesia', () {
    expect(
      AuthService.translateAuthError('Invalid login credentials'),
      'Email atau password salah.',
    );
    expect(
      AuthService.translateAuthError('Email not confirmed'),
      'Email belum dikonfirmasi. Cek inbox email kamu.',
    );
    expect(
      AuthService.translateAuthError('User already registered'),
      'Email ini sudah terdaftar. Silakan masuk.',
    );
    expect(
      AuthService.translateAuthError('Password should be at least 6 characters'),
      'Password terlalu pendek. Pakai minimal 8 karakter.',
    );
    // Pesan server tak dikenal tidak bocor mentah ke user.
    expect(
      AuthService.translateAuthError('weird internal pg error xyz'),
      'Terjadi kendala saat masuk. Coba lagi sebentar.',
    );
  });

  test('validator email & password daftar', () {
    expect(AuthValidators.emailError('  Kamu@Email.COM '), isNull);
    expect(AuthValidators.normalizeEmail('  Kamu@Email.COM '), 'kamu@email.com');
    expect(AuthValidators.emailError('bukan-email'), isNotNull);
    expect(AuthValidators.emailError('a b@c.com'), isNotNull);
    expect(AuthValidators.signupPasswordError('pendek1'), isNotNull);
    expect(AuthValidators.signupPasswordError('hanyahurufsaja'), isNotNull);
    expect(AuthValidators.signupPasswordError('12345678'), isNotNull);
    expect(AuthValidators.signupPasswordError('rahasia123'), isNull);
    expect(AuthValidators.passwordStrength(''), 0);
    expect(AuthValidators.passwordStrength('rahasia123'), 2);
    expect(AuthValidators.passwordStrength('Rahasia!12345'), 3);
  });

  test('backend menolak service_role & URL non-https', () {
    // JWT alg-none palsu dengan role service_role / anon (bukan kunci asli).
    String jwt(String role) {
      String seg(String json) =>
          base64Url.encode(utf8.encode(json)).replaceAll('=', '');
      return '${seg('{"alg":"none"}')}.${seg('{"role":"$role"}')}.sig';
    }

    expect(BackendConfig.isServiceRoleKey(jwt('service_role')), isTrue);
    expect(BackendConfig.isServiceRoleKey(jwt('anon')), isFalse);
    expect(BackendConfig.isServiceRoleKey('sb_publishable_xyz'), isFalse);
    expect(BackendConfig.isServiceRoleKey('sb_secret_xyz'), isTrue);
    expect(BackendConfig.isServiceRoleKey('  sb_secret_xyz  '), isTrue);
    expect(BackendConfig.urlValid('https://xyz.supabase.co'), isTrue);
    expect(BackendConfig.urlValid('http://xyz.supabase.co'), isFalse);
    expect(BackendConfig.urlValid('bukan url'), isFalse);
  });
}
