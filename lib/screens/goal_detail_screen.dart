import 'package:flutter/material.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/screens/activity_detail_screen.dart';
import 'package:moveup/screens/goal_form_screen.dart';
import 'package:moveup/screens/reminder_form_screen.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/goal_store.dart';
import 'package:moveup/services/reminder_store.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/widgets/goal_progress_card.dart';
import 'package:moveup/widgets/like_button.dart';

class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  Future<void> _confirmDelete(BuildContext context, Goal goal) async {
    final linked = ReminderStore.instance.forGoal(goal.id).length;
    final delete = await showConfirmDialog(
      context,
      title: "Hapus target?",
      message:
          "\"${goal.title}\" akan dihapus permanen."
          "${linked > 0 ? "\n\n$linked pengingat yang terhubung tetap disimpan tanpa target." : ""}",
      confirmLabel: "Hapus",
    );
    if (!delete || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    await GoalStore.instance.remove(goal.id);
    messenger.success("Target dihapus");
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        GoalStore.instance,
        ActivityStore.instance,
        ReminderStore.instance,
      ]),
      builder: (context, _) {
        final goal = GoalStore.instance.byId(goalId);
        if (goal == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyStateWidget(
              message: "Target tidak ditemukan",
              icon: Icons.search_off,
            ),
          );
        }
        return _build(context, goal);
      },
    );
  }

  Widget _build(BuildContext context, Goal goal) {
    final scheme = Theme.of(context).colorScheme;
    final progress = goal.progress(ActivityStore.instance.activities);
    final reminders = ReminderStore.instance.forGoal(goal.id);
    final lastDay = progress.to.subtract(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Detail Target"),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: "Edit",
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => GoalFormScreen(goal: goal)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: "Hapus",
            onPressed: () => _confirmDelete(context, goal),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              Expanded(child: Text(goal.title, style: AppTheme.display(30))),
              if (progress.completed) const GoalDoneBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: LikeButton(type: 'goal', id: goal.id),
          ),
          const SizedBox(height: 4),
          Text(
            "${goal.period.label} · ${formatDate(progress.from)} – ${formatDate(lastDay)}",
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: progress.fraction,
                    strokeWidth: 12,
                    backgroundColor: scheme.outline.withValues(alpha: 0.3),
                  ),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "${(progress.fraction * 100).round()}%",
                          style: AppTheme.display(44),
                        ),
                        Text(
                          "${goal.metric.format(progress.current)} / ${goal.targetLabel}",
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              progress.completed
                  ? "Target ${goal.period.currentLabel} sudah tercapai!"
                  : "Kurang ${goal.metric.format(progress.remaining)} ${goal.metric.unit} lagi ${goal.period.currentLabel}",
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                _infoRow(
                  context,
                  Icons.category_outlined,
                  "Kategori",
                  goal.categoryLabel,
                ),
                _infoRow(
                  context,
                  goal.metric.icon,
                  "Ukuran",
                  goal.metric.label,
                ),
                _infoRow(
                  context,
                  Icons.flag_outlined,
                  "Target",
                  "${goal.targetLabel} per ${goal.period == GoalPeriod.weekly ? 'minggu' : 'bulan'}",
                ),
                _infoRow(
                  context,
                  Icons.calendar_today_outlined,
                  "Dibuat",
                  formatDate(goal.createdAt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(child: Text("Pengingat", style: AppTheme.display(22))),
              TextButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text("Tambah"),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReminderFormScreen(initialGoal: goal),
                  ),
                ),
              ),
            ],
          ),
          if (reminders.isEmpty)
            Text(
              "Belum ada pengingat untuk target ini.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final r in reminders)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  r.enabled
                      ? Icons.notifications_active_outlined
                      : Icons.notifications_off_outlined,
                ),
                title: Text(r.title),
                subtitle: Text(
                  "${r.daysLabel} · ${r.timeLabel}${r.enabled ? '' : ' · nonaktif'}",
                ),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ReminderFormScreen(reminder: r),
                  ),
                ),
              ),
          const SizedBox(height: 16),
          Text(
            "Aktivitas ${goal.period.currentLabel} (${progress.activities.length})",
            style: AppTheme.display(22),
          ),
          const SizedBox(height: 8),
          if (progress.activities.isEmpty)
            Text(
              "Belum ada aktivitas yang dihitung pada periode ini.",
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final a in progress.activities)
              ActivityCard(
                title: a.title,
                subtitle: formatRelativeDateTime(a.startTime),
                primaryValue:
                    "+${goal.metric.format(goal.metric.valueOf(a))} ${goal.metric.unit}",
                secondaryValue: a.type.label,
                icon: a.type.icon,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ActivityDetailScreen(activity: a),
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
