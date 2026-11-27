import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:moveup/firebase_options.dart';
import 'package:sqflite/sqflite.dart';
import 'package:workmanager/workmanager.dart';

enum SocialEvent {
  friend('friendships', 'createdAt'),
  message('chats', 'updatedAt');

  const SocialEvent(this.collection, this.timeField);
  final String collection;
  final String timeField;

  Query<Map<String, dynamic>> query(String uid, int since) => FirebaseFirestore
      .instance
      .collection(collection)
      .where('members', arrayContains: uid)
      .where(
        timeField,
        isGreaterThanOrEqualTo: Timestamp.fromMicrosecondsSinceEpoch(since),
      );

  SocialAlert? incoming(String uid, Map<String, dynamic> data) {
    final sender = data[this == friend ? 'senderId' : 'lastSenderId'];
    if (sender is! String ||
        sender == uid ||
        !(data['members'] as List).contains(uid)) {
      return null;
    }
    if (this == friend && data['status'] != 'pending') return null;
    final time = data[timeField] as Timestamp?;
    if (time == null) return null;
    final name =
        (data['names'] as Map?)?[sender] as String? ?? 'Pengguna MoveUp';
    return SocialAlert(this, uid, sender, name, time.microsecondsSinceEpoch);
  }
}

class SocialAlert {
  const SocialAlert(
    this.event,
    this.recipient,
    this.sender,
    this.name,
    this.time,
  );
  final SocialEvent event;
  final String recipient;
  final String sender;
  final String name;
  final int time;

  String get title => event == SocialEvent.friend
      ? 'Permintaan teman baru'
      : 'Pesan dari $name';
  String get body => event == SocialEvent.friend
      ? 'Buka daftar teman untuk melihat permintaan masuk.'
      : 'Ketuk untuk membuka percakapan.';
  String get tag => '${event.name}:$recipient:$sender';
  String get payload => jsonEncode([event.name, recipient, sender, name, time]);

  static SocialAlert? parse(String? payload) {
    if (payload == null) return null;
    try {
      if (jsonDecode(payload) case [
        String type,
        String uid,
        String sender,
        String name,
        int time,
      ]) {
        final event = SocialEvent.values.asNameMap()[type];
        if (event != null) return SocialAlert(event, uid, sender, name, time);
      }
    } on FormatException {
      return null;
    }
    return null;
  }
}

class SocialNotifications {
  static bool get android =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static final plugin = FlutterLocalNotificationsPlugin();
  static Future<void>? _init;
  static final tapped = ValueNotifier<SocialAlert?>(null);
  static const task = 'moveup-social-notifications';

  static Future<void> initializePlugin() => _init ??= plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_run'),
        ),
        onDidReceiveNotificationResponse: (response) =>
            tapped.value = SocialAlert.parse(response.payload),
      )
      .then((_) {});

  static AndroidFlutterLocalNotificationsPlugin get platform => plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()!;

  static Future<Database> get database => openDatabase(
    'social_notifications.db',
    version: 1,
    onCreate: (db, _) async {
      await db.execute(
        'CREATE TABLE cursors (uid TEXT, kind TEXT, time INTEGER NOT NULL, PRIMARY KEY(uid, kind))',
      );
      await db.execute(
        'CREATE TABLE delivered (tag TEXT PRIMARY KEY, time INTEGER NOT NULL)',
      );
    },
  );

  static Future<int> cursor(String uid, SocialEvent event, int start) async {
    final db = await database;
    await db.insert('cursors', {
      'uid': uid,
      'kind': event.name,
      'time': start,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
    final rows = await db.query(
      'cursors',
      where: 'uid = ? AND kind = ?',
      whereArgs: [uid, event.name],
    );
    return rows.single['time'] as int;
  }

  // Layar dan tugas latar belakang bisa menerima perubahan yang sama.
  static Future<void> deliver(
    SocialAlert alert,
    Future<void> Function() display,
  ) async {
    final db = await database;
    await db.transaction((tx) async {
      final previous = await tx.query(
        'delivered',
        where: 'tag = ?',
        whereArgs: [alert.tag],
      );
      if (previous.isNotEmpty && (previous.single['time'] as int) >= alert.time) {
        return;
      }
      if (FirebaseAuth.instance.currentUser?.uid != alert.recipient) return;
      await display();
      await tx.insert('delivered', {
        'tag': alert.tag,
        'time': alert.time,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  static Future<void> show(SocialAlert alert) => plugin.show(
    id: 7100,
    title: alert.title,
    body: alert.body,
    payload: alert.payload,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'moveup_social',
        'Pesan dan pertemanan',
        importance: Importance.high,
        priority: Priority.high,
        tag: alert.tag,
        visibility: NotificationVisibility.private,
      ),
    ),
  );

  static Future<void> schedule(String uid) async {
    await Workmanager().initialize(socialNotificationWorker);
    await Workmanager().registerPeriodicTask(
      task,
      task,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
      constraints: Constraints(networkType: NetworkType.connected),
      inputData: {'uid': uid},
    );
  }

  static Future<void> clearAccount(String uid) async {
    if (!android) return;
    await Workmanager().cancelByUniqueName(task);
    await initializePlugin();
    for (final notification in await plugin.getActiveNotifications()) {
      if (notification.id == 7100 && notification.tag != null) {
        await plugin.cancel(id: 7100, tag: notification.tag);
      }
    }
    final db = await database;
    await db.delete('cursors', where: 'uid = ?', whereArgs: [uid]);
  }
}

@pragma('vm:entry-point')
void socialNotificationWorker() {
  Workmanager().executeTask((task, data) async {
    if (task != SocialNotifications.task) return true;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    final uid = (await FirebaseAuth.instance.authStateChanges().first)?.uid;
    if (uid == null || uid != data?['uid']) return true;
    await SocialNotifications.initializePlugin();
    if (await SocialNotifications.platform.areNotificationsEnabled() != true) {
      return true;
    }
    for (final event in SocialEvent.values) {
      final since = await SocialNotifications.cursor(
        uid,
        event,
        DateTime.now().microsecondsSinceEpoch,
      );
      final QuerySnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await event
            .query(uid, since)
            .get(const GetOptions(source: Source.server));
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable' || e.code == 'deadline-exceeded') {
          return false;
        }
        rethrow;
      }
      var latest = since;
      for (final doc in snapshot.docs) {
        if (FirebaseAuth.instance.currentUser?.uid != uid) return true;
        final values = doc.data();
        final alert = event.incoming(uid, values);
        if (alert != null) {
          await SocialNotifications.deliver(
            alert,
            () => SocialNotifications.show(alert),
          );
        }
        final time =
            (values[event.timeField] as Timestamp).microsecondsSinceEpoch;
        if (time > latest) latest = time;
      }
      final db = await SocialNotifications.database;
      await db.rawUpdate(
        'UPDATE cursors SET time = ? WHERE uid = ? AND kind = ? AND time < ?',
        [latest, uid, event.name, latest],
      );
    }
    return true;
  });
}
