import 'package:cloud_firestore/cloud_firestore.dart';

class Friendship {
  const Friendship({
    required this.id,
    required this.members,
    required this.senderId,
    required this.isAccepted,
    required this.createdAt,
  });

  final String id;
  final List<String> members;
  final String senderId;
  final bool isAccepted;
  final Timestamp createdAt;

  static List<String> membersFor(String first, String second) =>
      [first, second]..sort();

  String otherUid(String uid) => members.firstWhere((member) => member != uid);

  factory Friendship.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Friendship(
      id: doc.id,
      members: List<String>.from(data['members'] as List),
      senderId: data['senderId'] as String,
      isAccepted: data['status'] == 'accepted',
      createdAt: data['createdAt'] as Timestamp,
    );
  }
}
