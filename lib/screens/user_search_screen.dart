import 'dart:async';

import 'package:flutter/material.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/screens/chat_room_screen.dart';
import 'package:moveup/services/auth_service.dart';
import 'package:moveup/services/chat_service.dart';
import 'package:moveup/widgets.dart';

// Cari pengguna lain berdasarkan awal nama atau email lengkap
class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  Timer? _debounce;
  String _query = '';
  bool _loading = false;
  String? _error;
  List<PublicProfile> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(value));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    setState(() {
      _query = query;
      _error = null;
      _loading = query.isNotEmpty;
      if (query.isEmpty) _results = [];
    });
    if (query.isEmpty) return;

    try {
      final results = await ChatService.searchUsers(query, excludeUid: AuthService.currentUser!.uid);
      // Abaikan hasil pencarian lama kalau pengguna sudah mengetik lagi
      if (!mounted || query != _query) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || query != _query) return;
      setState(() {
        _error = "Pencarian gagal. Periksa koneksi internet.";
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text("Cari Pengguna")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: _onChanged,
              onSubmitted: _search,
              decoration: const InputDecoration(
                hintText: "Nama atau email lengkap",
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? EmptyStateWidget(message: _error!, icon: Icons.cloud_off)
                : _query.isEmpty
                    ? const EmptyStateWidget(message: "Ketik nama atau email\nteman latihanmu.", icon: Icons.person_search)
                    : _results.isEmpty && !_loading
                        ? const EmptyStateWidget(message: "Pengguna tidak ditemukan.", icon: Icons.person_off_outlined)
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final user = _results[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: scheme.primary,
                                  foregroundColor: scheme.onPrimary,
                                  child: Text(user.initials),
                                ),
                                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                subtitle: Text(
                                  [user.level.label, ...user.favoriteSports.map((s) => s.label)].join(' · '),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: const Icon(Icons.chat_bubble_outline, size: 20),
                                onTap: () => Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => ChatRoomScreen(otherUid: user.uid, otherName: user.name)),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
