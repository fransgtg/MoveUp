import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/services/chat_service.dart';
import 'package:moveup/services/friendship_service.dart';

// Satu set listener per akun, dipakai bersama oleh beranda, profil, dan daftar chat.
class AccountInbox extends StatefulWidget {
  const AccountInbox({super.key, required this.uid, required this.child});
  final String? uid;
  final Widget child;

  @override
  State<AccountInbox> createState() => _AccountInboxState();
}

class _AccountInboxState extends State<AccountInbox> {
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _messages = <String, ({Timestamp? through, StreamSubscription<int> sub})>{};
  List<Chat> _chats = [];
  Map<String, Timestamp>? _reads;
  Map<String, int> _counts = {};
  int _requests = 0;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(AccountInbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uid != widget.uid) {
      _stop();
      _listen();
    }
  }

  void _listen() {
    final uid = widget.uid;
    if (uid == null) return;
    _subscriptions.add(FriendshipService.watch(uid).listen((items) {
      if (!mounted || widget.uid != uid) return;
      final count = items.where((f) => !f.isAccepted && f.senderId != uid).length;
      if (count != _requests) setState(() => _requests = count);
    }, onError: _logError));
    _subscriptions.add(ChatService.chatsOf(uid).listen((items) {
      if (!mounted || widget.uid != uid) return;
      _chats = items;
      _watchMessages(uid);
    }, onError: _logError));
    _subscriptions.add(ChatService.readPositions(uid).listen((items) {
      if (!mounted || widget.uid != uid) return;
      _reads = items;
      _watchMessages(uid);
    }, onError: _logError));
  }

  void _watchMessages(String uid) {
    final reads = _reads;
    if (reads == null) return;
    final ids = _chats.map((chat) => chat.id).toSet();
    for (final id in _messages.keys.where((id) => !ids.contains(id)).toList()) {
      _messages.remove(id)?.sub.cancel();
      setState(() => _counts = {..._counts}..remove(id));
    }
    for (final chat in _chats) {
      final through = reads[chat.id];
      final previous = _messages[chat.id];
      if (previous != null && previous.through == through) continue;
      previous?.sub.cancel();
      final sub = ChatService.unreadMessages(chat.id, chat.otherUid(uid), through)
          .listen((count) {
        if (!mounted || widget.uid != uid || _reads?[chat.id] != through) return;
        if ((_counts[chat.id] ?? 0) != count) {
          setState(() => _counts = {..._counts, chat.id: count});
        }
      }, onError: _logError);
      _messages[chat.id] = (through: through, sub: sub);
    }
  }

  void _logError(Object error) => debugPrint('Gagal memuat badge: $error');

  void _stop() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    for (final watch in _messages.values) {
      watch.sub.cancel();
    }
    _subscriptions.clear();
    _messages.clear();
    _counts = {};
    _chats = [];
    _reads = null;
    _requests = 0;
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _InboxCounts(
    messages: _counts, requests: _requests, child: widget.child,
  );
}

class _InboxCounts extends InheritedWidget {
  const _InboxCounts({required this.messages, required this.requests, required super.child});
  final Map<String, int> messages;
  final int requests;

  @override
  bool updateShouldNotify(_InboxCounts oldWidget) =>
      messages != oldWidget.messages || requests != oldWidget.requests;
}

class InboxBadge extends StatelessWidget {
  const InboxBadge.messages(this.child, {super.key, this.chatId}) : friends = false;
  const InboxBadge.friends(this.child, {super.key}) : friends = true, chatId = null;
  final Widget child;
  final bool friends;
  final String? chatId;

  @override
  Widget build(BuildContext context) {
    final inbox = context.dependOnInheritedWidgetOfExactType<_InboxCounts>();
    if (inbox == null) return child;
    final count = friends
        ? inbox.requests
        : chatId != null
        ? inbox.messages[chatId] ?? 0
        : inbox.messages.values.fold<int>(0, (sum, n) => sum + n);
    return Badge.count(count: count, maxCount: 99, isLabelVisible: count > 0, child: child);
  }
}
