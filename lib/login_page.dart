import 'package:flutter/foundation.dart';
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
          : ConfigMissingPage(onOffline: onOffline);
    }
    return AnimatedBuilder(
      animation: auth!,
      builder: (context, _) =>
          auth!.signedIn ? child : LoginPage(auth: auth!, onOffline: onOffline),
    );
  }
}

class _AuthShell extends StatelessWidget {
  const _AuthShell({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const CPIcon('wallet', size: 48),
                    const SizedBox(height: 8),
                    Text(
                      'RANGKAI',
                      textAlign: TextAlign.center,
                      style: tt.labelLarge?.copyWith(
                        letterSpacing: 3,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      style: tt.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    ...children,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
    final detail = kDebugMode ? AuthService.lastError : null;
    return _AuthShell(
      title: 'Tidak tersambung ke server',
      children: [
        Text(
          detail == null
              ? 'Cek internet kamu lalu coba lagi. Data lokal tetap bisa dipakai offline.'
              : 'Cek internet kamu lalu coba lagi.\nDetail (debug): $detail',
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        CpiButton(
          busy: busy,
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
    );
  }
}

/// Ditampilkan saat SUPABASE_URL / SUPABASE_ANON_KEY belum diisi.
/// Mode lokal tetap bisa dipakai lewat Lanjut offline; halaman ini
/// hanya petunjuk, bukan jalan buntu permanen.
class ConfigMissingPage extends StatelessWidget {
  const ConfigMissingPage({super.key, this.onOffline});
  final VoidCallback? onOffline;
  @override
  Widget build(BuildContext context) {
    const cmd = 'flutter run --dart-define=SUPABASE_URL=https://xyz.supabase.co '
        '--dart-define=SUPABASE_ANON_KEY=eyJ...';
    return _AuthShell(
      title: 'Backend belum disambung',
      children: [
        const Text(
          'Isi SUPABASE_URL dan SUPABASE_ANON_KEY (anon/publishable, bukan service_role) lalu jalanin ulang:',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        CpiCard(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: SelectableText(cmd, style: TextStyle(fontSize: 12)),
              ),
              IconButton(
                tooltip: 'Salin perintah',
                icon: const Icon(Icons.copy_outlined, size: 19),
                onPressed: () {
                  Clipboard.setData(const ClipboardData(text: cmd));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Perintah disalin.')),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        CpiButton(
          secondary: true,
          onPressed: onOffline,
          child: const Text('Lanjut offline (data lokal)'),
        ),
      ],
    );
  }
}

// ---------- Login / daftar ----------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.auth, this.onOffline});
  final AuthService auth;
  final VoidCallback? onOffline;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  var _signup = false;
  var _busy = false;
  String? _error, _info, _emailErr, _pwErr, _confirmErr;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _toggleMode() => setState(() {
        _signup = !_signup;
        _error = null;
        _info = null;
        _emailErr = null;
        _pwErr = null;
        _confirmErr = null;
        // Password tidak dibawa lintas mode.
        _password.clear();
        _confirm.clear();
      });

  Future<void> _go() async {
    if (_busy) return; // anti submit ganda (tombol + Enter bersamaan)
    final emailErr = AuthValidators.emailError(_email.text);
    final pwErr = _signup
        ? AuthValidators.signupPasswordError(_password.text)
        : (_password.text.isEmpty ? 'Password wajib diisi.' : null);
    final confirmErr = _signup && _confirm.text != _password.text
        ? 'Konfirmasi password tidak sama.'
        : null;
    setState(() {
      _emailErr = emailErr;
      _pwErr = pwErr;
      _confirmErr = confirmErr;
      _error = null;
      _info = null;
    });
    if (emailErr != null || pwErr != null || confirmErr != null) return;
    setState(() => _busy = true);
    if (_signup) {
      final res = await widget.auth.signUpDetailed(_email.text, _password.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = res.error;
        _info = res.error == null
            ? (res.needsConfirmation
                ? 'Akun dibuat. Cek inbox email kamu buat konfirmasi, lalu masuk.'
                : 'Akun dibuat. Selamat datang di Rangkai.')
            : null;
        if (res.error == null && res.needsConfirmation) {
          _signup = false;
          _password.clear();
          _confirm.clear();
        }
      });
    } else {
      final err = await widget.auth.signIn(_email.text, _password.text);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err;
        if (err != null) _password.clear();
      });
    }
    if ((_error == null) && mounted) {
      TextInput.finishAutofillContext(shouldSave: true);
    }
  }

  Future<void> _forgot() async {
    if (_busy) return;
    final emailErr = AuthValidators.emailError(_email.text);
    setState(() {
      _emailErr = emailErr;
      _error = null;
      _info = null;
    });
    if (emailErr != null) return;
    setState(() => _busy = true);
    final err = await widget.auth.resetPassword(_email.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
      _info = err == null
          ? 'Kalau email itu terdaftar, tautan atur ulang password sudah dikirim. Cek inbox kamu.'
          : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final strength = AuthValidators.passwordStrength(_password.text);
    return _AuthShell(
      title: _signup ? 'Bikin akun Rangkai' : 'Masuk ke Rangkai',
      children: [
        Text(
          _signup
              ? 'Satu akun untuk workspace dan rencana kamu.'
              : 'Kelola keuangan dan rencana bersama.',
          style: tt.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        CpiField(
          controller: _email,
          label: 'Email',
          hint: 'kamu@email.com',
          error: _emailErr,
          enabled: !_busy,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
          autocorrect: false,
          onChanged: (_) {
            if (_emailErr != null) setState(() => _emailErr = null);
          },
        ),
        const SizedBox(height: 12),
        FTextField.password(
          control: .managed(
            controller: _password,
            onChange: (_) => setState(() => _pwErr = null),
          ),
          label: const Text('Password'),
          hint: _signup ? 'Minimal 8 karakter, huruf + angka' : 'Password kamu',
          description: _signup
              ? const Text('Minimal 8 karakter dengan huruf dan angka.')
              : null,
          error: _pwErr == null ? null : Text(_pwErr!),
          enabled: !_busy,
          autofillHints: [
            _signup ? AutofillHints.newPassword : AutofillHints.password,
          ],
          textInputAction: _signup ? TextInputAction.next : TextInputAction.done,
          onSubmit: (_) {
            if (!_signup) _go();
          },
        ),
        if (_signup) ...[
          if (_password.text.isNotEmpty) ...[
            const SizedBox(height: 8),
            Semantics(
              label: 'Kekuatan password: ${AuthValidators.strengthLabel(strength)}',
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: strength / 3,
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(6),
                      color: switch (strength) {
                        1 => cs.error,
                        2 => cs.tertiary,
                        _ => cs.primary,
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AuthValidators.strengthLabel(strength),
                    style: tt.bodySmall,
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          FTextField.password(
            control: .managed(
              controller: _confirm,
              onChange: (_) => setState(() => _confirmErr = null),
            ),
            label: const Text('Ulangi password'),
            hint: 'Ketik ulang password',
            error: _confirmErr == null ? null : Text(_confirmErr!),
            enabled: !_busy,
            autofillHints: const [AutofillHints.newPassword],
            textInputAction: TextInputAction.done,
            onSubmit: (_) => _go(),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              style: tt.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ],
        if (_info != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Text(
              _info!,
              style: tt.bodyMedium?.copyWith(color: cs.primary),
            ),
          ),
        ],
        const SizedBox(height: 20),
        CpiButton(
          busy: _busy,
          onPressed: _busy ? null : _go,
          child: Text(_busy ? 'Tunggu...' : _signup ? 'Daftar' : 'Masuk'),
        ),
        const SizedBox(height: 8),
        CpiButton(
          secondary: true,
          onPressed: _busy ? null : _toggleMode,
          child: Text(
            _signup ? 'Sudah punya akun? Masuk' : 'Belum punya akun? Daftar',
          ),
        ),
        if (!_signup)
          TextButton(
            onPressed: _busy ? null : _forgot,
            child: const Text('Lupa password?'),
          ),
        if (widget.onOffline != null) ...[
          const Divider(height: 24),
          TextButton(
            onPressed: _busy ? null : widget.onOffline,
            child: const Text('Lanjut offline (data lokal)'),
          ),
          Text(
            'Mode offline menyimpan data hanya di perangkat ini dan tetap butuh GPS aktif.',
            style: tt.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Rangkai v4.0.0',
          style: tt.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
