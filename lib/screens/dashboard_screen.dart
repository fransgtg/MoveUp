import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/screens/activity_detail_screen.dart';
import 'package:moveup/screens/add_activity_screen.dart';
import 'package:moveup/screens/chat_list_screen.dart';
import 'package:moveup/screens/coach_chat_screen.dart';
import 'package:moveup/screens/goal_detail_screen.dart';
import 'package:moveup/screens/goals_screen.dart';
import 'package:moveup/screens/reminder_screen.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/services/reminder_store.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/widgets/activity_feed_card.dart';
import 'package:moveup/widgets/goal_progress_card.dart';

// Beranda: ringkasan minggu ini dan feed aktivitas
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = ActivityStore.instance;

    return SafeArea(
      child: ListenableBuilder(
        listenable: Listenable.merge([store, GoalStore.instance, ReminderStore.instance, ProfileService.instance]),
        builder: (context, _) {
          final activities = store.activities;
          final now = DateTime.now();
          final weekStart = startOfWeek(now);
          final week = store.between(weekStart, weekStart.add(const Duration(days: 7)));

          final firstName = ProfileService.instance.profile?.name.split(' ').first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 100),
            children: [
              ScreenHeader(
                subtitle: _greeting(now),
                title: firstName == null || firstName.isEmpty ? "BERANDA" : "Halo, $firstName",
                actions: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: "Pesan",
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.edit_note),
                    tooltip: "Tambah aktivitas manual",
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddActivityScreen())),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              _WeekSummaryCard(week: week, todayIndex: now.weekday - 1),
              const SizedBox(height: AppSpacing.lg),
              const _CoachCard(),
              const SizedBox(height: AppSpacing.xl),
              _PlanSection(now: now),
              if (activities.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxl),
                  child: EmptyStateWidget(
                    title: "Belum ada aktivitas",
                    message: "Tekan Rekam untuk mulai bergerak, atau catat latihan secara manual.",
                    icon: Icons.directions_run,
                    actionLabel: "Catat Manual",
                    onAction: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddActivityScreen())),
                  ),
                )
              else ...[
                Text("Aktivitas Terbaru", style: AppTheme.display(24)),
                const SizedBox(height: AppSpacing.md),
                for (final activity in activities)
                  ActivityFeedCard(
                    activity: activity,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: activity)),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  static String _greeting(DateTime now) {
    final h = now.hour;
    if (h < 11) return "Selamat pagi";
    if (h < 15) return "Selamat siang";
    if (h < 18) return "Selamat sore";
    return "Selamat malam";
  }
}

// Pintu masuk ke chat MoveUp Coach
class _CoachCard extends StatelessWidget {
  const _CoachCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoachChatScreen())),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.accentGradient),
            child: const Icon(Icons.sports_gymnastics, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Tanya MoveUp Coach", style: AppTheme.display(20)),
                Text(
                  "Saran latihan berdasarkan datamu",
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.chat_bubble_outline, color: scheme.primary),
        ],
      ),
    );
  }
}

class _WeekSummaryCard extends StatelessWidget {
  const _WeekSummaryCard({required this.week, required this.todayIndex});

  final List<Activity> week;
  final int todayIndex;

  @override
  Widget build(BuildContext context) {
    final perDay = List<double>.filled(7, 0);
    var meters = 0.0;
    var seconds = 0;
    for (final a in week) {
      perDay[a.startTime.weekday - 1] += a.km;
      meters += a.distanceMeters;
      seconds += a.movingSeconds;
    }

    final faded = Colors.white.withValues(alpha: 0.75);

    return HeroCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("MINGGU INI", style: AppTheme.display(16, color: faded, letterSpacing: 2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${week.length} aktivitas",
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Jarak dibuat paling besar karena itu angka yang paling sering dicari
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(formatKm(meters), style: AppTheme.display(56, color: Colors.white)),
              const SizedBox(width: 6),
              Text("km", style: AppTheme.display(22, color: faded)),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 18, color: faded),
              const SizedBox(width: 4),
              Text(formatDurationShort(seconds), style: AppTheme.display(22, color: Colors.white)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SimpleBarChart(
            values: perDay,
            labels: dayInitials,
            highlightIndex: todayIndex,
            height: 64,
            barColor: Colors.white,
            labelColor: faded,
          ),
        ],
      ),
    );
  }
}

// Target yang belum tercapai dan jadwal latihan berikutnya
class _PlanSection extends StatelessWidget {
  const _PlanSection({required this.now});

  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final activities = ActivityStore.instance.activities;
    final progress = [for (final g in GoalStore.instance.goals) g.progress(activities, now: now)]
      ..sort((a, b) => b.fraction.compareTo(a.fraction));
    final ongoing = progress.where((p) => !p.completed).take(2).toList();
    final next = [
      for (final r in ReminderStore.instance.reminders)
        if (r.nextAfter(now) case final at?) (r, at),
    ]..sort((a, b) => a.$2.compareTo(b.$2));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (next.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: AppSpacing.xl),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
              leading: IconBadge(icon: next.first.$1.sportType.icon),
              title: Text(
                "JADWAL BERIKUTNYA",
                style: AppTheme.display(13, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.5),
              ),
              subtitle: Text(
                "${next.first.$1.title} · ${formatRelativeDateTime(next.first.$2)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderScreen())),
            ),
          ),
        if (progress.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text("Target", style: AppTheme.display(24))),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                child: Text("Lihat semua (${progress.length})"),
              ),
            ],
          ),
          if (ongoing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                "Semua target periode ini sudah tercapai. Mantap!",
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            )
          else
            for (final p in ongoing)
              GoalProgressCard(
                progress: p,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => GoalDetailScreen(goalId: p.goal.id)),
                ),
              ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
