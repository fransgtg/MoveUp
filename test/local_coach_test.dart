import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/goal.dart';
import 'package:moveup/models/user_profile.dart';
import 'package:moveup/services/local_coach.dart';

// Coach offline: topik dikenali dari kata kunci dan jawaban memakai data pengguna
void main() {
  // Kamis, 8 Oktober 2026; minggu berjalan dimulai Senin 5 Oktober
  final now = DateTime(2026, 10, 8, 19);

  final profile = UserProfile(
    uid: 'u1',
    name: 'Budi Santoso',
    email: 'budi@example.com',
    gender: Gender.male,
    birthDate: DateTime(2000, 1, 1),
    weightKg: 70,
    heightCm: 175,
    level: FitnessLevel.beginner,
    favoriteSports: const [SportType.run],
  );

  Activity run(String id, DateTime start, double km, int minutes) => Activity(
        id: id,
        type: SportType.run,
        title: 'Lari',
        startTime: start,
        movingSeconds: minutes * 60,
        distanceMeters: km * 1000,
      );

  final activities = [
    run('1', DateTime(2026, 10, 6, 6), 5, 30), // minggu ini
    run('2', DateTime(2026, 10, 7, 6), 3, 18), // minggu ini
    run('3', DateTime(2026, 9, 30, 6), 4, 26), // minggu lalu
  ];

  final goal = Goal(
    id: 'g1',
    title: 'Lari 20 km',
    sportTypeId: 'run',
    metric: GoalMetric.distance,
    period: GoalPeriod.weekly,
    target: 20,
    createdAt: DateTime(2026, 9, 1),
  );

  LocalCoach coach({List<Activity>? list, List<Goal> goals = const []}) =>
      LocalCoach(profile: profile, activities: list ?? activities, goals: goals, now: now);

  test('progres minggu ini dibandingkan dengan minggu lalu', () {
    final reply = coach().reply('Bagaimana progres latihanku minggu ini?');
    expect(reply, contains('**2 aktivitas**'));
    expect(reply, contains('**8,0 km**'));
    expect(reply, contains('Naik 100%'));
  });

  test('progres tanpa aktivitas minggu ini tetap memberi dorongan', () {
    final reply = coach(list: [activities[2]]).reply('progres');
    expect(reply, contains('belum mencatat aktivitas'));
    expect(reply, contains('4,0 km'));
  });

  test('target menghitung sisa dan kebutuhan per hari', () {
    final reply = coach(goals: [goal]).reply('targetku gimana?');
    expect(reply, contains('**Lari 20 km**: 40%'));
    // Sisa 12 km dalam 4 hari (Kamis sampai Minggu)
    expect(reply, contains('Kurang 12,0 km dalam 4 hari'));
    expect(reply, contains('3,0 km per hari'));
  });

  test('rencana mingguan untuk pemula berisi 3 sesi', () {
    final reply = coach().reply('Buatkan rencana latihan untuk minggu depan');
    expect(reply, contains('level **Pemula**'));
    expect(RegExp(r'km tempo nyaman|sesi panjang').allMatches(reply).length, 3);
    expect('istirahat atau jalan santai'.allMatches(reply).length, 4);
  });

  test('keluhan kesehatan didahulukan dari topik lain', () {
    final reply = coach().reply('Lututku sakit setelah lari, bagaimana rencana minggu depan?');
    expect(reply, contains('hentikan latihan sekarang'));
  });

  test('pace memakai rata-rata lari terakhir', () {
    final reply = coach().reply('Tips meningkatkan pace lari');
    // 74 menit untuk 12 km = 6:10 /km
    expect(reply, contains('**6:10 /km**'));
  });

  test('kata pendek tidak salah cocok di tengah kata lain', () {
    // "hi" di "hiking" bukan sapaan
    expect(coach().reply('hiking'), startsWith('Maaf, aku belum paham'));
    expect(coach().reply('hi coach'), startsWith('Halo, Budi!'));
  });

  test('pertanyaan yang tidak dikenali menampilkan daftar bantuan', () {
    expect(coach().reply('siapa presiden pertama?'), contains('Aku bisa membantu soal'));
  });
}
