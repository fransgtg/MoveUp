import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moveup/models/activity.dart';
import 'package:moveup/models/user_profile.dart';

// Data profil yang boleh dilihat pengguna lain: publicProfiles/{uid}
class PublicProfile {
  const PublicProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.level,
    required this.favoriteSports,
  });

  final String uid;
  final String name;
  final String email;
  final FitnessLevel level;
  final List<SportType> favoriteSports;

  String get initials => initialsOf(name);

  factory PublicProfile.fromProfile(UserProfile p) => PublicProfile(
        uid: p.uid,
        name: p.name,
        email: p.email,
        level: p.level,
        favoriteSports: p.favoriteSports,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        // Firestore tidak punya pencarian tanpa huruf besar-kecil, jadi disimpan versi huruf kecilnya
        'nameLower': name.toLowerCase(),
        'email': email.toLowerCase(),
        'level': level.name,
        'favoriteSports': favoriteSports.map((s) => s.name).toList(),
      };

  factory PublicProfile.fromMap(String uid, Map<String, dynamic> map) => PublicProfile(
        uid: uid,
        name: map['name'] as String,
        email: map['email'] as String,
        level: FitnessLevel.values.byName(map['level'] as String),
        favoriteSports: ((map['favoriteSports'] as List?) ?? []).map((s) => SportType.fromName(s as String)).toList(),
      );
}

// Percakapan dua orang: chats/{uidA_uidB}, uid diurutkan supaya ID-nya selalu sama
class Chat {
  const Chat({
    required this.id,
    required this.members,
    required this.names,
    required this.lastMessage,
    required this.lastSenderId,
    required this.updatedAt,
  });

  final String id;
  final List<String> members;
  final Map<String, String> names;
  final String lastMessage;
  final String lastSenderId;
  final DateTime updatedAt;

  static String idFor(String a, String b) => (a.compareTo(b) < 0 ? [a, b] : [b, a]).join('_');

  String otherUid(String me) => members.firstWhere((m) => m != me, orElse: () => me);

  String nameOf(String uid) => names[uid] ?? 'Pengguna';

  factory Chat.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return Chat(
      id: doc.id,
      members: List<String>.from(map['members'] as List),
      names: Map<String, String>.from(map['names'] as Map),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastSenderId: map['lastSenderId'] as String? ?? '',
      updatedAt: (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

// chats/{chatId}/messages/{id}
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.pending,
  });

  final String id;
  final String senderId;
  final String text;
  final DateTime createdAt;

  // Belum sampai ke server; createdAt masih perkiraan waktu perangkat
  final bool pending;

  factory ChatMessage.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return ChatMessage(
      id: doc.id,
      senderId: map['senderId'] as String,
      text: map['text'] as String,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      pending: doc.metadata.hasPendingWrites,
    );
  }
}
