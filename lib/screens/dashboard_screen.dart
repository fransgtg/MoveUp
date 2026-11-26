import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/goal.dart';
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

    return Stack(
      fit: StackFit.expand,
      children: [
        const SportsPhotoBackground('assets/sports/training.jpg'),
        SafeArea(
          child: ListenableBuilder(
            listenable: Listenable.merge([
              store,
              GoalStore.instance,
              ReminderStore.instance,
              ProfileService.instance,
            ]),
            builder: (context, _) {
              final activities = store.activities;
              final now = DateTime.now();
              final weekStart = startOfWeek(now);
              final week = store.between(
                weekStart,
                weekStart.add(const Duration(days: 7)),
              );

              final firstName = ProfileService.instance.profile?.name
                  .split(' ')
                  .first;

              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _TrainingCover(
                      week: week,
                      now: now,
                      greeting: firstName == null || firstName.isEmpty
                          ? _greeting(now)
                          : '${_greeting(now)}, $firstName',
                    ),
                  ),
                  DecoratedSliver(
                    decoration: BoxDecoration(
                      color: Theme.of(context).canvasColor
                          .withValues(alpha: 0.84),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    sliver: SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                      sliver: SliverList.list(
                        children: [
                          Text('Ritme mingguan', style: AppTheme.display(28)),
                          const SizedBox(height: AppSpacing.md),
                          _WeekSummaryCard(
                            week: week,
                            todayIndex: now.weekday - 1,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          const _CoachCard(),
                          const SizedBox(height: AppSpacing.lg),
                          _PlanSection(now: now),
                          if (activities.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AppSpacing.lg,
                              ),
                              child: EmptyStateWidget(
                                title: "Belum ada aktivitas",
                                message: "Tekan Rekam untuk mulai bergerak, atau catat latihan secara manual.",
                                icon: Icons.directions_run,
                                actionLabel: "Catat Manual",
                                onAction: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddActivityScreen(),
                                  ),
                                ),
                              ),
                            )
                          else ...[
                            Text(
                              "Aktivitas Terbaru",
                              style: AppTheme.display(24),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            for (final activity in activities)
                              ActivityFeedCard(
                                activity: activity,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActivityDetailScreen(
                                      activity: activity,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
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

class _TrainingCover extends StatefulWidget {
  const _TrainingCover({
    required this.week,
    required this.now,
    required this.greeting,
  });
  final List<Activity> week;
  final DateTime now;
  final String greeting;

  @override
  State<_TrainingCover> createState() => _TrainingCoverState();
}

class _TrainingCoverState extends State<_TrainingCover> {
  SportType selected = SportType.run;

  @override
  Widget build(BuildContext context) {
    final week = widget.week.where((activity) => activity.type == selected);
    final days = week
        .map((activity) => activity.startTime.weekday)
        .toSet()
        .length;
    final meters = week.fold<double>(
      0,
      (total, activity) => total + activity.distanceMeters,
    );
    final weeklyGoals = GoalStore.instance.goals.where(
      (goal) => goal.period == GoalPeriod.weekly,
    );
    final goal =
        weeklyGoals
            .where((goal) => goal.sportTypeId == selected.id)
            .firstOrNull ??
        weeklyGoals.where((goal) => goal.sportTypeId == null).firstOrNull;
    final progress = goal?.progress(widget.week, now: widget.now);
    final style = IconButton.styleFrom(
      backgroundColor: const Color(0x66344774),
      foregroundColor: Colors.white,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    style: style,
                    icon: const Icon(Icons.edit_note),
                    tooltip: 'Tambah aktivitas manual',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddActivityScreen(),
                      ),
                    ),
                  ),
                  const Text(
                    'M O V E U P',
                    semanticsLabel: 'MoveUp',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    style: style,
                    icon: const Icon(Icons.chat_bubble_outline),
                    tooltip: 'Pesan',
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                widget.greeting,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Temukan ritmemu.',
                style: AppTheme.display(42, color: Colors.white),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final sport in SportType.available)
                      Padding(
                        padding: const EdgeInsets.only(right: 7),
                        child: ChoiceChip(
                          label: Text(sport.label),
                          selected: selected == sport,
                          showCheckmark: false,
                          labelStyle: TextStyle(
                            color: selected == sport
                                ? AppTheme.accentDeep
                                : Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xb8273d69),
                          side: const BorderSide(color: Colors.white38),
                          onSelected: (_) => setState(() => selected = sport),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${selected.label.toUpperCase()}  /  MINGGU INI',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CoverStat(
                    icon: Icons.calendar_month_outlined,
                    label: 'Hari aktif',
                    value: '$days hari',
                  ),
                  const SizedBox(width: 8),
                  _CoverStat(
                    icon: Icons.route_outlined,
                    label: 'Total jarak',
                    value: '${formatKm(meters)} km',
                  ),
                ],
              ),
              if (progress != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Target mingguan · ${progress.goal.title}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${progress.goal.metric.format(progress.current)} dari '
                  '${progress.goal.targetLabel}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: AppSpacing.xs),
                LinearProgressIndicator(
                  value: progress.fraction,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                  color: Colors.white,
                  backgroundColor: Colors.white30,
                  semanticsLabel: 'Progres target mingguan',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverStat extends StatelessWidget {
  const _CoverStat({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x99445a80),
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(value, style: AppTheme.display(26, color: Colors.white)),
        ],
      ),
    ),
  );
}

// Pintu masuk ke chat MoveUp Coach
class _CoachCard extends StatelessWidget {
  const _CoachCard();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CoachChatScreen()),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(17),
              gradient: AppTheme.accentGradient,
            ),
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "MOVEUP COACH",
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text("Chat dengan Coach", style: AppTheme.display(20)),
                Text(
                  "Tanya soal latihan, progres, dan targetmu",
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: scheme.primary,
              size: 20,
            ),
          ),
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
              Text(
                "TOTAL JARAK",
                style: AppTheme.display(16, color: faded, letterSpacing: 2),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "${week.length} aktivitas",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
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
              Text(
                formatKm(meters),
                style: AppTheme.display(56, color: Colors.white),
              ),
              const SizedBox(width: 6),
              Text("km", style: AppTheme.display(22, color: faded)),
              const Spacer(),
              Icon(Icons.timer_outlined, size: 18, color: faded),
              const SizedBox(width: 4),
              Text(
                formatDurationShort(seconds),
                style: AppTheme.display(22, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  "AKTIVITAS HARIAN",
                  style: TextStyle(
                    color: faded,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              Text(
                "MINGGU INI",
                style: TextStyle(
                  color: faded,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
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
    final progress = [
      for (final g in GoalStore.instance.goals)
        g.progress(activities, now: now),
    ]..sort((a, b) => b.fraction.compareTo(a.fraction));
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
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              leading: IconBadge(icon: next.first.$1.sportType.icon),
              title: Text(
                "JADWAL BERIKUTNYA",
                style: AppTheme.display(
                  13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  letterSpacing: 1.5,
                ),
              ),
              subtitle: Text(
                "${next.first.$1.title} · ${formatRelativeDateTime(next.first.$2)}",
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReminderScreen()),
              ),
            ),
          ),
        if (progress.isNotEmpty) ...[
          Row(
            children: [
              Expanded(child: Text("Target", style: AppTheme.display(24))),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const GoalsScreen()),
                ),
                child: Text("Lihat semua (${progress.length})"),
              ),
            ],
          ),
          if (ongoing.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                "Semua target periode ini sudah tercapai. Mantap!",
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            for (final p in ongoing)
              GoalProgressCard(
                progress: p,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GoalDetailScreen(goalId: p.goal.id),
                  ),
                ),
              ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}
