import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/services/activity_store.dart';
import 'package:moveup/services/sample_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final store = ActivityStore.instance;
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('moveup-activity-test');
    messenger.setMockMethodCallHandler(channel, (_) async => directory.path);
  });

  tearDown(() async {
    store.clear();
    messenger.setMockMethodCallHandler(channel, null);
    await directory.delete(recursive: true);
  });

  final recorded = Activity(
    id: '1795752000000',
    type: SportType.run,
    title: 'Lari kamu',
    startTime: DateTime(2026, 11, 27),
    movingSeconds: 600,
    distanceMeters: 1500,
    points: const [TrackPoint(-6.9, 107.6, 0, 0), TrackPoint(-6.91, 107.61, 600, 0)],
  );

  test('akun baru kosong dan riwayat tetap milik akun perekam', () async {
    final legacy = File('${directory.path}/activities.json');
    await legacy.writeAsString(jsonEncode([recorded.toJson()]));

    await store.loadFor('first');
    expect(store.activities, isEmpty);
    expect(await legacy.exists(), isTrue);

    final save = store.add(recorded);
    await store.loadFor('second');
    await save;
    expect(store.activities, isEmpty);

    await store.loadFor('first');
    expect(store.activities.single.toJson(), recorded.toJson());
  });

  test('data simulasi lama dihapus dan rekaman GPS tetap tersimpan', () async {
    final file = await store.fileFor('existing');
    final sample = SampleData.activities(recorded.startTime).first;
    await file.writeAsString(jsonEncode([sample.toJson(), recorded.toJson()]));

    await store.loadFor('existing');
    expect(store.activities.single.toJson(), recorded.toJson());
    expect(jsonDecode(await file.readAsString()), [recorded.toJson()]);
  });
}
