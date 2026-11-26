import 'package:flutter/material.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/models/friendship.dart';
import 'package:moveup/screens/chat_room_screen.dart';
import 'package:moveup/screens/user_search_screen.dart';
import 'package:moveup/services/auth_service.dart';
import 'package:moveup/services/chat_service.dart';
import 'package:moveup/services/friendship_service.dart';
import 'package:moveup/widgets.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  late final _uid = AuthService.currentUser?.uid;
  late final _friendships = FriendshipService.watch(_uid!);
  final _responding = <String>{};

  void _openSearch() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserSearchScreen()),
    );
  }

  Future<void> _respond(Friendship request, {required bool accept}) async {
    if (_responding.contains(request.id)) return;
    setState(() => _responding.add(request.id));
    try {
      final changed = await FriendshipService.respond(request, accept: accept);
      if (!mounted) return;
      if (changed) {
        final message = accept
            ? 'Permintaan pertemanan diterima.'
            : request.senderId == _uid
            ? 'Permintaan pertemanan dibatalkan.'
            : 'Permintaan pertemanan ditolak.';
        showSuccessMessage(context, message);
      } else {
        showErrorMessage(context, 'Permintaan ini sudah berubah.');
      }
    } catch (_) {
      if (mounted) {
        showErrorMessage(context, 'Gagal memperbarui permintaan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _responding.remove(request.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teman'),
        actions: [
          if (uid != null)
            IconButton(
              icon: const Icon(Icons.person_search),
              tooltip: 'Cari pengguna',
              onPressed: _openSearch,
            ),
        ],
      ),
      body: uid == null
          ? const EmptyStateWidget(
              message: 'Masuk dengan akun MoveUp untuk menambahkan teman.',
              icon: Icons.lock_outline,
            )
          : StreamBuilder<List<Friendship>>(
              stream: _friendships,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyStateWidget(
                    message: 'Gagal memuat daftar pertemanan.',
                    icon: Icons.cloud_off,
                  );
                }
                final friendships = snapshot.data;
                if (friendships == null) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView(
                  padding: const EdgeInsets.only(bottom: 24),
                  children: [
                    ..._section(
                      'Permintaan masuk',
                      'Belum ada permintaan masuk.',
                      friendships.where(
                        (f) => !f.isAccepted && f.senderId != uid,
                      ),
                      uid,
                    ),
                    ..._section(
                      'Permintaan terkirim',
                      'Belum ada permintaan terkirim.',
                      friendships.where(
                        (f) => !f.isAccepted && f.senderId == uid,
                      ),
                      uid,
                    ),
                    ..._section(
                      'Daftar teman',
                      'Belum ada teman.',
                      friendships.where((f) => f.isAccepted),
                      uid,
                    ),
                  ],
                );
              },
            ),
    );
  }

  List<Widget> _section(
    String title,
    String emptyMessage,
    Iterable<Friendship> entries,
    String uid,
  ) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      if (entries.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Text(emptyMessage),
        ),
      for (final friendship in entries)
        _FriendTile(
          key: ValueKey(friendship.id),
          otherUid: friendship.otherUid(uid),
          isFriend: friendship.isAccepted,
          outgoing: friendship.senderId == uid,
          busy: _responding.contains(friendship.id),
          onAccept: () => _respond(friendship, accept: true),
          onDismiss: () => _respond(friendship, accept: false),
        ),
    ];
  }
}

class _FriendTile extends StatefulWidget {
  const _FriendTile({
    super.key,
    required this.otherUid,
    required this.isFriend,
    required this.outgoing,
    required this.busy,
    required this.onAccept,
    required this.onDismiss,
  });

  final String otherUid;
  final bool isFriend;
  final bool outgoing;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  State<_FriendTile> createState() => _FriendTileState();
}

class _FriendTileState extends State<_FriendTile> {
  late final _profile = ChatService.watchProfile(widget.otherUid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PublicProfile?>(
      stream: _profile,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return ListTile(
          leading: CircleAvatar(
            child: profile == null
                ? const Icon(Icons.person_outline)
                : Text(profile.initials),
          ),
          title: Text(profile?.name ?? 'Pengguna MoveUp'),
          trailing: _actions(profile),
        );
      },
    );
  }

  Widget _actions(PublicProfile? profile) {
    if (widget.busy) {
      return const SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    if (widget.isFriend) {
      return IconButton(
        tooltip: 'Kirim pesan',
        icon: const Icon(Icons.chat_bubble_outline),
        onPressed: profile == null
            ? null
            : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChatRoomScreen(
                    otherUid: profile.uid,
                    otherName: profile.name,
                  ),
                ),
              ),
      );
    }
    if (widget.outgoing) {
      return TextButton(
        onPressed: widget.onDismiss,
        child: const Text('Batalkan'),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Tolak permintaan',
          icon: const Icon(Icons.close),
          onPressed: widget.onDismiss,
        ),
        TextButton(onPressed: widget.onAccept, child: const Text('Terima')),
      ],
    );
  }
}
