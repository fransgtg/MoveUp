import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/models/reminder.dart';
import 'package:moveup/services/sample_data.dart';
import 'package:moveup/utils/validators.dart';

Activity _activity(String id, SportType type, DateTime start, {double km = 5, int minutes = 30}) => Activity(
      id: id,
      type: type,
      title: id,
      startTime: start,
      movingSeconds: minutes * 60,
      distanceMeters: km * 1000,
    );

Goal _goal({String? sport, GoalMetric metric = GoalMetric.distance, GoalPeriod period = GoalPeriod.weekly, double target = 10}) =>
    Goal(
      id: 'g',
      title: 'Target',
      sportTypeId: sport,
      metric: metric,
      period: period,
      target: target,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  // Kamis, 24 September 2026; minggu berjalan dimulai Senin 21 September
  final now = DateTime(2026, 9, 24, 12);

  group('progres target', () {
    final activities = [
      _activity('a', SportType.run, DateTime(2026, 9, 21, 6), km: 5),
      _activity('b', SportType.run, DateTime(2026, 9, 23, 6), km: 7),
      _activity('c', SportType.ride, DateTime(2026, 9, 22, 6), km: 30),
      // Minggu lalu, tidak dihitung ke target mingguan
      _activity('d', SportType.run, DateTime(2026, 9, 20, 6), km: 10),
    ];

    test('hanya menghitung kategori dan periode yang cocok', () {
      final p = _goal(sport: 'run').progress(activities, now: now);
      expect(p.activities.map((a) => a.id), unorderedEquals(['a', 'b']));
      expect(p.current, 12);
      expect(p.completed, isTrue);
      expect(p.fraction, 1);
    });

    test('target tanpa kategori menghitung semua olahraga', () {
      final p = _goal(metric: GoalMetric.sessions, target: 4).progress(activities, now: now);
      expect(p.current, 3);
      expect(p.remaining, 1);
      expect(p.fraction, 0.75);
    });

    test('periode bulanan mencakup seluruh bulan berjalan', () {
      final p = _goal(sport: 'run', period: GoalPeriod.monthly, target: 50).progress(activities, now: now);
      expect(p.current, 22);
      expect(p.from, DateTime(2026, 9));
      expect(p.to, DateTime(2026, 10));
    });

    test('tersimpan dan terbaca ulang lewat JSON', () {
      final g = _goal(sport: 'swim', metric: GoalMetric.calories, period: GoalPeriod.monthly, target: 3000);
      final copy = Goal.fromJson(g.toJson());
      expect(copy.sportType, SportType.swim);
      expect(copy.metric, GoalMetric.calories);
      expect(copy.period, GoalPeriod.monthly);
      expect(copy.target, 3000);
    });
  });

  group('pengingat', () {
    const reminder = Reminder(id: 'r', title: 'Lari', sportTypeId: 'run', days: [1, 3, 5], hour: 6, minute: 0);

    test('jadwal berikutnya jatuh pada hari terpilih setelah sekarang', () {
      // Kamis siang → Jumat pagi
      expect(reminder.nextAfter(now), DateTime(2026, 9, 25, 6));
      // Jumat pagi sebelum jam 6 → hari itu juga
      expect(reminder.nextAfter(DateTime(2026, 9, 25, 5)), DateTime(2026, 9, 25, 6));
    });

    test('pengingat nonaktif tidak punya jadwal berikutnya', () {
      expect(reminder.copyWith(enabled: false).nextAfter(now), isNull);
    });

    test('label hari', () {
      expect(reminder.daysLabel, 'Sen, Rab, Jum');
      expect(Reminder.fromJson({...reminder.toJson(), 'days': [1, 2, 3, 4, 5]}).daysLabel, 'Senin–Jumat');
      expect(Reminder.fromJson({...reminder.toJson(), 'days': [6, 7]}).daysLabel, 'Akhir pekan');
    });

    test('relasi target bisa dilepas', () {
      final linked = Reminder.fromJson({...reminder.toJson(), 'goalId': 'goal-01'});
      expect(linked.copyWith(goalId: () => null).goalId, isNull);
      expect(linked.copyWith(enabled: false).goalId, 'goal-01');
    });
  });

  group('data simulasi', () {
    test('memenuhi jumlah minimum dan relasinya valid', () {
      final activities = SampleData.activities(now);
      final goals = SampleData.goals(now);
      final reminders = SampleData.reminders();

      expect(activities.length, greaterThanOrEqualTo(20));
      expect(SportType.available, isNot(contains(SportType.swim)));
      expect(activities.map((a) => a.id).toSet().length, activities.length);
      expect(activities.every((a) => !a.startTime.isAfter(now)), isTrue);

      final categoryIds = SportType.available.map((t) => t.id).toSet();
      expect(activities.every((a) => categoryIds.contains(a.type.id)), isTrue);
      final goalIds = goals.map((g) => g.id).toSet();
      expect(goals.every((g) => g.sportTypeId == null || categoryIds.contains(g.sportTypeId)), isTrue);
      expect(reminders.every((r) => categoryIds.contains(r.sportTypeId)), isTrue);
      expect(reminders.every((r) => r.goalId == null || goalIds.contains(r.goalId)), isTrue);
    });
  });

  group('validasi form', () {
    test('judul', () {
      final v = Validators.title(label: 'Nama');
      expect(v(''), 'Nama wajib diisi');
      expect(v('ab'), 'Nama minimal 3 karakter');
      expect(v('Lari pagi'), isNull);
      expect(Validators.title(label: 'Judul', required: false)(''), isNull);
    });

    test('angka positif', () {
      final v = Validators.positiveNumber(label: 'Target', max: 100, unit: 'km');
      expect(v(''), 'Target wajib diisi');
      expect(v('abc'), 'Target harus berupa angka');
      expect(v('0'), 'Target harus lebih dari 0');
      expect(v('150'), 'Target maksimal 100 km');
      expect(v('12,5'), isNull);
    });
  });
}
