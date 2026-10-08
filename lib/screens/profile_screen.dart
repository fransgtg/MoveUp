import 'package:flutter/material.dart';
import 'package:moveup/models/user_profile.dart';
import 'package:moveup/screens/change_password_screen.dart';
import 'package:moveup/screens/chat_list_screen.dart';
import 'package:moveup/screens/edit_profile_screen.dart';
import 'package:moveup/screens/goals_screen.dart';
import 'package:moveup/screens/reminder_screen.dart';
import 'package:moveup/screens/settings_screen.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/auth_service.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _confirmLogout(BuildContext context) async {
    final logout = await showConfirmDialog(
      context,
      title: "Keluar dari akun?",
      message: "Aktivitas Anda tetap tersimpan di perangkat ini dan muncul lagi saat Anda masuk kembali.",
      confirmLabel: "Keluar",
      icon: Icons.logout,
    );
    if (logout) await AuthService.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([ProfileService.instance, ActivityStore.instance]),
        builder: (context, _) {
          final profile = ProfileService.instance.profile;
          if (profile == null) return const Center(child: CircularProgressIndicator());
          return _buildContent(context, profile);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, UserProfile profile) {
    final scheme = Theme.of(context).colorScheme;
    final all = ActivityStore.instance.activities;
    final meters = all.fold<double>(0, (sum, a) => sum + a.distanceMeters);
    final seconds = all.fold<int>(0, (sum, a) => sum + a.movingSeconds);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          const SizedBox(height: 20),
          CircleAvatar(
            radius: 50,
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(profile.initials, style: AppTheme.display(36)),
          ),
          const SizedBox(height: 16),
          Text(profile.name, style: AppTheme.display(30), textAlign: TextAlign.center),
          Text(profile.email, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              Chip(label: Text(profile.level.label), avatar: const Icon(Icons.trending_up, size: 18)),
              Chip(label: Text("${profile.age} tahun · ${profile.gender.label}")),
              for (final sport in profile.favoriteSports) Chip(avatar: Icon(sport.icon, size: 18), label: Text(sport.label)),
            ],
          ),
          const SizedBox(height: 24),

          // Total sepanjang waktu
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(context, "Aktivitas", "${all.length}"),
                  _buildStat(context, "Total Jarak", "${formatKm(meters, decimals: 1)} km"),
                  _buildStat(context, "Total Waktu", formatDurationShort(seconds)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Data tubuh
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStat(context, "Berat", "${_number(profile.weightKg)} kg"),
              Container(height: 40, width: 1, color: scheme.outline),
              _buildStat(context, "Tinggi", "${_number(profile.heightCm)} cm"),
              Container(height: 40, width: 1, color: scheme.outline),
              _buildStat(context, "BMI · ${profile.bmiCategory}", profile.bmi.toStringAsFixed(1).replaceAll('.', ',')),
            ],
          ),
          const SizedBox(height: 32),

          // Menus
          _buildMenuItem(context, Icons.edit_outlined, "Edit Profil", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(profile: profile)));
          }),
          _buildMenuItem(context, Icons.track_changes, "Target (Goal Setting)", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen()));
          }),
          _buildMenuItem(context, Icons.notifications_none, "Pengaturan Reminder", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderScreen()));
          }),
          _buildMenuItem(context, Icons.chat_bubble_outline, "Pesan", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
          }),
          _buildMenuItem(context, Icons.security, "Keamanan Akun", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ChangePasswordScreen()));
          }),
          _buildMenuItem(context, Icons.settings_outlined, "Pengaturan", onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
          }),
          const SizedBox(height: 20),
          _buildMenuItem(context, Icons.logout, "Logout", color: Theme.of(context).colorScheme.error, onTap: () => _confirmLogout(context)),
        ],
      ),
    );
  }

  static String _number(double v) => (v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1)).replaceAll('.', ',');

  Widget _buildStat(BuildContext context, String label, String val) {
    return Column(
      children: [
        Text(val, style: AppTheme.display(24)),
        Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? Theme.of(context).primaryColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color ?? Theme.of(context).primaryColor),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}
