import 'package:cpi/auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('init tidak throw dan tidak gantung saat backend belum dikonfigurasi', () async {
    // Tanpa --dart-define, configured == false dan init harus kembali null.
    expect(BackendConfig.configured, isFalse);
    final auth = await AuthService.init().timeout(const Duration(seconds: 10));
    expect(auth, isNull);
  });
}
