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

    final faded = Colors.white.withValues(alpha: 0.75);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 100),
      child: Column(
        children: [
          HeroCard(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.xxl, AppSpacing.xl, AppSpacing.xl),
            child: Column(
              children: [
                // Cincin putih di sekeliling avatar
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                  child: CircleAvatar(
                    radius: 44,
                    backgroundColor: const Color(0xFF141414),
                    foregroundColor: Colors.white,
                    child: Text(profile.initials, style: AppTheme.display(34)),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(profile.name, style: AppTheme.display(30, color: Colors.white), textAlign: TextAlign.center),
                Text(profile.email, style: TextStyle(color: faded)),
                const SizedBox(height: AppSpacing.xl),
                // Total sepanjang waktu
                Row(
                  children: [
                    _buildHeroStat("Aktivitas", "${all.length}"),
                    _buildHeroStat("Total Km", formatKm(meters, decimals: 1)),
                    _buildHeroStat("Total Waktu", formatDurationShort(seconds)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
          const SizedBox(height: AppSpacing.lg),

          // Data tubuh
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStat(context, "Berat", "${_number(profile.weightKg)} kg"),
                  Container(height: 40, width: 1, color: scheme.outline),
                  _buildStat(context, "Tinggi", "${_number(profile.heightCm)} cm"),
                  Container(height: 40, width: 1, color: scheme.outline),
                  _buildStat(context, "BMI · ${profile.bmiCategory}", profile.bmi.toStringAsFixed(1).replaceAll('.', ',')),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // Menus
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: [
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
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Card(
            margin: EdgeInsets.zero,
            child: _buildMenuItem(context, Icons.logout, "Logout", color: Theme.of(context).colorScheme.error, onTap: () => _confirmLogout(context)),
          ),
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

  Widget _buildHeroStat(String label, String val) {
    return Expanded(
      child: Column(
        children: [
          Text(val, style: AppTheme.display(26, color: Colors.white)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, {Color? color, VoidCallback? onTap}) {
    return ListTile(
      onTap: onTap,
      leading: IconBadge(icon: icon, color: color, size: 20),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
      trailing: const Icon(Icons.chevron_right, size: 20),
    );
  }
}
