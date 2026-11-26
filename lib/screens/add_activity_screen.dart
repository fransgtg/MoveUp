import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/utils/validators.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/services/photo_store.dart';
import 'package:moveup/widgets/activity_media.dart';

// Input manual untuk aktivitas tanpa GPS (misalnya treadmill atau lupa merekam),
// sekaligus form edit kalau [activity] diisi
class AddActivityScreen extends StatefulWidget {
  const AddActivityScreen({super.key, this.activity});

  final Activity? activity;

  @override
  State<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends State<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Activity? _initial = widget.activity;
  late final _titleCtrl = TextEditingController(text: _initial?.title);
  late final _descCtrl = TextEditingController(text: _initial?.description);
  late final _hoursCtrl = TextEditingController(text: _initial == null ? '' : '${_initial.movingSeconds ~/ 3600}');
  late final _minutesCtrl = TextEditingController(
    text: _initial == null ? '' : '${(_initial.movingSeconds % 3600 / 60).round()}',
  );
  late final _distanceCtrl = TextEditingController(
    text: _initial == null || _initial.distanceMeters == 0 ? '' : formatKm(_initial.distanceMeters),
  );

  // Urutan fokus saat menekan "berikutnya" di keyboard: jam → menit → jarak → catatan
  final _hoursFocus = FocusNode();
  final _minutesFocus = FocusNode();
  final _distanceFocus = FocusNode();
  final _descFocus = FocusNode();

  late SportType _type = _initial?.type ?? SportType.run;
  late DateTime _date = _initial?.startTime ?? DateTime.now();
  late TimeOfDay _time = TimeOfDay.fromDateTime(_initial?.startTime ?? DateTime.now());
  late List<String> _photos = [...?_initial?.photos];
  bool _saving = false;
  bool _saved = false;

  bool get _editing => _initial != null;

  // Foto yang baru ditambahkan di form ini; dibuang lagi kalau form ditutup tanpa disimpan
  Iterable<String> get _newPhotos => _photos.where((p) => !(_initial?.photos.contains(p) ?? false));

  // Durasi dan jarak rekaman GPS berasal dari rute, jadi tidak boleh diubah manual
  bool get _fromGps => _initial?.points.isNotEmpty ?? false;

  DateTime get _start => DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  int get _seconds =>
      (int.tryParse(_hoursCtrl.text.trim()) ?? 0) * 3600 + (int.tryParse(_minutesCtrl.text.trim()) ?? 0) * 60;

