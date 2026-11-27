import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:moveup/screens/chat_room_screen.dart';
import 'package:moveup/screens/friends_screen.dart';
import 'package:moveup/services/social_notifications.dart';

class SocialNotificationListener extends StatefulWidget {
  const SocialNotificationListener({
    super.key,
    required this.uid,
    required this.child,
  });

  final String uid;
  final Widget child;

  @override
  State<SocialNotificationListener> createState() =>
      _SocialNotificationListenerState();
}

class _SocialNotificationListenerState
    extends State<SocialNotificationListener> {
  final _streams = <StreamSubscription<void>>[];
  final _seen = <String, int>{};
  static bool _launchChecked = false;

  bool get _active =>
      mounted && FirebaseAuth.instance.currentUser?.uid == widget.uid;

  @override
  void initState() {
    super.initState();
    SocialNotifications.tapped.addListener(_handleTap);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_active) unawaited(_start());
    });
  }

  Future<void> _start() async {
    final start = DateTime.now().microsecondsSinceEpoch;
    try {
      for (final event in SocialEvent.values) {
        final since = SocialNotifications.android
            ? await SocialNotifications.cursor(widget.uid, event, start)
            : start;
        if (!_active) return;
        final stream = event.query(widget.uid, since).snapshots();
        _streams.add(
          stream
              .asyncMap((snapshot) async {
                for (final change in snapshot.docChanges) {
                  if (!_active) return;
                  if (change.type == DocumentChangeType.removed ||
                      change.doc.metadata.hasPendingWrites) {
                    continue;
                  }
                  final alert = event.incoming(widget.uid, change.doc.data()!);
                  if (alert != null) await _notify(alert);
                }
              })
              .listen(
                (_) {},
                onError: (Object e) =>
                    debugPrint('Notifikasi ${event.name}: $e'),
              ),
        );
      }
      if (!SocialNotifications.android) return;
      await SocialNotifications.initializePlugin();
      if (!_active) return;
      if (!_launchChecked) {
        final launch = await SocialNotifications.plugin
            .getNotificationAppLaunchDetails();
        if (!_active) return;
        _launchChecked = true;
        if (launch?.didNotificationLaunchApp == true) {
          SocialNotifications.tapped.value = SocialAlert.parse(
            launch?.notificationResponse?.payload,
          );
        }
      }
      _handleTap();
      await SocialNotifications.platform.requestNotificationsPermission();
      if (_active) await SocialNotifications.schedule(widget.uid);
    } catch (e) {
      debugPrint('Gagal memulai notifikasi: $e');
    }
  }

  Future<void> _notify(SocialAlert alert) async {
    if (SocialNotifications.android) {
      await SocialNotifications.initializePlugin();
      await SocialNotifications.deliver(alert, () async {
        if (!_active) return;
        if (await SocialNotifications.platform.areNotificationsEnabled() ==
            true) {
          if (_active) await SocialNotifications.show(alert);
        } else if (_active) {
          _banner(alert);
        }
      });
    } else if ((_seen[alert.tag] ?? 0) < alert.time) {
      _seen[alert.tag] = alert.time;
      _banner(alert);
    }
  }

  void _banner(SocialAlert alert) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(alert.title),
        action: SnackBarAction(label: 'Buka', onPressed: () => _open(alert)),
      ),
    );
  }

  void _handleTap() {
    final alert = SocialNotifications.tapped.value;
    if (alert == null || !_active) return;
    SocialNotifications.tapped.value = null;
    _open(alert);
  }

  void _open(SocialAlert alert) {
    if (!_active || alert.recipient != widget.uid) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => alert.event == SocialEvent.friend
            ? const FriendsScreen()
            : ChatRoomScreen(otherUid: alert.sender, otherName: alert.name),
      ),
    );
  }

  @override
  void dispose() {
    SocialNotifications.tapped.removeListener(_handleTap);
    for (final subscription in _streams) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
