import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/screens/activity_detail_screen.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/widgets/route_map.dart';
import 'package:moveup/services/photo_store.dart';
import 'package:moveup/widgets/activity_media.dart';

// Layar setelah menekan "Selesai": beri judul dan deskripsi sebelum disimpan
class SaveActivityScreen extends StatefulWidget {
  const SaveActivityScreen({super.key, required this.draft});

  final Activity draft;

  @override
  State<SaveActivityScreen> createState() => _SaveActivityScreenState();
}

class _SaveActivityScreenState extends State<SaveActivityScreen> {
  late final _titleCtrl = TextEditingController(text: widget.draft.title);
  final _descCtrl = TextEditingController();
  final _descFocus = FocusNode();
  late SportType _type = widget.draft.type;
  List<String> _photos = [];
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _descFocus.dispose();
    super.dispose();
  }

  void _changeType(SportType type) {
    // Ikut ganti judul otomatis, kecuali pengguna sudah menulis judul sendiri
    if (_titleCtrl.text == defaultTitle(_type, widget.draft.startTime)) {
      _titleCtrl.text = defaultTitle(type, widget.draft.startTime);
    }
    setState(() => _type = type);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final d = widget.draft;
    final title = _titleCtrl.text.trim();
    final activity = Activity(
      id: d.id,
      type: _type,
      title: title.isEmpty ? defaultTitle(_type, d.startTime) : title,
      description: _descCtrl.text.trim(),
      startTime: d.startTime,
      movingSeconds: d.movingSeconds,
      distanceMeters: d.distanceMeters,
      points: d.points,
      photos: _photos,
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ActivityStore.instance.add(activity);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.error("Aktivitas gagal disimpan. Coba lagi.");
      return;
    }
    if (!mounted) return;
    messenger.success("Aktivitas \"${activity.title}\" disimpan");
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: activity)));
  }

  Future<void> _discard() async {
    final discard = await showConfirmDialog(
      context,
      title: "Buang aktivitas?",
      message: "Rekaman ini tidak akan disimpan dan tidak bisa dikembalikan.",
      confirmLabel: "Buang",
      icon: Icons.delete_outline,
    );
    if (!discard || !mounted) return;
    await PhotoStore.deleteAll(_photos);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    final preview = Activity(
      id: d.id,
      type: _type,
      title: d.title,
      startTime: d.startTime,
      movingSeconds: d.movingSeconds,
      distanceMeters: d.distanceMeters,
    );
    final (paceLabel, paceValue) = paceOrSpeed(preview);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_saving) _discard();
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Simpan Aktivitas")),
        body: FormLayout(
          action: PrimaryButton(text: "Simpan Aktivitas", icon: Icons.check, loading: _saving, onPressed: _save),
          secondaryAction: TextButton(
            onPressed: _saving ? null : _discard,
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text("Buang aktivitas"),
          ),
          children: [
            AppTextField(
              controller: _titleCtrl,
              label: "Judul",
              textCapitalization: TextCapitalization.sentences,
              maxLength: 60,
              nextFocus: _descFocus,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _descCtrl,
              focusNode: _descFocus,
              label: "Catatan",
              hint: "Bagaimana aktivitasnya? Ceritakan di sini",
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: AppSpacing.md),
            PhotoPickerField(photos: _photos, onChanged: (v) => setState(() => _photos = v)),
            const SizedBox(height: AppSpacing.xl),
            const SectionLabel("Jenis olahraga"),
            Wrap(
              spacing: 8,
              children: [
                for (final type in SportType.available)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 18),
                    label: Text(type.label),
                    selected: type == _type,
                    onSelected: (_) => _changeType(type),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _stat("Jarak", "${formatKm(d.distanceMeters)} km"),
                        _stat(paceLabel, paceValue),
                        _stat("Waktu", formatDuration(d.movingSeconds)),
                      ],
                    ),
                  ),
                  if (d.points.isNotEmpty)
                    SizedBox(height: 160, child: AbsorbPointer(child: RouteMap(points: d.points))),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(value, style: AppTheme.display(22)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }
}
