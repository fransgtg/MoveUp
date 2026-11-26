import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:moveup/models/friendship.dart';

class FriendshipService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;
  static CollectionReference<Map<String, dynamic>> get _friendships =>
      _db.collection('friendships');

  static Stream<List<Friendship>> watch(String uid) =>
      _friendships.where('members', arrayContains: uid).snapshots().map((snap) {
        final friendships = snap.docs
            .where((doc) => doc.data()['createdAt'] is Timestamp)
            .map(Friendship.fromSnapshot)
            .toList();
        friendships.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return friendships;
      });

  static Future<bool> send(String senderId, String recipientId) async {
    if (senderId == recipientId) return false;
    final members = Friendship.membersFor(senderId, recipientId);
    final ref = _friendships.doc(members.join(':'));

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (snapshot.exists) return false;
      transaction.set(ref, {
        'members': members,
        'senderId': senderId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    });
  }

  // Periksa permintaan yang sedang tampil sebelum mengubahnya. Permintaan lama
  // bisa sudah dibatalkan dan dikirim ulang oleh pengguna lain.
  static Future<bool> respond(Friendship request, {required bool accept}) {
    final ref = _friendships.doc(request.id);
    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) return false;
      final current = Friendship.fromSnapshot(snapshot);
      if (current.isAccepted ||
          current.createdAt != request.createdAt ||
          current.senderId != request.senderId) {
        return false;
      }
      if (accept) {
        transaction.update(ref, {'status': 'accepted'});
      } else {
        transaction.delete(ref);
      }
      return true;
    });
  }
}
