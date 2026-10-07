import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/services/voice_coach.dart';

// Pengumuman suara setiap 1 km saat merekam
void main() {
  // Mensimulasikan GPS: titik tiap 10 m dengan kecepatan [secondsPerKm] untuk masing-masing kilometer
  List<String> run(KmAnnouncer a, List<double> secondsPerKm) {
    final said = <String>[];
    var meters = 0.0, seconds = 0.0;
    for (final pace in secondsPerKm) {
      for (var i = 0; i < 100; i++) {
        final m = meters + 10, s = seconds + pace / 100;
        said.addAll(a.update(fromMeters: meters, fromSeconds: seconds, toMeters: m, toSeconds: s));
        meters = m;
        seconds = s;
      }
    }
    return said;
  }

  test('satu pengumuman untuk setiap kilometer yang dilewati', () {
    expect(run(KmAnnouncer(SportType.run), [360, 360, 360]).length, 3);
  });

  test('belum ada pengumuman sebelum 1 km', () {
    final a = KmAnnouncer(SportType.run);
    expect(a.update(fromMeters: 0, fromSeconds: 0, toMeters: 999, toSeconds: 300), isEmpty);
  });

  test('kilometer pertama menyebut jarak, waktu, dan pace', () {
    final said = run(KmAnnouncer(SportType.run), [362]);
    expect(said.single, 'Jarak 1 kilometer. Waktu 6 menit 2 detik. Pace kilometer ini 6 menit 2 detik per kilometer.');
  });

  test('kilometer berikutnya dibandingkan dengan kilometer sebelumnya', () {
    final said = run(KmAnnouncer(SportType.run), [377, 365, 380]);
    expect(said[1], contains('Pace kilometer ini 6 menit 5 detik per kilometer.'));
    expect(said[1], contains('12 detik lebih cepat dari kilometer sebelumnya.'));
    expect(said[1], contains('Pace rata-rata 6 menit 11 detik per kilometer.'));
    expect(said[2], contains('15 detik lebih lambat dari kilometer sebelumnya.'));
  });

  test('lompatan GPS yang melewati dua kilometer sekaligus menghasilkan dua pengumuman', () {
    final a = KmAnnouncer(SportType.run);
    final said = a.update(fromMeters: 900, fromSeconds: 300, toMeters: 2100, toSeconds: 700);
    expect(said.length, 2);
    expect(said[1], startsWith('Jarak 2 kilometer.'));
  });

  test('bersepeda memakai kecepatan, bukan pace', () {
    final said = run(KmAnnouncer(SportType.ride), [180, 150]);
    expect(said[0], contains('Kecepatan kilometer ini 20,0 kilometer per jam.'));
    expect(said[1], contains('4,0 kilometer per jam lebih cepat dari kilometer sebelumnya.'));
    expect(said[1], isNot(contains('Pace')));
  });

  test('durasi diucapkan dalam jam, menit, dan detik', () {
    expect(KmAnnouncer.spokenDuration(754), '12 menit 34 detik');
    expect(KmAnnouncer.spokenDuration(3725), '1 jam 2 menit 5 detik');
    expect(KmAnnouncer.spokenDuration(360), '6 menit');
  });

  test('kata pace dieja ulang agar dilafalkan benar oleh suara Indonesia', () {
    expect(VoiceCoach.forIndonesianSpeech('Pace kilometer ini 6 menit. Pace rata-rata 6 menit.'),
        'Peis kilometer ini 6 menit. Peis rata-rata 6 menit.');
    expect(VoiceCoach.forIndonesianSpeech('tips pace lari'), 'tips peis lari');
    expect(VoiceCoach.forIndonesianSpeech('Jarak 1 kilometer.'), 'Jarak 1 kilometer.');
  });
}
