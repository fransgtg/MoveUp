import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/screens/activity_detail_screen.dart';
import 'package:moveup/screens/add_activity_screen.dart';
import 'package:moveup/screens/chat_list_screen.dart';
import 'package:moveup/screens/goal_detail_screen.dart';
import 'package:moveup/screens/goals_screen.dart';
import 'package:moveup/screens/reminder_screen.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/goal_store.dart';
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
        listenable: Listenable.merge([store, GoalStore.instance, ReminderStore.instance]),
        builder: (context, _) {
          final activities = store.activities;
          final now = DateTime.now();
          final weekStart = startOfWeek(now);
          final week = store.between(weekStart, weekStart.add(const Duration(days: 7)));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Text("BERANDA", style: AppTheme.display(30, letterSpacing: 1.5)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: "Pesan",
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen())),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_note),
                    tooltip: "Tambah aktivitas manual",
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddActivityScreen())),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _WeekSummaryCard(week: week, todayIndex: now.weekday - 1),
              const SizedBox(height: 16),
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
                Text("Aktivitas Terbaru", style: AppTheme.display(22)),
                const SizedBox(height: 8),
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Minggu Ini", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryStat(context, "Aktivitas", "${week.length}"),
                _summaryStat(context, "Jarak", "${formatKm(meters)} km"),
                _summaryStat(context, "Waktu", formatDurationShort(seconds)),
              ],
            ),
            const SizedBox(height: 16),
            SimpleBarChart(values: perDay, labels: dayInitials, highlightIndex: todayIndex, height: 60),
          ],
        ),
      ),
    );
  }

  Widget _summaryStat(BuildContext context, String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(value, style: AppTheme.display(22)),
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
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              leading: Icon(next.first.$1.sportType.icon),
              title: Text("Jadwal berikutnya: ${next.first.$1.title}"),
              subtitle: Text(formatRelativeDateTime(next.first.$2)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderScreen())),
            ),
          ),
        if (progress.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text("Target", style: AppTheme.display(22))),
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
