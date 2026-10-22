import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'absen.dart';
import 'core.dart';
import 'theme/tokens.dart';
import 'workspace.dart';
import 'widgets.dart';

// ---------- Kelola workspace: anggota, invite, pindah, buat, gabung ----------
/// Route mandiri (dari Pengaturan/ikon lama).
class WorkspacePage extends StatelessWidget {
  const WorkspacePage({super.key, required this.ws});
  final WorkspaceService ws;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Workspace')),
        body: WorkspaceContent(ws: ws),
      );
}

/// Konten tab Workspace. Saat jadi tab tidak membuat Scaffold/AppBar ganda
/// dan memilih workspace tidak mem-pop route.
class WorkspaceContent extends StatefulWidget {
  const WorkspaceContent({
    super.key,
    required this.ws,
    this.embedded = false,
    this.store,
    this.location,
  });
  final WorkspaceService ws;
  final bool embedded;

  /// Bila diberikan (tab Shell), kartu absen per-plan ref 09 ditampilkan.
  final Store? store;
  final LocationService? location;
  @override
  State<WorkspaceContent> createState() => _WorkspaceContentState();
}

/// Tab Workspace saat belum login/offline: penjelasan jujur + ajakan masuk,
/// tanpa anggota/kode fiktif dan tanpa memaksa service null.
class WorkspaceOfflineTab extends StatelessWidget {
  const WorkspaceOfflineTab({super.key, this.onLogin});
  final VoidCallback? onLogin;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          const EmptyState(
            icon: 'wallet',
            text: 'Workspace butuh akun dan koneksi backend. '
                'Mode offline tetap bisa pakai Beranda, Keuangan, Rencana, dan Kalender.',
          ),
          if (onLogin != null)
            CpiButton(onPressed: onLogin, child: const Text('Masuk')),
        ],
      );
}

class _WorkspaceContentState extends State<WorkspaceContent> {
  WorkspaceService get ws => widget.ws;
  final _name = TextEditingController();
  final _code = TextEditingController();
  String? _msg;
  String? _planId;

