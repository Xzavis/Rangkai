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
      'Password minimal 6 karakter.',
    );
  });
}
