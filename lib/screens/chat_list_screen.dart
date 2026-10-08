import 'package:flutter/material.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/models/user_profile.dart';
import 'package:moveup/screens/chat_room_screen.dart';
import 'package:moveup/screens/user_search_screen.dart';
import 'package:moveup/services/auth_service.dart';
import 'package:moveup/services/chat_service.dart';
import 'package:moveup/utils/format.dart';
import 'package:moveup/widgets.dart';

// Daftar percakapan, terbaru di atas
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  void _openSearch(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const UserSearchScreen()));
  }

  @override
  Widget build(BuildContext context) {
    // Akun demo (AuthService.skipLogin) tidak login ke Firebase, jadi tidak bisa memakai chat
    final user = AuthService.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Pesan")),
        body: const EmptyStateWidget(
          message: "Chat butuh akun MoveUp.\nMasuk dengan email atau Google untuk mengobrol.",
          icon: Icons.lock_outline,
        ),
      );
    }
    final me = user.uid;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesan"),
        actions: [
          IconButton(icon: const Icon(Icons.person_search), tooltip: "Cari pengguna", onPressed: () => _openSearch(context)),
        ],
      ),
      body: StreamBuilder<List<Chat>>(
        stream: ChatService.chatsOf(me),
        builder: (context, snap) {
          if (snap.hasError) {
            return const EmptyStateWidget(message: "Gagal memuat percakapan.\nPeriksa koneksi internet.", icon: Icons.cloud_off);
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final chats = snap.data!;
          if (chats.isEmpty) {
            return const EmptyStateWidget(
              message: "Belum ada percakapan.\nCari teman latihan lewat ikon di atas.",
              icon: Icons.chat_bubble_outline,
            );
          }
          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
            itemBuilder: (context, i) {
              final chat = chats[i];
              final other = chat.otherUid(me);
              final name = chat.nameOf(other);
              final preview = chat.lastSenderId == me ? "Anda: ${chat.lastMessage}" : chat.lastMessage;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: scheme.primary,
                  foregroundColor: scheme.onPrimary,
                  child: Text(initialsOf(name)),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(formatChatTime(chat.updatedAt), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ChatRoomScreen(otherUid: other, otherName: name)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: "Percakapan baru",
        onPressed: () => _openSearch(context),
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }
}
