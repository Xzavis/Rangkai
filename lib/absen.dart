import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'attendance.dart';
import 'core.dart';
import 'workspace.dart';
import 'widgets.dart';

// ---------- Seksi absen di dalam PlanDetailPage ----------
class CheckpointSection extends StatefulWidget {
  const CheckpointSection({super.key, required this.plan, required this.location, required this.ws});
  final Plan plan;
  final LocationService location;
  final WorkspaceService? ws;
  @override
  State<CheckpointSection> createState() => _CheckpointSectionState();
}

class _CheckpointSectionState extends State<CheckpointSection> {
  List<Checkpoint>? _cps;
  List<Membership> _members = [];
  String? _repId;
  var _loading = true;

  AttendanceService? get _svc =>
      widget.ws == null ? null : AttendanceService(widget.ws!.client);

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final svc = _svc;
    if (svc == null) {
      setState(() => _loading = false);
      return;
    }
    final role = widget.ws!.roleOfActive();
    if (Permissions.can(WsAction.manageCheckpoints, role)) {
      await svc.ensureDefaults(widget.plan.id);
    }
    final cps = await svc.load(widget.plan.id);
    final members = await widget.ws!.members();
    final rep = await svc.getRep(widget.plan.id);
    if (!mounted) return;
    setState(() {
      _cps = cps;
      _members = members;
      _repId = rep;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    if (widget.ws == null) {
      return CpiCard(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Absen tim aktif setelah masuk + workspace tersambung.',
            style: tt.bodyMedium,
          ),
        ),
      );
    }
    if (_loading) return const LinearProgressIndicator();
    final cps = _cps ?? [];
    final role = widget.ws!.roleOfActive();
    final myId = widget.ws!.myId;
    final iAmRep = _repId != null && _repId == myId;
    final canSubmit = AttendanceRules.canSubmit(
      isRep: iAmRep,
      repSet: _repId != null,
      isAdmin: Permissions.can(WsAction.manageCheckpoints, role),
    );
    return CpiCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Absen tim',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  '${cps.where((c) => c.done).length}/${cps.length}',
                  style: tt.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _repId == null
                  ? 'Belum ada perwakilan. Admin tunjuk satu anggota.'
                  : iAmRep
                      ? 'Kamu perwakilan absen tim ini.'
                      : 'Perwakilan: ${_short(_repId!)}',
              style: tt.bodySmall,
            ),

            const SizedBox(height: 12),
            for (final cp in cps) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  cp.done ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: cp.done
                      ? Colors.green
                      : Theme.of(context).colorScheme.outline,
                ),
                title: Text(cp.name),
                subtitle: Text(
                  cp.done
                      ? '${cp.record!.headcount} orang · ${cp.record!.lat.toStringAsFixed(5)}, ${cp.record!.lng.toStringAsFixed(5)}'
                      : '${cp.required ? 'Wajib' : 'Opsional'} · belum absen',
                ),
                trailing: !cp.done && canSubmit
                    ? CpiButton(
                        onPressed: () async {
                          final ok = await showModalBottomSheet<bool>(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (_) => AbsenSheet(
                              cp: cp,
                              svc: _svc!,
                              location: widget.location,
                              memberCount: _members.length,
                            ),
                          );
                          if (ok == true) _reload();
                        },
                        child: const Text('Absen'),
                      )
                    : null,
              ),
              const Divider(height: 1),
            ],
            if (Permissions.can(WsAction.manageCheckpoints, role) &&
                _members.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _repId,
                decoration: const InputDecoration(
                  labelText: 'Perwakilan absen',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final m in _members)
                    DropdownMenuItem(
                      value: m.userId,
                      child: Text(m.userId == myId
                          ? 'Kamu'
                          : 'Anggota ${m.userId.substring(0, 8)}'),
                    ),
                ],
                onChanged: (v) async {
                  if (v == null) return;
                  final err = await _svc!.setRep(widget.plan.id, v);
                  if (!context.mounted) return;
                  if (err != null) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(err)));
                  } else {
                    _reload();
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _short(String id) => 'Anggota ${id.substring(0, 8)}';
}

