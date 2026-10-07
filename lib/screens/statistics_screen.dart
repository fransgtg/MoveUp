import 'package:flutter/material.dart';
import 'package:moveup/theme.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _monthly = false;
  // null berarti semua jenis olahraga
  SportType? _sport;

  bool _matches(Activity a) => _sport == null || a.type == _sport;

  @override
  Widget build(BuildContext context) {
    final store = ActivityStore.instance;

    return SafeArea(
      child: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final now = DateTime.now();
          final DateTime from;
          final DateTime to;
          final List<String> labels;
          final int todayIndex;
          if (_monthly) {
            from = DateTime(now.year, now.month);
            to = DateTime(now.year, now.month + 1);
            final days = to.difference(from).inDays;
            labels = [for (var d = 1; d <= days; d++) d == 1 || d % 5 == 0 ? "$d" : ""];
            todayIndex = now.day - 1;
          } else {
            from = startOfWeek(now);
            to = from.add(const Duration(days: 7));
            labels = dayInitials;
            todayIndex = now.weekday - 1;
          }

          final period = store.between(from, to).where(_matches).toList();
          final distance = List<double>.filled(labels.length, 0);
          final calories = List<double>.filled(labels.length, 0);
          var meters = 0.0;
          var seconds = 0;
          for (final a in period) {
            final i = _monthly ? a.startTime.day - 1 : a.startTime.weekday - 1;
            distance[i] += a.km;
            calories[i] += a.calories;
            meters += a.distanceMeters;
            seconds += a.movingSeconds;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpacing.xl, AppSpacing.lg, AppSpacing.xl, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScreenHeader(subtitle: _monthly ? monthNames[now.month - 1] : "Minggu ini", title: "STATISTIK"),
                const SizedBox(height: 20),
                _buildToggle(context),
                const SizedBox(height: 12),
                _buildSportFilter(),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildStatItem(Icons.local_fire_department_outlined, "Sesi", "${period.length}"),
                    const SizedBox(width: AppSpacing.md),
                    _buildStatItem(Icons.timer_outlined, "Durasi", formatDurationShort(seconds)),
                    const SizedBox(width: AppSpacing.md),
                    _buildStatItem(Icons.straighten, "Km", formatKm(meters, decimals: 1)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildChartCard("Jarak", "km", distance, labels, todayIndex),
                const SizedBox(height: AppSpacing.lg),
                _buildChartCard("Kalori Terbakar", "kkal", calories, labels, todayIndex),
                const SizedBox(height: 28),
                Text("Rekor Pribadi", style: AppTheme.display(24)),
                const SizedBox(height: 12),
                ..._buildRecords(store.activities.where(_matches).toList()),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildToggle(BuildContext context) {
    Widget option(String label, bool monthly) {
      final selected = _monthly == monthly;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _monthly = monthly),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: selected ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Row(children: [option("Mingguan", false), option("Bulanan", true)]),
    );
  }

  Widget _buildSportFilter() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            label: const Text("Semua"),
            selected: _sport == null,
            onSelected: (_) => setState(() => _sport = null),
          ),
          for (final type in SportType.values) ...[
            const SizedBox(width: 8),
            ChoiceChip(
              avatar: Icon(type.icon, size: 18),
              label: Text(type.label),
              selected: _sport == type,
              onSelected: (_) => setState(() => _sport = type),
            ),
          ],
        ],
      ),
    );
  }

  // Rekor dihitung terpisah per olahraga supaya bersepeda tidak mengalahkan lari
  List<Widget> _buildRecords(List<Activity> activities) {
    final cards = [
      for (final type in SportType.values)
        if (activities.any((a) => a.type == type))
          _buildSportRecords(type, activities.where((a) => a.type == type).toList()),
    ];
    if (cards.isEmpty) {
      return [Text("Rekor muncul setelah Anda menyimpan aktivitas.", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))];
    }
    return cards;
  }

  Widget _buildSportRecords(SportType type, List<Activity> list) {
    final longest = list.reduce((a, b) => a.distanceMeters >= b.distanceMeters ? a : b);
    final longestTime = list.reduce((a, b) => a.movingSeconds >= b.movingSeconds ? a : b);
    // Minimal 1 km supaya rekaman sangat pendek tidak jadi rekor kecepatan
    final eligible = list.where((a) => a.km >= 1).toList();
    final fastest = eligible.isEmpty ? null : eligible.reduce((a, b) => a.speedKmh >= b.speedKmh ? a : b);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                IconBadge(icon: type.icon, size: 18),
                const SizedBox(width: 12),
                Text(type.label, style: AppTheme.display(20)),
              ],
            ),
          ),
          _recordTile(Icons.straighten, "Jarak terjauh", "${formatKm(longest.distanceMeters)} km", longest),
          _recordTile(Icons.timer_outlined, "Durasi terlama", formatDuration(longestTime.movingSeconds), longestTime),
          if (fastest != null)
            type.showsSpeed
                ? _recordTile(Icons.bolt, "Kecepatan rata-rata tertinggi", "${formatSpeed(fastest.speedKmh)} km/j", fastest)
                : _recordTile(Icons.bolt, "Pace tercepat", "${formatPace(fastest.paceSecPerKm)} /km", fastest),
        ],
      ),
    );
  }

  Widget _recordTile(IconData icon, String label, String value, Activity from) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text("${from.title} · ${formatDate(from.startTime)}", style: const TextStyle(fontSize: 12)),
      trailing: Text(value, style: AppTheme.display(20, color: AppTheme.accent)),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String val) {
    final scheme = Theme.of(context).colorScheme;
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppTheme.accent),
              const SizedBox(height: AppSpacing.sm),
              FittedBox(child: Text(val, style: AppTheme.display(28))),
              Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChartCard(String title, String unit, List<double> values, List<String> labels, int todayIndex) {
    final total = values.fold<double>(0, (sum, v) => sum + v);
    final totalLabel = unit == "km" ? total.toStringAsFixed(1).replaceAll('.', ',') : total.round().toString();
    return AppCard(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(child: Text(title, style: AppTheme.display(20))),
              Text(totalLabel, style: AppTheme.display(20, color: AppTheme.accent)),
              const SizedBox(width: 4),
              Text(unit, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SimpleBarChart(values: values, labels: labels, highlightIndex: todayIndex),
        ],
      ),
    );
  }
}
