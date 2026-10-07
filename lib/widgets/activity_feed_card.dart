import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets/activity_media.dart';

// Kartu aktivitas di beranda, bergaya feed Strava
class ActivityFeedCard extends StatelessWidget {
  const ActivityFeedCard({super.key, required this.activity, this.onTap});

  final Activity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (paceLabel, paceValue) = paceOrSpeed(activity);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.onSurface,
                    foregroundColor: scheme.surface,
                    child: Text(ProfileService.instance.profile?.initials ?? '?', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ProfileService.instance.profile?.name ?? 'Pengguna', style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          formatRelativeDateTime(activity.startTime),
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Label jenis olahraga beraksen
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(activity.type.icon, size: 14, color: scheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          activity.type.label,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(activity.title, style: AppTheme.display(24)),
            ),
            if (activity.description.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Text(activity.description, maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    _FeedStat(label: 'Jarak', value: '${formatKm(activity.distanceMeters)} km'),
                    VerticalDivider(width: 24, color: scheme.outline),
                    _FeedStat(label: paceLabel, value: paceValue),
                    VerticalDivider(width: 24, color: scheme.outline),
                    _FeedStat(label: 'Waktu', value: formatDurationShort(activity.movingSeconds)),
                  ],
                ),
              ),
            ),
            // Peta rute lalu foto, bisa digeser seperti feed Strava
            if (ActivityMedia.hasMedia(activity))
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.card - 6),
                  child: ActivityMedia(activity: activity),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedStat extends StatelessWidget {
  const _FeedStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: AppTheme.display(12, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 1.2)),
          const SizedBox(height: 2),
          Text(value, style: AppTheme.display(22), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