// ---------- Sheet absen: foto + GPS + headcount ----------
class AbsenSheet extends StatefulWidget {
  const AbsenSheet({
    super.key,
    required this.cp,
    required this.svc,
    required this.location,
    required this.memberCount,
  });
  final Checkpoint cp;
  final AttendanceService svc;
  final LocationService location;
  final int memberCount;
  @override
  State<AbsenSheet> createState() => _AbsenSheetState();
}

class _AbsenSheetState extends State<AbsenSheet> {
  Uint8List? _photo;
  late int _headcount = widget.memberCount;
  var _busy = false;
  String? _error;

  Future<void> _takePhoto() async {
    final f = await ImagePicker().pickImage(
      source: ImageSource.camera,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (f == null) return;
    final bytes = await f.readAsBytes();
    if (!mounted) return;
    setState(() => _photo = bytes);
  }

  Future<void> _submit() async {
    final pos = widget.location.pos;
    if (_photo == null) {
      setState(() => _error = 'Ambil foto grup dulu.');
      return;
    }
    if (pos == null) {
      setState(() => _error = 'GPS belum dapat posisi. Tunggu sebentar.');
      return;
    }
    final herr =
        AttendanceRules.validateHeadcount(_headcount, widget.memberCount);
    if (herr != null) {
      setState(() => _error = herr);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.svc.submit(
      cp: widget.cp,
      photo: _photo!,
      lat: pos.latitude,
      lng: pos.longitude,
      accuracy: pos.accuracy,
      headcount: _headcount,
    );
    if (!mounted) return;
    if (err != null) {
      setState(() {
        _busy = false;
        _error = err;
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 8, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Absen: ${widget.cp.name}',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Satu foto wajib memuat semua ${widget.memberCount} anggota + titik GPS dicatat otomatis.',
            style: tt.bodySmall,
          ),
          const SizedBox(height: 14),
          if (_photo != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(_photo!, height: 180, fit: BoxFit.cover),
            )
          else
            OutlinedButton.icon(
              onPressed: _busy ? null : _takePhoto,
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Ambil foto grup'),
            ),
          if (_photo != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _busy ? null : _takePhoto,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Foto ulang'),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text('Orang di foto',
                    style: tt.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                tooltip: 'Kurangi',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _busy || _headcount <= 1
                    ? null
                    : () => setState(() => _headcount--),
              ),
              Text('$_headcount',
                  style: tt.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              IconButton(
                tooltip: 'Tambah',
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.add_circle_outline),
                onPressed: _busy
                    ? null
                    : () => setState(() => _headcount++),
              ),
            ],
          ),
          if (widget.location.pos != null)
            Text(
              'GPS aktif · akurasi ±${widget.location.pos!.accuracy.toStringAsFixed(0)} m (koordinat dicatat di bukti)',
              style: tt.bodySmall,
            ),
          const SizedBox(height: 12),
          Text('Kriteria validasi',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final c in [
            (_photo != null, _photo != null ? 'Foto grup siap (1 file terlampir)' : 'Foto grup belum diambil'),
            (
              AttendanceRules.validateHeadcount(_headcount, widget.memberCount) == null,
              '$_headcount orang dalam foto (anggota aktif ${widget.memberCount})',
            ),
            (widget.location.pos != null, widget.location.pos != null ? 'Lokasi GPS tercatat' : 'Lokasi GPS belum terbaca'),
            (false, 'Radius titik kumpul belum diatur untuk titik ini'),
          ])
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                c.$1 ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 20,
                color: c.$1 ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
              ),
              title: Text(c.$2, style: tt.bodySmall),
            ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: tt.bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          CpiButton(
            busy: _busy,
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Mengirim...' : 'Kirim absen'),
          ),
          const SizedBox(height: 8),
          CpiButton(
            secondary: true,
            onPressed: _busy ? null : () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
        ],
      ),
    );
  }
}
