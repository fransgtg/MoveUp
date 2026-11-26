import 'package:flutter/material.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/user_profile.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/utils/validators.dart';
import 'package:moveup/widgets.dart';

// Isian profil yang dipakai bersama oleh pendaftaran, lengkapi profil, dan edit profil
class ProfileDraft {
  ProfileDraft({
    this.name = '',
    this.gender,
    this.birthDate,
    this.weight = '',
    this.height = '',
    this.level = FitnessLevel.beginner,
    Set<SportType>? sports,
  }) : sports = sports ?? {};

  factory ProfileDraft.from(UserProfile p) => ProfileDraft(
        name: p.name,
        gender: p.gender,
        birthDate: p.birthDate,
        weight: _trim(p.weightKg),
        height: _trim(p.heightCm),
        level: p.level,
        sports: SportType.available.where(p.favoriteSports.contains).toSet(),
      );

  String name;
  Gender? gender;
  DateTime? birthDate;
  String weight;
  String height;
  FitnessLevel level;
  final Set<SportType> sports;

  // Hanya dipanggil setelah semua form lolos validasi
  UserProfile toProfile({required String uid, required String email}) => UserProfile(
        uid: uid,
        name: name.trim(),
        email: email,
        gender: gender!,
        birthDate: birthDate!,
        weightKg: Validators.parseNumber(weight)!,
        heightCm: Validators.parseNumber(height)!,
        level: level,
        favoriteSports: SportType.available.where(sports.contains).toList(),
      );

  static String _trim(double v) => v == v.roundToDouble() ? v.round().toString() : v.toString();
}

// Data fisik: jenis kelamin, tanggal lahir, berat, dan tinggi badan
class BodyInfoFields extends StatelessWidget {
  const BodyInfoFields({super.key, required this.draft, required this.onChanged});

  final ProfileDraft draft;
  final VoidCallback onChanged;

  Future<void> _pickBirthDate(BuildContext context, FormFieldState<DateTime> field) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: draft.birthDate ?? DateTime(now.year - 20, now.month, now.day),
      firstDate: DateTime(now.year - Validators.maxAge),
      lastDate: now,
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Tanggal lahir',
    );
    if (picked == null) return;
    draft.birthDate = picked;
    field.didChange(picked);
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Jenis kelamin'),
        FormField<Gender>(
          initialValue: draft.gender,
          validator: (v) => v == null ? 'Pilih jenis kelamin' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedButton<Gender>(
                emptySelectionAllowed: true,
                showSelectedIcon: false,
                segments: [for (final g in Gender.values) ButtonSegment(value: g, label: Text(g.label))],
                selected: {if (field.value != null) field.value!},
                onSelectionChanged: (s) {
                  if (s.isEmpty) return;
                  draft.gender = s.first;
                  field.didChange(s.first);
                  onChanged();
                },
              ),
              FieldError(field.errorText),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Tanggal lahir'),
        FormField<DateTime>(
          initialValue: draft.birthDate,
          validator: Validators.birthDate,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(AppRadius.control),
                onTap: () => _pickBirthDate(context, field),
                child: InputDecorator(
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.cake_outlined)),
                  child: Text(field.value == null
                      ? 'Pilih tanggal'
                      : '${formatDate(field.value!)} · ${ageOn(field.value!, DateTime.now())} tahun'),
                ),
              ),
              FieldError(field.errorText),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionLabel('Ukuran tubuh'),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextFormField(
                initialValue: draft.weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Berat', suffixText: 'kg'),
                validator: Validators.weight,
                onChanged: (v) {
                  draft.weight = v;
                  onChanged();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                initialValue: draft.height,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Tinggi', suffixText: 'cm'),
                validator: Validators.height,
                onChanged: (v) {
                  draft.height = v;
                  onChanged();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Berat badan dipakai untuk menghitung kalori yang terbakar.',
          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

// Level kebugaran dan olahraga favorit
class PreferenceFields extends StatelessWidget {
  const PreferenceFields({super.key, required this.draft, required this.onChanged});

  final ProfileDraft draft;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionLabel('Level kebugaran'),
        for (final level in FitnessLevel.values)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              side: BorderSide(color: draft.level == level ? scheme.primary : scheme.outline, width: draft.level == level ? 2 : 1),
            ),
            child: ListTile(
              onTap: () {
                draft.level = level;
                onChanged();
              },
              title: Text(level.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(level.description),
              trailing: Icon(
                draft.level == level ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: draft.level == level ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 20),
        const SectionLabel('Olahraga favorit'),
        FormField<Set<SportType>>(
          initialValue: draft.sports,
          validator: (v) => (v == null || v.isEmpty) ? 'Pilih minimal satu olahraga' : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in SportType.available)
                    FilterChip(
                      avatar: Icon(type.icon, size: 18),
                      label: Text(type.label),
                      selected: draft.sports.contains(type),
                      onSelected: (selected) {
                        selected ? draft.sports.add(type) : draft.sports.remove(type);
                        field.didChange(draft.sports);
                        onChanged();
                      },
                    ),
                ],
              ),
              FieldError(field.errorText),
            ],
          ),
        ),
      ],
    );
  }
}

// Kolom password dengan tombol tampil/sembunyi
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      validator: widget.validator,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        labelText: widget.label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Tampilkan password' : 'Sembunyikan password',
          icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}

class PasswordStrengthBar extends StatelessWidget {
  const PasswordStrengthBar({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final strength = Validators.passwordStrength(password);
    if (strength == 0) return const SizedBox.shrink();
    final (label, color) = switch (strength) {
      1 => ('Lemah', AppTheme.danger),
      2 => ('Sedang', AppTheme.warning),
      _ => ('Kuat', AppTheme.success),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i <= strength ? color : Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
