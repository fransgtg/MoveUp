import 'dart:math' as math;

import 'package:moveup/models/activity.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/models/reminder.dart';

// Data simulasi untuk akun baru atau saat dimuat ulang dari Pengaturan.
// Tanggal dihitung mundur dari hari ini supaya target mingguan dan bulanan langsung terisi.
class SampleData {
  // (hari lalu, jam, menit, olahraga, km, durasi menit, judul, catatan)
  static const _activitySpecs = <(int, int, int, SportType, double, int, String, String)>[
    (0, 6, 0, SportType.run, 5.2, 31, 'Lari Pagi Keliling Kompleks', 'Kaki terasa ringan hari ini'),
    (1, 17, 15, SportType.walk, 3.4, 42, 'Jalan Sore', ''),
    (2, 6, 10, SportType.ride, 24.5, 70, 'Gowes ke Waduk', 'Angin lumayan kencang di jalan pulang'),
    (3, 5, 45, SportType.run, 8.0, 50, 'Lari Tempo', 'Latihan tempo 3 × 2 km'),
    (3, 19, 0, SportType.walk, 2.7, 38, 'Jalan Malam', ''),
    (5, 7, 0, SportType.hike, 9.6, 185, 'Hiking Bukit Bintang', 'Pemandangan kabut pagi'),
    (6, 6, 5, SportType.run, 12.1, 78, 'Long Run Minggu', ''),
    (7, 17, 30, SportType.walk, 4.1, 50, 'Jalan Santai Taman Kota', ''),
    (8, 6, 0, SportType.run, 5.0, 29, 'Interval 400 m', '8 × 400 m, istirahat 90 detik'),
    (9, 6, 30, SportType.ride, 31.2, 88, 'Gowes Pagi', ''),
    (10, 19, 15, SportType.ride, 9.5, 32, 'Gowes Santai', ''),
    (11, 5, 50, SportType.run, 6.5, 41, 'Lari Pagi', ''),
    (12, 16, 45, SportType.walk, 5.2, 63, 'Jalan ke Pasar', 'Sekalian belanja sayur'),
    (13, 6, 15, SportType.run, 15.0, 98, 'Long Run 15K', 'Persiapan half marathon'),
    (15, 6, 0, SportType.ride, 42.8, 125, 'Gowes Akhir Pekan', 'Rute pantai'),
    (16, 17, 20, SportType.run, 4.8, 30, 'Lari Sore Ringan', 'Pemulihan'),
    (18, 6, 0, SportType.walk, 2.8, 35, 'Jalan Pagi', ''),
    (19, 19, 0, SportType.walk, 3.2, 45, 'Jalan Keliling Taman', ''),
    (20, 5, 40, SportType.run, 10.0, 62, 'Lari 10K', 'Catatan waktu terbaik bulan ini'),
    (22, 7, 30, SportType.hike, 7.2, 150, 'Hiking Curug', ''),
    (24, 6, 10, SportType.run, 7.3, 47, 'Lari Pagi', ''),
    (26, 6, 45, SportType.ride, 18.4, 55, 'Gowes Keliling Kota', ''),
    (28, 17, 0, SportType.walk, 3.9, 47, 'Jalan Sore', ''),
    (31, 6, 0, SportType.run, 9.1, 58, 'Lari Pagi Bersama Komunitas', 'Kumpul di GOR jam 6'),
  ];

  static List<Activity> activities(DateTime now) {
    return [
      for (final (i, spec) in _activitySpecs.indexed)
        _activity('act-${(i + 1).toString().padLeft(2, '0')}', spec, now),
    ];
  }

  static Activity _activity(String id, (int, int, int, SportType, double, int, String, String) spec, DateTime now) {
    final (daysAgo, hour, minute, type, km, minutes, title, description) = spec;
    var start = DateTime(now.year, now.month, now.day - daysAgo, hour, minute);
    // Jangan sampai aktivitas "hari ini" berada di masa depan
    if (start.isAfter(now)) start = start.subtract(const Duration(days: 1));
    return Activity(
      id: id,
      type: type,
      title: title,
      description: description,
      startTime: start,
      movingSeconds: minutes * 60,
      distanceMeters: km * 1000,
      points: routeFor(id, type, km * 1000, minutes * 60),
    );
  }

  static bool isSampleId(String id) => RegExp(r'^act-\d+$').hasMatch(id);

  // Rute contoh untuk aktivitas simulasi; renang di kolam tidak punya rute GPS
  static List<TrackPoint> routeFor(String id, SportType type, double meters, int seconds) =>
      type == SportType.swim || !isSampleId(id) ? const [] : _route(int.parse(id.substring(4)), meters, seconds);

