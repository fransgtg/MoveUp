import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/screens/activity_community_screen.dart';
import 'package:moveup/services/auth_service.dart';
import 'package:moveup/services/chat_service.dart';
import 'package:moveup/services/profile_service.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';
import 'package:moveup/widgets/like_button.dart';

// Ruang chat dua orang, diperbarui langsung dari Firestore
class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.otherUid,
    required this.otherName,
  });

  final String otherUid;
  final String otherName;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final _controller = TextEditingController();
  late final String _me = AuthService.currentUser!.uid;
  late final Stream<List<ChatMessage>> _messages = ChatService.messagesOf(
    Chat.idFor(_me, widget.otherUid),
  );
  late final AppLifecycleListener _lifecycle;
  DateTime? _readThrough;
  bool _marking = false;
  Timer? _retry;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: () => setState(() {}));
  }

  void _recordVisibleMessages(List<ChatMessage> messages) {
    final latest = messages.where((m) => !m.pending).firstOrNull?.createdAt;
    if (latest == null || _marking || _retry != null ||
        (_readThrough != null && !latest.isAfter(_readThrough!))) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _marking || ModalRoute.of(context)?.isCurrent != true ||
          WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed ||
          AuthService.currentUser?.uid != _me) return;
      _marking = true;
      try {
        await ChatService.markRead(_me, Chat.idFor(_me, widget.otherUid), Timestamp.fromDate(latest));
        if (mounted) setState(() => _readThrough = latest);
      } catch (e) {
        debugPrint('Gagal menyimpan status baca: $e');
        if (mounted) {
          _retry = Timer(const Duration(seconds: 15), () {
            if (mounted) setState(() => _retry = null);
          });
        }
      } finally {
        _marking = false;
      }
    });
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _retry?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ChatService.send(
        fromUid: _me,
        fromName:
            ProfileService.instance.profile?.name ??
            AuthService.currentUser!.displayName ??
            'Pengguna',
        toUid: widget.otherUid,
        toName: widget.otherName,
        text: text,
      );
    } catch (_) {
      if (!mounted) return;
      // Kembalikan teks supaya tidak perlu diketik ulang
      if (_controller.text.isEmpty) _controller.text = text;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Pesan gagal dikirim. Coba lagi.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = ModalRoute.isCurrentOf(context) == true;
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _messages,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const EmptyStateWidget(
                    message: "Gagal memuat pesan.",
                    icon: Icons.cloud_off,
                  );
                }
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snap.data!;
                if (visible) _recordVisibleMessages(messages);
                if (messages.isEmpty) {
                  return EmptyStateWidget(
                    message:
                        "Sapa ${widget.otherName}\nuntuk memulai percakapan.",
                    icon: Icons.waving_hand_outlined,
                  );
                }
                // Daftar dibalik: pesan terbaru di indeks 0, tampil paling bawah
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final msg = messages[i];
                    final older = i + 1 < messages.length
                        ? messages[i + 1]
                        : null;
                    final newDay =
                        older == null ||
                        !_sameDay(older.createdAt, msg.createdAt);
                    return Column(
                      children: [
                        if (newDay) _DayLabel(date: msg.createdAt),
                        _Bubble(
                          message: msg,
                          mine: msg.senderId == _me,
                          chatId: Chat.idFor(_me, widget.otherUid),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildInput(context),
        ],
      ),
    );
  }

  Widget _buildInput(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 5,
                maxLength: ChatService.maxMessageLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: "Tulis pesan",
                  counterText: '',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            ValueListenableBuilder(
              valueListenable: _controller,
              builder: (context, value, _) => IconButton.filled(
                icon: const Icon(Icons.send),
                tooltip: "Kirim",
                onPressed: value.text.trim().isEmpty ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayLabel extends StatelessWidget {
  const _DayLabel({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        formatChatDay(date),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.chatId,
  });

  final ChatMessage message;
  final bool mine;
  final String chatId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = mine ? scheme.onPrimary : scheme.onSurface;

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? scheme.primary : scheme.surface,
          border: mine ? null : Border.all(color: scheme.outline),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(mine ? 14 : 4),
            bottomRight: Radius.circular(mine ? 4 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.activityPostId case final postId?)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: fg),
                icon: const Icon(Icons.directions_run),
                label: Text(message.text),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ActivityPostScreen(postId: postId),
                  ),
                ),
              )
            else
              Text(message.text, style: TextStyle(color: fg, fontSize: 15)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  formatTime(message.createdAt),
                  style: TextStyle(
                    color: fg.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
                if (mine) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.pending ? Icons.schedule : Icons.done,
                    size: 12,
                    color: fg.withValues(alpha: 0.7),
                  ),
                ],
              ],
            ),
            LikeButton(
              type: 'chatMessage',
              id: '${chatId}_${message.id}',
              compact: true,
            ),
          ],
        ),
      ),
    );
  }
}
