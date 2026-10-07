import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/screens/activity_detail_screen.dart';
import 'package:moveup/screens/add_activity_screen.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/widgets/activity_media.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // null berarti semua jenis olahraga
  SportType? _filter;

  @override
  Widget build(BuildContext context) {
    final store = ActivityStore.instance;

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, AppSpacing.sm),
            child: ScreenHeader(
              subtitle: _filter?.label ?? "Semua aktivitas",
              title: "RIWAYAT",
              actions: [
                PopupMenuButton<String>(
                  icon: Icon(_filter == null ? Icons.filter_alt_outlined : Icons.filter_alt,
                      color: _filter == null ? null : AppTheme.accent),
                  tooltip: "Filter olahraga",
                  onSelected: (value) => setState(() => _filter = value == 'all' ? null : SportType.fromName(value)),
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'all', child: Text("Semua")),
                    for (final type in SportType.values)
                      PopupMenuItem(value: type.name, child: Text(type.label)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                final activities =
                    store.activities.where((a) => _filter == null || a.type == _filter).toList();
                if (activities.isEmpty) {
                  // Kosong karena filter berbeda dengan kosong karena belum pernah mencatat
                  if (_filter != null) {
                    return EmptyStateWidget(
                      title: "Tidak ada ${_filter!.label.toLowerCase()}",
                      message: "Belum ada aktivitas dengan jenis ini.",
                      icon: Icons.filter_alt_off_outlined,
                    );
                  }
                  return EmptyStateWidget(
                    title: "Belum ada aktivitas",
                    message: "Aktivitas yang direkam atau dicatat manual akan muncul di sini.",
                    icon: Icons.history,
                    actionLabel: "Catat Manual",
                    onAction: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AddActivityScreen())),
                  );
                }

                // Judul bulan disisipkan di antara aktivitas; ListView.builder supaya peta hanya dibuat saat terlihat
                final rows = <Object>[];
                String? lastMonth;
                for (final a in activities) {
                  final month = "${monthNames[a.startTime.month - 1]} ${a.startTime.year}";
                  if (month != lastMonth) rows.add(month);
                  lastMonth = month;
                  rows.add(a);
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, 100),
                  itemCount: rows.length,
                  itemBuilder: (context, i) => switch (rows[i]) {
                    final String month => Padding(
                        padding: const EdgeInsets.fromLTRB(AppSpacing.xs, AppSpacing.lg, 0, AppSpacing.sm),
                        child: Text(
                          month.toUpperCase(),
                          style: AppTheme.display(15, color: Theme.of(context).colorScheme.onSurfaceVariant, letterSpacing: 2),
                        ),
                      ),
                    final Activity a => _HistoryTile(
                        activity: a,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ActivityDetailScreen(activity: a)),
                        ),
                      ),
                    _ => const SizedBox.shrink(),
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Satu baris riwayat: thumbnail foto atau peta rute, judul, waktu, dan statistik utama
class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.activity, required this.onTap});

  final Activity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = activity;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final (paceLabel, paceValue) = paceOrSpeed(a);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ActivityThumbnail(activity: a),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(a.type.icon, size: 16, color: muted),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        formatRelativeDateTime(a.startTime),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: muted),
                      ),
                    ),
                    if (a.photos.isNotEmpty) ...[
                      Icon(Icons.photo_outlined, size: 14, color: muted),
                      Text(" ${a.photos.length}", style: TextStyle(fontSize: 12, color: muted)),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  a.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _MiniStat("Jarak", "${formatKm(a.distanceMeters)} km"),
                    _MiniStat(paceLabel, paceValue),
                    _MiniStat("Waktu", formatDurationShort(a.movingSeconds)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.display(18)),
        ],
      ),
    );
  }
}
