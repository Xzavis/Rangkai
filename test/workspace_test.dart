import 'package:cpi/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('owner bisa semua, member terbatas', () {
    for (final a in WsAction.values) {
      expect(Permissions.can(a, WsRole.owner), isTrue, reason: '$a');
    }
    expect(Permissions.can(WsAction.deleteWorkspace, WsRole.admin), isFalse);
    expect(Permissions.can(WsAction.manageMembers, WsRole.admin), isTrue);
    expect(Permissions.can(WsAction.managePlan, WsRole.admin), isTrue);
    expect(
        Permissions.can(WsAction.manageCheckpoints, WsRole.admin), isTrue);
    expect(Permissions.can(WsAction.deleteWorkspace, WsRole.member), isFalse);
    expect(Permissions.can(WsAction.manageMembers, WsRole.member), isFalse);
    expect(Permissions.can(WsAction.managePlan, WsRole.member), isFalse);
    expect(
        Permissions.can(WsAction.manageCheckpoints, WsRole.member), isFalse);
    expect(Permissions.can(WsAction.addRundown, WsRole.member), isTrue);
    expect(Permissions.can(WsAction.addTransaction, WsRole.member), isTrue);
  });

  test('kode invite 6 karakter tanpa huruf ambigu', () {
    final seen = <String>{};
    for (var i = 0; i < 50; i++) {
      final c = WorkspaceService.newCode();
      expect(c.length, 6);
      expect(RegExp(r'^[A-Z0-9]{6}$').hasMatch(c), isTrue);
      expect(c.contains(RegExp(r'[01OI]')), isFalse);
      seen.add(c);
    }
    expect(seen.length, greaterThan(45)); // praktis unik
  });
}
