import 'package:flutter/material.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/services/reminder_store.dart';
import 'package:moveup/services/settings_service.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/services/voice_coach.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _loadSample(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: "Muat data simulasi?",
      message: "Semua aktivitas, target, dan pengingat di perangkat ini akan diganti dengan data contoh.",
      confirmLabel: "Ganti Data",
      icon: Icons.dataset_outlined,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ActivityStore.instance.resetToSample();
    await GoalStore.instance.resetToSample();
    await ReminderStore.instance.resetToSample();
    messenger.success("Data simulasi dimuat");
  }

  Future<void> _clearAll(BuildContext context) async {
    final ok = await showConfirmDialog(
      context,
      title: "Hapus semua data?",
      message: "Semua aktivitas, target, dan pengingat akan dihapus permanen. Profil akun tidak ikut terhapus.",
      confirmLabel: "Hapus Semua",
      icon: Icons.delete_sweep_outlined,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await ActivityStore.instance.replaceAll([]);
    await GoalStore.instance.replaceAll([]);
    await ReminderStore.instance.replaceAll([]);
    messenger.success("Semua data dihapus");
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan")),
      body: ListenableBuilder(
        listenable: Listenable.merge([settings, ActivityStore.instance, GoalStore.instance, ReminderStore.instance]),
        builder: (context, _) => ListView(
          padding: AppSpacing.page,
          children: [
            Text("Tampilan", style: AppTheme.display(22)),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text("Sistem")),
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text("Terang")),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text("Gelap")),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
            const SizedBox(height: 32),
            Text("Rekam Aktivitas", style: AppTheme.display(22)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.record_voice_over_outlined),
              title: const Text("Pengumuman suara tiap 1 km"),
              subtitle: const Text("Jarak, waktu, pace, dan perbandingan dengan kilometer sebelumnya"),
              value: settings.voiceCoach,
              onChanged: settings.setVoiceCoach,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.volume_up_outlined),
              title: const Text("Coba suara"),
              subtitle: const Text("Contoh pengumuman kilometer ke-2"),
              onTap: () => VoiceCoach.instance.speak(KmAnnouncer.buildAnnouncement(
                type: SportType.run,
                km: 2,
                totalSeconds: 742,
                splitSeconds: 365,
                previousSplitSeconds: 377,
              )),
            ),
            const SizedBox(height: 32),
            Text("Data", style: AppTheme.display(22)),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  _countRow(Icons.directions_run, "Aktivitas", ActivityStore.instance.activities.length),
                  _countRow(Icons.track_changes, "Target", GoalStore.instance.goals.length),
                  _countRow(Icons.notifications_none, "Pengingat", ReminderStore.instance.reminders.length),
                  _countRow(Icons.category_outlined, "Kategori olahraga", SportType.available.length),
                ],
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.dataset_outlined),
              title: const Text("Muat data simulasi"),
              subtitle: const Text("24 aktivitas, 6 target, dan 4 pengingat contoh"),
              onTap: () => _loadSample(context),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.delete_sweep_outlined, color: scheme.error),
              title: Text("Hapus semua data", style: TextStyle(color: scheme.error)),
              subtitle: const Text("Aktivitas, target, dan pengingat di perangkat ini"),
              onTap: () => _clearAll(context),
            ),
            const SizedBox(height: 32),
            Text("Tentang", style: AppTheme.display(22)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.info_outline),
              title: const Text("MoveUp"),
              subtitle: Text("Versi 1.0.0 · Pelacak olahraga", style: TextStyle(color: scheme.onSurfaceVariant)),
              onTap: () => showAboutDialog(
                context: context,
                applicationName: "MoveUp",
                applicationVersion: "1.0.0",
                applicationLegalese: "Rekam lari, jalan, bersepeda, dan hiking. Pantau target dan jadwal latihanmu.",
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _countRow(IconData icon, String label, int count) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label),
      trailing: Text("$count", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }
}