  @override
  void dispose() {
    _name.dispose();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AnimatedBuilder(
      animation: ws,
      builder: (context, _) {
        final active = ws.active;
        final role = ws.roleOfActive();
        final canManage = Permissions.can(WsAction.manageMembers, role);
        return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              if (ws.loading) const LinearProgressIndicator(),
              if (ws.error != null)
                Text(ws.error!, style: tt.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
              Text('Aktif', style: tt.titleSmall),
              const SizedBox(height: 8),
              for (final w in ws.spaces)
                CpiCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text('${w.personal ? 'Pribadi' : 'Komunitas'} · ${ws.roleOf(w.id).name}'),
                    trailing: w.id == active?.id
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : null,
                    onTap: () {
                      ws.select(w.id);
                      if (!widget.embedded) Navigator.pop(context);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              if (active != null && !active.personal) ...[
                FutureBuilder<String?>(
                  future: ws.currentInvite(autoCreateIfMissing: canManage),
                  builder: (context, snap) {
                    final code = snap.data;
                    return CpiCard(
                      padding: const EdgeInsets.all(CpiTokens.panelPadding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Kode undangan', style: tt.titleSmall),
                              const Spacer(),
                              if (code != null && canManage)
                                TextButton(
                                  onPressed: () async {
                                    final newCode = await ws.makeInvite();
                                    if (!context.mounted) return;
                                    if (newCode != null) {
                                      setState(() {});
                                      await Clipboard.setData(ClipboardData(text: newCode));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Kode invite $newCode disalin.')),
                                      );
                                    }
                                  },
                                  child: const Text('Buat baru', style: TextStyle(fontSize: 12)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (snap.connectionState == ConnectionState.waiting)
                            const LinearProgressIndicator()
                          else if (code != null)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    code,
                                    style: tt.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                ),
                                TextButton.icon(
                                  icon: const Icon(Icons.copy_outlined, size: 18),
                                  label: const Text('Salin'),
                                  onPressed: () async {
                                    await Clipboard.setData(ClipboardData(text: code));
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Kode invite disalin.')),
                                      );
                                    }
                                  },
                                ),
                              ],
                            )
                          else ...[
                            Text(
                              canManage
                                  ? 'Belum ada kode aktif. Buat kode untuk membagikan workspace ini.'
                                  : 'Belum ada kode aktif.',
                              style: tt.bodySmall,
                            ),
                            if (canManage) ...[
                              const SizedBox(height: 8),
                              CpiButton(
                                onPressed: () async {
                                  final newCode = await ws.makeInvite();
                                  if (!context.mounted) return;
                                  if (newCode == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(ws.error ?? 'Gagal bikin kode invite.')),
                                    );
                                    return;
                                  }
                                  setState(() {});
                                  await Clipboard.setData(ClipboardData(text: newCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Kode invite $newCode disalin. Bagikan hanya ke orang yang dipercaya.')),
                                  );
                                },
                                child: const Text('Buat kode undangan'),
                              ),
                            ],
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Bagikan hanya ke orang yang dipercaya. Kode dipakai lewat Gabung pakai kode.',
                            style: tt.bodySmall,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text('Anggota ${active.name}', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                FutureBuilder<List<Membership>>(
                  future: ws.members(),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return Column(
                      children: [
                        for (final m in snap.data!)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              m.userId == ws.myId
                                  ? 'Kamu'
                                  : (m.email ?? 'Anggota workspace'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(m.role.name),
                            leading: CircleAvatar(
                              child: Text(
                                (m.email?.isNotEmpty == true
                                        ? m.email![0]
                                        : m.userId.isEmpty
                                            ? '?'
                                            : m.userId[0])
                                    .toUpperCase(),
                              ),
                            ),
                            trailing: canManage && m.role != WsRole.owner
                                ? PopupMenuButton<WsRole>(
                                    icon: const Icon(Icons.more_vert),
                                    onSelected: (r) => ws.setRole(m.userId, r).then((e) {
                                      if (e != null && context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
                                      }
                                      setState(() {});
                                    }),
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(value: WsRole.admin, child: Text('Jadikan admin')),
                                      const PopupMenuItem(value: WsRole.member, child: Text('Jadikan member')),
                                    ],
                                  )
                                : null,
                          ),
                      ],
                    );
                  },
                ),
                if (canManage) ...[
                  const SizedBox(height: 12),
                  CpiButton(
                    onPressed: () async {
                      final code = await ws.makeInvite();
                      if (!context.mounted) return;
                      if (code == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(ws.error ?? 'Gagal bikin kode invite.')),
                        );
                        return;
                      }
                      setState(() {});
                      await Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Kode invite $code disalin. Bagikan hanya ke orang yang dipercaya.')),
                      );
                    },
                    child: const Text('Buat kode baru'),
                  ),
                ],
              ],
              if (widget.store != null && widget.location != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Absen tim per rencana',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Titik kumpul dan perwakilan terikat rencana yang dipilih.',
                  style: tt.bodySmall,
                ),
                const SizedBox(height: 8),
                if (widget.store!.plans.isEmpty)
                  Text(
                    'Belum ada rencana. Buat rencana dulu di tab Rencana.',
                    style: tt.bodySmall,
                  )
                else ...[
                  DropdownButtonFormField<String>(
                    initialValue: _planId ?? widget.store!.plans.first.id,
                    decoration: const InputDecoration(
                      labelText: 'Rencana',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final p in widget.store!.plans)
                        DropdownMenuItem(value: p.id, child: Text(p.title)),
                    ],
                    onChanged: (v) => setState(() => _planId = v),
                  ),
                  const SizedBox(height: 8),
                  CheckpointSection(
                    key: ValueKey(
                      (widget.store!.plans
                              .where((p) => p.id == _planId)
                              .firstOrNull ??
                          widget.store!.plans.first)
                          .id,
                    ),
                    plan: widget.store!.plans
                            .where((p) => p.id == _planId)
                            .firstOrNull ??
                        widget.store!.plans.first,
                    location: widget.location!,
                    ws: ws,
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Text('Buat workspace komunitas', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              CpiField(controller: _name, label: 'Nama workspace', hint: 'Misal: Trip Bandung'),
              const SizedBox(height: 8),
              CpiButton(
                onPressed: () async {
                  if (_name.text.trim().isEmpty) return;
                  final e = await ws.create(_name.text);
                  if (!context.mounted) return;
                  if (e == null) {
                    _name.clear();
                    if (!widget.embedded) Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e)));
                  }
                },
                child: const Text('Buat'),
              ),
              const SizedBox(height: 24),
              Text('Gabung pakai kode', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              CpiField(
                controller: _code,
                label: 'Kode invite',
                hint: '6 karakter',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {},
              ),
              const SizedBox(height: 8),
              CpiButton(
                secondary: true,
                onPressed: () async {
                  final e = await ws.join(_code.text);
                  if (!context.mounted) return;
                  if (e == null) {
                    if (!widget.embedded) Navigator.pop(context);
                  } else {
                    setState(() => _msg = e);
                  }
                },
                child: const Text('Gabung'),
              ),
              if (_msg != null) ...[
                const SizedBox(height: 8),
                Text(_msg!, style: tt.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error)),
              ],
            ],
        );
      },
    );
  }
}
