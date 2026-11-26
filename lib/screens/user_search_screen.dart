import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/models/friendship.dart';
import 'package:moveup/screens/chat_room_screen.dart';
import 'package:moveup/services/auth_service.dart';
import 'package:moveup/services/chat_service.dart';
import 'package:moveup/services/friendship_service.dart';
import 'package:moveup/widgets.dart';

// Cari pengguna lain berdasarkan awal nama atau email lengkap
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  late final _uid = AuthService.currentUser?.uid;
  late final _friendships = FriendshipService.watch(_uid!);
  final _sending = <String>{};
  Timer? _debounce;
  int _searchVersion = 0;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<PublicProfile> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value, {bool submit = false}) {
    _debounce?.cancel();
    final query = value.trim();
    final version = ++_searchVersion;
    setState(() {
      _query = query;
      _error = null;
      _loading = query.isNotEmpty;
      _results = [];
    });
    final uid = _uid;
    if (query.isEmpty || uid == null) return;
    if (submit) {
      _search(query, uid, version);
    } else {
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => _search(query, uid, version),
      );
    }
  }

  Future<void> _search(String query, String uid, int version) async {
    try {
      final results = await ChatService.searchUsers(query, excludeUid: uid);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _error = "Pencarian gagal. Periksa koneksi internet.";
        _loading = false;
      });
    }
  }

  Future<void> _sendRequest(String uid, String recipientId) async {
    if (_sending.contains(recipientId)) return;
    setState(() => _sending.add(recipientId));
    try {
      final sent = await FriendshipService.send(uid, recipientId);
      if (!mounted) return;
      if (sent) {
        showSuccessMessage(context, 'Permintaan pertemanan dikirim.');
      } else {
        showErrorMessage(context, 'Status pertemanan sudah berubah.');
      }
    } catch (_) {
      if (mounted) {
        showErrorMessage(context, 'Gagal mengirim permintaan. Coba lagi.');
      }
    } finally {
      if (mounted) setState(() => _sending.remove(recipientId));
    }
  }

  void _openChat(PublicProfile user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChatRoomScreen(otherUid: user.uid, otherName: user.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      appBar: AppBar(title: const Text("Cari Pengguna")),
      body: uid == null
          ? const EmptyStateWidget(
              message: 'Masuk dengan akun MoveUp untuk mencari pengguna.',
              icon: Icons.lock_outline,
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onChanged: _onChanged,
                    onSubmitted: (value) => _onChanged(value, submit: true),
                    decoration: const InputDecoration(
                      hintText: "Nama atau email lengkap",
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                if (_loading) const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: StreamBuilder<List<Friendship>>(
                    stream: _friendships,
                    builder: (context, snapshot) =>
                        _buildResults(uid, snapshot),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildResults(String uid, AsyncSnapshot<List<Friendship>> snapshot) {
    if (_error != null) {
      return EmptyStateWidget(message: _error!, icon: Icons.cloud_off);
    }
    if (_query.isEmpty) {
      return const EmptyStateWidget(
        message: 'Ketik nama atau email\nteman latihanmu.',
        icon: Icons.person_search,
      );
    }
    if (_loading) return const SizedBox.shrink();
    if (_results.isEmpty) {
      return const EmptyStateWidget(
        message: 'Pengguna tidak ditemukan.',
        icon: Icons.person_off_outlined,
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final byUser = {
      for (final friendship in snapshot.data ?? <Friendship>[])
        friendship.otherUid(uid): friendship,
    };
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final user = _results[i];
        final friendship = byUser[user.uid];
        final String? status;
        if (snapshot.hasError) {
          status = 'Status pertemanan tidak tersedia';
        } else if (friendship == null) {
          status = null;
        } else if (friendship.isAccepted) {
          status = 'Sudah berteman';
        } else {
          status = friendship.senderId == uid
              ? 'Permintaan terkirim'
              : 'Permintaan masuk';
        }

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primary,
            foregroundColor: scheme.onPrimary,
            child: Text(user.initials),
          ),
          title: Text(
            user.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                [
                  user.level.label,
                  ...user.favoriteSports.map((s) => s.label),
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (status != null) Text(status),
            ],
          ),
          isThreeLine: status != null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_sending.contains(user.uid))
                const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (friendship == null && !snapshot.hasError)
                IconButton(
                  tooltip: 'Tambah teman',
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: snapshot.hasData
                      ? () => _sendRequest(uid, user.uid)
                      : null,
                ),
              IconButton(
                tooltip: 'Kirim pesan',
                icon: const Icon(Icons.chat_bubble_outline, size: 20),
                onPressed: () => _openChat(user),
              ),
            ],
          ),
          onTap: () => _openChat(user),
        );
      },
    );
  }
}
