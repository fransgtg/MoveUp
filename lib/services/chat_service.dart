import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moveup/models/chat.dart';
import 'package:moveup/models/user_profile.dart';

class ChatService {
  static const maxMessageLength = 1000;
  static const _pageSize = 100;

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> get _profiles => _db.collection('publicProfiles');

  static CollectionReference<Map<String, dynamic>> get _chats => _db.collection('chats');

  // Dipanggil setiap profil disimpan atau dimuat, supaya akun lama juga masuk direktori
  static Future<void> publishProfile(UserProfile profile) =>
      _profiles.doc(profile.uid).set(PublicProfile.fromProfile(profile).toMap());

  // Email harus persis sama; nama dicocokkan dari awal kata pertama
  static Future<List<PublicProfile>> searchUsers(String query, {required String excludeUid}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final snap = q.contains('@')
        ? await _profiles.where('email', isEqualTo: q).limit(20).get()
        : await _profiles
            .where('nameLower', isGreaterThanOrEqualTo: q)
            .where('nameLower', isLessThan: '$q')
            .orderBy('nameLower')
            .limit(20)
            .get();
    return snap.docs.where((d) => d.id != excludeUid).map((d) => PublicProfile.fromMap(d.id, d.data())).toList();
  }

  // Diurutkan di perangkat supaya tidak perlu indeks komposit Firestore
  static Stream<List<Chat>> chatsOf(String uid) =>
      _chats.where('members', arrayContains: uid).snapshots().map((snap) {
        final chats = snap.docs.map(Chat.fromSnapshot).toList();
        chats.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return chats;
      });

  static Stream<List<ChatMessage>> messagesOf(String chatId) => _chats
      .doc(chatId)
      .collection('messages')
      .orderBy('createdAt', descending: true)
      .limit(_pageSize)
      .snapshots(includeMetadataChanges: true)
      .map((snap) => snap.docs.map(ChatMessage.fromSnapshot).toList());

  // Dokumen percakapan baru dibuat saat pesan pertama dikirim
  static Future<void> send({
    required String fromUid,
    required String fromName,
    required String toUid,
    required String toName,
    required String text,
  }) {
    final chatId = Chat.idFor(fromUid, toUid);
    final chatRef = _chats.doc(chatId);
    final batch = _db.batch()
      ..set(chatRef.collection('messages').doc(), {
        'senderId': fromUid,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(chatRef, {
        'members': chatId.split('_'),
        'names': {fromUid: fromName, toUid: toName},
        'lastMessage': text,
        'lastSenderId': fromUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    return batch.commit();
  }
}
