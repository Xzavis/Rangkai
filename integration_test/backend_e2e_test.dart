import 'package:cpi/auth.dart';
import 'package:cpi/sync.dart';
import 'package:cpi/core.dart';
import 'package:cpi/workspace.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// E2E backend LIVE (butuh proyek Supabase beneran + migrasi 001-003 jalan;
// 004/005 untuk kategori/endDate + invite expiry):
//
//   flutter test integration_test/backend_e2e_test.dart -d emulator-5554 \
//     --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<anon/publishable>
//
// Alur: signup A -> login -> workspace pribadi otomatis -> buat komunitas
// -> kode invite -> signup/login B -> join_with_code -> B lihat workspace
// -> sync transaksi A terbaca B. Tanpa define, test ini SKIP dengan pesan.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('backend: signup/login/share workspace sampai join',
      (tester) async {
    if (!BackendConfig.hasValues) {
      // ignore: avoid_print
      print('SKIP backend E2E: SUPABASE_URL/SUPABASE_ANON_KEY belum diisi.');
      return;
    }
    expect(BackendConfig.configured, isTrue,
        reason: 'URL harus https & key bukan service_role');

    final auth = await AuthService.init();
    expect(auth, isNotNull, reason: 'init gagal: ${AuthService.lastError}');
    final client = auth!.client;
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final emailA = 'rangkai.e2e.a+$stamp@example.com';
    final emailB = 'rangkai.e2e.b+$stamp@example.com';
    const password = 'RangkaiE2E2026!';

    // --- Signup + login A ---
    final upA = await auth.signUpDetailed(emailA, password);
    expect(upA.error, isNull, reason: 'signup A gagal');
    expect(upA.needsConfirmation, isFalse,
        reason:
            'Proyek mewajibkan konfirmasi email; matikan Confirm email '
            'di Supabase Auth settings atau pakai akun terkonfirmasi.');
    if (!auth.signedIn) {
      expect(await auth.signIn(emailA, password), isNull);
    }
    expect(auth.signedIn, isTrue);
    expect(auth.email, emailA.toLowerCase());

    // --- Workspace pribadi otomatis + buat komunitas ---
    final wsA = WorkspaceService(client);
    await wsA.load();
    expect(wsA.spaces.isNotEmpty, isTrue,
        reason: 'workspace pribadi otomatis tidak terbentuk (trigger 001?)');
    final createErr = await wsA.create('E2E Komunitas $stamp');
    expect(createErr, isNull, reason: 'buat workspace gagal');
    expect(wsA.active, isNotNull);
    expect(wsA.active!.personal, isFalse);
    final communityId = wsA.active!.id;

    // --- Invite ---
    final code = await wsA.makeInvite();
    expect(code, isNotNull, reason: wsA.error ?? 'makeInvite gagal');
    expect(code, matches(RegExp(r'^[A-Z0-9]{6}$')));
    expect(await wsA.currentInvite(), code);

    // --- Sync: A tulis transaksi ke komunitas ---
    final syncA = CloudSync(client, communityId);
    final push = await syncA.insertTx(
      Tx(
        id: 'local',
        title: 'E2E transaksi A',
        amount: -25000,
        date: DateTime.now(),
        category: 'Makan',
        note: 'dari A',
      ),
    );
    expect(push.error, isNull, reason: 'insertTx A gagal');

    await auth.signOut();
    expect(auth.signedIn, isFalse);

    // --- Signup + login B, join pakai kode ---
    final upB = await auth.signUpDetailed(emailB, password);
    expect(upB.error, isNull, reason: 'signup B gagal');
    expect(upB.needsConfirmation, isFalse);
    if (!auth.signedIn) {
      expect(await auth.signIn(emailB, password), isNull);
    }
    final wsB = WorkspaceService(client);
    await wsB.load();
    final joinErr = await wsB.join(code!);
    expect(joinErr, isNull, reason: 'join_with_code gagal');
    expect(wsB.spaces.any((w) => w.id == communityId), isTrue,
        reason: 'B tidak melihat workspace hasil share');
    wsB.select(communityId);
    expect(wsB.roleOfActive(), WsRole.member);

    // --- B membaca transaksi A lewat pull ---
    final storeB = Store();
    final syncB = CloudSync(client, communityId);
    final pullErr = await syncB.pull(storeB);
    expect(pullErr, isNull, reason: 'pull B gagal');
    expect(
      storeB.txs.any((t) => t.title == 'E2E transaksi A' && t.amount == -25000),
      isTrue,
      reason: 'transaksi A tidak terbaca B',
    );

    // --- Login ulang A membuktikan sesi/kredensial valid ---
    await auth.signOut();
    expect(await auth.signIn(emailA, password), isNull);
    expect(auth.signedIn, isTrue);

    // Cleanup sebisa RLS: owner hapus workspace komunitas E2E.
    try {
      await client.from('workspaces').delete().eq('id', communityId);
    } catch (_) {
      // Biarkan bila policy menolak; akun & workspace test berawalan E2E.
    }
    await auth.signOut();
    wsA.dispose();
    wsB.dispose();
    storeB.dispose();
    auth.dispose();
  });
}
