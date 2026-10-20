import 'package:cpi/attendance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('headcount harus sama dengan jumlah anggota', () {
    expect(AttendanceRules.validateHeadcount(5, 5), isNull);
    expect(AttendanceRules.validateHeadcount(4, 5), isNotNull);
    expect(AttendanceRules.validateHeadcount(6, 5), isNotNull);
    expect(AttendanceRules.validateHeadcount(0, 5), isNotNull);
  });

  test('hanya perwakilan yang bisa submit bila sudah ditunjuk', () {
    // Belum ada perwakilan: admin/owner dulu.
    expect(
      AttendanceRules.canSubmit(isRep: false, repSet: false, isAdmin: true),
      isTrue,
    );
    expect(
      AttendanceRules.canSubmit(isRep: false, repSet: false, isAdmin: false),
      isFalse,
    );
    // Sudah ditunjuk: hanya dia.
    expect(
      AttendanceRules.canSubmit(isRep: true, repSet: true, isAdmin: false),
      isTrue,
    );
    expect(
      AttendanceRules.canSubmit(isRep: false, repSet: true, isAdmin: true),
      isFalse,
    );
  });

  test('checkpoint default: titik kumpul opsional', () {
    expect(AttendanceService.defaults.length, 4);
    expect(AttendanceService.defaults.first.$2, isFalse);
    expect(
      AttendanceService.defaults.skip(1).every((d) => d.$2),
      isTrue,
    );
  });
}