  // Titik awal rute contoh di sekitar Bandung
  static const _starts = [
    (-6.9003, 107.6186), // Gasibu
    (-6.8915, 107.6107), // Dago
    (-6.9218, 107.6071), // Alun-alun
    (-6.8701, 107.5973), // Setiabudi
    (-6.9147, 107.6355), // Antapani
    (-6.8445, 107.6455), // Dago Pakar
  ];

  // Rute melingkar berbentuk tidak beraturan yang panjangnya disamakan dengan [meters].
  // Bentuknya ditentukan [seed] supaya data simulasi selalu sama setiap kali dimuat.
  static List<TrackPoint> _route(int seed, double meters, int seconds) {
    final (lat0, lng0) = _starts[seed % _starts.length];
    final random = math.Random(seed);
    final a = 0.15 + random.nextDouble() * 0.2, b = random.nextDouble() * 0.12;
    final phase = random.nextDouble() * math.pi * 2, stretch = 0.6 + random.nextDouble() * 0.8;
    const n = 160;

    // Bentuk dasar dalam meter, lalu diskalakan ke panjang yang diminta
    final shape = <(double, double)>[];
    for (var i = 0; i <= n; i++) {
      final th = i / n * math.pi * 2;
      final r = 1 + a * math.sin(3 * th + phase) + b * math.sin(7 * th);
      // Titik awal berada di (0, 0) supaya rute mulai dan berakhir di titik start
      shape.add((r * math.cos(th) * stretch - (1 + a * math.sin(phase)) * stretch, r * math.sin(th)));
    }
    var length = 0.0;
    for (var i = 1; i < shape.length; i++) {
      length += math.sqrt(math.pow(shape[i].$1 - shape[i - 1].$1, 2) + math.pow(shape[i].$2 - shape[i - 1].$2, 2));
    }
    final scale = meters / length;
    final mPerLng = 111320 * math.cos(lat0 * math.pi / 180);

    final points = <TrackPoint>[];
    var walked = 0.0;
    for (var i = 0; i < shape.length; i++) {
      if (i > 0) {
        walked += math.sqrt(math.pow(shape[i].$1 - shape[i - 1].$1, 2) + math.pow(shape[i].$2 - shape[i - 1].$2, 2)) * scale;
      }
      final (x, y) = shape[i];
      points.add(TrackPoint(lat0 + y * scale / 111320, lng0 + x * scale / mPerLng, walked / meters * seconds, 0));
    }
    return points;
  }

  static List<Goal> goals(DateTime now) {
    Goal goal(int n, String title, SportType? type, GoalMetric metric, GoalPeriod period, double target) => Goal(
          id: 'goal-0$n',
          title: title,
          sportTypeId: type?.id,
          metric: metric,
          period: period,
          target: target,
          // Selisih menit menjaga urutan tampilan sama seperti daftar ini
          createdAt: now.subtract(Duration(days: 40, minutes: n)),
        );

    return [
      goal(1, 'Lari 20 km per minggu', SportType.run, GoalMetric.distance, GoalPeriod.weekly, 20),
      goal(2, 'Aktif 4 kali seminggu', null, GoalMetric.sessions, GoalPeriod.weekly, 4),
      goal(3, 'Jalan 150 menit seminggu', SportType.walk, GoalMetric.duration, GoalPeriod.weekly, 150),
      goal(4, 'Bakar 5.000 kcal sebulan', null, GoalMetric.calories, GoalPeriod.monthly, 5000),
      goal(5, 'Bersepeda 100 km sebulan', SportType.ride, GoalMetric.distance, GoalPeriod.monthly, 100),
      goal(6, 'Hiking 4 sesi sebulan', SportType.hike, GoalMetric.sessions, GoalPeriod.monthly, 4),
    ];
  }

  static List<Reminder> reminders() => const [
        Reminder(
          id: 'rem-01',
          title: 'Lari Pagi',
          sportTypeId: 'run',
          days: [1, 3, 5],
          hour: 5,
          minute: 30,
          goalId: 'goal-01',
        ),
        Reminder(
          id: 'rem-02',
          title: 'Jalan Sore',
          sportTypeId: 'walk',
          days: [1, 2, 3, 4, 5, 6, 7],
          hour: 17,
          minute: 0,
          goalId: 'goal-03',
        ),
        Reminder(
          id: 'rem-03',
          title: 'Gowes Akhir Pekan',
          sportTypeId: 'ride',
          days: [6, 7],
          hour: 6,
          minute: 30,
          goalId: 'goal-05',
        ),
        Reminder(
          id: 'rem-04',
          title: 'Hiking',
          sportTypeId: 'hike',
          days: [2, 4],
          hour: 19,
          minute: 0,
          enabled: false,
          goalId: 'goal-06',
        ),
      ];
}
