import 'package:flutter/material.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/models/reminder.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/services/reminder_store.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/utils/validators.dart';
import 'package:moveup/widgets.dart';

// Form tambah pengingat, sekaligus edit kalau [reminder] diisi.
// [initialGoal] dipakai saat dibuka dari detail target supaya relasinya langsung terisi.
class ReminderFormScreen extends StatefulWidget {
  const ReminderFormScreen({super.key, this.reminder, this.initialGoal});

  final Reminder? reminder;
  final Goal? initialGoal;

  @override
  State<ReminderFormScreen> createState() => _ReminderFormScreenState();
}

class _ReminderFormScreenState extends State<ReminderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Reminder? _initial = widget.reminder;
  late final _titleCtrl = TextEditingController(text: _initial?.title ?? widget.initialGoal?.title);
  late SportType _sport = _initial?.sportType ??
      (widget.initialGoal?.sportType == SportType.swim
          ? SportType.run
          : widget.initialGoal?.sportType ?? SportType.run);
  late final Set<int> _days = {...?_initial?.days};
  late TimeOfDay _time = _initial?.time ?? const TimeOfDay(hour: 6, minute: 0);
  late bool _enabled = _initial?.enabled ?? true;
  late String? _goalId = _initial?.goalId ?? widget.initialGoal?.id;
  bool _saving = false;

  bool get _editing => _initial != null;

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final reminder = Reminder(
      id: _initial?.id ?? 'rem-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleCtrl.text.trim(),
      sportTypeId: _sport.id,
      days: _days.toList()..sort(),
      hour: _time.hour,
      minute: _time.minute,
      enabled: _enabled,
      goalId: _goalId,
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = ReminderStore.instance;
      await (_editing ? store.update(reminder) : store.add(reminder));
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.error("Reminder gagal disimpan. Coba lagi.");
      return;
    }
    if (!mounted) return;
    messenger.success(_editing ? "Reminder diperbarui" : "Reminder ${reminder.timeLabel} ditambahkan");
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final delete = await showConfirmDialog(
      context,
      title: "Hapus reminder?",
      message: "\"${_initial!.title}\" akan dihapus dan tidak lagi mengingatkan Anda.",
      confirmLabel: "Hapus",
    );
    if (!delete || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ReminderStore.instance.remove(_initial.id);
    messenger.success("Reminder dihapus");
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final goals = GoalStore.instance.goals;
    // Target yang dirujuk bisa saja sudah dihapus
    if (_goalId != null && goals.every((g) => g.id != _goalId)) _goalId = null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? "Edit Reminder" : "Reminder Baru"),
        actions: [
          if (_editing) IconButton(icon: const Icon(Icons.delete_outline), tooltip: "Hapus", onPressed: _delete),
        ],
      ),
      body: Form(
        key: _formKey,
        child: FormLayout(
          action: PrimaryButton(
            text: _editing ? "Simpan Perubahan" : "Simpan Reminder",
            icon: Icons.check,
            loading: _saving,
            onPressed: _save,
          ),
          children: [
            AppTextField(
              controller: _titleCtrl,
              label: "Nama aktivitas",
              hint: "Misal: Lari Pagi",
              textCapitalization: TextCapitalization.sentences,
              maxLength: 30,
              textInputAction: TextInputAction.done,
              validator: Validators.title(label: "Nama aktivitas", max: 30),
            ),
            const SizedBox(height: AppSpacing.md),
            const SectionLabel("Jenis olahraga"),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                if (_sport == SportType.swim)
                  const Chip(label: Text('Renang (kategori lama)')),
                for (final type in SportType.available)
                  ChoiceChip(
                    avatar: Icon(type.icon, size: 18),
                    label: Text(type.label),
                    selected: type == _sport,
                    onSelected: (_) => setState(() => _sport = type),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FormField<Set<int>>(
              validator: (_) => _days.isEmpty ? "Pilih minimal satu hari" : null,
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(child: SectionLabel("Hari")),
                      TextButton(
                        onPressed: () {
                          setState(() => _days.length == 7 ? _days.clear() : _days.addAll([1, 2, 3, 4, 5, 6, 7]));
                          field.didChange(_days);
                        },
                        child: Text(_days.length == 7 ? "Kosongkan" : "Setiap hari"),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (var d = 1; d <= 7; d++)
                        FilterChip(
                          label: Text(dayShortNames[d - 1]),
                          selected: _days.contains(d),
                          showCheckmark: false,
                          onSelected: (on) {
                            setState(() => on ? _days.add(d) : _days.remove(d));
                            field.didChange(_days);
                          },
                        ),
                    ],
                  ),
                  FieldError(field.errorText),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            PickerField<TimeOfDay>(
              label: "Jam pengingat",
              icon: Icons.schedule,
              initialValue: _time,
              display: (v) => v == null ? "Pilih jam" : v.format(context),
              pick: (current) => showTimePicker(context: context, initialTime: current ?? _time),
              onChanged: (v) => setState(() => _time = v),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              initialValue: _goalId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: "Terkait dengan Target (opsional)"),
              items: [
                const DropdownMenuItem(value: null, child: Text("Tidak terkait")),
                for (final g in goals)
                  DropdownMenuItem(value: g.id, child: Text(g.title, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (v) => setState(() => _goalId = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Aktif"),
              subtitle: const Text("Nonaktifkan untuk menjeda tanpa menghapus"),
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
            ),
          ],
        ),
      ),
    );
  }
}
