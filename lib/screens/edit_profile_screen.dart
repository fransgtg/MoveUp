import 'package:moveup/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:moveup/models/user_profile.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/utils/validators.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/widgets/profile_form.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _draft = ProfileDraft.from(widget.profile);
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final updated = _draft.toProfile(uid: widget.profile.uid, email: widget.profile.email);
      await ProfileService.instance.save(updated);
      await AuthService.currentUser?.updateDisplayName(updated.name);
      if (!mounted) return;
      messenger.success("Profil diperbarui");
      Navigator.pop(context);
    } catch (e) {
      messenger.error("Gagal menyimpan profil. Periksa koneksi Anda.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("EDIT PROFIL")),
      body: Form(
        key: _formKey,
        child: FormLayout(
          action: PrimaryButton(text: "Simpan Perubahan", icon: Icons.check, loading: _saving, onPressed: _save),
          children: [
            AppTextField(
              initialValue: _draft.name,
              label: "Nama lengkap",
              prefixIcon: Icons.person_outline,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              validator: Validators.name,
              onChanged: (v) => _draft.name = v,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: widget.profile.email,
              enabled: false,
              decoration: const InputDecoration(labelText: "Email", prefixIcon: Icon(Icons.mail_outline)),
            ),
            const SizedBox(height: 24),
            BodyInfoFields(draft: _draft, onChanged: () => setState(() {})),
            const SizedBox(height: 28),
            PreferenceFields(draft: _draft, onChanged: () => setState(() {})),
          ],
        ),
      ),
    );
  }
}
