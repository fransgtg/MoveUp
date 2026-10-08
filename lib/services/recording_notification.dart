import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Notifikasi rekaman yang tampil di status bar dan layar kunci (Android).
// Notifikasi ini sekaligus foreground service bertipe lokasi, jadi GPS tetap jalan saat layar mati.
class RecordingNotification {
  static const _id = 7001;
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  static bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> _init() async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_run')),
    );
    _initialized = true;
  }

  // Harus dipanggil saat aplikasi di depan layar; Android 12+ melarang memulai foreground service dari latar belakang
  static Future<void> start({required String title, required String body, required Duration elapsed}) async {
    if (!supported) return;
    await _init();
    // Android 13+ meminta izin notifikasi. Kalau ditolak, service tetap jalan tapi notifikasinya tersembunyi
    await _android?.requestNotificationsPermission();
    await _android?.startForegroundService(
      id: _id,
      title: title,
      body: body,
      notificationDetails: _details(running: true, elapsed: elapsed),
      startType: AndroidServiceStartType.startNotSticky,
      foregroundServiceTypes: {AndroidServiceForegroundType.foregroundServiceTypeLocation},
    );
  }

  static Future<void> update({
    required String title,
    required String body,
    required bool running,
    required Duration elapsed,
  }) async {
    if (!supported || !_initialized) return;
    await _plugin.show(
      id: _id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(android: _details(running: running, elapsed: elapsed)),
    );
  }

  static Future<void> stop() async {
    if (!supported || !_initialized) return;
    await _android?.stopForegroundService();
  }

  // Saat merekam, jam di notifikasi berjalan sendiri (chronometer) tanpa perlu diperbarui tiap detik.
  // Saat dijeda, chronometer dimatikan dan waktu ditulis di judul.
  static AndroidNotificationDetails _details({required bool running, required Duration elapsed}) =>
      AndroidNotificationDetails(
        'recording',
        'Rekaman aktivitas',
        channelDescription: 'Waktu, jarak, dan pace selama merekam aktivitas',
        importance: Importance.low,
        priority: Priority.low,
        category: AndroidNotificationCategory.workout,
        visibility: NotificationVisibility.public,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        playSound: false,
        enableVibration: false,
        channelShowBadge: false,
        showWhen: running,
        usesChronometer: running,
        when: DateTime.now().subtract(elapsed).millisecondsSinceEpoch,
      );
}
