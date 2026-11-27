import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/sample_data.dart';
import 'package:moveup/widgets/activity_media.dart';

// Foto aktivitas dan rute peta di riwayat
void main() {
  final start = DateTime(2026, 10, 1, 6);

  test('foto ikut tersimpan dan terbaca ulang lewat JSON', () {
    final a = Activity(
      id: '1',
      type: SportType.run,
      title: 'Lari',
      startTime: start,
      movingSeconds: 600,
      distanceMeters: 2000,
      photos: const ['img_1.jpg', 'img_2.jpg'],
    );
    expect(Activity.fromJson(a.toJson()).photos, ['img_1.jpg', 'img_2.jpg']);
  });

  test('data lama tanpa field photos tetap terbaca', () {
    final json = Activity(id: '1', type: SportType.run, title: 'Lari', startTime: start, movingSeconds: 1, distanceMeters: 1)
        .toJson()
      ..remove('photos');
    expect(Activity.fromJson(json).photos, isEmpty);
  });

  group('rute data simulasi', () {
    final activities = SampleData.activities(DateTime(2026, 10, 3, 12));

    test('setiap aktivitas contoh punya rute', () {
      for (final a in activities) {
        expect(a.hasRoute, isTrue, reason: a.title);
      }
    });

    test('panjang rute sama dengan jarak aktivitas (selisih < 1%)', () {
      for (final a in activities.where((a) => a.hasRoute)) {
        var meters = 0.0;
        for (var i = 1; i < a.points.length; i++) {
          final p = a.points[i - 1], q = a.points[i];
          meters += haversineMeters(p.lat, p.lng, q.lat, q.lng);
        }
        expect((meters - a.distanceMeters).abs() / a.distanceMeters, lessThan(0.01), reason: a.title);
      }
    });

    test('rute berakhir di titik awal dan waktunya sama dengan durasi', () {
      final a = activities.firstWhere((a) => a.hasRoute);
      final first = a.points.first, last = a.points.last;
      expect(haversineMeters(first.lat, first.lng, last.lat, last.lng), lessThan(5));
      expect(last.t, closeTo(a.movingSeconds, 1));
    });

    test('split per km terisi dari rute contoh', () {
      final run = activities.firstWhere((a) => a.type == SportType.run);
      expect(run.splits.length, run.km.ceil());
    });
  });

  test('aktivitas contoh lama dibuang dan catatan manual tetap utuh', () {
    final old = [
      Activity(id: 'act-01', type: SportType.run, title: 'Contoh', startTime: start, movingSeconds: 1800, distanceMeters: 5000),
      Activity(id: '1759300000000', type: SportType.run, title: 'Milik pengguna', startTime: start, movingSeconds: 600, distanceMeters: 2000),
    ];
    final upgraded = ActivityStore.instance.upgrade(old)!;
    expect(upgraded, [old[1]]);
    expect(upgraded.single.hasRoute, isFalse);
    expect(ActivityStore.instance.upgrade(upgraded), isNull);
  });

  testWidgets('thumbnail riwayat memakai ikon olahraga kalau tidak ada foto dan rute', (tester) async {
    final saved = Activity(id: '1', type: SportType.swim, title: 'Renang', startTime: start, movingSeconds: 1, distanceMeters: 1);
    final a = Activity.fromJson(saved.toJson());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ActivityThumbnail(activity: a))));
    expect(find.byIcon(SportType.swim.icon), findsOneWidget);
  });

  testWidgets('galeri tidak tampil untuk aktivitas tanpa foto dan rute', (tester) async {
    final a = Activity(id: '1', type: SportType.swim, title: 'Renang', startTime: start, movingSeconds: 1, distanceMeters: 1);
    expect(ActivityMedia.hasMedia(a), isFalse);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ActivityMedia(activity: a))));
    expect(find.byType(PageView), findsNothing);
  });
}
