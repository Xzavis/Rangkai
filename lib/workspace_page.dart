import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'workspace.dart';
import 'widgets.dart';

// ---------- Kelola workspace: anggota, invite, pindah, buat, gabung ----------
class WorkspacePage extends StatefulWidget {
  const WorkspacePage({super.key, required this.ws});
  final WorkspaceService ws;
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  WorkspaceService get ws => widget.ws;
  final _name = TextEditingController();
  final _code = TextEditingController();
  String? _msg;

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
        return Scaffold(
          appBar: AppBar(title: const Text('Workspace')),
          body: ListView(
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
                      Navigator.pop(context);
                    },
                  ),
                ),
              const SizedBox(height: 16),
              if (active != null && !active.personal) ...[
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
                              m.userId == ws.myId ? 'Kamu' : 'Anggota ${m.userId.substring(0, 8)}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(m.role.name),
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
                      await Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Kode invite $code disalin. Bagikan ke teman.')),
                      );
                    },
                    child: const Text('Buat kode invite'),
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
                    Navigator.pop(context);
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
                    Navigator.pop(context);
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
          ),
        );
      },
    );
  }
}
