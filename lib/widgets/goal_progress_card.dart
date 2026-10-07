import 'package:flutter/material.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/widgets.dart';

// Kartu ringkas satu target beserta progres periode berjalan
class GoalProgressCard extends StatelessWidget {
  const GoalProgressCard({super.key, required this.progress, this.onTap});

  final GoalProgress progress;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final goal = progress.goal;
    final scheme = Theme.of(context).colorScheme;
    final done = progress.completed;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(icon: goal.icon, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      goal.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (done) const GoalDoneBadge(),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                "${goal.categoryLabel} · ${goal.period.label}",
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: progress.fraction,
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
                color: done ? AppTheme.success : scheme.primary,
                backgroundColor: scheme.outline.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    "${goal.metric.format(progress.current)} / ${goal.targetLabel}",
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    "${(progress.fraction * 100).round()}%",
                    style: AppTheme.display(18, color: done ? AppTheme.success : scheme.primary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GoalDoneBadge extends StatelessWidget {
  const GoalDoneBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.success, borderRadius: BorderRadius.circular(12)),
      child: const Text(
        "Tercapai",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}
