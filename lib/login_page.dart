import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forui/forui.dart' show FTextField;

import 'auth.dart';
import 'widgets.dart';

// ---------- Gerbang: config -> login -> aplikasi ----------
// initFailed = backend dikonfigurasi tapi init gagal (offline/URL salah).
// Bedakan dari config kosong agar pesannya jujur + ada tombol aksi.
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.auth,
    required this.child,
    this.initFailed = false,
    this.offline = false,
    this.busy = false,
    this.onRetry,
    this.onOffline,
  });
  final AuthService? auth;
  final Widget child;
  final bool initFailed, offline, busy;
  final VoidCallback? onRetry, onOffline;

  @override
  Widget build(BuildContext context) {
    if (offline) return child;
    if (auth == null) {
      return initFailed
          ? BackendGagalPage(busy: busy, onRetry: onRetry, onOffline: onOffline)
          : const ConfigMissingPage();
    }
    return AnimatedBuilder(
      animation: auth!,
      builder: (context, _) =>
          auth!.signedIn ? child : LoginPage(auth: auth!),
    );
  }
}

/// Ditampilkan saat init Supabase gagal (HP offline, URL/key salah).
/// Selalu ada jalan keluar: coba lagi atau lanjut offline.
class BackendGagalPage extends StatelessWidget {
  const BackendGagalPage({super.key, this.busy = false, this.onRetry, this.onOffline});
  final bool busy;
  final VoidCallback? onRetry, onOffline;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CPIcon('wallet', size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Tidak tersambung ke server',
                    style: tt.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AuthService.lastError == null
                        ? 'Cek internet kamu lalu coba lagi.'
                        : 'Cek internet kamu lalu coba lagi.\nDetail: ${AuthService.lastError}',
                    style: tt.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  CpiButton(
                    onPressed: busy ? null : onRetry,
                    child: Text(busy ? 'Menyambung...' : 'Coba lagi'),
                  ),
                  const SizedBox(height: 8),
                  CpiButton(
                    secondary: true,
                    onPressed: busy ? null : onOffline,
                    child: const Text('Lanjut offline (data lokal)'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ditampilkan saat SUPABASE_URL / SUPABASE_ANON_KEY belum diisi.
/// Mode lokal tetap bisa dipakai setelah backend dikonfigurasi; halaman ini
/// hanya petunjuk, bukan jalan buntu permanen.
class ConfigMissingPage extends StatelessWidget {
  const ConfigMissingPage({super.key});
  @override
  Widget build(BuildContext context) {
    const cmd = 'flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co '
        '--dart-define=SUPABASE_ANON_KEY=eyJ...';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CPIcon('wallet', size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Backend belum disambung',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Isi SUPABASE_URL dan SUPABASE_ANON_KEY lalu jalanin ulang:',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  CpiCard(
                    child: Row(
                      children: [
                        const Expanded(
                          child: SelectableText(cmd,
                              style: TextStyle(fontSize: 12)),
                        ),
                        IconButton(
                          tooltip: 'Salin perintah',
                          icon: const Icon(Icons.copy_outlined, size: 19),
                          onPressed: () {
                            Clipboard.setData(
                                const ClipboardData(text: cmd));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Perintah disalin.')),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Login / daftar ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth});
  final AuthService auth;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  var _signup = false;
  var _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    if (_email.text.trim().isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'Isi email dan password dulu.');
      return;
    }
    if (_password.text.length < 6) {
      setState(() => _error = 'Password minimal 6 karakter.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = _signup
        ? await widget.auth.signUp(_email.text, _password.text)
        : await widget.auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const CPIcon('wallet', size: 48),
                  const SizedBox(height: 16),
                  Text(
                    _signup ? 'Bikin akun Rangkai' : 'Masuk ke Rangkai',
                    style: tt.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Semua terangkai. Satu akun untuk workspace pribadi dan komunitas.',
                    style: tt.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  CpiField(
                    controller: _email,
                    label: 'Email',
                    hint: 'kamu@email.com',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  FTextField.password(
                    control: .managed(controller: _password),
                    label: const Text('Password'),
                    hint: 'Minimal 6 karakter',
                    onSubmit: (_) => _go(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: tt.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  CpiButton(
                    onPressed: _busy ? null : _go,
                    child: Text(_busy
                        ? 'Tunggu...'
                        : _signup
                            ? 'Daftar'
                            : 'Masuk'),
                  ),
                  const SizedBox(height: 8),
                  CpiButton(
                    secondary: true,
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _signup = !_signup;
                              _error = null;
                            }),
                    child: Text(_signup
                        ? 'Sudah punya akun? Masuk'
                        : 'Belum punya akun? Daftar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