  @override
  void dispose() {
    for (final c in [_titleCtrl, _descCtrl, _hoursCtrl, _minutesCtrl, _distanceCtrl]) {
      c.dispose();
    }
    for (final f in [_hoursFocus, _minutesFocus, _distanceFocus, _descFocus]) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    final title = _titleCtrl.text.trim();
    final activity = Activity(
      id: _initial?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: _type,
      title: title.isEmpty ? defaultTitle(_type, _start) : title,
      description: _descCtrl.text.trim(),
      startTime: _start,
      movingSeconds: _fromGps ? _initial!.movingSeconds : _seconds,
      distanceMeters: _fromGps ? _initial!.distanceMeters : (Validators.parseNumber(_distanceCtrl.text) ?? 0) * 1000,
      points: _initial?.points ?? const [],
      photos: _photos,
    );
    final messenger = ScaffoldMessenger.of(context);
    try {
      final store = ActivityStore.instance;
      await (_editing ? store.update(activity) : store.add(activity));
      _saved = true;
      // Foto yang dihapus dari aktivitas baru dibuang filenya setelah perubahan tersimpan
      await PhotoStore.deleteAll(_initial?.photos.where((p) => !_photos.contains(p)) ?? const []);
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.error("Aktivitas gagal disimpan. Coba lagi.");
      return;
    }
    if (!mounted) return;
    messenger.success(_editing ? "Aktivitas diperbarui" : "Aktivitas \"${activity.title}\" ditambahkan");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop && !_saved) PhotoStore.deleteAll(_newPhotos.toList());
      },
      child: Scaffold(
        appBar: AppBar(title: Text(_editing ? "Edit Aktivitas" : "Aktivitas Manual")),
        body: Form(
          key: _formKey,
          child: FormLayout(
            action: PrimaryButton(
              text: _editing ? "Simpan Perubahan" : "Simpan Aktivitas",
              icon: Icons.check,
              loading: _saving,
              onPressed: _save,
            ),
            children: [
              const SectionLabel("Jenis olahraga"),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final type in SportType.available)
                    ChoiceChip(
                      avatar: Icon(type.icon, size: 18),
                      label: Text(type.label),
                      selected: type == _type,
                      onSelected: (_) => setState(() => _type = type),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _titleCtrl,
                label: "Judul",
                hint: defaultTitle(_type, _start),
                helper: "Kosongkan untuk memakai judul otomatis",
                textCapitalization: TextCapitalization.sentences,
                maxLength: 60,
                // Tanggal dan jam diisi lewat picker, jadi "berikutnya" lompat ke isian durasi
                nextFocus: _fromGps ? _descFocus : _hoursFocus,
                validator: Validators.title(label: "Judul", max: 60, required: false),
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionLabel("Waktu mulai"),
              PickerField<DateTime>(
                label: "Tanggal",
                icon: Icons.event,
                initialValue: _date,
                display: (v) => v == null ? "Pilih tanggal" : formatDate(v),
                pick: (current) => showDatePicker(
                  context: context,
                  initialDate: current ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  helpText: "Tanggal aktivitas",
                ),
                onChanged: (v) => setState(() => _date = v),
              ),
              const SizedBox(height: AppSpacing.md),
              PickerField<TimeOfDay>(
                label: "Jam",
                icon: Icons.schedule,
                initialValue: _time,
                display: (v) => v == null ? "--:--" : v.format(context),
                pick: (current) =>
                    showTimePicker(context: context, initialTime: current ?? TimeOfDay.now(), helpText: "Jam mulai"),
                onChanged: (v) => setState(() => _time = v),
                validator: (_) => _start.isAfter(DateTime.now()) ? "Jam belum lewat" : null,
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionLabel("Durasi dan jarak"),
              if (_fromGps)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    "Durasi dan jarak berasal dari rekaman GPS sehingga tidak dapat diubah.",
                    style: TextStyle(color: muted, fontSize: 12),
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _hoursCtrl,
                      focusNode: _hoursFocus,
                      nextFocus: _minutesFocus,
                      label: "Jam",
                      suffixText: "j",
                      enabled: !_fromGps,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                      validator: Validators.wholeNumber(label: "Jam", max: 23),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _minutesCtrl,
                      focusNode: _minutesFocus,
                      nextFocus: _distanceFocus,
                      label: "Menit",
                      suffixText: "m",
                      enabled: !_fromGps,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
                      validator: (v) {
                        final error = Validators.wholeNumber(label: "Menit", max: 59)(v);
                        if (error != null || _fromGps) return error;
                        return _seconds <= 0 ? "Isi durasi minimal 1 menit" : null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _distanceCtrl,
                focusNode: _distanceFocus,
                nextFocus: _descFocus,
                label: "Jarak",
                suffixText: "km",
                hint: "Contoh: 5,2",
                helper: "Opsional, misalnya untuk latihan beban",
                enabled: !_fromGps,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                validator: _fromGps
                    ? null
                    : Validators.positiveNumber(label: "Jarak", max: 500, unit: "km", required: false),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descCtrl,
                focusNode: _descFocus,
                label: "Catatan",
                hint: "Bagaimana latihannya? (opsional)",
                maxLines: 4,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.md),
              PhotoPickerField(photos: _photos, onChanged: (v) => setState(() => _photos = v)),
            ],
          ),
        ),
      ),
    );
  }
}
